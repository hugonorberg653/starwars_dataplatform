{# '2 months' -> 60. 'none' and '0' -> 0. Anything else (e.g. 'Live food tanks') -> NULL; the text stays in consumables_desc. #}
{% macro consumables_days(column) -%}
    case
        when lower({{ clean_null(column) }}) in ('0', 'none') then 0
        when regexp_matches(lower({{ clean_null(column) }}), '^[0-9]+(\.[0-9]+)? (hour|day|week|month|year)s?$')
            then cast(regexp_extract(lower({{ clean_null(column) }}), '^([0-9.]+)', 1) as double)
                * case regexp_extract(lower({{ clean_null(column) }}), '(hour|day|week|month|year)', 1)
                    when 'hour' then 1.0 / 24
                    when 'day' then 1
                    when 'week' then 7
                    when 'month' then 30
                    when 'year' then 365
                end
    end
{%- endmacro %}
