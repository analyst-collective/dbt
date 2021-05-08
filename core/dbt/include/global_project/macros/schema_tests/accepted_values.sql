
{% macro default__test_accepted_values(model, values) %}

{% set column_name = kwargs.get('column_name', kwargs.get('field')) %}
{% set quote_values = kwargs.get('quote', True) %}

with all_values as (

    select
        {{ column_name }} as value_field,
        count(*) as num

    from {{ model }}
    group by 1

),

validation_errors as (

    select
        value_field,
        num

    from all_values
    where value_field not in (
        {% for value in values -%}
            {% if quote_values -%}
            '{{ value }}'
            {%- else -%}
            {{ value }}
            {%- endif -%}
            {%- if not loop.last -%},{%- endif %}
        {%- endfor %}
    )
)

select *
from validation_errors

{% endmacro %}

{% test accepted_values(model, values) %}
    {% set macro = adapter.dispatch('test_accepted_values') %}
    {{ macro(model, values, **kwargs) }}
{% endtest %}
