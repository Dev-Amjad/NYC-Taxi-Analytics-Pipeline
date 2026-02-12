{{
    config(
        materialized='table',
        partition_by={
            'field': 'pickup_date',
            'data_type': 'date',
            'granularity': 'month'
        },
        cluster_by=['pickup_location_id', 'payment_type_id', 'rate_code_id']
    )
}}

with trips as (
    select * from {{ ref('int_trips_enriched') }}
),

vendors as (
    select * from {{ ref('seed_vendors') }}
),

payment_types as (
    select * from {{ ref('seed_payment_types') }}
),

rate_codes as (
    select * from {{ ref('seed_rate_codes') }}
)

select
    t.trip_id,
    t.pickup_location_id,
    t.dropoff_location_id,
    t.vendor_id,
    t.payment_type_id,
    t.rate_code_id,
    t.store_and_fwd_flag,
    t.pickup_date,
    t.pickup_year,
    t.pickup_month,
    t.pickup_day,
    t.pickup_hour,
    t.pickup_day_of_week,
    t.pickup_day_name,
    t.pickup_week,
    t.is_weekend,
    t.time_of_day_bucket,
    t.trip_distance_category,
    t.trip_duration_category,
    t.passenger_category,
    t.pickup_at,
    t.dropoff_at,
    t.passenger_count,
    t.trip_distance_miles,
    t.trip_duration_seconds,
    t.trip_duration_minutes,
    t.fare_amount,
    t.extra_charges,
    t.mta_tax,
    t.tip_amount,
    t.tolls_amount,
    t.improvement_surcharge,
    t.total_surcharges,
    t.total_amount,
    t.fare_per_mile,
    t.tip_percentage,
    t.avg_speed_mph,
    t.revenue_per_hour,
    v.vendor_name,
    pt.payment_type_name,
    rc.rate_code_name,
    t.synced_at,
    current_timestamp() as dbt_updated_at
from trips t
left join vendors v on t.vendor_id = v.vendor_id
left join payment_types pt on t.payment_type_id = pt.payment_type_id
left join rate_codes rc on t.rate_code_id = rc.rate_code_id
