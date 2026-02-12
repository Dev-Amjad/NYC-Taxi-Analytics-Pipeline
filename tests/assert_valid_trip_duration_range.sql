{{ config(severity='warn') }}

select
    trip_id,
    trip_duration_minutes
from {{ ref('fct_trips') }}
where trip_duration_minutes > 240
limit 100
