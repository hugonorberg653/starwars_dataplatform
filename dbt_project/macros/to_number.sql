{# Number from SWAPI text: missing markers become NULL, thousands commas are removed.
   try_cast is deliberate here; the no_silent_null test fails if a real value is lost this way. #}
{% macro to_number(column, type) -%}
    try_cast(replace({{ clean_null(column) }}, ',', '') as {{ type }})
{%- endmacro %}
