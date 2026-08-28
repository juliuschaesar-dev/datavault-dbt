{#
    The unit of business the vault turns on: a customer, in a country and
    state, buying a product. Declaration order fixes lmd5_superstore -- keep it
    aligned with satellite_superstore's parent_business_keys.
#}

{{ dv_link(
    source_relation = ref('bronze_superstore'),
    hash_key        = 'lmd5_superstore',
    foreign_keys    = [
        {'hash_key': 'hmd5_customer',     'business_key': 'customer_id'},
        {'hash_key': 'hmd5_country_code', 'business_key': 'country_code'},
        {'hash_key': 'hmd5_state_code',   'business_key': 'state_code'},
        {'hash_key': 'hmd5_product_code', 'business_key': 'product_id'}
    ],
    record_source   = 'bronze_superstore'
) }}
