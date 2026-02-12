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
    rate_code_id,
    rate_code_name,
    peak_category,
    is_weekend,
    count(*) as trip_count,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(total_amount), 2) as avg_fare,
    round(avg(trip_distance_miles), 2) as avg_distance,
    round(avg(trip_duration_minutes), 1) as avg_duration_minutes,
    round(avg(avg_speed_mph), 1) as avg_speed_mph,
    round(avg(tip_percentage), 1) as avg_tip_pct,
    round(avg(revenue_per_hour), 2) as avg_revenue_per_hour,
    round(
        safe_divide(
            sum(case when avg_speed_mph < 10 then 1 else 0 end),
            count(*)
        ) * 100, 1
    ) as congestion_pct
from trips
group by 1, 2, 3, 4
order by rate_code_id, peak_category, is_weekend
