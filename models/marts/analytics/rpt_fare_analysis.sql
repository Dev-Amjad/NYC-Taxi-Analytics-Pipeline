{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
)

select
    pickup_day_name,
    pickup_day_of_week,
    is_weekend,
    time_of_day_bucket,
    count(*) as trip_count,
    round(avg(fare_amount), 2) as avg_fare,
    round(avg(total_amount), 2) as avg_total,
    round(avg(trip_distance_miles), 2) as avg_distance,
    round(avg(fare_per_mile), 2) as avg_fare_per_mile,
    round(avg(tip_percentage), 1) as avg_tip_pct
from trips
group by 1, 2, 3, 4
order by pickup_day_of_week, time_of_day_bucket
