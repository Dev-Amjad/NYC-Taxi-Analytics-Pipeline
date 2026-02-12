# NYC Taxi Analytics Pipeline

**Take-Home Assessment for Alpha Mu Digital**

I built an end-to-end analytics pipeline that takes roughly a million NYC Yellow Taxi trips from Q1 2022 and turns them into a proper star schema warehouse with interactive dashboards. The stack is **BigQuery + dbt Core + Looker Studio**.

---

## Overview

The idea here is straightforward: take raw, messy taxi trip data and shape it into something an analyst can actually use. The pipeline pulls ~1 million trip records from Q1 2022, runs them through layered dbt transformations (staging, intermediate, marts), and produces clean fact/dimension tables plus a set of analytical reports ready for dashboarding.

**Dataset:** NYC Yellow Taxi Trip Data, Q1 2022 (January through March), ~1M rows sampled from BigQuery's public dataset.

**Why this dataset:** It's one of the best publicly available transactional datasets out there -- large-scale, well-documented by the TLC, and complex enough to show off dimensional modeling, data quality handling, and real business analytics.

---

## Stack & Constraints

| Component | Tool | Purpose |
|-----------|------|---------|
| Data Warehouse | Google BigQuery | Storage, compute, partitioning & clustering |
| Transformation | dbt Core 1.11 | Layered modeling, testing, documentation |
| Visualization | Looker Studio | Interactive dashboard |
| Ingestion | SQL script | Simulates Fivetran CDC sync |
| Packages | dbt_utils 1.1.1 | Surrogate keys, date spine |

**Constraints:** I worked within the free-tier BigQuery limits, used dbt Core locally (not Cloud), had no orchestrator, and kept it as a single-developer workflow.

---

## Part 1: Ingestion

In a real setup, Fivetran would handle ingestion automatically. Since I didn't have access to a Fivetran connector for this assessment, I wrote a SQL script (`scripts/ingest_raw_data.sql`) that simulates the same behavior:

1. Creates a `raw_nyc_taxi` schema as a landing zone
2. Copies ~1M rows from `bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022` (Q1 2022)
3. Adds Fivetran-style metadata columns: `_fivetran_synced` (timestamp) and `_fivetran_deleted` (soft-delete flag)

The key principle is the same as production -- the raw layer stays untouched, and all the cleaning happens downstream in dbt.

---

## Part 2: dbt Transformations

### Layer Architecture

| Layer | Schema | Materialization | Purpose |
|-------|--------|-----------------|---------|
| **Seeds** | `dbt_dev_seeds` | Table | Static lookup data (vendors, rate codes, payment types, 263 taxi zones) |
| **Staging** | `dbt_dev_staging` | View | Clean, rename, type-cast, filter out bad records |
| **Intermediate** | `dbt_dev_intermediate` | View | Enrich with derived metrics, categorizations, time dimensions |
| **Marts (Core)** | `dbt_dev_marts` | Table | Star schema: 1 fact table + 5 dimension tables |
| **Marts (Analytics)** | `dbt_dev_marts` | Table | Pre-aggregated report tables for dashboards |

### Star Schema

```
                        +──────────────+
                        |  dim_vendor  |
                        |  vendor_id   |
                        |  vendor_name |
                        +──────┬───────+
                               |
+──────────────+    +──────────┴───────────+    +─────────────────+
| dim_location |    |      fct_trips       |    | dim_payment_type|
| location_id  |<───| trip_id (PK)         |───>| payment_type_id |
| zone_name    |    | vendor_id (FK)       |    | payment_type_name|
| borough      |    | pickup_location_id   |    | is_electronic   |
| service_zone |    | dropoff_location_id  |    +─────────────────+
| zone_category|    | payment_type_id (FK) |
+──────────────+    | rate_code_id (FK)    |    +─────────────────+
                    | pickup_date (FK)     |    |  dim_rate_code  |
+──────────────+    | store_and_fwd_flag   |───>|  rate_code_id   |
|  dim_date    |    | trip_distance_miles   |    |  rate_code_name |
|  date_day    |<───| trip_duration_minutes |    |  rate_category  |
|  year/month  |    | fare_amount          |    |  is_airport_rate|
|  day_of_week |    | total_amount         |    +─────────────────+
|  is_weekend  |    | revenue_per_hour     |
+──────────────+    | ...43 columns total  |
                    +──────────────────────+
```

### Complete Model Inventory

