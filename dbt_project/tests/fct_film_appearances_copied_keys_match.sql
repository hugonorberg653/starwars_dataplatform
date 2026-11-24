-- The species and homeworld keys copied onto fct_film_appearances must equal the character's own keys in dim_characters.
select
    f.film_id,
    f.character_id,
    f.species_id as fact_species_id,
    c.species_id as dim_species_id,
    f.homeworld_planet_id as fact_homeworld_planet_id,
    c.homeworld_planet_id as dim_homeworld_planet_id
from {{ ref('fct_film_appearances') }} as f
inner join {{ ref('dim_characters') }} as c on f.character_id = c.character_id
where f.species_id <> c.species_id
    or f.homeworld_planet_id <> c.homeworld_planet_id
