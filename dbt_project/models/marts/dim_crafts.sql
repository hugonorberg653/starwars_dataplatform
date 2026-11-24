with starships as (

    select
        craft_key,
        'starship' as craft_type,
        starship_id as source_craft_id,
        name,
        model,
        manufacturer,
        craft_class,
        cost_credits,
        length_m,
        max_atmosphering_speed_kmh,
        crew_min,
        crew_max,
        passengers,
        cargo_capacity_kg,
        consumables_days,
        consumables_desc,
        hyperdrive_rating,
        mglt,
        loaded_at,
        source_system
    from {{ ref('stg_starships') }}

),

vehicles as (

    select
        craft_key,
        'vehicle' as craft_type,
        vehicle_id as source_craft_id,
        name,
        model,
        manufacturer,
        craft_class,
        cost_credits,
        length_m,
        max_atmosphering_speed_kmh,
        crew_min,
        crew_max,
        passengers,
        cargo_capacity_kg,
        consumables_days,
        consumables_desc,
        -- Only starships have a hyperdrive.
        cast(null as double) as hyperdrive_rating,
        cast(null as integer) as mglt,
        loaded_at,
        source_system
    from {{ ref('stg_vehicles') }}

),

crafts as (

    select * from starships
    union all
    select * from vehicles

),

pilot_counts as (

    select craft_key, count(*) as pilot_count
    from {{ ref('int_character_crafts') }}
    group by 1

),

film_counts as (

    select craft_key, count(*) as film_count
    from {{ ref('int_film_crafts') }}
    group by 1

)

select
    c.craft_key,
    c.craft_type,
    c.source_craft_id,
    c.name,
    c.model,
    c.manufacturer,
    c.craft_class,
    c.cost_credits,
    c.length_m,
    c.max_atmosphering_speed_kmh,
    c.crew_min,
    c.crew_max,
    c.passengers,
    c.cargo_capacity_kg,
    c.consumables_days,
    c.consumables_desc,
    c.hyperdrive_rating,
    c.mglt,
    coalesce(p.pilot_count, 0) as pilot_count,
    coalesce(f.film_count, 0) as film_count,
    c.loaded_at,
    c.source_system
from crafts as c
left join pilot_counts as p on c.craft_key = p.craft_key
left join film_counts as f on c.craft_key = f.craft_key
