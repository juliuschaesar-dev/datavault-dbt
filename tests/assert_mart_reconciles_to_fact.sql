-- dm_superstore joins five dimensions onto the fact. If any of them is keyed
-- at a finer grain than the column it joins on, rows multiply and every
-- measure silently inflates. Guard the grain, not just the row count.

with fact as (

    select count(*) as row_count, sum(sales) as total_sales
    from {{ ref('fact_superstore') }}

),

mart as (

    select count(*) as row_count, sum(sales) as total_sales
    from {{ ref('dm_superstore') }}

)

select
    fact.row_count   as fact_row_count,
    mart.row_count   as mart_row_count,
    fact.total_sales as fact_total_sales,
    mart.total_sales as mart_total_sales
from fact
cross join mart
where fact.row_count             <> mart.row_count
   or round(fact.total_sales, 2) <> round(mart.total_sales, 2)
