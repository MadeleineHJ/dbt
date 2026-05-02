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
        table='raw_football.matches_raw',
        json_column='raw_json',
        include_columns=['match_id', 'season', 'scraped_at'],
        is_source=true,
        filter_latest_run=true,
        extraction_date_column='scraped_at',
        unnest_levels=3,
        ignore_keys=['odds', 'referees'],
        filter_condition="JSON_VALUE(raw_json, '$.status') = 'FINISHED'",
        data_layer=data_layer
    )
}}