{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'hmd5_product_code',
    parent_business_keys = ['product_id'],
    payload              = ['product_name', 'category', 'sub_category'],
    record_source        = 'bronze_superstore'
) }}
