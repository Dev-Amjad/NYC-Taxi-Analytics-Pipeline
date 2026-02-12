{{ config(severity='warn') }}

select
    trip_id,
    avg_speed_mph,
    trip_distance_miles,
    trip_duration_minutes
from {{ ref('fct_trips') }}
where avg_speed_mph > 80
limit 100
