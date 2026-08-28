{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'hmd5_customer',
    parent_business_keys = ['customer_id'],
    payload              = ['customer_name', 'segment'],
    record_source        = 'bronze_superstore'
) }}
