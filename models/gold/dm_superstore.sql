{#
    Flat consumption mart: the fact with every dimension already resolved.

    Grain is unchanged from fact_superstore -- one row per order line. Each
    dimension is keyed on exactly the column joined here, so nothing fans out.
#}

select
    fact.row_id,
    fact.order_id,
    fact.order_date,
    fact.ship_date,
    fact.ship_mode,

    fact.customer_id,
    dim_customer.customer_name,
    dim_customer.segment,

    fact.product_id,
    dim_product.product_name,
    dim_product.category,
    dim_product.sub_category,

    fact.country_code,
    dim_country.country,
    fact.state_code,
    dim_state.state,
    dim_state.region,
    fact.city,
    fact.postal_code,

    dim_period.year_actual  as order_year,
    dim_period.quarter_name as order_quarter,
    dim_period.month_name   as order_month,
    dim_period.week_of_year as order_week,

    fact.sales,
    fact.quantity,
    fact.discount,
    fact.profit
from {{ ref('fact_superstore') }} as fact
left join {{ ref('dim_customer') }} as dim_customer
    on dim_customer.customer_id = fact.customer_id
left join {{ ref('dim_product') }} as dim_product
    on dim_product.product_id = fact.product_id
left join {{ ref('dim_country') }} as dim_country
    on dim_country.country_code = fact.country_code
left join {{ ref('dim_state') }} as dim_state
    on dim_state.state_code = fact.state_code
left join {{ ref('dim_period') }} as dim_period
    on dim_period.date_key = fact.order_date
