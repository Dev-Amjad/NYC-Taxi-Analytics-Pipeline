select
    trip_id,
    count(*) as row_count
from {{ ref('fct_trips') }}
group by trip_id
having count(*) > 1
