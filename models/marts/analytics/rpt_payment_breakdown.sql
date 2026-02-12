{{ config(materialized='table') }}

with trips as (
    select * from {{ ref('fct_trips') }}
)

select
    payment_type_id,
    payment_type_name,
    count(*) as trip_count,
    round(sum(total_amount), 2) as total_revenue,
    round(avg(total_amount), 2) as avg_trip_value,
    round(sum(tip_amount), 2) as total_tips,
    round(avg(tip_percentage), 1) as avg_tip_pct,
    round(count(*) * 100.0 / sum(count(*)) over (), 1) as pct_of_trips,
    round(sum(total_amount) * 100.0 / sum(sum(total_amount)) over (), 1) as pct_of_revenue
from trips
group by 1, 2
order by total_revenue desc