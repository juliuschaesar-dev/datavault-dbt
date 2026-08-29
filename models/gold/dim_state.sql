{#
    Conformed state dimension. Grain, one row per state_code.
#}

{{ dv_dimension(
    hub_relation       = ref('hub_state'),
    satellite_relation = ref('satellite_superstore_state'),
    hash_key           = 'hmd5_state',
    business_key       = 'state_code',
    attributes         = ['state']
) }}
