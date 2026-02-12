{{ config(materialized='table') }}

with trips as (
    select
        *,
        case
            when tip_percentage = 0 or tip_percentage is null then 'Zero Tip'
            when tip_percentage > 0 and tip_percentage < 10 then 'Low (<10%)'
            when tip_percentage between 10 and 20 then 'Standard (10-20%)'
            else 'Generous (>20%)'
        end as tip_bucket
    from {{ ref('fct_trips') }}
)

select
    payment_type_id,
    payment_type_name,
    time_of_day_bucket,
    is_weekend,
    trip_distance_category,
    tip_bucket,
    count(*) as trip_count,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(total_amount), 2) as avg_trip_value,
    round(sum(tip_amount), 2) as total_tips,
    round(avg(tip_percentage), 1) as avg_tip_pct,
    round(count(*) * 100.0 / sum(count(*)) over (partition by payment_type_id), 1) as pct_within_payment_type
from trips
group by 1, 2, 3, 4, 5, 6
order by payment_type_id, time_of_day_bucket, is_weekend
