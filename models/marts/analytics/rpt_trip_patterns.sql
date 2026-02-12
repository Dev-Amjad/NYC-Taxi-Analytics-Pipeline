{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
)

select
    pickup_day_of_week,
    pickup_day_name,
    pickup_hour,
    time_of_day_bucket,
    is_weekend,
    trip_distance_category,
    passenger_category,
    count(*) as trip_count,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(total_amount), 2) as avg_revenue,
    round(avg(trip_distance_miles), 2) as avg_distance,
    round(avg(trip_duration_minutes), 1) as avg_duration_minutes,
    round(avg(avg_speed_mph), 1) as avg_speed_mph,
    round(avg(revenue_per_hour), 2) as avg_revenue_per_hour,
    round(avg(tip_percentage), 1) as avg_tip_pct
from trips
group by 1, 2, 3, 4, 5, 6, 7
order by pickup_day_of_week, pickup_hour
