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
    grain ever claims to be in force. Read them with dv_satellite_current().

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
    post_hook = "{{ dv_deactivate_superseded('" ~ parent_hash_key ~ "', " ~ child_keys ~ ") }}"
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
        1 as meta_is_active
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
