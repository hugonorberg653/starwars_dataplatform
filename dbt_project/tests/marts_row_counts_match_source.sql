-- Mart row counts must equal the number of source references, so a join cannot drop or duplicate rows.
-- Returns a row for every fact or dimension where the counts differ.
with expected as (

    select 'fct_film_appearances' as model, sum(len(character_urls)) as expected_rows from {{ ref('stg_films') }}
    union all
    select 'fct_film_planets', sum(len(planet_urls)) from {{ ref('stg_films') }}
    union all
    select 'fct_film_species', sum(len(species_urls)) from {{ ref('stg_films') }}
    union all
    select 'fct_film_crafts', sum(len(starship_urls) + len(vehicle_urls)) from {{ ref('stg_films') }}
    union all
    select 'fct_craft_pilots', sum(len(starship_urls) + len(vehicle_urls)) from {{ ref('stg_people') }}
    union all
    select 'dim_characters', count(*) from {{ ref('stg_people') }}
    union all
    select 'dim_films', count(*) from {{ ref('stg_films') }}
    union all
    select 'dim_crafts', (select count(*) from {{ ref('stg_starships') }}) + (select count(*) from {{ ref('stg_vehicles') }})
    -- One extra row each for the unknown member; the placeholder planet is not loaded.
    union all
    select 'dim_planets', count(*) filter (where not is_placeholder) + 1 from {{ ref('stg_planets') }}
    union all
    select 'dim_species', count(*) + 1 from {{ ref('stg_species') }}

),

actual as (

    select 'fct_film_appearances' as model, count(*) as actual_rows from {{ ref('fct_film_appearances') }}
    union all
    select 'fct_film_planets', count(*) from {{ ref('fct_film_planets') }}
    union all
    select 'fct_film_species', count(*) from {{ ref('fct_film_species') }}
    union all
    select 'fct_film_crafts', count(*) from {{ ref('fct_film_crafts') }}
    union all
    select 'fct_craft_pilots', count(*) from {{ ref('fct_craft_pilots') }}
    union all
    select 'dim_characters', count(*) from {{ ref('dim_characters') }}
    union all
    select 'dim_films', count(*) from {{ ref('dim_films') }}
    union all
    select 'dim_crafts', count(*) from {{ ref('dim_crafts') }}
    union all
    select 'dim_planets', count(*) from {{ ref('dim_planets') }}
    union all
    select 'dim_species', count(*) from {{ ref('dim_species') }}

)

select
    e.model,
    e.expected_rows,
    a.actual_rows
from expected as e
inner join actual as a on e.model = a.model
where e.expected_rows <> a.actual_rows
