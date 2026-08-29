# Architecture

How a row travels from CSV to a queryable star schema, and why it takes the
route it does. For the concepts behind the middle layer, see
[What a Data Vault 2.0 is](../README.md#what-a-data-vault-20-is).

---

## 1. End-to-end lineage

Every model in the project, with the row count each one holds after a full
build.

```mermaid
flowchart LR
    subgraph seeds["seeds"]
        direction TB
        rs["raw_superstore.csv<br/>9,994"]
        rp["raw_period.csv<br/>18,628"]
    end

    subgraph bronze["bronze — typed mirrors"]
        direction TB
        bs["bronze_superstore<br/>9,994"]
        bp["bronze_period<br/>18,628"]
    end

    subgraph silver["silver — Data Vault 2.0"]
        direction TB
        subgraph hubs["hubs — business keys"]
            direction TB
            hcu["hub_customer<br/>793"]
            hpr["hub_product<br/>1,862"]
            hco["hub_country<br/>1"]
            hst["hub_state<br/>49"]
        end
        lnk["link_superstore<br/>9,983"]
        subgraph sats["satellites — descriptive history"]
            direction TB
            stx["satellite_superstore<br/>9,994"]
            scu["satellite_superstore_customer<br/>793"]
            spr["satellite_superstore_product<br/>1,862"]
            sco["satellite_superstore_country<br/>1"]
            sst["satellite_superstore_state<br/>49"]
        end
    end

    subgraph gold["gold — star schema"]
        direction TB
        dcu["dim_customer<br/>793"]
        dpr["dim_product<br/>1,862"]
        dco["dim_country<br/>1"]
        dst["dim_state<br/>49"]
        dpe["dim_period<br/>18,628"]
        fct["fact_superstore<br/>9,994"]
        mrt["dm_superstore<br/>9,994"]
    end

    rs --> bs
    rp --> bp

    bs --> hcu & hpr & hco & hst
    bs --> lnk
    bs --> stx & scu & spr & sco & sst

    hcu --> dcu
    scu --> dcu
    hpr --> dpr
    spr --> dpr
    hco --> dco
    sco --> dco
    hst --> dst
    sst --> dst

    bp -- "bypasses data vault" --> dpe

    stx --> fct
    lnk --> fct
    hcu & hpr & hco & hst --> fct

    fct --> mrt
    dcu & dpr & dco & dst & dpe --> mrt
```

Three things worth reading off that graph:

- **Everything in silver depends only on `bronze_superstore`.** No vault model
  reads another vault model. Because the keys are MD5 hashes of the business
  key rather than assigned sequences, nothing has to be loaded before anything
  else — dbt builds all ten in parallel.
- **`fact_superstore` has no edge back to bronze.** It is projected entirely
  from the vault. That is the test of whether the vault is actually load-bearing
  or just decoration.
- **`bronze_period` goes straight to gold.** A calendar has no mutable business
  key and no history, so a hub and satellite would add two tables and reproduce
  the seed exactly.

---

## 2. The vault

Hubs hold keys, the link holds the relationship between them, satellites hold
everything descriptive. Joins are on MD5 hashes throughout.

```mermaid
erDiagram
    hub_customer ||--o{ link_superstore : hmd5_customer
    hub_product  ||--o{ link_superstore : hmd5_product
    hub_country  ||--o{ link_superstore : hmd5_country
    hub_state    ||--o{ link_superstore : hmd5_state

    link_superstore ||--o{ satellite_superstore : lmd5_superstore

    hub_customer ||--o{ satellite_superstore_customer : hmd5_customer
    hub_product  ||--o{ satellite_superstore_product  : hmd5_product
    hub_country  ||--o{ satellite_superstore_country  : hmd5_country
    hub_state    ||--o{ satellite_superstore_state    : hmd5_state

    hub_customer {
        text hmd5_customer PK "md5(customer_id)"
        text customer_id UK
        timestamp load_timestamp
        text record_source
    }

    link_superstore {
        text lmd5_superstore PK "md5 over all four keys"
        text hmd5_customer FK
        text hmd5_country FK
        text hmd5_state FK
        text hmd5_product FK
        timestamp load_timestamp
        text record_source
    }

    satellite_superstore {
        text lmd5_superstore FK
        text md5_diff "md5 over keys + payload"
        int row_id "widens the grain"
        text order_id
        date order_date
        date ship_date
        text ship_mode
        text region
        text city
        text postal_code
        numeric sales
        int quantity
        numeric discount
        numeric profit
        timestamp load_timestamp
        text record_source
        int meta_is_active "1 = version in force"
        int is_deleted "1 = gone from source"
    }

    satellite_superstore_customer {
        text hmd5_customer FK
        text md5_diff
        text customer_name
        text segment
        timestamp load_timestamp
        text record_source
        int meta_is_active "1 = version in force"
        int is_deleted "1 = gone from source"
    }
```

### Why the link has fewer rows than the satellite

`link_superstore` holds 9,983 rows against `satellite_superstore`'s 9,994.
`lmd5_superstore` hashes customer + country + state + product, so one link key
covers every order line that customer ever placed for that product — and in
this dataset **11 links carry more than one line**.

That is why `row_id` is declared as a `child_key` on the transaction satellite,
making it explicitly multi-active. Without it, taking "the current row per link
key" would silently drop those 11 order lines and every total in gold would be
short.

---

## 3. The star schema

The vault flattened back into something an analyst can query. Grain of both
`fact_superstore` and `dm_superstore` is one row per order line.

```mermaid
erDiagram
    dim_customer ||--o{ fact_superstore : customer_id
    dim_product  ||--o{ fact_superstore : product_id
    dim_country  ||--o{ fact_superstore : country_code
    dim_state    ||--o{ fact_superstore : state_code
    dim_period   ||--o{ fact_superstore : "date_key = order_date"
    dim_period   ||--o{ fact_superstore : "date_key = ship_date"

    fact_superstore {
        int row_id PK
        text order_id
        text customer_id FK
        text product_id FK
        text country_code FK
        text state_code FK
        date order_date FK
        date ship_date FK
        text ship_mode
        text region "degenerate"
        text city "degenerate"
        text postal_code "degenerate"
        numeric sales
        int quantity
        numeric discount
        numeric profit
    }

    dim_state {
        text state_code PK
        text state
    }

    dim_period {
        date date_key PK
        int year_actual
        text quarter_name
        text month_name
        int week_of_year
        bool is_weekend
    }
```

### Why the dimensions are one row per key

Every dimension here publishes only attributes its business key determines --
`state_code -> state` is 1:1 across all 49 codes, so `dim_state` is 49 rows.
That is what lets a fact join it on the key alone without multiplying.

`assert_mart_reconciles_to_fact` is what keeps this honest — it fails the
moment a dimension join multiplies a row.

---

## 4. Load behaviour per layer

| Layer | Materialization | On re-run |
|---|---|---|
| bronze | `table` | rebuilt from the seed |
| silver | `incremental` | appends only the keys and versions not already loaded |
| gold | `table` | rebuilt from the vault |

A second `dbt build` is a no-op against silver: all ten vault models report the
same row counts, because every hub anti-joins on its hash key and every
satellite anti-joins on `(parent_hash, md5_diff)`.

Satellites also carry `meta_is_active` -- 1 for the version in force, 0 once
superseded. It is stored rather than derived, and the `dv_deactivate_superseded()`
post-hook demotes whatever each load supersedes, so the flag cannot go stale.
`assert_satellite_has_one_active_version` checks all five satellites hold
exactly one active row per grain.

An insert-only load only ever sees new data, so nothing so far records a
business key vanishing from the source. `is_deleted` closes that gap: the
`dv_track_deletions()` post-hook compares each satellite's active grains
against a fresh read of its source and flags whatever is missing -- clearing
the flag again if the grain later reappears. `dv_satellite_current()` filters
it out, so a deleted row disappears from every gold model without a row ever
being removed. `assert_is_deleted_matches_source` re-derives the same
comparison independently and checks it still agrees.

```mermaid
flowchart LR
    A["dbt seed"] --> B["bronze<br/>rebuild"]
    B --> C["silver<br/>append what is new"]
    C --> D["gold<br/>rebuild from vault"]
    D --> E["147 data tests<br/>4 of them reconciliation"]
```

The reconciliation tests are the ones that matter: row counts and
`sales` / `quantity` / `profit` totals must be identical in bronze,
`fact_superstore` and `dm_superstore`. A fan-out in the link or a collapsed
multi-active satellite is invisible to row-level tests and obvious in a total.
