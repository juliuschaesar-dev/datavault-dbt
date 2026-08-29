{{ dv_hub(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'hmd5_product',
    business_keys   = ['product_id'],
    record_source   = 'bronze_superstore'
) }}
