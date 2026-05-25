{%- set data_layer = 'bronze' %}
{%- set data_source = 'football' %}

{{

    config(
        materialized='table',
        schema='brz_football'
    )
}}

{{
    flatten_json(
        table='raw_football.football_top_scorers',
        json_column='raw_json',
        json_wrapper_column='data',
        include_columns=['run_id', 'execution_date'],
        is_source=true,
        filter_latest_run=true,
        extraction_date_column='execution_date',
        unnest_levels=3,
        ignore_keys=[],
        filter_condition=filter_cond,
        data_layer=data_layer
    )
}}