| Model | Type | Rows | Description |
|-------|------|------|-------------|
| `stg_nyc_taxi__yellow_trips` | Staging (View) | ~981K | Cleaned, typed, filtered raw trips |
| `int_trips_enriched` | Intermediate (View) | ~981K | Adds date dimensions, categories, speed, revenue/hour |
| `fct_trips` | Fact (Table) | ~981K | Central fact table, partitioned by month, clustered |
| `dim_vendor` | Dimension (Table) | 2 | Vendor lookup from seed |
| `dim_rate_code` | Dimension (Table) | 7 | Rate code lookup with airport flag |
| `dim_payment_type` | Dimension (Table) | 6 | Payment type lookup with electronic flag |
| `dim_location` | Dimension (Table) | 263 | All TLC taxi zones with borough and zone category |
| `dim_date` | Dimension (Table) | 90 | Calendar dimension covering Q1 2022 |
| `agg_location_stats` | Aggregate (Table) | ~242 | Per-location aggregated metrics |
| `rpt_zone_performance` | Report (Table) | ~484 | Pickup + dropoff zone analysis |
| `rpt_trip_patterns` | Report (Table) | varies | Day x hour x distance x passenger heatmap |
| `rpt_revenue_summary` | Report (Table) | 90 | Daily revenue with composition breakdown |
| `rpt_payment_and_tipping` | Report (Table) | varies | Payment + tip behavior by segment |
| `rpt_service_analysis` | Report (Table) | varies | Rate code, peak/off-peak, congestion |

---

## Part 3: Analytics Questions

Each report model was designed to answer a specific business question. Here's what they cover:

### 1. Which zones generate the most revenue, and how do pickup vs. dropoff patterns differ?
**Model:** `rpt_zone_performance`

This one looks at both pickup and dropoff directions per zone, enriched with actual zone names and boroughs from `dim_location`. I included avg speed, revenue per hour, and fare per mile so you can compare efficiency across zones -- not just raw volume.

### 2. What are the trip demand patterns by day, hour, distance, and passenger count?
**Model:** `rpt_trip_patterns`

Basically a full heatmap: day-of-week crossed with hour, distance category (Short/Medium/Long), and passenger category (Solo/Small Group/Large Group). You can see exactly when and where demand spikes, and how trip characteristics shift throughout the week.

### 3. How does revenue break down by component?
**Model:** `rpt_revenue_summary`

Daily revenue with composition percentages -- base_fare_pct + tip_pct + tolls_pct + surcharges_pct. It also supports weekly roll-ups via the pickup_week column, which is handy for spotting trends without daily noise.

### 4. How do tipping patterns vary by payment method, time, and trip type?
**Model:** `rpt_payment_and_tipping`

Tip distribution gets bucketed into Zero Tip, Low (<10%), Standard (10-20%), and Generous (>20%), then sliced by time of day, weekend flag, and distance category. One interesting finding: cash trips almost universally show zero tips -- not because passengers don't tip, but because the data simply doesn't capture cash tips.

### 5. How do rate codes compare, and where's the congestion?
**Model:** `rpt_service_analysis`

Breaks down performance by rate code (airport vs standard vs negotiated) with peak/off-peak splits. I added a congestion_pct metric (% of trips averaging under 10 mph) as a proxy for traffic conditions -- it clearly shows that Manhattan peak hours are significantly more congested than airport runs.

---

## Part 4: Dashboard

**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/u/0/reporting/dc4cf9e7-efc6-4dd1-b6c6-0894e41d7228)

The dashboard connects directly to the BigQuery mart tables and includes:

| Visualization | Source Table | Insight |
|--------------|-------------|---------|
| KPI Scorecards | `fct_trips` | Total trips, revenue, avg fare, avg tip % |
| Hourly Demand Heatmap | `rpt_trip_patterns` | Peak hours are 6-9 PM on weekdays |
| Top Zones by Revenue | `rpt_zone_performance` | Midtown, Upper East Side, and airports dominate |
| Revenue Composition | `rpt_revenue_summary` | Base fare is ~70%, tips ~15%, surcharges ~10% |
| Payment & Tipping | `rpt_payment_and_tipping` | Credit card accounts for ~67% of trips |
| Service Analysis | `rpt_service_analysis` | Airport trips have higher avg fare but lower congestion |

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

Run `scripts/ingest_raw_data.sql` in BigQuery Console to create the raw data layer.

### Step 4: Build Everything

```bash
dbt deps                # Install dbt_utils
dbt build               # Seeds + models + tests in DAG order
```

