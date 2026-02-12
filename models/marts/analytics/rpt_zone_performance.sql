{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
),

locations as (
    select * from {{ ref('dim_location') }}
),

pickup_stats as (
    select
        t.pickup_location_id as location_id,
        'pickup' as direction,
        l.zone_name,
        l.borough,
        l.service_zone,
        l.zone_category,
        count(*) as trip_count,
        round(sum(t.total_amount), 2) as total_revenue,
        round(avg(t.total_amount), 2) as avg_revenue,
        round(avg(t.trip_distance_miles), 2) as avg_distance,
        round(avg(t.trip_duration_minutes), 1) as avg_duration_minutes,
        round(avg(t.avg_speed_mph), 1) as avg_speed_mph,
        round(avg(t.revenue_per_hour), 2) as avg_revenue_per_hour,
        round(avg(t.tip_percentage), 1) as avg_tip_pct,
        round(avg(t.fare_per_mile), 2) as avg_fare_per_mile
    from trips t
    left join locations l on t.pickup_location_id = l.location_id
    group by 1, 2, 3, 4, 5, 6
),

dropoff_stats as (
    select
        t.dropoff_location_id as location_id,
        'dropoff' as direction,
        l.zone_name,
        l.borough,
        l.service_zone,
        l.zone_category,
        count(*) as trip_count,
        round(sum(t.total_amount), 2) as total_revenue,
        round(avg(t.total_amount), 2) as avg_revenue,
        round(avg(t.trip_distance_miles), 2) as avg_distance,
        round(avg(t.trip_duration_minutes), 1) as avg_duration_minutes,
        round(avg(t.avg_speed_mph), 1) as avg_speed_mph,
        round(avg(t.revenue_per_hour), 2) as avg_revenue_per_hour,
        round(avg(t.tip_percentage), 1) as avg_tip_pct,
        round(avg(t.fare_per_mile), 2) as avg_fare_per_mile
    from trips t
    left join locations l on t.dropoff_location_id = l.location_id
    group by 1, 2, 3, 4, 5, 6
)

select * from pickup_stats
union all
select * from dropoff_stats
