{{ dv_dimension(
    hub_relation       = ref('hub_country'),
    satellite_relation = ref('satellite_superstore_country'),
    hash_key           = 'hmd5_country',
    business_key       = 'country_code',
    attributes         = ['country']
) }}
