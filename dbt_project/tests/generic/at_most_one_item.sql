{# Array columns only: no more than one item. The source gives each character 0 or 1 species, and species_id depends on it. #}
{% test at_most_one_item(model, column_name) %}

select *
from {{ model }}
where len({{ column_name }}) > 1

{% endtest %}
