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

)

select
    craft_key,
    craft_type,
    source_craft_id,
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
from crafts
