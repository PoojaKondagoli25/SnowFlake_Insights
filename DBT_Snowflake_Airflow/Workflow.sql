use role accountadmin;

create warehouse dbt_wh with warehouse_size='x-small';
create database if not exists dbt_db;
create role if not exists dbt_role;


show grants on warehouse dbt_wh;DBT_DB.DBT_SCHEMA


grant usage on warehouse dbt_wh to role dbt_role;
grant role dbt_role to role accountadmin; 

grant all on database dbt_db to role dbt_role;

use role dbt_role;

create schema dbt_db.dbt_schema;


select * from stg_tpch_orders;


select distinct order_status from fct_orders;
select * from int_order_items;
select * from int_order_item_summary;