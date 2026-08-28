-- The vault must neither lose nor duplicate a transaction on the way through.
-- Row counts and measure totals in the gold fact have to match bronze exactly;
-- a fan-out in the link or a collapsed multi-active satellite shows up here
-- before it shows up in a report.

with bronze as (

    select
        count(*)      as row_count,
        sum(sales)    as total_sales,
        sum(quantity) as total_quantity,
        sum(profit)   as total_profit
    from {{ ref('bronze_superstore') }}

),

fact as (

    select
        count(*)      as row_count,
        sum(sales)    as total_sales,
        sum(quantity) as total_quantity,
        sum(profit)   as total_profit
    from {{ ref('fact_superstore') }}

)

select
    bronze.row_count      as bronze_row_count,
    fact.row_count        as fact_row_count,
    bronze.total_sales    as bronze_total_sales,
    fact.total_sales      as fact_total_sales,
    bronze.total_quantity as bronze_total_quantity,
    fact.total_quantity   as fact_total_quantity
from bronze
cross join fact
where bronze.row_count            <> fact.row_count
   or round(bronze.total_sales, 2) <> round(fact.total_sales, 2)
   or bronze.total_quantity        <> fact.total_quantity
   or round(bronze.total_profit, 2) <> round(fact.total_profit, 2)
