{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
),

locations as (
    select * from {{ ref('dim_location') }}
),

location_stats as (
    select
        pickup_location_id as location_id,
        count(*) as total_trips,
        count(distinct pickup_date) as active_days,
        sum(total_amount) as total_revenue,
        avg(total_amount) as avg_trip_revenue,
        sum(tip_amount) as total_tips,
        avg(trip_distance_miles) as avg_trip_distance,
        avg(trip_duration_minutes) as avg_trip_duration,
        avg(passenger_count) as avg_passengers,
        sum(case when is_weekend then 1 else 0 end) as weekend_trips,
        sum(case when not is_weekend then 1 else 0 end) as weekday_trips,
        sum(case when payment_type_id = 1 then 1 else 0 end) as credit_card_trips,
        sum(case when payment_type_id = 2 then 1 else 0 end) as cash_trips,
        avg(tip_percentage) as avg_tip_percentage,
        avg(fare_per_mile) as avg_fare_per_mile
    from trips
    group by 1
)

select
    ls.location_id,
    l.zone_name,
    l.borough,
    l.service_zone,
    l.zone_category,
    ls.total_trips,
    ls.active_days,
    round(ls.total_revenue, 2) as total_revenue,
    round(ls.avg_trip_revenue, 2) as avg_trip_revenue,
    round(ls.total_tips, 2) as total_tips,
    round(ls.avg_trip_distance, 2) as avg_trip_distance_miles,
    round(ls.avg_trip_duration, 1) as avg_trip_duration_minutes,
    round(ls.avg_passengers, 1) as avg_passengers,
    ls.weekend_trips,
    ls.weekday_trips,
    round(safe_divide(ls.weekend_trips, ls.total_trips) * 100, 1) as weekend_trip_pct,
    ls.credit_card_trips,
    ls.cash_trips,
    round(safe_divide(ls.credit_card_trips, ls.total_trips) * 100, 1) as credit_card_pct,
    round(ls.avg_tip_percentage, 1) as avg_tip_percentage,
    round(ls.avg_fare_per_mile, 2) as avg_fare_per_mile,
    rank() over (order by ls.total_revenue desc) as revenue_rank,
    rank() over (order by ls.total_trips desc) as trip_volume_rank,
    current_timestamp() as dbt_updated_at
from location_stats ls
left join locations l on ls.location_id = l.location_id
