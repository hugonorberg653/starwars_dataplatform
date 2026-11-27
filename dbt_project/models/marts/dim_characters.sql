with characters as (

    select * from {{ ref('stg_people') }}

),

species as (

    select species_id, name from {{ ref('stg_species') }}

)

select
    c.character_id,
    c.name,
    c.gender,
    c.height_cm,
    c.mass_kg,
    -- Only when both values exist. High values (Jabba, about 443) are real, so they are flagged by the data, not dropped.
    case
        when c.height_cm > 0 and c.mass_kg is not null
            then c.mass_kg / power(c.height_cm / 100.0, 2)
    end as bmi,
    c.birth_year_bby,
    c.hair_color,
    c.skin_color,
    c.eye_color,
    {{ resolve_planet_id('c.homeworld_planet_id') }} as homeworld_planet_id,
    coalesce(c.species_id, -1) as species_id,
    coalesce(s.name, 'Unknown') as species_name,
    coalesce(s.name = 'Droid', false) as is_droid,
    c.loaded_at,
    c.source_system
from characters as c
left join species as s on c.species_id = s.species_id
