{#
    Hashing primitives shared by every Data Vault 2.0 structure.

    Hub and link keys are MD5 over the business key; satellites hash their
    payload the same way to detect change. This is the single place that
    behaviour lives, so a change to the algorithm ripples through every hub,
    link and satellite at once.
#}

{#- Normalise a column before hashing it: cast to text, strip whitespace. -#}
{% macro dv_clean(column) -%}
    trim(cast({{ column }} as varchar))
{%- endmacro %}

{#-
    NULL-safe hash input. A NULL and an empty string are distinct business
    facts, so they must not collapse onto the same hash.
-#}
{% macro dv_hash_part(column) -%}
    coalesce(nullif({{ dv_clean(column) }}, ''), '{{ var("dv_null_placeholder") }}')
{%- endmacro %}

{#-
    MD5 over one or more columns.

    Parts are separated by var('dv_hash_delimiter') so that ('AB', 'C') and
    ('A', 'BC') cannot collide. Set the var to "" to join the parts with no
    separator at all.
-#}
{% macro dv_hash(columns) -%}
    {%- set column_list = [columns] if columns is string else columns -%}
    md5(
        {%- for column in column_list %}
        {{ dv_hash_part(column) }}
        {%- if not loop.last %} || '{{ var("dv_hash_delimiter") }}' || {% endif %}
        {%- endfor %}
    )
{%- endmacro %}

{#- Load audit timestamp, in the warehouse's reporting timezone. -#}
{% macro dv_load_timestamp() -%}
    cast(current_timestamp at time zone '{{ var("dv_timezone") }}' as timestamp)
{%- endmacro %}

{#- "col_a is not null and col_b is not null" for a list of columns. -#}
{% macro dv_not_null_filter(columns) -%}
    {%- for column in columns -%}
        {{ column }} is not null
        {%- if not loop.last %} and {% endif -%}
    {%- endfor -%}
{%- endmacro %}
