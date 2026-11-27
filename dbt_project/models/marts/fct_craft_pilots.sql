-- Grain: one row per pilot per craft. Keys only: the craft type is an attribute of dim_crafts. Unnested from
-- people.starships and people.vehicles; the opposite side (starships.pilots, vehicles.pilots) is checked by
-- tests/fct_craft_pilots_two_way_match.sql.
select
    p.character_id,
    {{ craft_key("'starship'", extract_id('u.craft_url')) }} as craft_key
from {{ ref('stg_people') }} as p
cross join unnest(p.starship_urls) as u(craft_url)

union all

select
    p.character_id,
    {{ craft_key("'vehicle'", extract_id('u.craft_url')) }} as craft_key
from {{ ref('stg_people') }} as p
cross join unnest(p.vehicle_urls) as u(craft_url)
