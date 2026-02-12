{{ config(materialized='table') }}

with trips as (
    select 
        *,
        case 
            when time_of_day_bucket in ('Morning Rush', 'Evening Rush') then 'Peak'
            else 'Off-Peak'
        end as peak_category
    from {{ ref('fct_trips') }}
)

select
    peak_category,
    is_weekend,
    count(*) as trip_count,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(total_amount), 2) as avg_fare,
    round(avg(trip_distance_miles), 2) as avg_distance,
    round(avg(trip_duration_minutes), 1) as avg_duration,
    round(avg(tip_percentage), 1) as avg_tip_pct
from trips
group by 1, 2
order by peak_category, is_weekend