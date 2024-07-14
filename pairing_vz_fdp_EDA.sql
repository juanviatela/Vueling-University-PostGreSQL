
------------------------------------EDA TABLA PAIRING------------------------------------------------------------
select * 
from pairing;
--3.834

-- columnas que me interesan:

-- at_ds_flight_crew_code as pairingid (varchar)
-- at_dt_duty_assing  as dia_de_servicio (date)
-- at dt_flight_date as fecha_ vuelos (date)
-- at_is_shc_flight as VERR (booleano)

select *
from pairing p 
left join 


select 
count(*) - count(at_ds_flight_crew_code) as pairing,
count(*) - count(at_dt_duty_assign) as dia_servicio,
count(*) - count(at_cd_route_category) as categoria_pairing,
count(*) - count(at_cd_flight_number) as numero_vuelo_pairing,
count(*) - count(at_cd_leg) as tipo_vuelo,
count(*) - count(at_dt_flight_date) as dia_vuelo,
count(*) - count(at_cd_airline_code) as aeolinea_opera,
count(*) - count(at_cd_airport_orig) as aeropuerto_salida,
count(*) - count(at_is_dhc_flight) as posicional
from pairing;

-- no hay valores faltantes : no vi blancos

-- campo at_cd_route_category as categoria_pairing

select 
	at_cd_route_category as categoria_pairing,
	count(*) as cantidad,
	count(*) * 100 / (select count(*) from pairing) as porcentaje
from pairing p
group by at_cd_route_category
order by porcentaje desc;

-- hay 4 categorías de pairing de 1 a 5, las más altas en porcetaje son la 4 (46%) y la 3 (45%),
-- luego le siguen la 1 (6 %), la 5 (1%), la 2 (0%)>> un solo caso.

-- campo at_cd_leg as tipo de vuelo
select 
sum(case when at_cd_leg = '' then 1 else 0 end) as tipo_vuelo
from pairing;
-- 3.818 blancos

select 
	distinct at_cd_leg,
	count(at_cd_leg),
	count(at_cd_leg) * 100 / (select count(*) from pairing)
from pairing
group by at_cd_leg;

-- hay tres tipos de categorias A (6 rows), D (2 rows), P (8 rows)


-- campo at_cd_airport_orig as as aeropuerto_salida


select 
	count (at_cd_airport_orig)
from pairing;

select 
	at_cd_airport_orig as aeropuerto_salida,
	count(*) as cantidad,
	count(*) * 100 / (select count(*) from pairing) as porcentaje
from pairing p
group by at_cd_airport_orig
order by porcentaje desc;


-- cat_dt_duty_assign as dia_servicio >> solo tenemos 4 días
-- desde el 2019-10-25 al 2019-20-29

select 
	min(at_dt_duty_assign) as fecha_inicio,
	max(at_dt_duty_assign) as fecha_fin,
	age(
		max(at_dt_duty_assign),
		min(at_dt_duty_assign)
	) as intervalo_tiempo
from pairing;

-- at_dt_flight_date as dia_vuelo >> los mismos días

select 
	min(at_dt_flight_date) as fecha_inicio,
	max(at_dt_flight_date) as fecha_fin,
	age(
		max(at_dt_flight_date),
		min(at_dt_flight_date)
	) as intervalo_tiempo
from pairing;

-- at_is_dhc_flight as posicional

select 
	at_is_dhc_flight,
	count (at_is_dhc_flight),
	count(*) * 100 / (select count(*) from pairing) as porcentaje
from pairing
group by at_is_dhc_flight;

-- solo el 9 % son vuelos son posicionales, el resto operacionales


--------------------------------  TABLA FDP Limit--------------------------------------------------------------
-- Esta tabla está pivoteada para trabajar la deberiamos despivotearla posiblemente
-- No esta en utc
-- no tiene nulos

select *
from fdp_limit fl;
-- 13



---------------------------------- TABLA Variation Zone------------------------------------------------------

select *
from variation_zone;
-- Total rows 25.592

select 
	at_cd_airport,
	count(at_cd_airport) as cantidad
from variation_zone
group by at_cd_airport
order by cantidad desc;

-- tome un caso para chequear, un aeropuerto que tenga varias horas utc

select *
from variation_zone
where at_cd_airport = 'NPT';

--- MI CONCLUSION ES QUE ES UN SLOWLY CHANGING--- 
-- ES UN HISTORIAL DE HORA UTC PARA UN AEROPUERTO
-- El caso tomado: NPT tiene un historial guardado
-- En el 2020 tuvieron un solo horario (raro)
-- No cmabiaron ese horario hasta el 2018 que empezaron a tener horario verano e invierno
-- Cosa que repitieron en el 2019.

-- Nuestros registros son del 25 al 20 de octubre de 2019 (4 dias) en la tabla pairing y flight


-----------------------------------CREACIÓN DE VISTA SOBRE TABLA VARIATION ZONE----------------------------------
------------cte_min_max_temporal

select 
	at_cd_airport_orig,
from fligt
left join flight f on 

-- CREAR VISTA VARIATION_ZONE__FILTRADA: 
-- Objetivo: tener la información filtrada por el rango temporal que nos interesa.

-- 1) hago una cte para poder ver aeropuero
-- origen con su primera y ultima salida de un avion
-- destino con su primer y ultimo arrivo de un avion
-- 2) después en un select saco para ese aeropuerta la fecha menor y mayor
-- 3) creo una vista con todo esto.


create view aeropuerto_fecha_inicio_fin_vuelos as (

with cte_min_max_temporal as (
select
	at_cd_airport_orig as aeropuerto,
	min(at_ts_std_utc) as fecha_inicio,
	max(at_ts_std_utc) as fecha_fin,
	'departure' as tipo
from flight
group by at_cd_airport_orig

union all

select 
	at_cd_airport_dest as aeropuerto,
	min(at_ts_sta_utc) as fecha_inicio,
	max(at_ts_sta_utc) as fecha_fin,
	'arrival' as tipo
from flight
group by at_cd_airport_dest
)

select 
	aeropuerto,
	min(fecha_inicio) as fecha_inicio_utc,
	max(fecha_fin) as fecha_fin_utc
from cte_min_max_temporal
group by aeropuerto

);

select *
from aeropuerto_fecha_inicio_fin_vuelos;

-- 4) Por último creo vista de varitione_zone_ filtrada por las fechas que nos interesan 

create view variatione_zone_filtrada as (
select
	at_cd_airport,
	at_dt_start_date_utc,
	at_dt_end_date_utc,
	at_min_variation 
from variation_zone vz
left join aeropuerto_fecha_inicio_fin_vuelos av on vz.at_cd_airport = av.aeropuerto
where av.fecha_inicio_utc between vz.at_dt_start_date_utc and at_dt_end_date_utc
and av.fecha_fin_utc between vz.at_dt_start_date_utc and at_dt_end_date_utc
);

select *
from variatione_zone_filtrada;

