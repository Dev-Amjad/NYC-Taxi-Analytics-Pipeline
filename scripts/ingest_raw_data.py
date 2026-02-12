"""
NYC Taxi Data Ingestion Script
==============================
Simulates Fivetran-style data landing into raw layer.

This script:
1. Connects to BigQuery using service account
2. Creates raw dataset (if not exists)
3. Loads NYC Taxi data with Fivetran-style metadata columns

Usage:
    python scripts/ingest_raw_data.py

Requirements:
    pip install google-cloud-bigquery
"""

import os
from google.cloud import bigquery
from google.oauth2 import service_account
from datetime import datetime


# Configuration
PROJECT_ID = "a8s-marketing"
RAW_DATASET = "raw_nyc_taxi"
RAW_TABLE = "yellow_tripdata"
LOCATION = "US"

# Source: BigQuery Public Dataset
SOURCE_TABLE = "bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022"

# Data parameters
START_DATE = "2022-01-01"
END_DATE = "2022-04-01"
ROW_LIMIT = 1000000


def get_client(keyfile_path: str = None) -> bigquery.Client:
    """
    Create BigQuery client using service account.
    
    Args:
        keyfile_path: Path to service account JSON key file.
                     If None, uses GOOGLE_APPLICATION_CREDENTIALS env var.
    
    Returns:
        BigQuery client instance
    """
    if keyfile_path:
        credentials = service_account.Credentials.from_service_account_file(
            keyfile_path,
            scopes=["https://www.googleapis.com/auth/cloud-platform"]
        )
        client = bigquery.Client(credentials=credentials, project=PROJECT_ID)
    else:
        client = bigquery.Client(project=PROJECT_ID)
    
    print(f"✓ Connected to BigQuery project: {PROJECT_ID}")
    return client


def create_raw_dataset(client: bigquery.Client) -> None:
    """Create raw dataset if it doesn't exist."""
    dataset_id = f"{PROJECT_ID}.{RAW_DATASET}"
    dataset = bigquery.Dataset(dataset_id)
    dataset.location = LOCATION
    dataset.description = "Raw data landing zone - simulates Fivetran sync"
    
    try:
        client.create_dataset(dataset, exists_ok=True)
        print(f"✓ Dataset ready: {dataset_id}")
    except Exception as e:
        print(f"✗ Error creating dataset: {e}")
        raise


def ingest_taxi_data(client: bigquery.Client) -> int:
    """
    Ingest NYC Taxi data into raw layer with Fivetran-style metadata.
    
    Returns:
        Number of rows ingested
    """
    table_id = f"{PROJECT_ID}.{RAW_DATASET}.{RAW_TABLE}"
    
    query = f"""
    CREATE OR REPLACE TABLE `{table_id}` AS
    SELECT 
        -- Original columns from source
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
        
    FROM `{SOURCE_TABLE}`
    WHERE pickup_datetime >= '{START_DATE}'
      AND pickup_datetime < '{END_DATE}'
    LIMIT {ROW_LIMIT}
    """
    
    print(f"⏳ Ingesting data from {SOURCE_TABLE}...")
    print(f"   Date range: {START_DATE} to {END_DATE}")
    print(f"   Row limit: {ROW_LIMIT:,}")
    
    # Execute query
    job = client.query(query)
    job.result()  # Wait for completion
    
    # Get row count
    table = client.get_table(table_id)
    row_count = table.num_rows
    
    print(f"✓ Table created: {table_id}")
    print(f"✓ Rows ingested: {row_count:,}")
    
    return row_count


def verify_data(client: bigquery.Client) -> None:
    """Run verification queries on ingested data."""
    table_id = f"{PROJECT_ID}.{RAW_DATASET}.{RAW_TABLE}"
    
    # Sample query
    query = f"""
    SELECT 
        COUNT(*) as total_rows,
        MIN(pickup_datetime) as min_date,
        MAX(pickup_datetime) as max_date,
        COUNT(DISTINCT vendor_id) as vendors,
        ROUND(SUM(total_amount), 2) as total_revenue
    FROM `{table_id}`
    """
    
    result = client.query(query).result()
    row = list(result)[0]
    
    print("\n📊 Data Verification:")
    print(f"   Total rows: {row.total_rows:,}")
    print(f"   Date range: {row.min_date} to {row.max_date}")
    print(f"   Vendors: {row.vendors}")
    print(f"   Total revenue: ${row.total_revenue:,.2f}")


def main():
    """Main ingestion workflow."""
    print("=" * 60)
    print("NYC Taxi Data Ingestion")
    print("=" * 60)
    print(f"Started at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
    
    # Check for keyfile
    keyfile_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if not keyfile_path:
        # Try default location
        default_path = os.path.expanduser("~/.dbt/bigquery-keyfile.json")
        if os.path.exists(default_path):
            keyfile_path = default_path
    
    if keyfile_path:
        print(f"Using keyfile: {keyfile_path}\n")
    
    # Run ingestion
    client = get_client(keyfile_path)
    create_raw_dataset(client)
    rows = ingest_taxi_data(client)
    verify_data(client)
    
    print("\n" + "=" * 60)
    print("✅ Ingestion complete!")
    print("=" * 60)
    
    return rows


if __name__ == "__main__":
    main()