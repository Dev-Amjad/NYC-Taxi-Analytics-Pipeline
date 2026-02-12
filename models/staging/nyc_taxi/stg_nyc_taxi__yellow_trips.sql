{{
    config(materialized='view')
}}

with source as (
    select 
        *,
        row_number() over (order by pickup_datetime, dropoff_datetime, pickup_location_id) as row_num
    from {{ source('raw_nyc_taxi', 'yellow_tripdata') }}
    where _fivetran_deleted = false
),

renamed_and_cast as (
    select
        -- Use row_number for guaranteed uniqueness
        {{ dbt_utils.generate_surrogate_key(['row_num']) }} as trip_id,
        
        cast(vendor_id as int64) as vendor_id,
        cast(pickup_location_id as int64) as pickup_location_id,
        cast(dropoff_location_id as int64) as dropoff_location_id,
        cast(pickup_datetime as timestamp) as pickup_at,
        cast(dropoff_datetime as timestamp) as dropoff_at,
        cast(passenger_count as int64) as passenger_count,
        cast(trip_distance as float64) as trip_distance_miles,
        cast(rate_code as int64) as rate_code_id,
        cast(payment_type as int64) as payment_type_id,
        cast(fare_amount as float64) as fare_amount,
        cast(extra as float64) as extra_charges,
        cast(mta_tax as float64) as mta_tax,
        cast(tip_amount as float64) as tip_amount,
        cast(tolls_amount as float64) as tolls_amount,
        cast(imp_surcharge as float64) as improvement_surcharge,
        cast(total_amount as float64) as total_amount,
        _fivetran_synced as synced_at
        
    from source
),

filtered as (
    select *
    from renamed_and_cast
    where 
        pickup_at is not null
        and dropoff_at is not null
        and dropoff_at > pickup_at
        and trip_distance_miles > 0
        and trip_distance_miles < 500
        and total_amount > 0
        and total_amount < 10000
        and fare_amount >= 0
)

select * from filtered