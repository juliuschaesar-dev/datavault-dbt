{{ dv_hub(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'hmd5_state',
    business_keys   = ['state_code'],
    record_source   = 'bronze_superstore'
) }}
