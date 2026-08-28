{{ dv_dimension(
    hub_relation       = ref('hub_customer'),
    satellite_relation = ref('satellite_superstore_customer'),
    hash_key           = 'hmd5_customer',
    business_key       = 'customer_id',
    attributes         = ['customer_name', 'segment']
) }}
