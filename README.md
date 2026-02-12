# NYC Taxi Analytics Pipeline

**Take-Home Assessment for Alpha Mu Digital**

An end-to-end analytics pipeline analyzing ~1M NYC Yellow Taxi trips (Q1 2022) using the modern data stack: **BigQuery + dbt Core + Looker Studio**.

---

## Overview

This project builds a production-style star schema data warehouse from raw NYC TLC Yellow Taxi trip records. The pipeline ingests ~1 million trip records from Q1 2022, applies layered dbt transformations (staging, intermediate, marts), and produces business-ready fact/dimension tables plus analytical reports.

**Dataset:** NYC Yellow Taxi Trip Data, Q1 2022 (January - March), ~1M rows sampled from BigQuery public data.

**Why this dataset:** NYC taxi data is large-scale, publicly available, well-documented by the TLC, and rich enough to demonstrate dimensional modeling, data quality handling, and meaningful business analytics.

---

## Stack & Constraints

| Component | Tool | Purpose |
|-----------|------|---------|
| Data Warehouse | Google BigQuery | Storage, compute, partitioning & clustering |
| Transformation | dbt Core 1.11 | Layered modeling, testing, documentation |
| Visualization | Looker Studio | Interactive dashboard |
| Ingestion | SQL script | Simulates Fivetran CDC sync |
| Packages | dbt_utils 1.1.1 | Surrogate keys, date spine |

**Constraints:** Free-tier BigQuery, dbt Core (not Cloud), no orchestrator, single-developer workflow.

---

## Part 1: Ingestion

The ingestion script (`scripts/ingest_raw_data.sql`) simulates a Fivetran sync by:

1. Creating a `raw_nyc_taxi` schema as a landing zone
2. Copying ~1M rows from `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` (Q1 2022)
3. Adding Fivetran-style metadata columns: `_fivetran_synced` (timestamp) and `_fivetran_deleted` (soft-delete flag)

This approach mirrors a production Fivetran setup where the raw layer is untouched and downstream transformations handle all cleaning.

---

## Part 2: dbt Transformations

### Layer Architecture

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| **Seeds** | `dbt_dev_seeds` | Table | Static lookup data (vendors, rate codes, payment types, 263 taxi zones) |
| **Staging** | `dbt_dev_staging` | View | Clean, rename, type-cast, filter invalid records |
| **Intermediate** | `dbt_dev_intermediate` | View | Enrich with derived metrics, categorizations, time dimensions |
| **Marts (Core)** | `dbt_dev_marts` | Table | Star schema: 1 fact table + 5 dimension tables |
| **Marts (Analytics)** | `dbt_dev_marts` | Table | Pre-aggregated report tables for dashboards |

### Star Schema

```
                        ┌──────────────┐
                        │  dim_vendor  │
                        │  vendor_id   │
                        │  vendor_name │
                        └──────┬───────┘
                               │
┌──────────────┐    ┌──────────┴───────────┐    ┌─────────────────┐
│ dim_location │    │      fct_trips       │    │ dim_payment_type│
│ location_id  │◄───┤ trip_id (PK)         ├───►│ payment_type_id │
│ zone_name    │    │ vendor_id (FK)       │    │ payment_type_name│
│ borough      │    │ pickup_location_id   │    │ is_electronic   │
│ service_zone │    │ dropoff_location_id  │    └─────────────────┘
│ zone_category│    │ payment_type_id (FK) │
└──────────────┘    │ rate_code_id (FK)    │    ┌─────────────────┐
                    │ pickup_date (FK)     │    │  dim_rate_code  │
┌──────────────┐    │ store_and_fwd_flag   ├───►│  rate_code_id   │
│  dim_date    │    │ trip_distance_miles   │    │  rate_code_name │
│  date_day    │◄───┤ trip_duration_minutes │    │  rate_category  │
│  year/month  │    │ fare_amount          │    │  is_airport_rate│
│  day_of_week │    │ total_amount         │    └─────────────────┘
│  is_weekend  │    │ revenue_per_hour     │
└──────────────┘    │ ...43 columns total  │
                    └──────────────────────┘
```

### Complete Model Inventory

| Model | Type | Rows | Description |
|-------|------|------|-------------|
| `stg_nyc_taxi__yellow_trips` | Staging (View) | ~981K | Cleaned, typed, filtered raw trips |
| `int_trips_enriched` | Intermediate (View) | ~981K | +date dims, categories, speed, revenue/hour |
| `fct_trips` | Fact (Table) | ~981K | Central fact table, partitioned by month, clustered |
| `dim_vendor` | Dimension (Table) | 2 | Vendor lookup from seed |
| `dim_rate_code` | Dimension (Table) | 7 | Rate code lookup with airport flag |
| `dim_payment_type` | Dimension (Table) | 6 | Payment type lookup with electronic flag |
| `dim_location` | Dimension (Table) | 263 | TLC taxi zones with borough and zone category |
| `dim_date` | Dimension (Table) | 90 | Calendar dimension for Q1 2022 |
| `agg_location_stats` | Aggregate (Table) | ~242 | Per-location aggregated metrics |
| `rpt_zone_performance` | Report (Table) | ~484 | Pickup + dropoff zone analysis |
| `rpt_trip_patterns` | Report (Table) | varies | Day x hour x distance x passenger heatmap |
| `rpt_revenue_summary` | Report (Table) | 90 | Daily revenue with composition breakdown |
| `rpt_payment_and_tipping` | Report (Table) | varies | Payment + tip behavior by segment |
| `rpt_service_analysis` | Report (Table) | varies | Rate code, peak/off-peak, congestion |

