{#
    Transaction satellite on link_superstore.

    One link key covers every order line a customer ever placed for a product,
    so row_id widens the grain -- this is a multi-active satellite. Without it,
    9,994 order lines would collapse to one surviving row per link.

    region, city and postal_code describe where an individual order went, so
    they belong to the transaction rather than to any hub.
#}

{{ dv_satellite(
    source_relation      = ref('bronze_superstore'),
    parent_hash_key      = 'lmd5_superstore',
    parent_business_keys = ['customer_id', 'country_code', 'state_code', 'product_id'],
    child_keys           = ['row_id'],
    payload              = [
        'order_id',
        'order_date',
        'ship_date',
        'ship_mode',
        'region',
        'city',
        'postal_code',
        'sales',
        'quantity',
        'discount',
        'profit'
    ],
    record_source        = 'bronze_superstore',
    source_is_distinct   = false
) }}
