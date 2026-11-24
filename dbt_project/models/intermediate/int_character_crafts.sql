with starships as (

    select
        p.character_id,
        'starship' as craft_type,
        {{ extract_id('u.craft_url') }} as source_craft_id
    from {{ ref('stg_people') }} as p
    cross join unnest(p.starship_urls) as u(craft_url)

),

vehicles as (

    select
        p.character_id,
        'vehicle' as craft_type,
        {{ extract_id('u.craft_url') }} as source_craft_id
    from {{ ref('stg_people') }} as p
    cross join unnest(p.vehicle_urls) as u(craft_url)

),

unioned as (

    select * from starships
    union all
    select * from vehicles

)

select
    character_id,
    {{ craft_key('craft_type', 'source_craft_id') }} as craft_key,
    craft_type,
    source_craft_id
from unioned
