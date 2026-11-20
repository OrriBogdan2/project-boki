# 0080: Incubator eggs take 20 minutes of play to hatch

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** the save format, the Incubator

## Problem
Owner (playtest of 0.24.4, DECISIONS.md): "incubator shouldn't instantly hatch, it should be a while before an
egg hatches." An egg was ready after 2 expeditions or 8 minutes, and the time you were away counted too, so a
short match or an evening off finished it. Progress was only six pebbles beside the cradle.

## Options
1. Raise HEAT_NEED and TRIPS. Away time and two quick matches still finish it.
2. One clock of play seconds: garden time (the home tick, also while visiting a friend's garden, at the plain
   pace) and match time (`Game.apply_result` hands the match's
   seconds to `Incubator.tick`), no expedition count, no catch-up for time with the game closed.

## Decision
Option 2, `hatch_secs` 1200 in `content/rules/incubator.json`. Ember kin and Ember Coals still speed it up. The
egg shows progress itself (`EggStages`: shell glow, three crack stages, harder wobble), no new panel; the old
Nook tab shows a percent and minutes of play left. Save: egg `heat` stays seconds of warmth; `ensure()` gives
every egg without `slow` a cold start (`heat` 0, `slow` true, `m0` and the incubator `t` dropped), so old saves
load and eggs already in cradles start again at 0. No `Save.VERSION` bump (idempotent, like `Incubator.migrate`).

## Affects
`incubator.gd` (TRIPS, HEAT_NEED, AWAY_CAP, `trips`, `catch_up` removed), `home_incubator.gd`, `egg_stages.gd`,
`game.gd` and `home.gd` (one line each), the Nook Incubator tab text, `--incubator-check`, `--garden-zones-check` (visit row).
