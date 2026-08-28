{#
    Conformed dimension built from a hub + its satellite.

    Takes the business key from the hub and the attributes from the satellite's
    live row, producing one row per key.

    The join is INNER by design: a satellite row whose hash is absent from the
    hub would otherwise land in the dimension with a NULL business key, which
    no fact can ever join to. Better a missing row than a corrupt one.

    Args:
        hub_relation:       ref() of the hub supplying the business key.
        satellite_relation: ref() of the satellite supplying the attributes.
        hash_key:           MD5 column joining the two.
        business_key:       natural key column exposed to the gold layer.
        attributes:         satellite columns to publish, in output order.
        child_keys:         grain columns to keep. Leave empty to publish one
                            row per business key, which is what a conformed
                            dimension needs.
#}
{% macro dv_dimension(
    hub_relation,
    satellite_relation,
    hash_key,
    business_key,
    attributes,
    child_keys=[]
) -%}

with current_satellite as (

    {{ dv_satellite_current(satellite_relation, hash_key, child_keys) }}

)

select
    hub.{{ business_key }},
    {% for attribute in attributes -%}
    satellite.{{ attribute }},
    {% endfor -%}
    satellite.load_timestamp
from current_satellite as satellite
inner join {{ hub_relation }} as hub
    on hub.{{ hash_key }} = satellite.{{ hash_key }}

{%- endmacro %}
