-- Grain: one row per planet, including the unknown member (-1). Residents are characters whose
-- homeworld is the planet, so the unknown member holds characters with no usable homeworld.
select
    p.planet_id,
    p.name,
    p.population,
    p.is_unknown_member,
    count(c.character_id) as resident_count
from {{ ref('dim_planets') }} as p
left join {{ ref('dim_characters') }} as c on p.planet_id = c.homeworld_planet_id
group by p.planet_id, p.name, p.population, p.is_unknown_member
