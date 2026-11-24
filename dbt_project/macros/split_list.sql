{# 'a, b' -> ['a', 'b'] (trimmed). NULL in, NULL out. Pass lower=true to lowercase the items. #}
{% macro split_list(column, lower=false) -%}
    list_transform(
        string_split({% if lower %}lower({{ column }}){% else %}{{ column }}{% endif %}, ','),
        lambda x: trim(x)
    )
{%- endmacro %}
