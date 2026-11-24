{# Trimmed text, with the SWAPI missing markers (unknown, n/a, empty) turned into NULL. #}
{% macro clean_null(column) -%}
    case when lower(trim({{ column }})) in ('unknown', 'n/a', '') then null else trim({{ column }}) end
{%- endmacro %}
