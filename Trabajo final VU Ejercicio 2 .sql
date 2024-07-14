-------------------------------------------Ejercicio 2-------------------------------------------------------------------------
/*   
Ejercicio 2
 Preguntas:
 1. ¿Cuál es la FDP y la FDP Máximo para cada pairing
 2. ¿Cómo se distribuyen los pairing a lo largo de las distintas bases y tipos de avion?

*/
-------------------------------------------------CREACIÓN VIEW Primer vuelo 1------------------------------------------
--Objetivo: crear una vista con el primer vuelo de la crew, para etablecer la hora de la firma

create view primer_vuelo_firma_1 as
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
from primer_vuelo_firma_1 

------------------------------------------------CREACIÓN VIEW Último vuelo------------------------------------------------
--Objetivo: crear una vista con los datos del ultimo vuelo para poder tener el ultimo arribo.

create view ultimo_vuelo as
with cte as (
    select 
        p.at_ds_flight_crew_code, 
        p.at_is_dhc_flight, 
        f.*, 
        row_number() over(
            partition by p.at_ds_flight_crew_code, date_part('day', p.at_dt_flight_date)
            order by p.at_dt_flight_date desc, f.at_ts_std_utc desc
        ) as rank,
        count(*) over (
            partition by p.at_ds_flight_crew_code, date_part('day', p.at_dt_flight_date)
        ) as num_vuelos_dia,
        a.at_cd_equipment_type
    from pairing p  
    join flight f on p.at_cd_flight_number = f.at_cd_flight_number
        and p.at_dt_flight_date = f.at_dt_flight_date
        and p.at_cd_airline_code = f.at_cd_airline_code
        and p.at_cd_airport_orig = f.at_cd_airport_orig
        and p.at_cd_leg = f.at_cd_leg
    join aircraft a on f.id_aircraft::varchar = a.id_aircraft
    order by p.at_ds_flight_crew_code, p.at_dt_flight_date desc, f.at_ts_std_utc desc
)
select 
    u.*,
    date_part('hour', age(at_ts_sta_utc, at_ts_std_utc)) as hora,
    case when date_part('hour', age(at_ts_sta_utc, at_ts_std_utc)) > 2 then 1 else 0 end as superior_3h,
    case when at_cd_equipment_type = '321' then 1 else 0 end as tipo_avion,
    case when at_cd_airport_orig in ('FCO', 'ORY', 'AMS') then 1 else 0 end as aerop_60,
    case when at_cd_airport_orig in ('MAD', 'ALC') then 1 else 0 end as mad_alic,
    case when at_is_dhc_flight then 1 else 0 end as posicional,
    case when at_cd_airport_orig = 'BCN' then 1 else 0 end as bcn,
    0 as ground_carrier,
    case when at_cd_equipment_type = '320' or at_cd_equipment_type = '319' then 1 else 0 end as tipo_avion2,
    vz.at_min_variation,
    u.at_ts_sta_utc + interval '1 minute' * vz.at_min_variation as local_sta_time
from 
    cte u
join 
    variation_zone vz 
on 
    u.at_cd_airport_dest = vz.at_cd_airport
    and u.at_ts_sta_utc between vz.at_dt_start_date_utc and vz.at_dt_end_date_utc
where 
    rank = 1;
    
select *
from ultimo_vuelo

-----------------------------------------CREACIÓN DE LA VISTA Vuelos por crew----------------------------------------------
--Objetivo, tener la hs de la firma, primer salida y último arrivo de la crew.
-- De esta manera contabilizamos: 
-- la FDP (Desde la hs de la firma hasta que el último vuelo del día se detiene)


create view vuelos_crew as
select 
    p.at_ds_flight_crew_code,
    p.at_dt_flight_date,
    p.at_cd_airline_code as aerolinea_primer_vuelo,
    p.at_cd_airport_orig as cd_airport_org_primer_vuelo,
    p.at_cd_airport_dest as cd_airport_dest_primer_vuelo,
    p.at_ts_std_utc as primer_vuelo_std_utc,
    p.at_ts_sta_utc as primer_vuelo_sta_utc,
    p.hora_firma_utc,
    p.local_std_time as primer_vuelo_local_std_time,
    p.local_sta_time as primer_vuelo_local_sta_time,
    p.hora_local_firma,
    p.tiempo_firma,
    p.at_min_variation as primer_vuelo_min_variation,
    u.at_cd_airline_code as aerolinea_ultimo_vuelo,
    u.at_cd_airport_orig as cd_airport_org_ultimo_vuelo,
    u.at_cd_airport_dest as cd_airport_dest_ultimo_vuelo,
    u.at_ts_std_utc as ultimo_vuelo_std_utc,
    u.at_ts_sta_utc as ultimo_vuelo_sta_utc,
    u.local_sta_time as ultimo_vuelo_local_sta_time,
    u.at_min_variation as ultimo_vuelo_min_variation,
    u.num_vuelos_dia,
    (u.local_sta_time - p.hora_local_firma) as fdp
