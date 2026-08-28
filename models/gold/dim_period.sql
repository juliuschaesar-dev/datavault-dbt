{#
    The calendar bypasses the vault.

    A date has no business key that can change, no source system to reconcile
    and no history to track, so a hub/satellite pair would add ceremony without
    adding a fact. Bronze straight to gold.

    Grain: one row per calendar date. Joins to fact_superstore on
    order_date / ship_date.
#}

select
    date_actual as date_key,
    date_actual,
    date_actual_time,
    day_suffix,
    day_name,
    day_of_week,
    day_of_month,
    day_of_quarter,
    day_of_year,
    week_of_month,
    week_of_year,
    week_of_year_iso,
    month_actual,
    month_name,
    month_name_abbreviated,
    quarter_actual,
    quarter_name,
    year_actual,
    first_day_of_week,
    last_day_of_week,
    first_day_of_month,
    last_day_of_month,
    first_day_of_quarter,
    last_day_of_quarter,
    first_day_of_year,
    last_day_of_year,
    case when weekend_flag = 1 then true else false end as is_weekend,
    load_timestamp
from {{ ref('bronze_period') }}
