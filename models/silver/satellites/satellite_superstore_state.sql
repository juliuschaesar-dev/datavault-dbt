{#
    State descriptors. Grain, one row per state code.

    state is the only attribute a state code determines on its own -- 1:1
    across all 49 codes -- which is what makes dim_state one row per key.
#}

{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'hmd5_state_code',
    parent_business_keys = ['state_code'],
    payload              = ['state'],
    record_source        = 'bronze_superstore'
) }}
