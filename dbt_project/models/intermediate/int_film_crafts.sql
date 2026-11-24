with starships as (

    select
        f.film_id,
        'starship' as craft_type,
        {{ extract_id('u.craft_url') }} as source_craft_id
    from {{ ref('stg_films') }} as f
    cross join unnest(f.starship_urls) as u(craft_url)

),

vehicles as (

    select
        f.film_id,
        'vehicle' as craft_type,
        {{ extract_id('u.craft_url') }} as source_craft_id
    from {{ ref('stg_films') }} as f
    cross join unnest(f.vehicle_urls) as u(craft_url)

),

unioned as (

    select * from starships
    union all
    select * from vehicles

)

select
    film_id,
    {{ craft_key('craft_type', 'source_craft_id') }} as craft_key,
    craft_type,
    source_craft_id
from unioned
