/*
 Cliente: Área de negocio de Crew
 Solicitud: Busca un análisis detallado que les permita conocer, por pairing y día, las Horas de Firma de cada tripulación,
 diferenciando por aeropuerto y tipo de vuelo. También desea optimizar esos tiempos , minimizando la antelación necesaria.
 
 Ejercio 1
 Preguntas que hay que responder en el análisis:
 1- ¿ A qué hora debe firmar cada tripulación por pairing y día?
 2- ¿Cómo afecta la elección del aeropuerto de salida en la hora de la firma requerida?
   
 Ejercicio 2
 Preguntas:
 1. ¿Cuál es la FDP y la FDP Máximo para cada pairing
 2. ¿Cómo se distribuyen los pairing a lo largo de las distintas bases y tipos de avion?
 
  */

-- Ejercicio 1

---------------------------------------------CREACIÓN DE VISTA flights_types_airports_hours------------------------------------------------------------------
/*
 Objetivo del equipo de data: crear una vista que nos ordena la información necesaria para comenzar a pensar 
 en una solución al ejercio 1.
 La misma contiene los siguientes campos 
 
 - id_aircraft: identificar el avion
 - a.at_cd_equipment_type: identificar el tipo de aeronave
 - af.at_cd_flight_number: identificar el numero de vuelo
 - af.at_cd_airport_orig: identificar el aeropuerto de origen
 - af.at_cd_airport_dest: identificar el aeropuerto de destino
 - af.at_dt_flight_date: identificar el dia del vuelo
 - af.at_cd_airline_code: identificar la aerolinea
 - af.at_ts_std_utc: identificar departure utc
 - af.at_ts_sta_utc: identificar arrival utc
 - af.at_cd_leg: identificar la tipología del vuelo
 - minutes_between_flights: identificar minutos entre cada salto o sector(1) 

(1)Entiendo salto o sector como el tiempo transcurridos en minutos entre que un avion llega a un aeropuerto y vuelve a salir. 
 
 **/

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

------------------------------------------------CREACIÓN DE VISTA PRIMER VUELO---------------------------------------------
/* Objetivo:

1) Tener en una vista la información acerca 
     - de cuál es el primer vuelo de una rotación asignado a una crew, teniendo en cuenta que el negocio definió rotación 
     como el  'conjunto de vuelos consecutivos que realiza un avión a lo largo del día'. Y a un pairing al conjunto de vuelos 
     asignados a una tripulación definida concreta. (rank= 1)
     - el aeropuerto de salida (at_cd_airport_orig)
   	 - el tipo de vuelo: si es posicional o operacional (at_is_dhc_flight)
   	 - el tipo de avion (at_cd_equipment_type)
 2) además necesitamos saber
   	 - la cantidad de horas de ese vuelo: hora (nos interesa saber si es menor igual a 3 o mayor a 3)
   	 - si el avion es a319/a320 (tipo_avion2)
   	 - si el avion es a321 (tipo_avion)
   	 - si el aeropuerta de salida es BCN (bcn)
   	 - si el aeropuerto de salida es FCO, ORY, AMS (aerop_60)
   	 - si el aeropuerto de salida es ALC/MAD (mad_alic)
   	 - si el vuelo es posicional (posicional)
   	 - y si refiere a ground_carrier (ground_carrier)
   	 
  */
   	  
-- drop view primer_vuelo;
create view primer_vuelo as (
with cte as(
select 
	p.at_ds_flight_crew_code, 
	p.at_is_dhc_flight, f.*, 
	rank() over(partition by p.at_ds_flight_crew_code, 
	date_part('day', p.at_dt_flight_date) order by  p.at_dt_flight_date asc, f.at_ts_std_utc asc),
	at_cd_equipment_type
from 
	pairing p  
join 
	flight f 
	on p.at_cd_flight_number = f.at_cd_flight_number 
	and p.at_dt_flight_date  = f.at_dt_flight_date 
	and p.at_cd_airline_code = f.at_cd_airline_code 
	and p.at_cd_airport_orig = f.at_cd_airport_orig
	and p.at_cd_leg = f.at_cd_leg
join 
	aircraft a 
	on f.id_aircraft::varchar = a.id_aircraft
order by p.at_ds_flight_crew_code , p.at_dt_flight_date asc, f.at_ts_std_utc asc)

select *, 
	date_part('hour',age(at_ts_sta_utc, at_ts_std_utc)) as hora,
	case when date_part('hour',age(at_ts_sta_utc, at_ts_std_utc)) > 2 then 1 else 0 end as superior_3h,
	case when at_cd_equipment_type = '321'then 1 else 0 end as tipo_avion,
	case when at_cd_airport_orig in('FCO','ORY','AMS') then 1 else 0 end as aerop_60,
	case when at_cd_airport_orig in('MAD', 'ALC') then 1 else 0 end as mad_alic,
	case when at_is_dhc_flight then 1 else 0 end as posicional,
	case when at_cd_airport_orig = 'BCN'then 1 else 0 end as bcn,0 as ground_carrier,
	case when at_cd_equipment_type = '320' or at_cd_equipment_type = '319' then 1 else 0 end as tipo_avion2
from cte
where rank = 1);

