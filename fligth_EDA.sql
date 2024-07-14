------------------------------------EDA TABLA FLIGHT------------------------------------------------------------


select column_name, data_type 
from information_schema.columns 
where
    table_name = 'flight';
     
--Columnas INT
   --id_aircraft (identificador del avión) INT (en la tabla airplanes era VARCHAR)
   --at_cd_fligth_number (número de vuelo que tiene el pairing) INT
   
--Columnas VARCHAR
   --at_cd_airport_orig (Aeropuerto de salida)
   --at_cd_airport_dest (Aeropuerto de destino)
   --at_cd_airline_code
   --at_cd_leg (tipología de vuelo en caso de que aplique)
   
--Columnas DATE
   --at_dt_flight_date (Fecha de vuelo)
   
--Columnas TIMESTAMP without time zone
   --at_ts_std_utc (hora programa de salida UTC)
   --at_ts_sta_utc (hora programa de llegada UTC)
   
select count(*) AS count
from flight; 

--Dimensionalidad de la tabla: 2899/9

select * 
from flight  

-- Comprobamos existencia de nulos en toda la tabla

select
	count(*) - count(at_cd_leg) as at_cd_leg,
	count(*) - count(at_dt_flight_date) as nulos_at_dt_flight_date,
	count(*) - count(at_cd_airline_code) as nulos_at_cd_airline_code,
	count(*) - count(at_cd_airport_orig) as nulos_at_cd_airport_orig,
	count(*) - count(at_cd_airport_dest) as nulos_at_cd_airport_dest,
	count(*) - count(at_ts_std_utc) as nulos_at_ts_std_utc,
	count(*) - count(at_ts_sta_utc) as nulos_at_ts_sta_utc,
	count(*) - count(id_aircraft) as nulos_id_aircraft,
	count(*) - count(at_cd_flight_number) as nulos_at_cd_flight_number
from flight;

-- No tenemos nulos. Estaremos pendientes de otro tipo de inconsistencias de los datos (0 o valores atípicos)


--columna at_cd_flight_number (número de vuelo que tiene el pairing)

select distinct at_cd_flight_number, count(*)
from flight
group by at_cd_flight_number
order by count desc;

--los números de vuelos con más vuelos son 123, 1.401, 2.510, 6.140

--Columna at_cd_leg (Identificación la tipología. VARCHAR)


select distinct at_cd_leg, count(at_cd_flight_number)
from flight f 
group by at_cd_leg; 

--Es campo numérico con valores de texto
--SIN cd_leg: 2.887 (asumimos que en la mayoría de vuelos no se ha identificado su tipología)
-- A: 5 (arrival?)
-- D: 1 (departure?)
-- P: 6 (?)


--En todo caso los valores que tienen un cd_leg son marginales y podríamos obviarlos (12 registros de 2899)


--Columna at_dt_flight_date (fecha del vuelo YYYY-MM-DD)

--Determinamos el rango de fechas. 

select 
    min(at_dt_flight_date) as minimo, --(2019-10-25)
    max(at_dt_flight_date) as maximo --(2019-10-29)
from flight;

--Tenemos entonces 2899 registros de vuelo dentro del rango del 25 de octubre de 2019 al 29 de octubre de 2019. 

--Contamos el número de vuelos por cada una de las fechas, establecemos las prorciones y los días de la semana de cada conjunto de vuelos. 

select 
    at_dt_flight_date, 
    to_char(at_dt_flight_date, 'Day') as day_of_week,
    count(at_cd_flight_number) as flight_count,
    round(count(at_cd_flight_number) * 100.0 / total.total_count, 2) as percentage
from flight,
    (select count(at_cd_flight_number) as total_count from flight) as total
group by at_dt_flight_date, to_char(at_dt_flight_date, 'Day'), total.total_count
order by at_dt_flight_date;

-- El rango de fechas cubre de Viernes a Martes. El viernes es el día con más vuelos y el martes con menos. 


--Columna at_cd_airline_code (VARCHAR)

select at_cd_airline_code, count(*)
from flight 
group by at_cd_airline_code
order by count desc; 

