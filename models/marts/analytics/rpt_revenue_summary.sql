{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
),

daily_revenue as (
    select
        pickup_date,
        pickup_year,
        pickup_month,
        pickup_week,
        pickup_day_name,
        is_weekend,
        count(*) as trip_count,
        round(sum(fare_amount), 2) as total_base_fare,
        round(sum(tip_amount), 2) as total_tips,
        round(sum(tolls_amount), 2) as total_tolls,
        round(sum(total_surcharges), 2) as total_surcharges,
        round(sum(total_amount), 2) as total_revenue,
        round(avg(total_amount), 2) as avg_trip_revenue,
        round(avg(fare_per_mile), 2) as avg_fare_per_mile,
        round(avg(tip_percentage), 1) as avg_tip_pct,
        round(avg(revenue_per_hour), 2) as avg_revenue_per_hour
    from trips
    group by 1, 2, 3, 4, 5, 6
)

select
    pickup_date,
    pickup_year,
    pickup_month,
    pickup_week,
    pickup_day_name,
    is_weekend,
    trip_count,
    total_base_fare,
    total_tips,
    total_tolls,
    total_surcharges,
    total_revenue,
    avg_trip_revenue,
    avg_fare_per_mile,
    avg_tip_pct,
    avg_revenue_per_hour,
    round(safe_divide(total_base_fare, total_revenue) * 100, 1) as base_fare_pct,
    round(safe_divide(total_tips, total_revenue) * 100, 1) as tip_pct,
    round(safe_divide(total_tolls, total_revenue) * 100, 1) as tolls_pct,
    round(safe_divide(total_surcharges, total_revenue) * 100, 1) as surcharges_pct
from daily_revenue
order by pickup_date
