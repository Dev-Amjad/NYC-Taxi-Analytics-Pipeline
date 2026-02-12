select
    location_id,
    zone_name,
    borough,
    service_zone,
    case
        when service_zone = 'Airports' then 'Airport'
        when service_zone = 'EWR' then 'Airport'
        when borough = 'Manhattan' and service_zone = 'Yellow Zone' then 'Manhattan Core'
        when borough = 'Manhattan' and service_zone = 'Boro Zone' then 'Manhattan Other'
        when borough in ('Brooklyn', 'Queens', 'Bronx', 'Staten Island') then 'Outer Borough'
        else 'Other'
    end as zone_category
from {{ ref('seed_taxi_zones') }}