---

## Part 3: Analytics Questions

The pipeline answers these business questions through dedicated report models:

### 1. Which zones generate the most revenue and how do pickup vs. dropoff patterns differ?
**Model:** `rpt_zone_performance`

Analyzes both pickup and dropoff directions per zone, enriched with zone name and borough from `dim_location`. Includes avg speed, revenue per hour, and fare per mile for efficiency comparison.

### 2. What are the trip demand patterns by day, hour, distance, and passenger count?
**Model:** `rpt_trip_patterns`

Full heatmap data: day-of-week x hour x distance category (Short/Medium/Long) x passenger category (Solo/Small Group/Large Group). Includes speed and efficiency metrics per segment.

### 3. How does revenue break down by component (base fare, tips, tolls, surcharges)?
**Model:** `rpt_revenue_summary`

Daily revenue with composition percentages: base_fare_pct + tip_pct + tolls_pct + surcharges_pct. Supports weekly roll-up via pickup_week column.

### 4. How do tipping patterns vary by payment method, time, and trip type?
**Model:** `rpt_payment_and_tipping`

Tip distribution buckets (Zero Tip / Low / Standard / Generous) sliced by time_of_day, weekend flag, and distance category. Reveals that cash trips show zero tips (not recorded) while credit card tips cluster around 15-20%.

### 5. How do rate codes (airport vs standard vs negotiated) compare, and what indicates congestion?
**Model:** `rpt_service_analysis`

Rate code breakdown with peak/off-peak splits. Includes congestion_pct (% of trips averaging < 10 mph), revealing that Manhattan peak hours show significantly higher congestion than airport runs.

---

## Part 4: Dashboard

**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/s/h_Kxfie8lXo)

The dashboard connects directly to the BigQuery mart tables and includes:

| Visualization | Source Table | Insight |
|--------------|-------------|---------|
| KPI Scorecards | `fct_trips` | Total trips, revenue, avg fare, avg tip % |
| Hourly Demand Heatmap | `rpt_trip_patterns` | Peak hours: 6-9 PM weekdays |
| Top Zones by Revenue | `rpt_zone_performance` | Midtown, UES, airports dominate |
| Revenue Composition | `rpt_revenue_summary` | Base fare ~70%, tips ~15%, surcharges ~10% |
| Payment & Tipping | `rpt_payment_and_tipping` | Credit card ~67% of trips |
| Service Analysis | `rpt_service_analysis` | Airport trips: higher avg fare, lower congestion |

---

## Part 5: Setup & How to Run

### Prerequisites

- Google Cloud account with BigQuery access
- Python 3.8+
- Git

### Step 1: Clone & Setup

```bash
git clone <repo-url>
cd nyc_taxi_analytics
python -m venv venv
source venv/bin/activate
pip install dbt-bigquery
```

### Step 2: Configure dbt Profile

Create or edit `~/.dbt/profiles.yml`:

```yaml
nyc_taxi_analytics:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: service-account
      project: your-gcp-project-id
      dataset: dbt_dev
      threads: 4
      keyfile: /path/to/your/service-account-key.json
      location: US
```

### Step 3: Ingest Raw Data

Execute `scripts/ingest_raw_data.sql` in BigQuery Console to create the raw data layer.

### Step 4: Build Everything

```bash
dbt deps                # Install dbt_utils
dbt build               # Seeds + models + tests in DAG order
```

Or run each step individually:

```bash
dbt seed                # Load 4 seed CSVs
dbt run                 # Build all models
dbt test                # Run all ~56 tests
```

### Step 5: Explore Documentation

```bash
dbt docs generate
dbt docs serve          # Opens at localhost:8080
```

---

## Assumptions

- **1M row sample** is representative of Q1 2022 patterns (full dataset is ~10M+ rows)
- **Trip distance > 0 and < 500 miles** filters out GPS errors and zero-distance records
- **Total amount > 0 and < $10,000** removes refunds, chargebacks, and data entry errors
- **Rate code nulls mapped to 99 (Unknown)** rather than dropping those rows
- **Cash tips are not recorded** in the source data; tip analysis is inherently biased toward credit card trips
- **store_and_fwd_flag** nulls are preserved as-is (not all records have this populated)
- **Taxi zone IDs 258-263** are placeholder/unknown zones in the TLC reference data

