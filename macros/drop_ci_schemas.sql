{# Drops every schema in the target database that starts with `prefix` (used to clean up PR builds). #}
{% macro drop_ci_schemas(prefix) %}
    {% if target.name == 'prod' %}
        {{ exceptions.raise_compiler_error("drop_ci_schemas must never run against prod") }}
    {% endif %}
    {% set q %}
        select schema_name from {{ target.database }}.information_schema.schemata
        where schema_name ilike '{{ prefix }}%'
    {% endset %}
    {% for row in run_query(q) %}
        {% do log("Dropping " ~ target.database ~ "." ~ row[0], info=true) %}
        {% do run_query("drop schema if exists " ~ target.database ~ "." ~ row[0] ~ " cascade") %}
    {% endfor %}
{% endmacro %}
