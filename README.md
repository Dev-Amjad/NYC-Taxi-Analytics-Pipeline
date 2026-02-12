# NYC Taxi Analytics Pipeline

End-to-end analytics pipeline using **BigQuery**, **dbt Core**, and **Looker Studio**.

## 📊 Overview

Analyzes NYC Yellow Taxi trip data (Q1 2022, ~1M trips) to answer business questions about trip patterns, revenue, and operations.

### Business Questions Answered

1. Which pickup locations generate the most revenue?
2. How does trip volume vary by hour of day?
3. What is the average fare per mile?
4. How do payment methods differ in usage?
5. How do peak hours compare to off-peak?

## 🏗️ Architecture
```
BigQuery Public Data → Raw Layer → Staging → Intermediate → Marts → Looker Studio
```

| Layer | Purpose | Materialization |
|-------|---------|-----------------|
| Raw | Fivetran simulation | Table |
| Staging | Clean, cast, filter | View |
| Intermediate | Enrich data | View |
| Marts | Analytics-ready | Table |

## 🚀 Setup

### Prerequisites
- Google Cloud account with BigQuery
- Python 3.8+
- dbt-bigquery

### Installation
```bash
# Clone and setup
git clone https://github.com/yourusername/nyc-taxi-analytics.git
cd nyc-taxi-analytics
python -m venv venv
source venv/bin/activate
pip install dbt-bigquery

# Configure ~/.dbt/profiles.yml
# Run ingestion script in BigQuery (scripts/ingest_raw_data.sql)

# Build
dbt deps
dbt build
dbt docs generate
```

## 📁 Structure
```
models/
├── staging/nyc_taxi/
│   ├── _sources.yml
│   └── stg_nyc_taxi__yellow_trips.sql
├── intermediate/
│   └── int_trips_enriched.sql
└── marts/
    ├── core/
    │   ├── fct_trips.sql
    │   └── dim_locations.sql
    └── analytics/
        ├── rpt_hourly_trip_volume.sql
        ├── rpt_top_pickup_locations.sql
        ├── rpt_fare_analysis.sql
        ├── rpt_payment_breakdown.sql
        └── rpt_peak_vs_offpeak.sql
```

## 🧪 Testing

| Type | Count |
|------|-------|
| not_null | 10 |
| unique | 2 |
| Custom | 2 |
```bash
dbt test
```

## 📈 Key Models

- **fct_trips**: ~981K rows, partitioned by date, clustered by location
- **dim_locations**: 242 locations with aggregated stats
- **5 analytics reports**: Hourly volume, top locations, fare analysis, payments, peak hours

## 💭 Design Decisions

| Decision | Rationale |
|----------|-----------|
| 1M row sample | Free tier efficiency |
| Row-number surrogate key | No natural unique key |
| Views for staging | Fresh data, less storage |
| Tables for marts | Query performance |
| Partitioned by date | Cost optimization |

## 🔮 Productionization

With paid tools:
- **Fivetran**: Automated CDC, 15-min syncs
- **dbt Cloud**: Scheduled runs, CI/CD
- **Looker**: Governed metrics, row-level security

## ⏱️ Time Spent

| Phase | Time |
|-------|------|
| Setup | 30 min |
| Ingestion | 20 min |
| dbt models | 2 hours |
| Testing | 45 min |
| Dashboard | 45 min |
| Docs | 30 min |
| **Total** | **~5 hours** |

## 👤 Author

**Amjad Ali** - Data & AI Engineer  
[LinkedIn](https://linkedin.com/in/amjad-ali-ml) | [GitHub](https://github.com/Dev-Amjad)
