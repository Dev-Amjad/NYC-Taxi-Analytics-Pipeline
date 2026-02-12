with date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="cast('2022-01-01' as date)",
        end_date="cast('2022-04-01' as date)"
    ) }}
),

dates as (
    select
        cast(date_day as date) as date_day
    from date_spine
)

select
    date_day,
    extract(year from date_day) as year,
    extract(quarter from date_day) as quarter,
    extract(month from date_day) as month,
    extract(week from date_day) as week_of_year,
    extract(dayofweek from date_day) as day_of_week,
    format_date('%A', date_day) as day_name,
    extract(dayofweek from date_day) in (1, 7) as is_weekend,
    format_date('%Y-%m', date_day) as year_month,
    format_date('%G-W%V', date_day) as year_week
from dates
