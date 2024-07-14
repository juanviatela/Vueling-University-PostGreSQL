------------------------------------EDA TABLA AIRCRAFT------------------------------------------------------------


select column_name, data_type 
from information_schema.columns 
where
    table_name = 'aircraft';
    
   --id_aircraft (id consecutiva del registro) VARCHAR
   --at_cd_equipment_type (código tipo de avión) VARCHAR
   --mt_seats (media de sillas por avión) INT
   --id_source_ac (¿origen del sistema del avión) INT
   --at_cd_airline_code (código avión IATA -dos letras) VARCHAR
    
--mt: mean
--at: aircraft tipe
--cd: code   

select count(*) AS count
from aircraft; 

--Dimensionalidad de la tabla: 483/5

select * 
from aircraft 
limit 5; 

-- Comprobamos existencia de nulos en toda la tabla

select
	count(*) - count(id_aircraft) as nulos_id_aircraft,
	count(*) - count(at_cd_equipment_type) as nulos_at_cd_equipment_type,
	count(*) - count(mt_seats) as nulos_total_mt_seats,
	count(*) - count(id_source_ac) as nulos_id_source_ac,
	count(*) - count(at_cd_airline_code) as nulos_at_cd_airline_code
from aircraft;

-- No tenemos nulos. Estaremos pendientes de otro tipo de inconsistencias de los datos (0 o valores atípicos)


-- Columna id_aircraf (id único de identificación del avión. Columna VARCHAR)
 
-- comprobamos que los códigos sean únicos. 
select distinct id_aircraft, count(*)
from aircraft 
group by id_aircraft 
order by count desc
limit 5; 


-- Columna at_cd_airline_code (código de aerolinea por cada id_flight)
select distinct at_cd_airline_code, count(*)
from aircraft 
group by id_aircraft 
order by count desc
limit 5; 


--Columna at_cd_equipment_type (código de identificación por tipo de aeronave. VARCHAR)

select 
    at_cd_equipment_type, 
    mt_seats, 
    count(id_aircraft) as aircraft_count,
    round(count(id_aircraft) * 100.0 / total.total_count, 2) as percentage
from aircraft,
    (select count(id_aircraft) as total_count from aircraft) as total
group by at_cd_equipment_type, mt_seats, total.total_count
order by aircraft_count desc;


-- Tipos de avion, por número de sillas, id source_ac y aerolinea conteo
-- Tenemos 31 códigos de tipo de aeronave. Cinco máx: 320: 170 (35,2), 32A (13,87): 67, SUB: 37, 321: 31
-- Resalta que tenemos un código SUB con 37, y un N/A con 21. Identificarlos. 


--Columna mt_seats (valor medio de número de sillas por cada tipo de avión. INT)
--máximo y mínimo y promedio de número de sillas medias 

select 
	round(avg(mt_seats),2) as media, --(178,34)
	min(mt_seats) as minimo, --(0),  
	max(mt_seats) as maximo --(529)
from aircraft; 

--Aquí tenemos el primer dato problemático. Valores de media de asientos de 0. Ningún vuelo puede tener 0 como asignación de sillas
--Investigamos

select at_cd_equipment_type, mt_seats, count(id_aircraft)
from aircraft 
where mt_seats = 0
group by at_cd_equipment_type, mt_seats;

-- 9 de los 21 con N/A tienen conteo de sillas medio de 0. 320, TEC, 319, 32A tiene 1 cada uno. Total de 13 con 0 mt_seats


--Columna id_source_ac (hipótesis: código de identificación de la fuente de la aeronave ¿empresa que la alquila? ¿si es alquilada o prestad?, INT)

select distinct id_source_ac, count(id_aircraft)
from aircraft
group by id_source_ac;

--Cada id_aicraft tiene su propio id_source_ace de la siguiente manera: 
--Tendríamos que averiguar que significa cada uno y si -1 es un error de tipeo o el código real es así. 
-- -1: 2
--  2: 233
--  3: 248


--Columna at_cd_airline_code (código de identificación de aerolinea por tipo de avión. VARCHAR)

select at_cd_airline_code, count(id_aircraft)
from aircraft
group by at_cd_airline_code;

--Sin nulos o incoherencias en el dato. 
--VK: Level (35)
--VY: Vueling (448)

--vista general de todos los datos. Dependerá si utilizaramos el id_source_ac para la agrupación.

select distinct at_cd_equipment_type, at_cd_airline_code, mt_seats, id_source_ac, count(id_aircraft) as count
from aircraft 
group by at_cd_equipment_type, at_cd_airline_code, mt_seats, id_source_ac
order by count desc; 



