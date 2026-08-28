-- meta_is_active is derived, not stored, so "exactly one live row per grain"
-- is a property of dv_satellite_current() rather than of the table. Assert it
-- on the transaction satellite, which is the one with a widened grain.

select
    lmd5_superstore,
    row_id,
    count(*) as active_versions
from (
    {{ dv_satellite_current(ref('satellite_superstore'), 'lmd5_superstore', ['row_id']) }}
) as current_rows
group by lmd5_superstore, row_id
having count(*) > 1