from 
    primer_vuelo_firma p
join 
    ultimo_vuelo u 
on 
    p.at_ds_flight_crew_code = u.at_ds_flight_crew_code
    and p.at_dt_flight_date = u.at_dt_flight_date
order by 
    p.at_ds_flight_crew_code, p.at_dt_flight_date;

select count(*)
from vuelos_crew --(1487)

select *
from vuelos_crew

---------------------------------------CREACIÓN DE LA VISTA fdp_limit_unpivot----------------------------------------------
-- Objetivo: la misma se realiza para poder manejar los datos provenientes de la tabla fdp limit de manera más optima.

create view fdp_limit_unpivot as(
select at_tm_initial_time, at_tm_final_time, 1 as num_sectores, at_tm_sectors_1 as fdp_max
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 2 , at_tm_sectors_2
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 3 , at_tm_sectors_3
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 4 , at_tm_sectors_4
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 5 , at_tm_sectors_5
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 6 , at_tm_sectors_6
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 7 , at_tm_sectors_7
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 8 , at_tm_sectors_8
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 9 , at_tm_sectors_9
from fdp_limit fl
union all
select at_tm_initial_time, at_tm_final_time, 10 , at_tm_sectors_10
from fdp_limit fl);
 
select * 
from fdp_limit_unpivot


------------------------------------------ CREACIÓN DE LA VISTA FDP_LIMIT-----------------------------------------------
-- Objetivo: 
--contablizar la FDP MAX (Establecida por la tabla FDP Limit)>> nosotros usamos la vista fdp_limit_unpivot que realizamos 
-- con la finalidad de un mejor manejo de los datos.
-- y ver la relación existente entre la fdp y la fdp_max

create view fdp_max as(
select 
	vc.*, 
	v.fdp_max
from vuelos_crew vc join fdp_limit_unpivot v on (vc.hora_local_firma::time between trim(regexp_replace(v.at_tm_initial_time, '[^0-9:]', '', 'g'))::time and v.at_tm_final_time::time)
and vc.num_vuelos_dia = v.num_sectores
order by at_ds_flight_crew_code asc
); 

select *
from fdp_max; 

-- YA TENEMOS LOS PAIRING CON SU FDP Y SU FDP_MAX

----------------------------------------CASOS fdp max < fdp------------------------------------------------------
SELECT 
    COUNT(*) AS total_cases,
    round(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM fdp_max),2) AS porcentaje
FROM 
    fdp_max
WHERE 
    fdp_max < fdp; -- 35 casos en que la fdp max < fdp

--------------------------MICROANALISIS DE LAS CREW QUE SUPERAN EL FDP_MAX--------------------------------------------------------
 

-crew que exceden el fdp 
select count(*)
from fdp_max
where fdp > fdp_max -- (35)

--crew que exceden el fdp y hacen dos vuelos
select *
from fdp_max
where fdp > fdp_max and num_vuelos_dia = 2

select count(*)
from fdp_max
where fdp > fdp_max and num_vuelos_dia = 2 --(12)


---PRIMER VUELO

-- la mayor parte de crews hacen dos vuelos por día. Investigamos patrones sobre aquellas crews que hacen dos vuelos al día y han sobrepasado el fpd_max (12). 
-- Escogemos también aquellas que solo han hecho dos vuelos al día pues podemos intentar solucionar el exceso de fdp sin tener en cuenta el comportamiento de los vuelos
-- intermedios. 

select cd_airport_org_primer_vuelo, count(*) as conteo_salida_primer_vuelo
from fdp_max
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_org_primer_vuelo
order by cd_airport_org_primer_vuelo asc;

-- Aeropuertos con mayor cantidad de primeros vuelos de salida  con crews que exceden el fdp_max BCN (4), ALC (2) el resto 1

select cd_airport_dest_primer_vuelo, count(*) as conteo_llegada_primer_vuelo
from fdp_max 
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_dest_primer_vuelo
order by cd_airport_dest_primer_vuelo asc;

