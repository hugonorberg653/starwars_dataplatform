{% macro generate_schema_name(custom_schema_name, node) -%}
    {#- Use the custom schema as is (staging, marts, reporting) instead of main_<custom>. -#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
