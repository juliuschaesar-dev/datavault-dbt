{{ dv_hub(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'hmd5_country',
    business_keys   = ['country_code'],
    record_source   = 'bronze_superstore'
) }}
