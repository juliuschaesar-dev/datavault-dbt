{{ dv_hub(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'hmd5_state_code',
    business_keys   = ['state_code'],
    record_source   = 'bronze_superstore'
) }}
