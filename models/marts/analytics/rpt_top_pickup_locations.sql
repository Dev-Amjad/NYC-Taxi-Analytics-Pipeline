{{ config(materialized='table') }}

select
    location_id,
    total_trips,
    total_revenue,
    avg_trip_revenue,
    avg_trip_distance_miles,
    avg_tip_percentage,
    credit_card_pct,
    revenue_rank,
    trip_volume_rank
from {{ ref('dim_locations') }}
where revenue_rank <= 20
order by revenue_rank