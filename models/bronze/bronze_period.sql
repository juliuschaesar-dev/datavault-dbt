{#
    Bronze: the seeded calendar CSV.

    The seed is already typed by dbt_project.yml, so this model only stamps the
    audit columns. dim_period carries no business keys and no history, so it
    bypasses data vault and goes straight from here to gold.
#}

select
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
    weekend_flag,
    {{ dv_load_timestamp() }} as load_timestamp,
    'raw_period'              as record_source
from {{ ref('raw_period') }}
