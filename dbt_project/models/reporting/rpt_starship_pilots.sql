-- Grain: one row per starship, including ships without recorded pilots.
select
    c.craft_key,
    c.name,
    coalesce(c.craft_class, 'Unknown') as craft_class,
    c.cost_credits,
    c.length_m,
    c.crew_max,
    count(p.character_id) as pilot_count,
    string_agg(ch.name, ', ' order by ch.name, ch.character_id) as pilot_names
from {{ ref('dim_crafts') }} as c
left join {{ ref('fct_craft_pilots') }} as p on c.craft_key = p.craft_key
left join {{ ref('dim_characters') }} as ch on p.character_id = ch.character_id
where c.craft_type = 'starship'
group by c.craft_key, c.name, c.craft_class, c.cost_credits, c.length_m, c.crew_max
