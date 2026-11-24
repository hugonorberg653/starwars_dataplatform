-- The denormalised counts on the dimensions must add up to the rows of the facts and bridges they summarise.
-- Returns a row for every pair that differs.
with checks as (

    select
        'dim_planets.resident_count = characters' as check_name,
        (select sum(resident_count) from {{ ref('dim_planets') }}) as dimension_total,
        (select count(*) from {{ ref('dim_characters') }}) as reference_total

    union all
    select
        'dim_species.member_count = characters',
        (select sum(member_count) from {{ ref('dim_species') }}),
        (select count(*) from {{ ref('dim_characters') }})

    union all
    select
        'dim_crafts.pilot_count = fct_craft_pilots',
        (select sum(pilot_count) from {{ ref('dim_crafts') }}),
        (select count(*) from {{ ref('fct_craft_pilots') }})

    union all
    select
        'dim_films.character_count = fct_film_appearances',
        (select sum(character_count) from {{ ref('dim_films') }}),
        (select count(*) from {{ ref('fct_film_appearances') }})

    union all
    select
        'dim_crafts.film_count = dim_films.craft_count',
        (select sum(film_count) from {{ ref('dim_crafts') }}),
        (select sum(craft_count) from {{ ref('dim_films') }})

    union all
    select
        'dim_planets.film_count = dim_films.planet_count',
        (select sum(film_count) from {{ ref('dim_planets') }}),
        (select sum(planet_count) from {{ ref('dim_films') }})

    union all
    select
        'dim_characters.film_count = fct_film_appearances',
        (select sum(film_count) from {{ ref('dim_characters') }}),
        (select count(*) from {{ ref('fct_film_appearances') }})

)

select *
from checks
where dimension_total is distinct from reference_total
