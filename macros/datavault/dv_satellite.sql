{#
    Satellite loader.

    Carries the descriptive attributes hanging off a hub or a link. Pick up the
    parent's business key plus a payload, build md5_diff over (parent keys +
    payload), and insert a row whenever that hash is new for the parent.

    Satellites are append-only: a changed attribute is a new row, never an
    update, so the full history stays recoverable and a re-run cannot alter
    what is already loaded.

    Rows land with meta_is_active = 1, and the dv_deactivate_superseded()
    post-hook demotes whatever this load supersedes -- so exactly one row per
    grain ever claims to be in force.

    A row also has no way to record that its business key vanished from the
    source: an insert-only load only ever sees new data, never a negative
    signal. The dv_track_deletions() post-hook closes that gap -- as another
    insert, not a rewrite of the row it concerns: when an active grain goes
    missing from record_source, it inserts a new row carrying the same
    attributes with is_deleted = 1 and a fresh load_timestamp, so the moment
    the deletion was noticed is itself part of the history. dv_deactivate_superseded()
    then demotes whatever that insert supersedes, the same as it would for any
    other new row. A grain that reappears with its old attributes unchanged
    gets the same treatment in reverse. Read live, present rows with
    dv_satellite_current().

    Args:
        source_relation:      ref() of the staged source to load from.
        parent_hash_key:      hub or link MD5 column this satellite hangs off.
        parent_business_keys: natural keys that produce parent_hash_key.
        payload:              descriptive columns tracked for change.
        record_source:        lineage tag written to every row.
        child_keys:           extra columns that widen the satellite's grain
                              (a multi-active satellite). They take part in
                              md5_diff and in the current-record window.
        source_is_distinct:   emit SELECT DISTINCT. True for hub satellites,
                              where the source repeats one row per transaction;
                              false when child_keys already give a unique grain.
#}
{% macro dv_satellite(
    source_relation,
    parent_hash_key,
    parent_business_keys,
    payload,
    record_source,
    child_keys=[],
    source_is_distinct=true
) -%}

{%- set parent_business_keys = [parent_business_keys] if parent_business_keys is string else parent_business_keys -%}
{%- set descriptors = child_keys + payload -%}

{{ config(
    post_hook = [
        "{{ dv_track_deletions('" ~ record_source ~ "', '" ~ parent_hash_key ~ "', "
            ~ parent_business_keys ~ ", " ~ payload ~ ", " ~ child_keys ~ ") }}",
        "{{ dv_deactivate_superseded('" ~ parent_hash_key ~ "', " ~ child_keys ~ ") }}"
    ]
) }}
{%- set hash_diff_columns = parent_business_keys + descriptors -%}

with source_rows as (

    select {% if source_is_distinct %}distinct{% endif %}
        {% for business_key in parent_business_keys -%}
        {{ dv_clean(business_key) }} as {{ business_key }},
        {% endfor -%}
        {% for column in descriptors -%}
        {{ column }}{{ "," if not loop.last }}
        {% endfor -%}
    from {{ source_relation }}
    where {{ dv_not_null_filter(parent_business_keys) }}

),

hashed as (

    select
        {{ dv_hash(parent_business_keys) }} as {{ parent_hash_key }},
        {{ dv_hash(hash_diff_columns) }} as md5_diff,
        {% for column in descriptors -%}
        {{ column }},
        {% endfor -%}
        {{ dv_load_timestamp() }} as load_timestamp,
        '{{ record_source }}' as record_source,
        1 as meta_is_active,
        0 as is_deleted
    from source_rows

)

select * from hashed

{% if is_incremental() -%}
where not exists (
    select 1
    from {{ this }} as loaded
    where loaded.{{ parent_hash_key }} = hashed.{{ parent_hash_key }}
      and loaded.md5_diff = hashed.md5_diff
)
{%- endif %}

{%- endmacro %}


