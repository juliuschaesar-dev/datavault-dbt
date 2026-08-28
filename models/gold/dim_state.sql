{#
    One row per state_code. city and postal_code live on the satellite but not
    here -- they vary within a state, so publishing them would fan the fact out
    on every join to this dimension. The fact carries them instead.
#}

{{ dv_dimension(
    hub_relation       = ref('hub_state'),
    satellite_relation = ref('satellite_superstore_state'),
    hash_key           = 'hmd5_state_code',
    business_key       = 'state_code',
    attributes         = ['state', 'region']
) }}
