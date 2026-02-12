{{
    config(
        materialized='table',
        partition_by={
            'field': 'pickup_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by=['pickup_location_id', 'payment_type_id']
    )
}}

with trips as (
    select * from {{ ref('int_trips_enriched') }}
)

select
    trip_id,
    pickup_location_id,
    dropoff_location_id,
    vendor_id,
    payment_type_id,
    pickup_date,
    pickup_year,
    pickup_month,
    pickup_day,
    pickup_hour,
    pickup_day_of_week,
    pickup_day_name,
    is_weekend,
    time_of_day_bucket,
    pickup_at,
    dropoff_at,
    passenger_count,
    trip_distance_miles,
    trip_duration_minutes,
    fare_amount,
    extra_charges,
    mta_tax,
    tip_amount,
    tolls_amount,
    improvement_surcharge,
    total_amount,
    fare_per_mile,
    tip_percentage,
    avg_speed_mph,
    payment_type_name,
    synced_at,
    current_timestamp() as dbt_updated_at
from trips