-- Todos los vuelos tienen asignado un código de aerolinea de la siguiente manera. 
--VY (vueling) 2.871
--XXX: marcador determinado para errores o valores faltantes. No es un código. 22
--UX: Air Europa. 2
--U2: Easy Jet. 2
--I2: Iberia Express. 1
--IB: Iberia.1

--Tenemos que recordar que este código también está presente en la tabla flights pero allí solo aparecen los códigos de VY y VK
--Esto es la si hacemos un join solo tendremos información completa para los vuelos de VY que son la mayoría. 


--Columna at_cd_airport_orig (VARCHAR)

select 
    at_cd_airport_orig, 
    count(*) as flight_count,
    round(count(*) * 100.0 / total.total_count, 2) as percentage
from flight,
    (select count(*) as total_count from flight) as total
group by at_cd_airport_orig, total.total_count
order by flight_count desc;

--Todos los vuelos tienen código de aeropuerto de origen. 
--De lejos el aeropuerto con mayor número de vuelos en origen es BCN con 903, el 31.15% seguido de con el aeropuerto PMI (Palma de Mayorca) 126 vuelos y 4.35


--Columna at_cd_airport_dest (VARCHAR)

select 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / total.total_count, 2) as percentage
from flight,
    (select count(*) as total_count from flight) as total
group by at_cd_airport_dest, total.total_count
order by flight_count desc;

--El aeropuerto de llegada con más vuelos también es Barcelona con 898 (30.98) seguido también del aeropuerto de Palma con 4.31

--Parejas origen destino más populares, conteo y porcentaje. 

select 
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / total.total_count, 2) as percentage
from flight,
    (select count(*) as total_count from flight) as total
group by at_cd_airport_orig, at_cd_airport_dest, total.total_count
order by flight_count desc;

--Las rutas más populares son las que vuelan desde y hasta Palma de Mallorca, desde y hasta Barcelona. 
--También incluimos la ruta ORY-BCN, BCN-MAD, BCN-ORY y MAD-BCN
--Es decir Barcelona - Palma; Barcelona - Madrid; Barcelona - Paris. 


--Emparejamientos más populares por cada día de la semana
with total_flights as (
    select count(*) as total_count from flight
)
select 
    at_dt_flight_date,
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week,
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / (select total_count from total_flights), 2) as percentage
from flight
where trim(to_char(at_dt_flight_date, 'Day')) = 'Friday'
group by at_dt_flight_date, trim(to_char(at_dt_flight_date, 'Day')), at_cd_airport_orig, at_cd_airport_dest
order by at_dt_flight_date, flight_count desc
--limit 6; 

--Viernes: PMI - BCN / BCN - PMI / BCN - ORY / BCN - IBZ / BCN - MAD. Número máximo de vuelos por ruta 12

with total_flights as (
    select count(*) as total_count from flight
)
select 
    at_dt_flight_date,
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week,
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / (select total_count from total_flights), 2) as percentage
from flight
where trim(to_char(at_dt_flight_date, 'Day')) = 'Saturday'
group by at_dt_flight_date, trim(to_char(at_dt_flight_date, 'Day')), at_cd_airport_orig, at_cd_airport_dest
order by at_dt_flight_date, flight_count desc
limit 6; 

--Sábado: PMI - BCN / BCN - PMI / IBZ - BCN / BCN - LGW / BCN - IBZ. Número máximo de vuelos por ruta 11

with total_flights as (
    select count(*) as total_count from flight
)
select 
    at_dt_flight_date,
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week,
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / (select total_count from total_flights), 2) as percentage
from flight
where trim(to_char(at_dt_flight_date, 'Day')) = 'Sunday'
group by at_dt_flight_date, trim(to_char(at_dt_flight_date, 'Day')), at_cd_airport_orig, at_cd_airport_dest
order by at_dt_flight_date, flight_count desc
limit 6; 

--Domingo: PMI - BCN / BCN - PMI / ORY - BCN / BCN - MAD / BCN - ORY. Número máximo de vuelos por ruta 11 

