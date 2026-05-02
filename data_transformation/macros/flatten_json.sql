{% macro flatten_json(
    table,
    json_column,
    include_columns=[],
    is_source=false,
    filter_condition=none,
    ignore_keys=[],
    unnest_levels=1,
    extraction_date_column=none,
    filter_latest_run=false,
    data_layer=none,
    target_model=none,
    should_cast=false,
    json_keys=none
) %}

{# ── Resolve table reference ─────────────────────────────────────────────── #}
{%- if is_source -%}
    {%- set parts = table.split('.') -%}
    {%- set source_ref = source(parts[0], parts[1]) -%}
{%- else -%}
    {%- set source_ref = ref(table) -%}
{%- endif -%}

{# ── Normalize include_columns to list ───────────────────────────────────── #}
{%- if include_columns is string -%}
    {%- set include_columns = [include_columns] -%}
{%- endif -%}

{# ── Normalize ignore_keys to list ───────────────────────────────────────── #}
{%- if ignore_keys is string -%}
    {%- set ignore_keys = [ignore_keys] -%}
{%- endif -%}

{# ── Dynamically discover keys ───────────────────────────────────────────── #}
{%- if json_keys is none -%}

    {# Fetch one sample row #}
    {%- set sample_query -%}
        select {{ json_column }}
        from `{{ source_ref.database }}`.`{{ source_ref.schema }}`.`{{ source_ref.identifier }}`
        {% if filter_condition %}where {{ filter_condition }}{% endif %}
        limit 1
    {%- endset -%}

    {%- set sample_result = run_query(sample_query) -%}
    {%- set discovered_keys = [] -%}

    {%- if execute and sample_result and sample_result.rows | length > 0 -%}

        {%- set sample_json = sample_result.columns[0].values()[0] | tojson -%}

        {# Get top-level keys #}
        {%- set top_key_query -%}
            select k
            from unnest(json_keys(parse_json({{ sample_json }}))) as k
            order by k
        {%- endset -%}

        {%- set top_results = run_query(top_key_query) -%}
        {%- set top_keys = [] -%}

        {%- if execute and top_results -%}
            {%- for row in top_results.rows -%}
                {%- if row[0] not in ignore_keys -%}
                    {%- do top_keys.append(row[0]) -%}
                {%- endif -%}
            {%- endfor -%}
        {%- endif -%}

        {%- if unnest_levels == 1 -%}
            {%- set discovered_keys = top_keys -%}

        {%- elif unnest_levels >= 2 -%}
            {%- for key in top_keys -%}

                {%- set subkey_query -%}
                    select k
                    from unnest(
                        json_keys(
                            json_query(parse_json({{ sample_json }}), '$.{{ key }}')
                        )
                    ) as k
                    order by k
                {%- endset -%}

                {%- set sub_results = run_query(subkey_query) -%}

                {%- if execute and sub_results and sub_results.rows | length > 0 -%}
                    {# This is a nested object — expand sub-keys #}
                    {%- for subrow in sub_results.rows -%}
                        {%- set subkey = subrow[0] -%}

                        {%- if unnest_levels >= 3 -%}
                            {%- set subsubkey_query -%}
                                select k
                                from unnest(
                                    json_keys(
                                        json_query(parse_json({{ sample_json }}), '$.{{ key }}.{{ subkey }}')
                                    )
                                ) as k
                                order by k
                            {%- endset -%}
                            {%- set subsub_results = run_query(subsubkey_query) -%}

                            {%- if execute and subsub_results and subsub_results.rows | length > 0 -%}
                                {%- for subsubrow in subsub_results.rows -%}
                                    {%- set full_key = key ~ '.' ~ subkey ~ '.' ~ subsubrow[0] -%}
                                    {%- if full_key not in discovered_keys -%}
                                        {%- do discovered_keys.append(full_key) -%}
                                    {%- endif -%}
                                {%- endfor -%}
                            {%- else -%}
                                {%- set full_key = key ~ '.' ~ subkey -%}
                                {%- if full_key not in discovered_keys -%}
                                    {%- do discovered_keys.append(full_key) -%}
                                {%- endif -%}
                            {%- endif -%}

                        {%- else -%}
                            {%- set full_key = key ~ '.' ~ subkey -%}
                            {%- if full_key not in discovered_keys -%}
                                {%- do discovered_keys.append(full_key) -%}
                            {%- endif -%}
                        {%- endif -%}

                    {%- endfor -%}
                {%- else -%}
                    {# Scalar value — keep as top-level key #}
                    {%- if key not in discovered_keys -%}
                        {%- do discovered_keys.append(key) -%}
                    {%- endif -%}
                {%- endif -%}

            {%- endfor -%}
        {%- endif -%}

    {%- endif -%}

    {%- set json_keys = discovered_keys -%}

{%- endif -%}

{# ── Build CTE ───────────────────────────────────────────────────────────── #}
{%- if filter_latest_run and extraction_date_column -%}
with latest_run as (
    select max({{ extraction_date_column }}) as max_ingested_at
    from {{ source_ref }}
),

source_data as (
    select s.*
    from {{ source_ref }} s
    inner join latest_run l
        on s.{{ extraction_date_column }} = l.max_ingested_at
    {% if filter_condition %}where {{ filter_condition }}{% endif %}
)
{%- else -%}
with source_data as (
    select *
    from {{ source_ref }}
    {% if filter_condition %}where {{ filter_condition }}{% endif %}
)
{%- endif %}

select

    {%- for col in include_columns %}
    {{ col }},
    {%- endfor %}

    {%- for key in json_keys %}
    {%- set col_name = key | lower | replace('.', '__') | replace(' ', '_') | replace('-', '_') %}
    json_value({{ json_column }}, '$.{{ key }}') as `{{ col_name }}`{% if not loop.last %},{% endif %}

    {%- endfor %}

from source_data

{% endmacro %}