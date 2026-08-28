{{ dv_hub(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'hmd5_customer',
    business_keys   = ['customer_id'],
    record_source   = 'bronze_superstore'
) }}
