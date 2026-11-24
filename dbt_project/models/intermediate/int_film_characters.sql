select
    f.film_id,
    {{ extract_id('u.character_url') }} as character_id
from {{ ref('stg_films') }} as f
cross join unnest(f.character_urls) as u(character_url)