{#
    Live rows of a satellite: the version currently in force for each grain.

    meta_is_active is stored on the row -- 1 for the version in force, 0 once
    superseded -- and kept true by dv_deactivate_superseded(), which runs after
    every satellite load.

    Args:
        satellite_relation: ref() of the satellite to read.
#}
{% macro dv_satellite_current(satellite_relation) -%}

    select *
    from {{ satellite_relation }}
    where meta_is_active = 1
      and is_deleted = 0

{%- endmacro %}


{#
    Demote every satellite row that a newer version has superseded.

    Runs as a post-hook on each satellite. A row stays active only while no
    other row shares its grain with a later (load_timestamp, md5_diff) -- the
    same ordering the loader inserts by, so the winner is deterministic even
    when two versions arrive in one load and share a timestamp.

    Args:
        parent_hash_key: the satellite's parent MD5 column.
        child_keys:      extra grain columns, matching the dv_satellite call.
#}
{% macro dv_deactivate_superseded(parent_hash_key, child_keys=[]) -%}

    update {{ this }} as superseded
    set meta_is_active = 0
    where superseded.meta_is_active = 1
      and exists (
          select 1
          from {{ this }} as newer
          where newer.{{ parent_hash_key }} = superseded.{{ parent_hash_key }}
            {%- for child_key in child_keys %}
            and newer.{{ child_key }} is not distinct from superseded.{{ child_key }}
            {%- endfor %}
            and (newer.load_timestamp, newer.md5_diff)
              > (superseded.load_timestamp, superseded.md5_diff)
      )

{%- endmacro %}


{#
    Insert a new row for every active grain whose presence in the source has
    flipped since the last load.

    Runs as a post-hook on each satellite, before dv_deactivate_superseded() --
    that ordering matters, because these inserts need demoting by the very
    same pass that demotes everything else, not by a rule of their own. Every
    dbt run re-extracts the full source into bronze, so "grain present in this
    load's source" is a complete answer, not a delta.

    Two directions, both inserts, neither an update:

    - An active, present row (is_deleted = 0) whose grain has gone missing
      gets a new row: same attributes, is_deleted = 1, load_timestamp = now.
      The row being superseded is untouched -- the moment the deletion was
      noticed becomes its own entry in the history, not a rewrite of the row
      it concerns.
    - An active, deleted row (is_deleted = 1) whose grain has reappeared with
      the very same attributes as before gets the mirror image: is_deleted = 0.
      (Attributes that changed while the grain was gone need no help here --
      dv_satellite's own insert already picks up a new hash for those.)

    md5_diff on these rows is derived from the row they supersede rather than
    recomputed from source, since deleted data has no current source row to
    hash; deriving it also guarantees a change of state always changes the
    hash, which is what lets these rows exist as siblings of the ones they
    replace under a (grain, md5_diff) uniqueness test.

    Args:
        record_source:         model name dv_satellite loaded from; re-resolved
                               with ref() here rather than passed as a relation,
                               because a relation embedded into a post_hook
                               string does not survive dbt's early config pass.
        parent_hash_key:      the satellite's parent MD5 column.
        parent_business_keys: natural keys that produce parent_hash_key.
        payload:               descriptive columns, matching the dv_satellite call.
        child_keys:           extra grain columns, matching the dv_satellite call.
#}
{% macro dv_track_deletions(record_source, parent_hash_key, parent_business_keys, payload, child_keys=[]) -%}

{%- set parent_business_keys = [parent_business_keys] if parent_business_keys is string else parent_business_keys -%}
{%- set descriptors = child_keys + payload -%}
{%- set source_relation = ref(record_source) -%}

with current_source_grain as (

    select distinct
        {{ dv_hash(parent_business_keys) }} as {{ parent_hash_key }}
        {%- for child_key in child_keys %},
        {{ child_key }}
        {%- endfor %}
    from {{ source_relation }}
    where {{ dv_not_null_filter(parent_business_keys) }}

)

insert into {{ this }} (
    {{ parent_hash_key }},
    md5_diff,
    {% for column in descriptors -%}
    {{ column }},
    {% endfor -%}
    load_timestamp,
    record_source,
    meta_is_active,
    is_deleted
)
select
    active.{{ parent_hash_key }},
    md5(active.md5_diff || '|deleted') as md5_diff,
    {% for column in descriptors -%}
    active.{{ column }},
    {% endfor -%}
    {{ dv_load_timestamp() }} as load_timestamp,
    active.record_source,
    1 as meta_is_active,
    1 as is_deleted
from {{ this }} as active
left join current_source_grain as source
    on source.{{ parent_hash_key }} = active.{{ parent_hash_key }}
    {%- for child_key in child_keys %}
    and source.{{ child_key }} is not distinct from active.{{ child_key }}
    {%- endfor %}
where active.meta_is_active = 1
  and active.is_deleted = 0
  and source.{{ parent_hash_key }} is null

union all

select
    active.{{ parent_hash_key }},
    md5(active.md5_diff || '|restored') as md5_diff,
    {% for column in descriptors -%}
    active.{{ column }},
    {% endfor -%}
    {{ dv_load_timestamp() }} as load_timestamp,
    active.record_source,
    1 as meta_is_active,
    0 as is_deleted
from {{ this }} as active
inner join current_source_grain as source
    on source.{{ parent_hash_key }} = active.{{ parent_hash_key }}
    {%- for child_key in child_keys %}
    and source.{{ child_key }} is not distinct from active.{{ child_key }}
    {%- endfor %}
where active.meta_is_active = 1
  and active.is_deleted = 1
  and not exists (
      select 1
      from {{ this }} as fresher
      where fresher.{{ parent_hash_key }} = active.{{ parent_hash_key }}
        {%- for child_key in child_keys %}
        and fresher.{{ child_key }} is not distinct from active.{{ child_key }}
        {%- endfor %}
        and fresher.meta_is_active = 1
        and fresher.is_deleted = 0
  )

{%- endmacro %}
