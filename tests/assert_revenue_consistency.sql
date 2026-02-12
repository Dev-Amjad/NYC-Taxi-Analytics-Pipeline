select
    trip_id,
    fare_amount,
    total_amount
from {{ ref('fct_trips') }}
where total_amount < fare_amount
  and fare_amount > 0