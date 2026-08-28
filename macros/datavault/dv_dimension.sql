{#
    Conformed dimension built from a hub + its satellite.

    Takes the business key from the hub and the attributes from the satellite's
    live row, producing one row per key.

    A satellite can stay active at a finer grain than the dimension it feeds --
    the state satellite holds an active row per city -- so the active rows are
    collapsed to one per business key. Anything published must be functionally
    dependent on that key, or the choice of row would change what is reported.

    The join is INNER by design: a satellite row whose hash is absent from the
    hub would otherwise land in the dimension with a NULL business key, which
    no fact can ever join to. Better a missing row than a corrupt one.

    Args:
        hub_relation:       ref() of the hub supplying the business key.
        satellite_relation: ref() of the satellite supplying the attributes.
        hash_key:           MD5 column joining the two.
        business_key:       natural key column exposed to the gold layer.
        attributes:         satellite columns to publish, in output order.
#}
{% macro dv_dimension(
    hub_relation,
    satellite_relation,
    hash_key,
    business_key,
    attributes
) -%}

with current_satellite as (

    {{ dv_satellite_current(satellite_relation) }}

),

one_row_per_key as (

    select
        {{ hash_key }},
        {% for attribute in attributes -%}
        {{ attribute }},
        {% endfor -%}
        load_timestamp,
        row_number() over (
            partition by {{ hash_key }}
            order by load_timestamp desc, md5_diff desc
        ) as meta_row_rank
    from current_satellite

)

select
    hub.{{ business_key }},
    {% for attribute in attributes -%}
    satellite.{{ attribute }},
    {% endfor -%}
    satellite.load_timestamp
from one_row_per_key as satellite
inner join {{ hub_relation }} as hub
    on hub.{{ hash_key }} = satellite.{{ hash_key }}
where satellite.meta_row_rank = 1

{%- endmacro %}