select *
from primer_vuelo

-----------------------------------------CREACIÓN DE VISTA DE CANTIDAD DE PRIMEROS VUELOS POR AEROPUERTO--------------------------

with cte as(
	select 
		p.at_ds_flight_crew_code, 
		f.*, rank() over(partition by p.at_ds_flight_crew_code, 
		date_part('day', p.at_dt_flight_date)
order by  
	p.at_dt_flight_date asc, 
	f.at_ts_std_utc asc)
from 
	pairing p  
	join flight f 
	on p.at_cd_flight_number = f.at_cd_flight_number 
	and p.at_dt_flight_date  = f.at_dt_flight_date 
	and p.at_cd_airline_code = f.at_cd_airline_code
	and p.at_cd_airport_orig = f.at_cd_airport_orig
	and p.at_cd_leg = f.at_cd_leg
order by 
	p.at_ds_flight_crew_code, 
	p.at_dt_flight_date asc, 
	f.at_ts_std_utc asc)

select 
	at_cd_airport_orig, 
	count(1) as q_primer_vuelo
from cte
where rank = 1
group by at_cd_airport_orig
order by count(1) desc;


-------------------------------------------------CREACIÓN DE VISTA PARA PRIMERA FIRMA--------------------------------------
--Objetivo: crear una vista para determinar la hora de firma de cada crew.

create view primer_vuelo_firma as
(
with primer_vuelo as (
    with cte as (
        select
            p.at_ds_flight_crew_code,
            p.at_is_dhc_flight,
            f.*,
            rank() over(
                partition by p.at_ds_flight_crew_code, date_part('day', p.at_dt_flight_date)
                order by p.at_dt_flight_date asc, f.at_ts_std_utc asc
            ) as rank,
            a.at_cd_equipment_type
        from pairing p  
        join flight f on p.at_cd_flight_number = f.at_cd_flight_number
            and p.at_dt_flight_date = f.at_dt_flight_date
            and p.at_cd_airline_code = f.at_cd_airline_code
            and p.at_cd_airport_orig = f.at_cd_airport_orig
            and p.at_cd_leg = f.at_cd_leg
        join aircraft a on f.id_aircraft::varchar = a.id_aircraft
        order by p.at_ds_flight_crew_code, p.at_dt_flight_date asc, f.at_ts_std_utc asc
    )
    select
        *,
        date_part('hour', age(at_ts_sta_utc, at_ts_std_utc)) as hora,
        case when date_part('hour', age(at_ts_sta_utc, at_ts_std_utc)) > 2 then 1 else 0 end as superior_3h,
        case when at_cd_equipment_type = '321' then 1 else 0 end as tipo_avion,
        case when at_cd_airport_orig in ('FCO', 'ORY', 'AMS') then 1 else 0 end as aerop_60,
        case when at_cd_airport_orig in ('MAD', 'ALC') then 1 else 0 end as mad_alic,
        case when at_is_dhc_flight then 1 else 0 end as posicional,
        case when at_cd_airport_orig = 'BCN' then 1 else 0 end as bcn,
        0 as ground_carrier,
        case when at_cd_equipment_type = '320' or at_cd_equipment_type = '319' then 1 else 0 end as tipo_avion2
    from cte
    where rank = 1
)
select
    pv.*,
    case
        when superior_3h = 1 and posicional = 0 then 60
        when posicional = 1 then 45
        when aerop_60 = 1 then 60
        when tipo_avion = 1 then 55
        when bcn = 1 then 55
        when mad_alic = 1 then 50
        when tipo_avion2 = 1 then 45
        when ground_carrier = 1 then 15
        else 45
    end as tiempo_firma,
    at_ts_std_utc - interval '1 minute' * (
        case
            when superior_3h = 1 and posicional = 0 then 60
            when posicional = 1 then 45
            when aerop_60 = 1 then 60
            when tipo_avion = 1 then 55
            when bcn = 1 then 55
            when mad_alic = 1 then 50
            when tipo_avion2 = 1 then 45
            when ground_carrier = 1 then 15
            else 45
        end
    ) as hora_firma_utc, (pv.at_ts_std_utc - interval '1 minute' * (
        case
            when superior_3h = 1 and posicional = 0 then 60
            when posicional = 1 then 45
            when aerop_60 = 1 then 60
            when tipo_avion = 1 then 55
            when bcn = 1 then 55
            when mad_alic = 1 then 50
            when tipo_avion2 = 1 then 45
            when ground_carrier = 1 then 15
            else 45
        end
    ) ) + interval '1 minute' * vz.at_min_variation as hora_local_firma,
    pv.at_ts_std_utc + interval '1 minute' * vz.at_min_variation as local_std_time,
    pv.at_ts_sta_utc + interval '1 minute' * vz.at_min_variation as local_sta_time,
    vz.at_min_variation
from
    primer_vuelo pv
left join
    variation_zone vz
on
    pv.at_cd_airport_orig = vz.at_cd_airport
    and pv.at_ts_std_utc between vz.at_dt_start_date_utc and vz.at_dt_end_date_utc
order by
    pv.at_cd_airport_orig, pv.at_ts_std_utc
);



