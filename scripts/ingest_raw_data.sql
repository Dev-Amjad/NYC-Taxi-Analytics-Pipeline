-- =============================================================================
-- NYC Taxi Data Ingestion Script (SQL Version)
-- =============================================================================
-- This SQL script can be run directly in BigQuery Console.
-- For automated ingestion, use the Python script: ingest_raw_data.py
-- =============================================================================

-- Step 1: Create raw dataset
CREATE SCHEMA IF NOT EXISTS `a8s-marketing.raw_nyc_taxi`
OPTIONS(
    description = 'Raw data landing zone - simulates Fivetran sync',
    location = 'US'
);

-- Step 2: Create raw table with Fivetran-style metadata
CREATE OR REPLACE TABLE `a8s-marketing.raw_nyc_taxi.yellow_tripdata` AS
SELECT 
    -- Original columns
    vendor_id,
    pickup_datetime,
    dropoff_datetime,
    passenger_count,
    trip_distance,
    pickup_location_id,
    dropoff_location_id,
    rate_code,
    store_and_fwd_flag,
    payment_type,
    fare_amount,
    extra,
    mta_tax,
    tip_amount,
    tolls_amount,
    imp_surcharge,
    total_amount,
    
    -- Fivetran-style metadata columns
    CURRENT_TIMESTAMP() AS _fivetran_synced,
    FALSE AS _fivetran_deleted
    
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= '2022-01-01'
  AND pickup_datetime < '2022-04-01'
LIMIT 1000000;

-- Step 3: Verify ingestion
SELECT 
    COUNT(*) as total_rows,
    MIN(pickup_datetime) as min_date,
    MAX(pickup_datetime) as max_date,
    ROUND(SUM(total_amount), 2) as total_revenue
FROM `a8s-marketing.raw_nyc_taxi.yellow_tripdata`;