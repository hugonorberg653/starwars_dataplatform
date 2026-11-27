-- Grain: one row per character per film. Keys only: species, homeworld and release date come from the
-- dimensions. Unnested from films.characters; the opposite side (people.films) is checked by
-- tests/fct_film_appearances_two_way_match.sql.
select
    f.film_id,
    {{ extract_id('u.character_url') }} as character_id
from {{ ref('stg_films') }} as f
cross join unnest(f.character_urls) as u(character_url)
