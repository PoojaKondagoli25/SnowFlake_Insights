-- Switch to your target database & schema where you want to create the view
USE DATABASE SNOWFLAKE_SAMPLE_DATA;
USE SCHEMA SNOWFLAKE_SAMPLE_DATA.TPCH_SF1;

create or replace schema dev_db.eda;

CREATE OR REPLACE VIEW dev_db.eda.VW_TPCH_SF1_SALES_KPIS AS
SELECT
    r.r_name                                             AS region_name,
    --DATE_TRUNC('year', o.o_orderdate)                   AS order_year,
    year(o.o_orderdate) AS order_year,
    -- Volumes
    COUNT(DISTINCT o.o_orderkey)                        AS total_orders,
    COUNT(DISTINCT c.c_custkey)                         AS distinct_customers,
    SUM(l.l_quantity)                                   AS total_quantity,

    -- Revenue KPIs (classic TPC-H revenue calc)
    SUM(l.l_extendedprice * (1 - l.l_discount))         AS gross_revenue,
    SUM(l.l_extendedprice * (1 - l.l_discount)
        * (1 - l.l_tax))                                AS net_revenue,
    AVG(l.l_extendedprice * (1 - l.l_discount))         AS avg_line_revenue,
    AVG(
        (l.l_extendedprice * (1 - l.l_discount))
    )                                                   AS avg_revenue_per_line,

    -- Margin (approx: revenue - cost using PARTSUPP supply cost)
    SUM(
        (l.l_extendedprice * (1 - l.l_discount))
        - (l.l_quantity * ps.ps_supplycost)
    )                                                   AS gross_margin

FROM SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.ORDERS      o
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.CUSTOMER    c
    ON o.o_custkey = c.c_custkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.NATION      n
    ON c.c_nationkey = n.n_nationkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.REGION      r
    ON n.n_regionkey = r.r_regionkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.LINEITEM    l
    ON o.o_orderkey = l.l_orderkey
JOIN SNOWFLAKE_SAMPLE_DATA.TPCH_SF1.PARTSUPP    ps
    ON l.l_partkey = ps.ps_partkey
   AND l.l_suppkey = ps.ps_suppkey
GROUP BY
    r.r_name,
   year(o.o_orderdate);


SELECT *
FROM dev_db.eda.VW_TPCH_SF1_SALES_KPIS
where order_year=1995
ORDER BY region_name, order_year;




CREATE OR REPLACE SEMANTIC VIEW dev_db.eda.TPCH_SF1_SALES_KPIS_SEMV
  TABLES (
    kpi_view AS dev_db.eda.VW_TPCH_SF1_SALES_KPIS
      PRIMARY KEY (region_name, order_year)
  )
  FACTS (
    -- expose numeric fields as facts
    kpi_view.f_total_orders           AS total_orders,
    kpi_view.f_distinct_customers     AS distinct_customers,
    kpi_view.f_total_quantity         AS total_quantity,
    kpi_view.f_gross_revenue          AS gross_revenue,
    kpi_view.f_net_revenue            AS net_revenue,
    kpi_view.f_avg_line_revenue       AS avg_line_revenue,
    kpi_view.f_avg_revenue_per_line   AS avg_revenue_per_line,
    kpi_view.f_gross_margin           AS gross_margin
  )
  DIMENSIONS (
    kpi_view.d_region_name AS region_name,
    kpi_view.d_order_year  AS order_year
  )
  METRICS (
    -- core KPIs (aggregations over the facts)
    kpi_view.m_total_orders AS SUM(total_orders)
      COMMENT = 'Total number of orders',
    kpi_view.m_distinct_customers AS SUM(distinct_customers)
      COMMENT = 'Total distinct customers',
    kpi_view.m_total_quantity AS SUM(total_quantity)
      COMMENT = 'Total quantity ordered',
    kpi_view.m_gross_revenue AS SUM(gross_revenue)
      COMMENT = 'Gross revenue (extended price * (1 - discount))',
    kpi_view.m_net_revenue AS SUM(net_revenue)
      COMMENT = 'Net revenue (after tax)',
    kpi_view.m_gross_margin AS SUM(gross_margin)
      COMMENT = 'Gross margin (revenue - supply cost)',
    -- helpful averages
    kpi_view.m_avg_line_revenue AS AVG(avg_line_revenue)
      COMMENT = 'Average revenue per line',
    kpi_view.m_avg_revenue_per_line AS AVG(avg_revenue_per_line)
      COMMENT = 'Average revenue per line (pre-defined in view)'
  )
  COMMENT = 'Semantic view for TPCH SF1 KPIs by region and year';

select * from dev_db.eda.TPCH_SF1_SALES_KPIS_SEMV;