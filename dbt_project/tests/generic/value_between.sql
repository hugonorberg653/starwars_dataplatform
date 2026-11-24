{# Values must be within [min_value, max_value]. NULL (unknown) is allowed. Catches unit and parsing errors that stay positive. #}
{% test value_between(model, column_name, min_value, max_value) %}

select *
from {{ model }}
where {{ column_name }} < {{ min_value }}
    or {{ column_name }} > {{ max_value }}

{% endtest %}