with total_flights as (
    select count(*) as total_count from flight
)
select 
    at_dt_flight_date,
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week,
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / (select total_count from total_flights), 2) as percentage
from flight
where trim(to_char(at_dt_flight_date, 'Day')) = 'Monday'
group by at_dt_flight_date, trim(to_char(at_dt_flight_date, 'Day')), at_cd_airport_orig, at_cd_airport_dest
order by at_dt_flight_date, flight_count desc
limit 6; 

--Lunes: MAD - BCN / PMI - BCN / BCN - PMI / BCN - MAD / BCN - ORY. Número máximo de vuelos por ruta 10

with total_flights as (
    select count(*) as total_count from flight
)
select 
    at_dt_flight_date,
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week,
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    count(*) as flight_count,
    round(count(*) * 100.0 / (select total_count from total_flights), 2) as percentage
from flight
where trim(to_char(at_dt_flight_date, 'Day')) = 'Tuesday'
group by at_dt_flight_date, trim(to_char(at_dt_flight_date, 'Day')), at_cd_airport_orig, at_cd_airport_dest
order by at_dt_flight_date, flight_count desc
--limit 6; 

--Martes: BCN - PMI / PMI - BCN / MAD - BCN / BCN - MAD / BCN - SVQ (Sevilla). Número máximo de vuelos por ruta 10

--En resumen podemos decir que las rutas con más vuelos en el período de tiempo son aquellas que incluyen a las ciudades de
--Barcelona, Palma, Madrid, Paris e Ibiza. 



--Columna at_ts_std_utc (hora programa de salida std)

--Revisamos primero que no haya irregularidades en la info 

select at_ts_std_utc, count(*)
from flight 
group by at_ts_std_utc
order by count desc; 

--Todos los vuelos tienen hora de salida
--Agruparemos por día de la semana para entender el patron horario de salidas por día. 

select 
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week, 
    at_ts_std_utc, 
    count(*)
from flight 
where trim(to_char(at_dt_flight_date, 'Day')) = 'Friday'
group by trim(to_char(at_dt_flight_date, 'Day')), at_ts_std_utc
order by count desc;

--El viernes la mayor cantidad de vuelos (16) tienen hora de programada de salida a las 5 de la mañana. 
-- Otras horas populares de salida son las 15:40, las 18:30, las 4:50 y las 5:30 todas ellas con 8 vuelos. 

select 
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week, 
    at_ts_std_utc, 
    count(*)
from flight 
where trim(to_char(at_dt_flight_date, 'Day')) = 'Saturday'
group by trim(to_char(at_dt_flight_date, 'Day')), at_ts_std_utc
order by count desc;

--El sábado la mayor cantidad de vuelos (14) tienen hora de programada de salida a las 5 de la mañana. 
-- Otras horas populares de salida son las 4.50 (10) y 15:40 y 18:30 con 8 vuelos.

select 
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week, 
    at_ts_std_utc, 
    count(*)
from flight 
where trim(to_char(at_dt_flight_date, 'Day')) = 'Sunday'
group by trim(to_char(at_dt_flight_date, 'Day')), at_ts_std_utc
order by count desc;

--El domingo la mayor cantidad de vuelos (14) tienen hora de programada de salida a las 6 de la mañana. 
-- Otras horas populares de salida son las 18:15 (9) y 11:45(8).

select 
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week, 
    at_ts_std_utc, 
    count(*)
from flight 
where trim(to_char(at_dt_flight_date, 'Day')) = 'Monday'
group by trim(to_char(at_dt_flight_date, 'Day')), at_ts_std_utc
order by count desc;

--El lunes la mayor cantidad de vuelos (14) tienen hora de programa de salida a las 6 de la mañana. 
-- Otras horas populares de salida son las 20:25 (7) y las 12:20 (6).

select 
    trim(to_char(at_dt_flight_date, 'Day')) as day_of_week, 
    at_ts_std_utc, 
    count(*)
from flight 
where trim(to_char(at_dt_flight_date, 'Day')) = 'Tuesday'
group by trim(to_char(at_dt_flight_date, 'Day')), at_ts_std_utc
order by count desc;

--El lunes la mayor cantidad de vuelos (14) tienen hora de programa de salida a las 6 de la mañana. 
-- Otras horas populares de salida son las 18:15 (7) y las 20:45 (6).


