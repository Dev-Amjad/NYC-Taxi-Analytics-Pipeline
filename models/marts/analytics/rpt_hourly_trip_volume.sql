{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
),

hourly_stats as (
    select
        pickup_hour,
        time_of_day_bucket,
        is_weekend,
        count(*) as trip_count,
        sum(total_amount) as total_revenue,
        avg(total_amount) as avg_revenue
    from trips
    group by 1, 2, 3
)

select
    pickup_hour,
    time_of_day_bucket,
    sum(case when not is_weekend then trip_count else 0 end) as weekday_trips,
    round(avg(case when not is_weekend then avg_revenue end), 2) as weekday_avg_revenue,
    sum(case when is_weekend then trip_count else 0 end) as weekend_trips,
    round(avg(case when is_weekend then avg_revenue end), 2) as weekend_avg_revenue,
    sum(trip_count) as total_trips,
    round(sum(total_revenue), 2) as total_revenue
from hourly_stats
group by 1, 2
order by 1