select
    f.film_id,
    {{ extract_id('u.species_url') }} as species_id
from {{ ref('stg_films') }} as f
cross join unnest(f.species_urls) as u(species_url)