-- Aeropuertos con mayor cantidad de primeros vuelos de llegada con crews que exceden el fdp_max BCN (8), BJL (Banjul, Gambia) (2) el resto 1

select cd_airport_org_primer_vuelo, count(*) as conteo_salida_primer_vuelo, cd_airport_dest_primer_vuelo, count(*) as conteo_llegada_primer_vuelo
from fdp_max 
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_org_primer_vuelo, cd_airport_dest_primer_vuelo
order by cd_airport_org_primer_vuelo asc, cd_airport_dest_primer_vuelo asc;

--Emparejamientos en vuelos de salida-llegada con mayor cantidad de vuelos con crews que exceden el fdp_max ALC/BCN (2), BCN/BLJ (2)


--ULTIMO VUELO 

select cd_airport_org_ultimo_vuelo, count(*) as conteo_salida_ultimo_vuelo
from fdp_max
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_org_ultimo_vuelo
order by cd_airport_org_ultimo_vuelo asc;

-- Aeropuertos con mayor cantidad de primeros vuelos de llegada con crews que exceden el fdp_max BCN (8), BJL (2) el resto 1

select cd_airport_dest_ultimo_vuelo, count(*) as conteo_llegada_ultimo_vuelo
from fdp_max 
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_dest_ultimo_vuelo
order by cd_airport_dest_ultimo_vuelo asc;

-- Aeropuertos con mayor cantidad de primeros vuelos de llegada con crews que exceden el fdp_max BCN (4), ALC (2) el resto 1

select cd_airport_org_ultimo_vuelo, count(*) as conteo_salida_ultimo_vuelo, cd_airport_dest_ultimo_vuelo, count(*) as conteo_llegada_ultimo_vuelo
from fdp_max 
where fdp > fdp_max and num_vuelos_dia = 2
group by cd_airport_org_ultimo_vuelo, cd_airport_dest_ultimo_vuelo
order by cd_airport_org_ultimo_vuelo asc, cd_airport_dest_ultimo_vuelo asc;

--Emparejamientos en vuelos de salida-llegada con mayor cantidad de vuelos con crews que exceden el fdp_max BCN/ALC (2), BLJ/BCN (2)


--Fijandonos en el caso BCN/BLJ - BLJ/BCN detectamos que simplemente adelantando 10 minutos la salida del vuelo de vuelta podríamos ajustar la fdp 
--para que no supere la fdp_max

--Investigamos entonces aquellos vuelos que con un ajuste mínimo en la hora de despegue (máx 15 minutos) del último vuelo puede ajustarse la fdp para que 
--no supere la fdp_max

select at_ds_flight_crew_code as crew, at_dt_flight_date as flight_date, cd_airport_org_primer_vuelo as origen_primer_vuelo, 
	   cd_airport_dest_primer_vuelo as destino_primer_vuelo, cd_airport_org_ultimo_vuelo as origen_ultimo_vuelo, 
	   cd_airport_dest_ultimo_vuelo as destino_ultimo_vuelo, 
	   ultimo_vuelo_std_utc horad_ultimo_vuelo,
	   fdp,
	   fdp_max,
       fdp - fdp_max::interval as diferencia_fdp
from fdp_max 
where fdp > (fdp_max::interval) 
  and num_vuelos_dia = 2
  and (fdp - fdp_max::interval) < interval '15 minutes';

--Conseguimos una lista de 7 vuelos que al adelantar la hora de salida del segundo vuelo en 15 minutos ajustamos el fdp para que no exceda el fdp_max
  --BCN/DSS - DSS/BCN  5 minutos de exceso
  --ALC/BCN - BCN/ALC  10 minutos de exceso
  --BCN/BJL - BJL/BCN  10 minutos de exceso
  --ALC/BCN - BCN/ALC  5 minutos de exceso
  --ORY/BCN - BCN/ORY  10 minutos de exceso
  --BCN/BJL - BJL/BCN  5 minutos de exceso
  --BCN/ORY - ORY/BCN  5 minutos de exceso 
  
  
--Seleccionamos los otros casos para intentar encontrar algún patrón. 
  
select at_ds_flight_crew_code as crew, at_dt_flight_date as flight_date, cd_airport_org_primer_vuelo as origen_primer_vuelo, 
	   cd_airport_dest_primer_vuelo as destino_primer_vuelo, cd_airport_org_ultimo_vuelo as origen_ultimo_vuelo, 
	   cd_airport_dest_ultimo_vuelo as destino_ultimo_vuelo, 
	   ultimo_vuelo_std_utc horad_ultimo_vuelo,
	   fdp,
	   fdp_max,
       fdp - fdp_max::interval as diferencia_fdp
