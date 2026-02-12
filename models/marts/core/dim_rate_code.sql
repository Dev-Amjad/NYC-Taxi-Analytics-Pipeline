select
    rate_code_id,
    rate_code_name,
    rate_category,
    rate_category in ('airport') as is_airport_rate
from {{ ref('seed_rate_codes') }}
