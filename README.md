# NYC Taxi Analytics Pipeline

**Take-Home Assessment for Alpha Mu Digital**

A production-style end-to-end analytics pipeline analyzing NYC Yellow Taxi trip data using the modern data stack: **BigQuery + dbt Core + Looker Studio**.

---

## Table of Contents

- [Overview](#overview)
- [Business Questions](#business-questions)
- [Tech Stack](#tech-stack)
- [Data Pipeline](#data-pipeline)
- [Project Structure](#project-structure)
- [Setup Instructions](#setup-instructions)
- [Data Models](#data-models)
- [Testing](#testing)
- [Dashboard](#dashboard)
- [Design Decisions](#design-decisions)
- [Productionization](#productionization)
- [Author](#author)

---

## Overview

This project demonstrates a complete analytics workflow from raw data ingestion to business-ready dashboards. Using NYC Yellow Taxi trip data from Q1 2022 (~1 million trips), the pipeline transforms raw transactional data into actionable insights.

**Key Highlights:**
- Simulated Fivetran ingestion with metadata columns
- Layered dbt transformations (staging → intermediate → marts)
- Dimensional modeling with fact and dimension tables
- Comprehensive testing suite (15 tests)
- Interactive Looker Studio dashboard

---

## Business Questions

The pipeline answers these key business questions:

| # | Question | Report Model |
|---|----------|--------------|
| 1 | Which pickup locations generate the most revenue? | `rpt_top_pickup_locations` |
| 2 | How does trip volume vary by hour of day? | `rpt_hourly_trip_volume` |
| 3 | What's the average fare per mile by day/time? | `rpt_fare_analysis` |
| 4 | How do payment methods differ in usage and tips? | `rpt_payment_breakdown` |
| 5 | How do peak hours compare to off-peak demand? | `rpt_peak_vs_offpeak` |

---

## Tech Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Data Warehouse | Google BigQuery | Storage and compute |
| Transformation | dbt Core 1.11 | Data modeling and testing |
| Visualization | Looker Studio | Dashboard and reporting |
| Ingestion | SQL script | Simulates Fivetran sync |

---

## Data Pipeline

### Layer Overview

| Layer | Schema | Description | Materialization |
|-------|--------|-------------|-----------------|
| **Raw** | `raw_nyc_taxi` | Landing zone mimicking Fivetran | Table |
| **Staging** | `dbt_dev_staging` | Cleaned, renamed, typed | View |
| **Intermediate** | `dbt_dev_intermediate` | Enriched with derived fields | View |
| **Marts** | `dbt_dev_marts` | Business-ready tables | Table |

### Transformation Flow

```
Source: bigquery-public-data.new_york_taxi_trips.tlc_yellow_trips_2022
    │
    ▼
Raw: raw_nyc_taxi.yellow_tripdata (1M rows, Fivetran metadata added)
    │
    ▼
Staging: stg_nyc_taxi__yellow_trips (cleaned, filtered, surrogate key)
    │
    ▼
Intermediate: int_trips_enriched (time dimensions, derived metrics)
    │
    ▼
Marts: fct_trips (fact table) + dim_locations (dimension table)
    │
    ▼
Analytics: 5 report tables for dashboards
```

---

## Project Structure

```
nyc_taxi_analytics/
│
├── dbt_project.yml              # Project configuration
├── packages.yml                 # dbt packages (dbt_utils)
├── README.md                    # This file
│
├── models/
│   ├── staging/
│   │   └── nyc_taxi/
│   │       ├── _sources.yml                    # Source definitions
│   │       ├── _stg_nyc_taxi__models.yml       # Model tests & docs
│   │       └── stg_nyc_taxi__yellow_trips.sql  # Staging model
│   │
│   ├── intermediate/
│   │   └── int_trips_enriched.sql              # Enriched trips
│   │
│   └── marts/
│       ├── core/
│       │   ├── _core__models.yml               # Core model tests
│       │   ├── fct_trips.sql                   # Fact table
│       │   └── dim_locations.sql               # Dimension table
│       │
│       └── analytics/
│           ├── _analytics__models.yml          # Analytics docs
│           ├── rpt_hourly_trip_volume.sql
│           ├── rpt_top_pickup_locations.sql
│           ├── rpt_fare_analysis.sql
│           ├── rpt_payment_breakdown.sql
│           └── rpt_peak_vs_offpeak.sql
│
├── tests/
│   ├── assert_positive_trip_duration.sql       # Custom test
│   └── assert_revenue_consistency.sql          # Custom test
│
└── scripts/
    └── ingest_raw_data.sql                     # Ingestion script
```

---

## Setup Instructions

### Prerequisites

- Google Cloud account with BigQuery access
- Python 3.8 or higher
- Git

### Step 1: Clone Repository

```bash
git clone https://github.com/yourusername/nyc-taxi-analytics.git
cd nyc-taxi-analytics
```

### Step 2: Create Virtual Environment

```bash
python -m venv venv
source venv/bin/activate  # Windows: venv\Scripts\activate
pip install dbt-bigquery
```

### Step 3: Configure dbt Profile

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

### Step 4: Run Ingestion Script

Execute `scripts/ingest_raw_data.sql` in BigQuery Console to create the raw data layer.

### Step 5: Install Dependencies & Build

```bash
dbt deps
dbt build
```

### Step 6: Generate Documentation

```bash
dbt docs generate
dbt docs serve  # Opens browser at localhost:8080
```

---

## Data Models

### Fact Table: `fct_trips`

The central fact table containing trip-level transactions.

| Column | Type | Description |
|--------|------|-------------|
| `trip_id` | STRING | Surrogate key (primary key) |
| `pickup_location_id` | INT64 | Foreign key to location |
| `pickup_date` | DATE | Partition key |
| `pickup_hour` | INT64 | Hour of pickup (0-23) |
| `is_weekend` | BOOLEAN | Weekend flag |
| `time_of_day_bucket` | STRING | Morning Rush/Midday/Evening Rush/Night/Late Night |
| `trip_distance_miles` | FLOAT64 | Trip distance |
| `trip_duration_minutes` | INT64 | Duration in minutes |
| `fare_amount` | FLOAT64 | Base fare |
| `tip_amount` | FLOAT64 | Tip amount |
| `total_amount` | FLOAT64 | Total charged |
| `fare_per_mile` | FLOAT64 | Derived: fare/distance |
| `tip_percentage` | FLOAT64 | Derived: tip/fare × 100 |
| `payment_type_name` | STRING | Credit Card/Cash/etc. |

**Optimizations:**
- Partitioned by `pickup_date` (monthly granularity)
- Clustered by `pickup_location_id`, `payment_type_id`
- ~981,600 rows

### Dimension Table: `dim_locations`

Aggregated statistics per pickup location.

| Column | Type | Description |
|--------|------|-------------|
| `location_id` | INT64 | Primary key |
| `total_trips` | INT64 | Trip count |
| `total_revenue` | FLOAT64 | Sum of total_amount |
| `avg_trip_revenue` | FLOAT64 | Average fare |
| `avg_trip_distance_miles` | FLOAT64 | Average distance |
| `avg_tip_percentage` | FLOAT64 | Average tip % |
| `credit_card_pct` | FLOAT64 | % paid by card |
| `revenue_rank` | INT64 | Rank by revenue |
| `trip_volume_rank` | INT64 | Rank by trips |

**Stats:** 242 unique pickup locations

---

## Testing

### Test Summary

| Test Type | Count | Description |
|-----------|-------|-------------|
| `not_null` | 10 | Required field validation |
| `unique` | 2 | Primary key uniqueness |
| Custom | 2 | Business rule validation |
| **Total** | **14** | |

### Custom Tests

**`assert_positive_trip_duration`**: Warns if trips have zero or negative duration (data quality monitoring).

**`assert_revenue_consistency`**: Validates that `total_amount >= fare_amount`.

### Running Tests

```bash
dbt test                    # Run all tests
dbt test --select staging   # Test staging layer only
dbt test --select fct_trips # Test specific model
```

### Latest Test Results

```
PASS=23  WARN=1  ERROR=0  SKIP=0
```

---

## Dashboard

**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/s/h_Kxfie8lXo)

### Visualizations

| Chart | Type | Insight |
|-------|------|---------|
| Total Trips | Scorecard | 981,600 trips in Q1 2022 |
| Total Revenue | Scorecard | $X.XX million |
| Avg Fare | Scorecard | $XX.XX per trip |
| Hourly Volume | Line Chart | Peak hours: 6-9 PM |
| Top Locations | Bar Chart | Top 20 by revenue |
| Payment Methods | Pie Chart | Credit card dominant |
| Peak vs Off-Peak | Table | Comparison metrics |

---

## Design Decisions

### Decisions Made

| Decision | Rationale |
|----------|-----------|
| **1M row sample** | Sufficient for demonstrating patterns while staying within free tier |
| **Q1 2022 data** | Recent, complete quarter with seasonal variation |
| **Row-number surrogate key** | Source lacks natural unique key; ensures uniqueness |
| **Views for staging/intermediate** | Reduces storage costs; always reflects latest data |
| **Tables for marts** | Optimized query performance for dashboards |
| **Monthly partitioning** | Balances partition count with query efficiency |
| **Location + payment clustering** | Most common filter/group-by columns |

### Tradeoffs

| Tradeoff | Impact | Mitigation |
|----------|--------|------------|
| No incremental models | Full refresh on each run | Acceptable for 1M rows; would implement for production |
| Simulated ingestion | Missing CDC, schema handling | Documented how Fivetran would differ |
| No zone name lookup | Location IDs instead of names | Could join TLC zone reference data |
| Warning on duration test | 3,071 trips with zero/negative duration | Data quality issue in source; flagged, not blocked |

---

## Productionization

### With Full Tool Access

| Component | Current | Production |
|-----------|---------|------------|
| **Ingestion** | Manual SQL script | Fivetran with CDC connectors |
| **Transformation** | dbt Core (local) | dbt Cloud with scheduling |
| **Testing** | Manual `dbt test` | CI/CD pipeline on PR |
| **Monitoring** | None | dbt Cloud alerts + Monte Carlo |
| **Visualization** | Looker Studio | Looker with LookML metrics |

### Fivetran Configuration

```yaml
connector:
  type: bigquery
  sync_frequency: 15_minutes
  sync_mode: incremental
  cursor_field: pickup_datetime
  schema_handling: auto_propagate
```

### dbt Cloud Configuration

```yaml
jobs:
  - name: daily_production
    schedule: "0 6 * * *"  # 6 AM daily
    commands:
      - dbt run
      - dbt test
      - dbt source freshness
    notifications:
      slack: "#data-alerts"
```

---

## Time Log

| Phase | Duration |
|-------|----------|
| Environment setup | 30 min |
| Data ingestion | 20 min |
| Staging model | 30 min |
| Intermediate model | 20 min |
| Mart models | 45 min |
| Analytics reports | 30 min |
| Testing & debugging | 45 min |
| Looker Studio dashboard | 45 min |
| Documentation | 30 min |
| **Total** | **~5.5 hours** |

---

## Author

**Amjad Ali**  
Data & AI Engineer

- 📧 Email: amjadaligolocsais.com
- 💼 LinkedIn: [linkedin.com/in/amjad-ali-ml](https://linkedin.com/in/amjad-ali-ml)
- 🐙 GitHub: [github.com/Dev-Amjad](https://github.com/Dev-Amjad)

---

## License

This project was created under 5 hours.
**Looker Studio Dashboard:** [View Dashboard](https://lookerstudio.google.com/s/h_Kxfie8lXo)

---

*Built with ❤️ using dbt + BigQuery + Looker Studio*