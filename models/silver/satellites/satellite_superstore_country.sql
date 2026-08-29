{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'hmd5_country',
    parent_business_keys = ['country_code'],
    payload              = ['country'],
    record_source        = 'bronze_superstore'
) }}
