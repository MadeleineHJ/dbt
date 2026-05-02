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
    player_id,
    season,

    -- player info
    player__name                                                        as player_name,
    player__firstname                                                   as first_name,
    player__lastname                                                    as last_name,
    DATE(player__dateofbirth)                                           as date_of_birth,
    player__nationality                                                 as nationality,
    player__position                                                    as position,

    -- team
    CAST(team__id AS INT64)                                             as team_id,
    team__name                                                          as team_name,
    team__shortname                                                     as team_short_name,
    team__tla                                                           as team_tla,

    -- scoring stats
    CAST(goals AS INT64)                                                as goals,
    CAST(assists AS INT64)                                              as assists,
    CAST(penalties AS INT64)                                            as penalty_goals,
    CAST(playedmatches AS INT64)                                        as played_matches,

    -- derived
    CAST(goals AS INT64) - CAST(penalties AS INT64)                     as open_play_goals,
    SAFE_DIVIDE(
        CAST(goals AS INT64), CAST(playedmatches AS INT64)
    )                                                                   as goals_per_match,

    -- metadata
    scraped_at

from {{ ref('brz_football__top_scorers') }}
