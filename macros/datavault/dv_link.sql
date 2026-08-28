{#
    Link loader.

    Records that a set of business keys occurred together. The link's own MD5
    is taken over the concatenated keys in declaration order, and each hub's
    MD5 is re-derived from its own business key -- so a link never needs to
    join back to the hubs it references, and the two can load in parallel.

    Args:
        source_relation: ref() of the staged source to load from.
        hash_key:        name of the link's MD5 surrogate key column.
        foreign_keys:    ordered list of {'hash_key': ..., 'business_key': ...}.
                         Order defines the link hash, so it must stay stable.
        record_source:   lineage tag written to every row.
#}
{% macro dv_link(source_relation, hash_key, foreign_keys, record_source) -%}

{%- set business_keys = foreign_keys | map(attribute='business_key') | list -%}

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
        {% for foreign_key in foreign_keys -%}
        {{ dv_hash(foreign_key.business_key) }} as {{ foreign_key.hash_key }},
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