select *
from primer_vuelo_firma
where at_ds_flight_crew_code ='PM03T';

--- Empezamos a responder a los requerimientos del negocio

----------------------------------------------SEPARAR DIA Y HORA------------------------------------------------------------------
-- Ojetivo: crear el listado de dia, hora y aeropuerto de firma para cada crew.

drop view listado_de_firmas;

create view listado_de_firmas as (
   SELECT 
    at_ds_flight_crew_code,
    at_cd_airport_orig as aeropuerto,
    hora_local_firma::date AS fecha,
    TRIM(TO_CHAR(hora_local_firma, 'Day')) AS day_of_week,
    hora_local_firma::time AS hora
    
FROM
    primer_vuelo_firma
GROUP BY 
    at_ds_flight_crew_code,
     at_cd_airport_orig,
    hora_local_firma::date,
    TRIM(TO_CHAR(hora_local_firma, 'Day')),
    hora_local_firma::time
   );
   
   select * from listado_de_firmas;
   
  
  -- Compara las diferencias de horas de firma para varios aeropuertos comunes y diferentes tipos de aviones
 
 -- Pregunta 1:
 -- -- ¿cómo afecta la elección del aeropuerto de salida en la hora de la firma requerisa ?  
 -- Ojetivo: 
 -- 1) segmentar el cronograma de horarios en turnos o franjas horarias para poder ver
 -- la información de manera más organizada y analizar los puntos más altos de operación por aeropuerto 
 -- 2) ver una hs promedio de firma 
 
  
  SELECT 
    aeropuerto,
    SUM(CASE WHEN hora::time BETWEEN '00:01' AND '06:00' THEN 1 ELSE 0 END) AS turno_madrugada,
    SUM(CASE WHEN hora::time BETWEEN '06:01' AND '12:00' THEN 1 ELSE 0 END) AS turno_mañana,
    SUM(CASE WHEN hora::time BETWEEN '12:01' AND '18:00' THEN 1 ELSE 0 END) AS turno_tarde,
    SUM(CASE WHEN hora::time BETWEEN '18:01' AND '00:00' THEN 1 ELSE 0 END) AS turno_vespertino,
    COUNT(*) AS cantidad_de_firmas,
    COUNT(*) * 100 / (SELECT COUNT(*) FROM listado_de_firmas) AS proporción,
    avg(hora)::time as hora_promedio_de_firma
 FROM 
    listado_de_firmas
GROUP BY
    aeropuerto
ORDER BY 
    cantidad_de_firmas desc;
   
-- Conclusión: como podemos ver el aeropuerto de BCN es el aeropuerto con más procesos de firma sucediendo de manera
-- simultanea, sobre todo en los turnos mañana y tarde.
-- Luego en el top 10 de primeros vuelos le sigue el aeropuerto de Roma (FCO), Alicante (ALC), Bilbao (BIO), Málaga(AGP), Sevilla (SBQ), PARIS(ORY),
-- Paris (CDG), Palma de Mallorca (PMI), Madrid (MAD).

   
 -- Pregunta 2: 
 -- ¿Cómo afecta la hora de la firma por diferentes tipos de aviones?
-- Objetivo: Ver como puede afectar a los aeropuertos de Madrid y Alicante el tipo de avión del primer vuelo.
 
   WITH total_por_aeropuerto AS (
    SELECT 
        at_cd_airport_orig,
        COUNT(*) AS total_aviones
    FROM 
        primer_vuelo_firma
    GROUP BY 
        at_cd_airport_orig
)
SELECT 
    p.at_cd_airport_orig,
    p.at_cd_equipment_type,
    COUNT(*) AS cantidad_aviones,
    ROUND(COUNT(*) * 100.0 / t.total_aviones, 2) AS porcentaje_aviones,
    p.tiempo_firma,
    CASE 
        WHEN p.hora > 3 THEN 'horario_por_duracion_vuelo'
        WHEN p.at_is_dhc_flight = true THEN 'horario_posicional'
        WHEN p.at_cd_airport_orig = 'ALC' AND p.tiempo_firma = 55 THEN 'horario_avion' 
        WHEN p.at_cd_airport_orig = 'MAD' AND p.tiempo_firma = 55 THEN 'horario_avion' 
        ELSE 'horario aeropuerto'
    END AS determinacion_motivo_horario
