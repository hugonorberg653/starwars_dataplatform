{# A raw value that is not a missing marker must not turn into NULL while cleaning, so try_cast cannot drop data silently.
   Returns the raw values that were lost. key_column is the staging primary key; raw_field the field in raw.<table>.doc.
   allowed_raw_values: lowercase raw values that are deliberately NULL here (for example 'indefinite'). #}
{% test no_silent_null(model, column_name, key_column, source_table, raw_field, allowed_raw_values=[]) %}

with raw as (

    select
        {{ extract_id("doc ->> 'url'") }} as id,
        doc ->> '{{ raw_field }}' as raw_value
    from {{ source('raw', source_table) }}

)

select
    raw.id,
    raw.raw_value
from raw
inner join {{ model }} as cleaned on cleaned.{{ key_column }} = raw.id
where cleaned.{{ column_name }} is null
    and {{ clean_null('raw.raw_value') }} is not null
    {%- if allowed_raw_values %}
    and lower(trim(raw.raw_value)) not in ({{ allowed_raw_values | map('tojson') | join(', ') | replace('"', "'") }})
    {%- endif %}

{% endtest %}
