{# JSON array of strings (e.g. a list of SWAPI URLs) from the raw `doc` column as VARCHAR[]. #}
{% macro json_array(field) -%}
    from_json(doc -> '{{ field }}', '["VARCHAR"]')
{%- endmacro %}