from fdp_max 
where fdp > (fdp_max::interval) 
  and num_vuelos_dia = 2
  and (fdp - fdp_max::interval) > interval '15 minutes';
  
-- MAD/BCN  -  BCN/MAD  25 minutos exceso
-- PMI/BCN  -  BCN/PMI  75 minutos exceso
-- SVQ/BCN  -  BCN/SVQ  40 minutos exceso
-- LCG/BCN  -  BCN/LCG  150 minutos exceso 
-- TFN/BCN  -  BCN/TFN  45 minutos exceso
  
--En este caso tendríamos que al ajuste que podamos hacer en la hora del despegue del segundo vuelo sumar una revisión de la planificación general de la ruta, pues es 
--difícil de justificar que una crew que haga en un día un vuelo de ida y vuelta La Coruña-Barcelona tenga un exceso de fdp de 150 minutos. 
  
   
 
  ------------------------------ Algunas métricas para entender la distribución de las FDPs-------------------------

SELECT 
    COUNT(at_ds_flight_crew_code) AS cantidad_crew,
    MIN(fdp) AS minimo_fdp,
    MAX(fdp) AS maximo_fdp,
    AVG(fdp)::time AS promedio_fdp,
    AVG(fdp_max)::time AS promedio_fdp_max,
    INTERVAL '1 second' * TRUNC(STDDEV(EXTRACT(EPOCH FROM fdp))) AS desviacion_estandar_fdp
FROM 
    fdp_max;

-- Conclusión:  si bien hay 35 casos, estos no llegan a disparar el promedio.
   
----------------------------------------Promedio fdp por crew---------------------------------------
   
create view pbi2 as(
select 
	vc.at_ds_flight_crew_code, 
	avg(fdp)
from 
	vuelos_crew vc
group by 
	vc.at_ds_flight_crew_code
order by 
	vc.at_ds_flight_crew_code)

select *
from pbi2;

   ------------------------------PREGUNTA 2---------------------------------------
   --Objetivo: ordenar la información para luego poder consultarla de manera más eficiente.
   
   create view b as(
select 
	p.at_ds_flight_crew_code, 
	f.*, 
	rank() over(partition by p.at_ds_flight_crew_code, 
	date_part('day', p.at_dt_flight_date)
	order by  
	p.at_dt_flight_date asc, 
	f.at_ts_std_utc asc)
from 
	pairing p  
join 
	flight f 
	on p.at_cd_flight_number = f.at_cd_flight_number and
	p.at_dt_flight_date  = f.at_dt_flight_date and 
	p.at_cd_airline_code = f.at_cd_airline_code and 
	p.at_cd_airport_orig = f.at_cd_airport_orig and 
	p.at_cd_leg = f.at_cd_leg
order by 
	p.at_ds_flight_crew_code , 
	p.at_dt_flight_date asc, 
	f.at_ts_std_utc asc);
    
select *
from b;

---------------------------------- CREAR UNA VISTA PARA CONTAR VUELOS POR CREW------------------------------------
--Objetivos: ver como es la distribución de crews por vuelos. De esta manera podemos ver cuál es su
-- operacionalidad y determinar por cuántas bases pasan.
-- Nuestro supuesto es que el total de aeropuertos es uno más que la cantidad de vuelos totales.

create view pbi as(
-- agrupo por crew y cantidad de vuelos

with cte as(
	select 
		at_ds_flight_crew_code, 
		count(1) as cuenta 
	from b
	group by at_ds_flight_crew_code
	order by count(1) desc)

select 
	cuenta as cantidad_vuelos, 
	count(1) as cantidad_crew
from cte
group by cantidad_vuelos);

select *
from pbi;

---------------------------------INVESTIGAMOS LAS CREWS ESPECIALIZADAS DE UNA RUTA--------------------------------------
--Estas son crews que son locales de un destino en particular y siempre hacen la misma ruta. Ej. Vigo-BCN BCN-Vigo

create view aerop_freq as(
with cte as(
	select 
		at_ds_flight_crew_code, 
		at_cd_airport_orig, 
		count(1) as c
from b
group by 
	at_ds_flight_crew_code, 
	at_cd_airport_orig
order by 
	at_ds_flight_crew_code, 
	c desc)

select *, 
row_number() over(partition by at_ds_flight_crew_code order by c)
from cte);
 
select 
	at_cd_airport_orig, 
	count(1) 
from 
	aerop_freq
where row_number = 1
group by at_cd_airport_orig
order by 2 desc;

