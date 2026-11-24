{# Integer ID from a SWAPI URL such as https://swapi.dev/api/people/1/ #}
{% macro extract_id(column) -%}
    cast(regexp_extract({{ column }}, '/([0-9]+)/?$', 1) as integer)
{%- endmacro %}
