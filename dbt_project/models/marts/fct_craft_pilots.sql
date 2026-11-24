-- Grain: one row per pilot per craft.
select
    character_id,
    craft_key,
    craft_type
from {{ ref('int_character_crafts') }}