FROM 
    primer_vuelo_firma p
JOIN 
    total_por_aeropuerto t ON p.at_cd_airport_orig = t.at_cd_airport_orig
WHERE 
    p.at_cd_airport_orig IN ('MAD','ALC') 
GROUP BY 
    p.at_cd_airport_orig, p.at_cd_equipment_type, p.tiempo_firma, t.total_aviones, p.hora, p.at_is_dhc_flight
ORDER BY 
    cantidad_aviones DESC, p.at_cd_airport_orig;

   
-- Conclusión: 
-- Solo afecta en los aeropuertos que no tienen prestablecido un tiempo de firma previo al vuelo.
-- En los aeropuertos que tienen prestablecido su tiempo previo para la firma, el unico que podría ser afectado
-- serían los aeropuertos de Alicante y Madrid y solo en el caso de aviones tipo a321 (pasaría de '50 a '55 min).
-- De todos modos, esto no sucede porque no hay primeros vuelos con este tipo de aviones en estos aeropuertos.

--- OTROS ANÁLISIS PARA ENTENDER EL RANGO DE ACCIÓN DEL NEGOCIO EN LA OPTIMIZACIÓN:
   
----------- Aviones de cada tipo para ver cuánto podría afectarnos en nuestra operación:
   
select 
	a.at_cd_equipment_type, 
	round(avg(mt_seats),2) as promedio_asientos, 
	count(1) as total_de_aviones
from 
	aircraft a
where  
	a.at_cd_equipment_type = '321' or  a.at_cd_equipment_type = '320' or  a.at_cd_equipment_type = '319'
group by 
	a.at_cd_equipment_type
order by 
	promedio_asientos desc; -- aviones 321 con mas asientos -> mas antelacion

-- Conclusión: presominan los aviones medianos, menos tiempo para la firma.
	
----------------- Vuelos posicionales y operacionales por aeropuerto
--Objetivo: ver la proporción de los primeros vuelos por estas categorías, para entender cómo podría afectarnos
-- al momento de la firma 
	
	--drop view tipo_vuelo

create view tipo_vuelo as(
select 
	at_cd_airport_orig,
	COUNT(*) as cantidad_primeros_vuelos,
	ROUND(sum(case when at_is_dhc_flight = true then 1 else 0 end) * 100.0 / count(*),2) as vuelos_posicionales,
	ROUND(sum(case when at_is_dhc_flight != true then 1 else 0 end)* 100.0/ count(*),2) as vuelos_operacionales
from
	primer_vuelo_firma
group by at_cd_airport_orig
order by cantidad_primeros_vuelos desc
);

select *
from tipo_vuelo

select 
	round(avg(cantidad_primeros_vuelos),2) as promedio_cantidad_de_primeros_vuelos,
	round(avg(vuelos_posicionales),2) as promedio_primeros_vuelos_posicionales,
	round(avg(vuelos_operacionales),2) as promedio_primeros_vuelos_operacionales
from tipo_vuelo;

--------------------- cada aeropuerto cuantos vuelos >3h cuantos <3h y el ratio sup/inferior (primer vuelo)

SELECT 
    at_cd_airport_orig, 
    COUNT(1) FILTER (WHERE superior_3h = 1) AS sup, 
    COUNT(1) FILTER (WHERE superior_3h = 0) AS inf,
    ROUND(CAST(COUNT(1) FILTER (WHERE superior_3h = 1) AS numeric) / COUNT(1) * 100, 2) AS prop_vuelos_sup,
    ROUND(CAST(COUNT(1) FILTER (WHERE superior_3h = 0) AS numeric) / COUNT(1) * 100, 2) AS prop_vuelos_inf
FROM 
    primer_vuelo_firma
GROUP BY 
    at_cd_airport_orig
ORDER BY 
    COUNT(1) FILTER (WHERE superior_3h = 1) DESC;
   
-- Conclusión: 
-- nos parece interesante que negocio haga un analisis de los aeropuertos menos optimizados
-- en este sentido. Ver si se puede modificar en alguno el itinerario para evitar el vuelo mayor a 3 hs como 1º vuelo.

   
   
--- Optimización
-- vuelos menores a tres horas como primer vuelo
-- vuelos posicionales como primer vuelo
-- turnos con menos primeros vuelos 

 