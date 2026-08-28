{#
    Geography satellite on hub_state.

    city and postal_code vary within a state (up to 81 cities for one state
    code), so they widen the grain here rather than pretending to be
    state-level attributes. dim_state publishes only what state_code truly
    determines -- state and region -- and the fact carries city and postal_code
    as degenerate dimensions.
#}

{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'hmd5_state_code',
    parent_business_keys = ['state_code'],
    child_keys           = ['city', 'postal_code'],
    payload              = ['state', 'region'],
    record_source        = 'bronze_superstore'
) }}
