-- Grain: one row per species listed on a film. This is what the source says appears in the film, not the
-- species of its characters (that is fct_film_appearances joined to dim_characters). Unnested from
-- films.species; the opposite side (species.films) is checked by tests/fct_film_species_two_way_match.sql.
select
    f.film_id,
    {{ extract_id('u.species_url') }} as species_id
from {{ ref('stg_films') }} as f
cross join unnest(f.species_urls) as u(species_url)
