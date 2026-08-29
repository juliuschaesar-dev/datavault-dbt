-- meta_is_active is stored, not derived, so its correctness depends on the
-- post-hook running after every load. If dv_deactivate_superseded() is ever
-- skipped, or its grain drifts from the loader's, a satellite ends up with two
-- rows both claiming to be in force -- and the dimension built on it silently
-- doubles.
--
-- Assert exactly one active row per grain, for every satellite.

{% set satellites = [
    ('satellite_superstore',          ['lmd5_superstore', 'row_id']),
    ('satellite_superstore_customer', ['hmd5_customer']),
    ('satellite_superstore_product',  ['hmd5_product']),
    ('satellite_superstore_country',  ['hmd5_country']),
    ('satellite_superstore_state',    ['hmd5_state'])
] %}

{% for satellite_name, grain in satellites %}
select
    '{{ satellite_name }}' as satellite,
    count(*) as active_versions
from {{ ref(satellite_name) }}
where meta_is_active = 1
group by {{ grain | join(', ') }}
having count(*) > 1
{% if not loop.last %}union all{% endif %}
{% endfor %}
