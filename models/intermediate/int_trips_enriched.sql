{{
    config(materialized='view')
}}

with trips as (
    select * from {{ ref('stg_nyc_taxi__yellow_trips') }}
),

enriched as (
    select
        trip_id,
        vendor_id,
        pickup_location_id,
        dropoff_location_id,
        pickup_at,
        dropoff_at,
        passenger_count,
        trip_distance_miles,
        payment_type_id,
        fare_amount,
        extra_charges,
        mta_tax,
        tip_amount,
        tolls_amount,
        improvement_surcharge,
        total_amount,
        synced_at,
        
        -- Date dimensions
        date(pickup_at) as pickup_date,
        extract(year from pickup_at) as pickup_year,
        extract(month from pickup_at) as pickup_month,
        extract(day from pickup_at) as pickup_day,
        extract(hour from pickup_at) as pickup_hour,
        extract(dayofweek from pickup_at) as pickup_day_of_week,
        format_date('%A', date(pickup_at)) as pickup_day_name,
        
        case 
            when extract(dayofweek from pickup_at) in (1, 7) then true
            else false
        end as is_weekend,
        
        case
            when extract(hour from pickup_at) between 6 and 9 then 'Morning Rush'
            when extract(hour from pickup_at) between 10 and 15 then 'Midday'
            when extract(hour from pickup_at) between 16 and 19 then 'Evening Rush'
            when extract(hour from pickup_at) between 20 and 23 then 'Night'
            else 'Late Night'
        end as time_of_day_bucket,
        
        -- Derived metrics
        timestamp_diff(dropoff_at, pickup_at, second) as trip_duration_seconds,
        timestamp_diff(dropoff_at, pickup_at, minute) as trip_duration_minutes,
        safe_divide(fare_amount, nullif(trip_distance_miles, 0)) as fare_per_mile,
        safe_divide(tip_amount, nullif(fare_amount, 0)) * 100 as tip_percentage,
        safe_divide(trip_distance_miles, nullif(timestamp_diff(dropoff_at, pickup_at, second) / 3600.0, 0)) as avg_speed_mph,
        
        case payment_type_id
            when 1 then 'Credit Card'
            when 2 then 'Cash'
            when 3 then 'No Charge'
            when 4 then 'Dispute'
            when 5 then 'Unknown'
            when 6 then 'Voided'
            else 'Other'
        end as payment_type_name

    from trips
)

select * from enriched