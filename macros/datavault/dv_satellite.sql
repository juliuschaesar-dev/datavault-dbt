{#
    Satellite loader.

    Carries the descriptive attributes hanging off a hub or a link. Pick up the
    parent's business key plus a payload, build md5_diff over (parent keys +
    payload), and insert a row whenever that hash is new for the parent.

    Satellites are append-only: a changed attribute is a new row, never an
    update, so the full history stays recoverable and a re-run cannot alter
    what is already loaded. Use dv_satellite_current() to read the live
    version.

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
        '{{ record_source }}' as record_source
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
    Live rows of a satellite: the newest version per grain, flagged
    meta_is_active = 1.

    The flag is derived at read time rather than stored. A stored flag has to be
    back-dated on every load, and any load that misses that step leaves two rows
    claiming to be current.

    Args:
        satellite_relation: ref() of the satellite to read.
        parent_hash_key:    the satellite's parent MD5 column.
        child_keys:         extra grain columns, matching the dv_satellite call.
#}
{% macro dv_satellite_current(satellite_relation, parent_hash_key, child_keys=[]) -%}

{%- set grain = [parent_hash_key] + child_keys -%}

    select
        versioned.*,
        1 as meta_is_active
    from (
        select
            satellite.*,
            row_number() over (
                partition by {{ grain | join(', ') }}
                order by load_timestamp desc, md5_diff desc
            ) as meta_version_rank
        from {{ satellite_relation }} as satellite
    ) as versioned
    where versioned.meta_version_rank = 1

{%- endmacro %}
