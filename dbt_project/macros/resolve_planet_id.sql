{# The one place that decides which planet key a reference points to. A planet that is NULL, missing or the
   placeholder record (planet 28) resolves to the unknown member -1 of dim_planets. #}
{% macro resolve_planet_id(planet_id) -%}
    case
        when {{ planet_id }} in (select planet_id from {{ ref('stg_planets') }} where not is_placeholder)
            then {{ planet_id }}
        else -1
    end
{%- endmacro %}
