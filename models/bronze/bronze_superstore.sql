{#
    Bronze: the seeded Superstore CSV, typed and trimmed.

    The seed lands every column as text on purpose, so a malformed value fails
    here -- in a model with a diff and a test -- rather than inside dbt seed.
    Nothing is filtered or reshaped: bronze mirrors the file.
#}

with source as (

    select * from {{ ref('raw_superstore') }}

),

typed as (

    select
        cast(nullif(trim(row_id), '') as integer)                as row_id,
        trim(order_id)                                           as order_id,
        to_date(nullif(trim(order_date), ''), 'MM/DD/YYYY')      as order_date,
        to_date(nullif(trim(ship_date), ''), 'MM/DD/YYYY')       as ship_date,
        trim(ship_mode)                                          as ship_mode,
        trim(customer_id)                                        as customer_id,
        trim(customer_name)                                      as customer_name,
        trim(segment)                                            as segment,
        trim(country_code)                                       as country_code,
        trim(country)                                            as country,
        trim(city)                                               as city,
        trim(state)                                              as state,
        trim(state_code)                                         as state_code,
        nullif(trim(postal_code), '')                            as postal_code,
        trim(region)                                             as region,
        trim(product_id)                                         as product_id,
        trim(category)                                           as category,
        trim(sub_category)                                       as sub_category,
        trim(product_name)                                       as product_name,
        cast(nullif(trim(sales), '') as numeric(12, 4))          as sales,
        cast(nullif(trim(quantity), '') as integer)              as quantity,
        cast(nullif(trim(discount), '') as numeric(6, 4))        as discount,
        cast(nullif(trim(profit), '') as numeric(12, 4))         as profit,
        {{ dv_load_timestamp() }}                                as load_timestamp,
        'raw_superstore'                                         as record_source
    from source

)

select * from typed
