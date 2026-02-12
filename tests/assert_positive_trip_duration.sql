{{ config(severity='warn') }}

select
    trip_id,
    trip_duration_minutes
from {{ ref('fct_trips') }}
where trip_duration_minutes <= 0
limit 100