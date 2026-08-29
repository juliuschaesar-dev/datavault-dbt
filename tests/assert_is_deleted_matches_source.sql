-- is_deleted is a stored mirror of "does this grain still exist in its
-- source", kept true by the dv_track_deletions() post-hook rather than
-- computed at read time. That means it can go stale exactly the way a cache
-- can: if the hook is ever skipped, or a satellite's business keys drift from
-- what it hashes, is_deleted stops reflecting reality.
--
-- Recompute the same grain comparison the hook makes and assert it agrees:
-- every active row flagged not-deleted has to exist in a fresh read of
-- bronze_superstore, every active row absent from bronze has to be flagged
-- deleted, and every grain in bronze has to have an active, non-deleted row.

{% set satellites = [
    ('satellite_superstore',          'lmd5_superstore',     ['customer_id', 'country_code', 'state_code', 'product_id'], ['row_id']),
    ('satellite_superstore_customer', 'hmd5_customer',       ['customer_id'], []),
    ('satellite_superstore_product',  'hmd5_product_code',   ['product_id'], []),
    ('satellite_superstore_country',  'hmd5_country_code',   ['country_code'], []),
    ('satellite_superstore_state',    'hmd5_state_code',     ['state_code'], [])
] %}

with

{% for satellite_name, hash_key, business_keys, child_keys in satellites %}
current_source_grain_{{ loop.index }} as (
    select distinct
        {{ dv_hash(business_keys) }} as {{ hash_key }}
        {%- for child_key in child_keys %}, {{ child_key }}{% endfor %}
    from {{ ref('bronze_superstore') }}
    where {{ dv_not_null_filter(business_keys) }}
){{ "," if not loop.last }}
{% endfor %}

{% for satellite_name, hash_key, business_keys, child_keys in satellites %}
select
    '{{ satellite_name }}' as satellite,
    coalesce(satellite.{{ hash_key }}, source.{{ hash_key }}) as grain_hash
from (
    select * from {{ ref(satellite_name) }} where meta_is_active = 1
) as satellite
full outer join current_source_grain_{{ loop.index }} as source
    on source.{{ hash_key }} = satellite.{{ hash_key }}
    {%- for child_key in child_keys %}
    and source.{{ child_key }} is not distinct from satellite.{{ child_key }}
    {%- endfor %}
where (satellite.{{ hash_key }} is not null and source.{{ hash_key }} is null and satellite.is_deleted = 0)
   or (satellite.{{ hash_key }} is not null and source.{{ hash_key }} is not null and satellite.is_deleted = 1)
   or (satellite.{{ hash_key }} is null and source.{{ hash_key }} is not null)
{{ "union all" if not loop.last }}
{% endfor %}
