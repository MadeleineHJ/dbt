{%- set data_layer = 'silver' %}
{%- set data_source = 'football' %}

{{
    config(
        materialized='table',
        schema='slv_football'
    )
}}

select
    -- identifiers
    team_id,
    season,
    standing_type,

    -- team info
    team__name                                                          as team_name,
    team__shortname                                                     as team_short_name,
    team__tla                                                           as team_tla,

    -- standings
    CAST(position AS INT64)                                             as position,
    CAST(points AS INT64)                                               as points,
    CAST(playedgames AS INT64)                                          as played_games,
    CAST(won AS INT64)                                                  as won,
    CAST(draw AS INT64)                                                 as drawn,
    CAST(lost AS INT64)                                                 as lost,
    CAST(goalsfor AS INT64)                                             as goals_for,
    CAST(goalsagainst AS INT64)                                         as goals_against,
    CAST(goaldifference AS INT64)                                       as goal_difference,
    form,

    -- derived
    SAFE_DIVIDE(CAST(won AS INT64), CAST(playedgames AS INT64))         as win_rate,
    SAFE_DIVIDE(CAST(draw AS INT64), CAST(playedgames AS INT64))        as draw_rate,
    SAFE_DIVIDE(CAST(lost AS INT64), CAST(playedgames AS INT64))        as loss_rate,

    -- metadata
    DATE(SAFE_CAST(execution_date AS TIMESTAMP))                        as last_updated

from {{ ref('brz_football__standings') }}
