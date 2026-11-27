-- Reporting totals must add up to the rows of the facts, dimensions and bridges they summarise. Each reference
-- is computed from a different model than the report, so a join that drops or duplicates rows shows up here.
-- Returns a row for every pair that differs.
with checks as (

    select
        'rpt_planet_residents.resident_count = characters' as check_name,
        (select sum(resident_count) from {{ ref('rpt_planet_residents') }}) as report_total,
        (select count(*) from {{ ref('dim_characters') }}) as reference_total

    union all
    select
        'rpt_character_film_summary.film_count = fct_film_appearances',
        (select sum(film_count) from {{ ref('rpt_character_film_summary') }}),
        (select count(*) from {{ ref('fct_film_appearances') }})

    union all
    select
        'rpt_film_summary.character_count = films.characters',
        (select sum(character_count) from {{ ref('rpt_film_summary') }}),
        (select sum(len(character_urls)) from {{ ref('stg_films') }})

    union all
    select
        'rpt_film_summary.planet_count = films.planets',
        (select sum(planet_count) from {{ ref('rpt_film_summary') }}),
        (select sum(len(planet_urls)) from {{ ref('stg_films') }})

    union all
    select
        'rpt_film_summary.species_count_listed = films.species',
        (select sum(species_count_listed) from {{ ref('rpt_film_summary') }}),
        (select sum(len(species_urls)) from {{ ref('stg_films') }})

    union all
    select
        'rpt_film_summary.craft_count = films.starships + films.vehicles',
        (select sum(craft_count) from {{ ref('rpt_film_summary') }}),
        (select sum(len(starship_urls) + len(vehicle_urls)) from {{ ref('stg_films') }})

)

select *
from checks
where report_total is distinct from reference_total
