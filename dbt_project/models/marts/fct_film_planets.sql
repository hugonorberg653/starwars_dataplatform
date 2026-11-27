-- Grain: one row per planet listed on a film. Unnested from films.planets; the opposite side (planets.films)
-- is checked by tests/fct_film_planets_two_way_match.sql. No placeholder mapping: if a film ever listed the
-- placeholder planet 28, the relationships test to dim_planets fails instead of hiding it.
select
    f.film_id,
    {{ extract_id('u.planet_url') }} as planet_id
from {{ ref('stg_films') }} as f
cross join unnest(f.planet_urls) as u(planet_url)
