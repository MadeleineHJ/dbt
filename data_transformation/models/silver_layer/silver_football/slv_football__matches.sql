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
    match_id,
    season,
    CAST(matchday AS INT64)                                             as matchday,
    stage,
    TIMESTAMP(utcdate)                                                  as match_timestamp,
    DATE(utcdate)                                                       as match_date,

    -- competition
    CAST(competition__id AS INT64)                                      as competition_id,
    competition__name                                                   as competition_name,
    competition__code                                                   as competition_code,

    -- home team
    CAST(hometeam__id AS INT64)                                         as home_team_id,
    hometeam__name                                                      as home_team_name,
    hometeam__shortname                                                 as home_team_short_name,
    hometeam__tla                                                       as home_team_tla,

    -- away team
    CAST(awayteam__id AS INT64)                                         as away_team_id,
    awayteam__name                                                      as away_team_name,
    awayteam__shortname                                                 as away_team_short_name,
    awayteam__tla                                                       as away_team_tla,

    -- match result
    score__winner                                                       as result,
    score__duration                                                     as match_duration,
    CAST(score__fulltime__home AS INT64)                                as full_time_home_goals,
    CAST(score__fulltime__away AS INT64)                                as full_time_away_goals,
    CAST(score__halftime__home AS INT64)                                as half_time_home_goals,
    CAST(score__halftime__away AS INT64)                                as half_time_away_goals,

    -- derived
    CAST(score__fulltime__home AS INT64)
        - CAST(score__fulltime__away AS INT64)                          as goal_difference,
    CASE score__winner
        WHEN 'HOME_TEAM' THEN 'Home Win'
        WHEN 'AWAY_TEAM' THEN 'Away Win'
        WHEN 'DRAW'      THEN 'Draw'
    END                                                                 as result_label,

    -- metadata
    DATE(SAFE_CAST(execution_date AS TIMESTAMP))                        as last_updated

from {{ ref('brz_football__matches') }}
