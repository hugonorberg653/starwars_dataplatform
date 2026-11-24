with films as (

    select * from {{ ref('stg_films') }}

),

character_counts as (

    select film_id, count(*) as character_count
    from {{ ref('int_film_characters') }}
    group by 1

),

planet_counts as (

    select film_id, count(*) as planet_count
    from {{ ref('int_film_planets') }}
    group by 1

),

species_counts as (

    select film_id, count(*) as species_count_listed
    from {{ ref('int_film_species') }}
    group by 1

),

craft_counts as (

    select film_id, count(*) as craft_count
    from {{ ref('int_film_crafts') }}
    group by 1

)

select
    f.film_id,
    f.title,
    f.episode_id,
    f.release_date,
    cast(row_number() over (order by f.release_date, f.episode_id) as integer) as release_order,
    case
        when f.episode_id between 1 and 3 then 'prequel'
        when f.episode_id between 4 and 6 then 'original'
    end as trilogy,
    f.director,
    f.producers,
    coalesce(cc.character_count, 0) as character_count,
    coalesce(pc.planet_count, 0) as planet_count,
    coalesce(sc.species_count_listed, 0) as species_count_listed,
    coalesce(kc.craft_count, 0) as craft_count,
    f.loaded_at,
    f.source_system
from films as f
left join character_counts as cc on f.film_id = cc.film_id
left join planet_counts as pc on f.film_id = pc.film_id
left join species_counts as sc on f.film_id = sc.film_id
left join craft_counts as kc on f.film_id = kc.film_id
