select
    f.film_id,
    {{ extract_id('u.planet_url') }} as planet_id
from {{ ref('stg_films') }} as f
cross join unnest(f.planet_urls) as u(planet_url)
