-- =============================================================================
-- INGESTION SCRIPT: Simulates Fivetran landing raw data
-- =============================================================================
-- In production, Fivetran would:
-- 1. Connect to source system via pre-built connector
-- 2. Perform initial historical sync
-- 3. Run incremental syncs based on CDC or timestamp
-- 4. Auto-handle schema changes
-- =============================================================================

CREATE SCHEMA IF NOT EXISTS `a8s-marketing.raw_nyc_taxi`
OPTIONS(description = 'Raw data landing zone - simulates Fivetran sync', location = 'US');

CREATE OR REPLACE TABLE `a8s-marketing.raw_nyc_taxi.yellow_tripdata` AS
SELECT 
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
    CURRENT_TIMESTAMP() AS _fivetran_synced,
    FALSE AS _fivetran_deleted
FROM `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022`
WHERE pickup_datetime >= '2022-01-01'
  AND pickup_datetime < '2022-04-01'
LIMIT 1000000;