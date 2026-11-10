{#
  prod  -> clean schema names (STAGING, MARTS)
  other -> prefixed with the target schema (e.g. DBT_ASA_STAGING, PR_42_MARTS)
  so developers and PR builds never collide.
#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- elif target.name == 'prod' -%}
        {{ custom_schema_name | trim }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
