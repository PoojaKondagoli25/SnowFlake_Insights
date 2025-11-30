SELECT * FROM STG_CUSTOMERS LIMIT 10;
SELECT * FROM DEV_DB.DBT_LEARNING.INT_ORDER_METRICS;

SELECT * FROM  DEV_DB.DBT_LEARNING.INT_ORDER_ITEMS;

SELECT * FROM DEV_DB.DBT_LEARNING.STG_LINEITEMS;

SELECT * FROM DEV_DB.DBT_LEARNING.stg_orders;

select
    o_orderkey as order_key,
    o_custkey as customer_key,
    o_orderstatus as order_status,
    o_totalprice as total_price,
    o_orderdate as order_date,
    o_orderpriority as order_priority,
    o_clerk as clerk,
    o_shippriority as ship_priority,
    o_comment as comment,
    current_timestamp() as _loaded_at
from DEV_DB.DBT_LEARNING.orders
where o_orderdate >= '1992-01-01'
  and o_orderdate <= '1998-08-02'