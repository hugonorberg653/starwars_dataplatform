with characters as (

    select * from {{ ref('stg_people') }}

),

planets as (

    select planet_id from {{ ref('dim_planets') }}

),

species as (

    select species_id, name from {{ ref('stg_species') }}

),

film_counts as (

    select
        character_id,
        count(*) as film_count
    from {{ ref('int_film_characters') }}
    group by 1

),

total_films as (

    select count(*) as film_total from {{ ref('stg_films') }}

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
    coalesce(p.planet_id, -1) as homeworld_planet_id,
    coalesce(c.species_id, -1) as species_id,
    coalesce(s.name = 'Droid', false) as is_droid,
    coalesce(fc.film_count, 0) as film_count,
    coalesce(fc.film_count, 0) = t.film_total as is_in_all_films,
    c.loaded_at,
    c.source_system
from characters as c
left join planets as p on c.homeworld_planet_id = p.planet_id
left join species as s on c.species_id = s.species_id
left join film_counts as fc on c.character_id = fc.character_id
cross join total_films as t
