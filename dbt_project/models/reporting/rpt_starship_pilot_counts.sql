-- Grain: one row per pilot and starship class, plus one all-classes row per pilot.
with starships as (

    select craft_key, name, coalesce(craft_class, 'Unknown') as craft_class
    from {{ ref('dim_crafts') }}
    where craft_type = 'starship'

)

select
    ch.character_id,
    ch.name,
    c.craft_class,
    grouping(c.craft_class) = 1 as all_classes,
    count(*) as starship_count,
    string_agg(c.name, ', ' order by c.name, c.craft_key) as starship_names
from {{ ref('fct_craft_pilots') }} as p
inner join starships as c on p.craft_key = c.craft_key
inner join {{ ref('dim_characters') }} as ch on p.character_id = ch.character_id
group by grouping sets (
    (ch.character_id, ch.name, c.craft_class),
    (ch.character_id, ch.name)
)