--Con las horas de salida y llegada programadas también podemos calcular el tiempo programado de vuelo por emparejamiento de destinos
--en horas. 

select 
    at_cd_airport_orig, 
    at_cd_airport_dest, 
    round(avg(extract(epoch from (at_ts_sta_utc - at_ts_std_utc)) / 3600),3) as avg_flight_time_hours
from flight
group by at_cd_airport_orig, at_cd_airport_dest
order by avg_flight_time_hours desc;

--Podemos ordenar por destinos más largos o más cortos o buscar el promedio de tiempo de emparejamientos específicos. 


--Columna id_aircraft. Comprobamos que todos los vuelos tengan identificado el avión y que no hayan datos raros. 
select 
    id_aircraft, 
    count(*) as flight_count,
    round(count(*) * 100.0 / total.total_count, 2) as percentage
from flight,
    (select count(*) as total_count from flight) as total
group by id_aircraft, total.total_count
order by flight_count desc;

--los aviones con el id 832, 33, 233 y 28 son los que más viajan (podemos obtener más info de estos aviones haciendo join con la tabla aircraft)

--Revisemos qué vuelos por día han hecho estos aviones

--VUELO 832

with aircraft_flights as (
    select 
        id_aircraft,
        at_cd_flight_number,
        at_cd_airport_orig,
        at_cd_airport_dest,
        at_dt_flight_date,
        at_ts_std_utc,
        at_ts_sta_utc,
        at_cd_leg,
        lag(at_ts_sta_utc) over (partition by id_aircraft order by id_aircraft, at_dt_flight_date, at_ts_std_utc) as prev_arrival
    from 
        flight
)
select
    af.id_aircraft,
    a.at_cd_equipment_type,
    af.at_cd_flight_number,
    af.at_cd_airport_orig,
    af.at_cd_airport_dest,
    af.at_dt_flight_date,
    af.at_ts_std_utc,
    af.at_ts_sta_utc,
    af.at_cd_leg,
    round(extract(epoch from (af.at_ts_std_utc - af.prev_arrival)) / 60, 2) as minutes_between_flights
from
    aircraft_flights af
left join aircraft a on cast(af.id_aircraft as varchar) = a.id_aircraft
--where af.at_dt_flight_date = '2019-10-25'
order by
	af.id_aircraft,
    af.at_dt_flight_date,
    af.at_ts_std_utc;
  


--Emparejamiento de vuelos más populares cada día por hora de salida y tiempo programado de ruta. 

--Revisar si un mismo fligth_number tiene varios vuelos de salida y el mismo día y establecer sus ruta diaria

--flight_number con mayor número de vuelos en el período 123, 1.401, 2.510, 6.140
   
   create view flights_types_airports_hours as
with aircraft_flights as (
    select 
        id_aircraft,
        at_cd_flight_number,
        at_cd_airport_orig,
        at_cd_airport_dest,
        at_dt_flight_date,
        at_cd_airline_code,
        at_ts_std_utc,
        at_ts_sta_utc,
        at_cd_leg,
        lag(at_ts_sta_utc) over (partition by id_aircraft order by id_aircraft, at_dt_flight_date, at_ts_std_utc) as prev_arrival
    from 
        flight
)
select
    af.id_aircraft,
    a.at_cd_equipment_type,
    af.at_cd_flight_number,
    af.at_cd_airport_orig,
    af.at_cd_airport_dest,
    af.at_dt_flight_date,
    af.at_cd_airline_code,
    af.at_ts_std_utc,
    af.at_ts_sta_utc,
    af.at_cd_leg,
    round(extract(epoch from (af.at_ts_std_utc - af.prev_arrival)) / 60, 2) as minutes_between_flights
from
    aircraft_flights af
left join aircraft a on cast(af.id_aircraft as varchar) = a.id_aircraft
order by
    af.id_aircraft,
    af.at_dt_flight_date,
    af.at_ts_std_utc;
    
select *
from flights_types_airports_hours
where at_dt_flight_date = '2019-10-25'

--Examinamos los registros por cada tipo de id_craft y revisamos si existen registros irregulares. En este caso id_aircraft
-- -1 y 1 no tienen información sobre at_cd_equipment_type.