---

## Tradeoffs & Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Seed-based dimensions** over hard-coded CASE statements | Maintainable, testable, single source of truth for lookups |
| **Denormalized fact table** (joins vendor_name, payment_type_name, rate_code_name) | Eliminates joins for Looker Studio; dimensions still available for proper star schema queries |
| **Views for staging/intermediate** | Reduces storage cost; always reflects latest logic |
| **Tables for marts** | Optimized query performance for dashboard reads |
| **Monthly partitioning + 3-column clustering** on fct_trips | Balances partition pruning with common query patterns |
| **Revenue per hour** as a core metric | Better measures driver efficiency than revenue per trip |
| **Congestion indicator** (% trips < 10 mph) | Proxy for traffic conditions without external data |
| **Row-number surrogate key** | Source lacks natural unique key; deterministic ordering ensures reproducibility |
| **Warn severity** on duration/speed tests | Flags data quality issues without blocking the pipeline |

---

## What Would Improve With More Time

- **Incremental models** for fct_trips (append-only pattern on pickup_date)
- **Origin-Destination (OD) matrix** report for route-level analysis
- **Weather data join** to correlate trip patterns with conditions
- **dbt exposures** to formally document Looker Studio dashboard dependencies
- **Unit tests** with dbt's built-in unit testing framework
- **Snapshot tables** for SCD Type 2 tracking on dimension changes
- **CI/CD pipeline** with PR-based dbt slim CI (`dbt build --select state:modified+`)
- **Monte Carlo or Elementary** for data observability and anomaly detection
- **Zone-to-zone distance estimation** using centroid calculations for better speed/efficiency metrics

---

## Productionization

| Component | Current | Production |
|-----------|---------|------------|
| **Ingestion** | Manual SQL script | Fivetran with CDC + auto schema propagation |
| **Transformation** | dbt Core (local) | dbt Cloud with scheduled jobs |
| **Testing** | Manual `dbt test` | CI/CD: `dbt build` on every PR |
| **Monitoring** | None | dbt Cloud alerts + Elementary dashboards |
| **Orchestration** | Manual | Airflow/Dagster triggering dbt Cloud API |
| **Visualization** | Looker Studio | Looker with governed LookML metrics layer |

---

## Testing Summary

| Category | Count | Examples |
|----------|-------|---------|
| `unique` | 10 | PKs on all dimensions, fact, staging, intermediate, reports |
| `not_null` | 22 | All PKs, FKs, and critical measures |
| `accepted_values` | 12 | vendor_id, payment_type_id, rate_code_id, categories, buckets |
| `relationships` | 5 | fct_trips FKs to all dimensions |
| Custom (error) | 3 | Grain uniqueness, revenue consistency |
| Custom (warn) | 3 | Duration range, speed plausibility, store_and_fwd_flag values |
| **Total** | **~55** | |

```bash
dbt test                    # Run all tests
dbt test --select staging   # Test staging layer only
dbt test --select tag:relationships  # Test FK integrity
```

---

## Project Structure

```
nyc_taxi_analytics/
├── dbt_project.yml
├── packages.yml
├── README.md
│
├── seeds/
│   ├── _seeds__schema.yml
│   ├── seed_vendors.csv             # 2 vendors
│   ├── seed_rate_codes.csv          # 7 rate codes
│   ├── seed_payment_types.csv       # 6 payment types
│   └── seed_taxi_zones.csv          # 263 TLC taxi zones
│
├── models/
│   ├── staging/nyc_taxi/
│   │   ├── _sources.yml
│   │   ├── _stg_nyc_taxi__models.yml
│   │   └── stg_nyc_taxi__yellow_trips.sql
│   │
│   ├── intermediate/
│   │   ├── _int__models.yml
│   │   └── int_trips_enriched.sql
│   │
│   └── marts/
│       ├── core/
│       │   ├── _core__models.yml
│       │   ├── fct_trips.sql
│       │   ├── dim_vendor.sql
│       │   ├── dim_rate_code.sql
│       │   ├── dim_payment_type.sql
│       │   ├── dim_location.sql
│       │   └── dim_date.sql
│       │
│       └── analytics/
│           ├── _analytics__models.yml
│           ├── agg_location_stats.sql
│           ├── rpt_zone_performance.sql
│           ├── rpt_trip_patterns.sql
│           ├── rpt_revenue_summary.sql
│           ├── rpt_payment_and_tipping.sql
│           └── rpt_service_analysis.sql
│
├── tests/
│   ├── assert_positive_trip_duration.sql
│   ├── assert_revenue_consistency.sql
│   ├── assert_valid_trip_duration_range.sql
│   ├── assert_fact_grain_unique.sql
│   └── assert_valid_speed.sql
│
└── scripts/
    └── ingest_raw_data.sql
```

---

## Author

**Amjad Ali**
Data & AI Engineer

---

**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/s/h_Kxfie8lXo)
