{{ dv_dimension(
    hub_relation       = ref('hub_product'),
    satellite_relation = ref('satellite_superstore_product'),
    hash_key           = 'hmd5_product',
    business_key       = 'product_id',
    attributes         = ['product_name', 'category', 'sub_category']
) }}
