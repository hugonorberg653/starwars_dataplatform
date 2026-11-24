{# Key of dim_crafts. Starship and vehicle IDs share one dimension, so the type is part of the key. #}
{% macro craft_key(craft_type, source_craft_id) -%}
    md5({{ craft_type }} || '|' || cast({{ source_craft_id }} as varchar))
{%- endmacro %}
