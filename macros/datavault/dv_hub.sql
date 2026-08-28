{#
    Hub loader.

    De-duplicate the business key, hash it, and insert only what is not already
    in the table. A hub is the most stable thing in the warehouse: once a key
    is here it never changes and it is never removed.

    The materialization is incremental and the load is insert-only -- the
    anti-join at the bottom is what makes a re-run a no-op.

    Args:
        source_relation: ref() of the staged source to load from.
        hash_key:        name of the hub's MD5 surrogate key column.
        business_keys:   list of natural key columns forming the hub's grain.
        record_source:   lineage tag written to every row.
#}
{% macro dv_hub(source_relation, hash_key, business_keys, record_source) -%}

{%- set business_keys = [business_keys] if business_keys is string else business_keys -%}

with source_rows as (

    select distinct
        {% for business_key in business_keys -%}
        {{ dv_clean(business_key) }} as {{ business_key }}{{ "," if not loop.last }}
        {% endfor -%}
    from {{ source_relation }}
    where {{ dv_not_null_filter(business_keys) }}

),

hashed as (

    select
        {{ dv_hash(business_keys) }} as {{ hash_key }},
        {% for business_key in business_keys -%}
        {{ business_key }},
        {% endfor -%}
        {{ dv_load_timestamp() }} as load_timestamp,
        '{{ record_source }}' as record_source
    from source_rows

)

select * from hashed

{% if is_incremental() -%}
where {{ hash_key }} not in (select {{ hash_key }} from {{ this }})
{%- endif %}

{%- endmacro %}
