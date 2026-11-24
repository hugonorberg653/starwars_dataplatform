-- Grain: one row per character per film. Species and homeworld keys are copied from
-- dim_characters so that species-per-film questions need no join through the character.
select
    b.film_id,
    b.character_id,
    c.species_id,
    c.homeworld_planet_id,
    f.release_date as film_release_date,
    1 as appearance_count
from {{ ref('int_film_characters') }} as b
inner join {{ ref('dim_characters') }} as c on b.character_id = c.character_id
inner join {{ ref('dim_films') }} as f on b.film_id = f.film_id