Or if you prefer running each step individually:

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

- **1M row sample** is representative enough of Q1 2022 patterns (the full dataset is 10M+ rows, but this sample captures the key distributions)
- **Trip distance > 0 and < 500 miles** -- anything outside this range is almost certainly a GPS error or a zero-distance record
- **Total amount > 0 and < $10,000** -- this filters out refunds, chargebacks, and obvious data entry mistakes
- **Rate code nulls get mapped to 99 (Unknown)** rather than dropping those rows entirely, since losing the trip data isn't worth it
- **Cash tips aren't recorded** in the source data, so any tip analysis is inherently biased toward credit card transactions
- **store_and_fwd_flag nulls are preserved as-is** -- not every record has this field populated, and forcing a value would be misleading
- **Taxi zone IDs 258-263** are placeholder/unknown zones in the TLC reference data

---

## Tradeoffs & Design Decisions

| Decision | Rationale |
|----------|-----------|
| **Seed-based dimensions** over hard-coded CASE statements | Much easier to maintain, fully testable, and gives us a single source of truth for lookups |
| **Denormalized fact table** (joins in vendor_name, payment_type_name, rate_code_name) | Looker Studio doesn't handle joins well, so baking in the names avoids headaches; the proper dimensions are still there for anyone who wants the star schema approach |
| **Views for staging/intermediate** | Keeps storage costs down and always reflects the latest logic |
| **Tables for marts** | Dashboard queries need to be fast, so materializing these as tables is worth the storage trade-off |
| **Monthly partitioning + 3-column clustering** on fct_trips | Monthly granularity keeps partition count reasonable while clustering on location + payment + rate code covers the most common query patterns |
| **Revenue per hour** as a core metric | It's a much better measure of efficiency than revenue per trip -- a $50 airport fare that takes 90 minutes isn't as impressive as it looks |
| **Congestion indicator** (% trips < 10 mph) | A simple but effective proxy for traffic conditions when you don't have access to external traffic data |
| **Row-number surrogate key** | The source data doesn't have a natural unique key, so I generate one from row ordering -- deterministic and reproducible |
| **Warn severity** on duration/speed tests | These flag genuine data quality issues in the source, but they shouldn't block the pipeline from running |

---

## What I'd Improve With More Time

- **Incremental models** for fct_trips -- with a million rows it's fine to full-refresh, but at scale you'd want append-only logic keyed on pickup_date
- **Origin-Destination (OD) matrix** report for route-level analysis (which zone pairs generate the most revenue?)
- **Weather data join** to see how rain, snow, and temperature affect trip patterns
- **dbt exposures** to formally document which Looker Studio charts depend on which models
- **Unit tests** using dbt's built-in unit testing framework for more granular logic validation
- **Snapshot tables** for SCD Type 2 tracking if dimension attributes ever change
- **CI/CD pipeline** with PR-based dbt slim CI (`dbt build --select state:modified+`) to catch issues before merging
- **Monte Carlo or Elementary** for ongoing data observability and anomaly detection
- **Zone-to-zone distance estimation** using centroid calculations -- right now speed metrics rely solely on the taximeter distance, which isn't perfect

---

## Productionization

If this were going to production, here's what would change:

| Component | Current | Production |
|-----------|---------|------------|
| **Ingestion** | Manual SQL script | Fivetran with CDC + auto schema propagation |
| **Transformation** | dbt Core (local) | dbt Cloud with scheduled jobs |
| **Testing** | Manual `dbt test` | CI/CD: `dbt build` on every PR |
| **Monitoring** | None | dbt Cloud alerts + Elementary dashboards |
| **Orchestration** | Manual | Airflow or Dagster triggering dbt Cloud API |
| **Visualization** | Looker Studio | Looker with a governed LookML metrics layer |

---

## Testing Summary

I went from 14 tests in the original build to 93 test runs covering every layer of the pipeline:

| Category | Count | Examples |
|----------|-------|---------|
| `unique` | 10 | PKs on all dimensions, fact, staging, intermediate, reports |
| `not_null` | 22 | All PKs, FKs, and critical measures |
| `accepted_values` | 12 | vendor_id, payment_type_id, rate_code_id, categories, buckets |
| `relationships` | 5 | fct_trips FKs validated against all dimensions |
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
[LinkedIn](https://linkedin.com/in/amjad-ali-ml)

---

**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/u/0/reporting/dc4cf9e7-efc6-4dd1-b6c6-0894e41d7228)
