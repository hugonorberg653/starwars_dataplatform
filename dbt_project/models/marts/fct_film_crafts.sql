-- Grain: one row per craft (starship or vehicle) listed on a film. The key is the craft_key macro, so the
-- type is part of the key and the ID ranges of the two resources do not have to stay disjoint. The opposite
-- side (starships.films, vehicles.films) is checked by tests/fct_film_crafts_two_way_match.sql.
select
    f.film_id,
    {{ craft_key("'starship'", extract_id('u.craft_url')) }} as craft_key
from {{ ref('stg_films') }} as f
cross join unnest(f.starship_urls) as u(craft_url)

union all

select
    f.film_id,
    {{ craft_key("'vehicle'", extract_id('u.craft_url')) }} as craft_key
from {{ ref('stg_films') }} as f
cross join unnest(f.vehicle_urls) as u(craft_url)
