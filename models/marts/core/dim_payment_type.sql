select
    payment_type_id,
    payment_type_name,
    is_electronic
from {{ ref('seed_payment_types') }}
