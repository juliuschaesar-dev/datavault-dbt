{#
    Transaction fact, one row per Superstore order line (row_id).

    Business keys are resolved by walking the vault outwards from the
    transaction satellite: satellite -> link -> hubs. Nothing here re-reads
    bronze, which is the whole point of building the vault first -- the fact is
    a projection of the vault, not a second copy of the source.

    order_date and ship_date join to dim_period.date_key.
#}

with current_transaction as (

    {{ dv_satellite_current(ref('satellite_superstore'), 'lmd5_superstore', ['row_id']) }}

)

select
    sale.row_id,
    sale.order_id,
    customer.customer_id,
    product.product_id,
    country.country_code,
    state.state_code,
    sale.order_date,
    sale.ship_date,
    sale.ship_mode,
    sale.city,
    sale.postal_code,
    sale.sales,
    sale.quantity,
    sale.discount,
    sale.profit,
    sale.load_timestamp
from current_transaction as sale
inner join {{ ref('link_superstore') }} as link
    on link.lmd5_superstore = sale.lmd5_superstore
inner join {{ ref('hub_customer') }} as customer
    on customer.hmd5_customer = link.hmd5_customer
inner join {{ ref('hub_product') }} as product
    on product.hmd5_product_code = link.hmd5_product_code
inner join {{ ref('hub_country') }} as country
    on country.hmd5_country_code = link.hmd5_country_code
inner join {{ ref('hub_state') }} as state
    on state.hmd5_state_code = link.hmd5_state_code