-- Esta querry nos dice de cuantas crews el aeropuerto x es el origen mas frecuentado
-- obviamente bcn es el lider
 
select * 
from 
	aerop_freq
where at_ds_flight_crew_code like '%MUC%'; 

-- buscando crews con nombres semejantes a los de los aeropuertos
-- encontramos que estos casi exclusivamente hacen aeropuerto x -> bcn y viceversa
-- por lo tanto hay cierta 'especializadas' en una sola ruta
-- si la crew 'vive' en Vigo por ej tiene sentido que no realizen tantos viajes pues tendran poca variedad
-- EJ VCE,VGO, AGP,
 
select * from b
where at_ds_flight_crew_code = 'VGO04';
 
 
select * from aerop_freq;

---------------------------------------------------------------------------------------------------------------------
-- de promedio los aviones 321 hacen vuelos mas largos que los otros tipos
-- Entendemos que los aviones 321, son aviones con mayor capacidad de pasajeros y que hacen vuelos más largos
-- afectando directamente las fdp de las crew.

select 
	a.at_cd_equipment_type, 
	avg(a.mt_seats), 
	avg(age(f.at_ts_sta_utc, f.at_ts_std_utc)) as tiempo_vuelo_promedio
from 
	aircraft a 
join 
	flight f on a.id_aircraft = f.id_aircraft::varchar
group by 
	a.at_cd_equipment_type
order by 
	tiempo_vuelo_promedio;

---------------------------------------------------------------------------------------------------------------------
--conteo de vuelos por crew y tipo de avión

select p.at_ds_flight_crew_code, a.at_cd_equipment_type, count(f.*) as cantidad_vuelos
  from pairing p  
        join flight f on p.at_cd_flight_number = f.at_cd_flight_number
            and p.at_dt_flight_date = f.at_dt_flight_date
            and p.at_cd_airline_code = f.at_cd_airline_code
            and p.at_cd_airport_orig = f.at_cd_airport_orig
            and p.at_cd_leg = f.at_cd_leg
        join aircraft a on f.id_aircraft::varchar = a.id_aircraft
group by p.at_ds_flight_crew_code, a.at_cd_equipment_type
order by p.count desc
limit 10; 

--Durante el periodo las crews que hicieron más vuelos los hicieron en aviones tipo 320. 
--Las que más hicieron fueron la SVO7E con 20 vuelos y la OV01A también con 20 vuelos en aviones tipo 320. 

--Determinamos el promedio de vuelos por crew y por avión. 

with crew_flights as (
    select
        p.at_ds_flight_crew_code,
        a.at_cd_equipment_type,
        count(*) as flights_per_crew
    from
        pairing p  
        join flight f on p.at_cd_flight_number = f.at_cd_flight_number
            and p.at_dt_flight_date = f.at_dt_flight_date
            and p.at_cd_airline_code = f.at_cd_airline_code
            and p.at_cd_airport_orig = f.at_cd_airport_orig
            and p.at_cd_leg = f.at_cd_leg
        join aircraft a on f.id_aircraft::varchar = a.id_aircraft
    group by
        p.at_ds_flight_crew_code,
        a.at_cd_equipment_type
),
average_flights as (
    select
        at_cd_equipment_type,
        round(avg(flights_per_crew),2) as avg_flights_per_crew
    from
        crew_flights
    group by
        at_cd_equipment_type
)
select
    at_cd_equipment_type,
    avg_flights_per_crew
from
    average_flights
order by avg_flights_per_crew desc;
   
-- Por tipo de avión las crew hicieron un promedio de vuelos de la siguiente manera: 
-- Tipo 320, promedio de 3.72 vuelos. 
-- Tipo 319, promedio de 3.65 vuelos.
-- Tipo 32A, promedio de 3,17 vuelos.
-- Tipo 321, promedio de 2,76 vuelos. 

-----------------------------------------------------------------------------------------------------------------
--Promedio FDP por aeropuerto

select cd_airport_org_primer_vuelo, count(*) as conteo_vuelos, AVG(fdp) as promedio_fdp
from fdp_max 
group by cd_airport_org_primer_vuelo
order by conteo_vuelos asc; 

--investigamos por qué el promedio de FDP de MUC es tan alto
select at_dt_flight_date, cd_airport_org_primer_vuelo, cd_airport_dest_primer_vuelo, cd_airport_org_ultimo_vuelo, cd_airport_dest_ultimo_vuelo, fdp, fdp_max 
from fdp_max 
where cd_airport_org_primer_vuelo = 'MUC';

