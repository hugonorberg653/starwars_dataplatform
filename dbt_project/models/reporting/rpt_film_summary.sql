-- Grain: one row per film. Characters come from the appearances fact. The other counts come from what the
-- source lists on the film (films.planets, films.species, films.starships and vehicles), which is not
-- the same as the species of the film's characters.
with character_counts as (

    select film_id, count(*) as character_count
    from {{ ref('fct_film_appearances') }}
    group by 1

),

planet_counts as (

    select film_id, count(*) as planet_count
    from {{ ref('fct_film_planets') }}
    group by 1

),

species_counts as (

    select film_id, count(*) as species_count_listed
    from {{ ref('fct_film_species') }}
    group by 1

),

craft_counts as (

    select film_id, count(*) as craft_count
    from {{ ref('fct_film_crafts') }}
    group by 1

)

select
    f.film_id,
    f.title,
    coalesce(cc.character_count, 0) as character_count,
    coalesce(pc.planet_count, 0) as planet_count,
    coalesce(sc.species_count_listed, 0) as species_count_listed,
    coalesce(kc.craft_count, 0) as craft_count
from {{ ref('dim_films') }} as f
left join character_counts as cc on f.film_id = cc.film_id
left join planet_counts as pc on f.film_id = pc.film_id
left join species_counts as sc on f.film_id = sc.film_id
left join craft_counts as kc on f.film_id = kc.film_id
