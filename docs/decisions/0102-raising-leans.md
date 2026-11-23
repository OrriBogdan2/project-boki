# 0102: Raising leans a Boki's personality

- **Status:** accepted
- **Date:** 2026-11-20
- **Area:** save / farm

## Problem
DECISIONS 2026-11-09: raising shapes the Boki, personality included, and Boki live on their own. Care today moves
trust and needs; the four inborn traits only move by friends (BaseDrift). Nothing a player does changes what a Boki
chooses to do on its own.

## Options
1. Care writes straight into the four traits: no new field, but it erases the inborn value and double counts the
   curiosity and temper BaseLife already reads.
2. A separate care-earned lean per axis, read next to the traits (chosen).

## Decision
`rec["raised"] = {bold, busy, gentle}`, each -1..1 (shy/bold, lazy/busy, rough/gentle). Each first care of a farm day
(`Care.care_day`) steps it by `content/rules/base_axes.json` `steps`, capped at `cap`; so a day of care moves it a
fixed small amount and ten days of one style are a clean row in `--garden-sim-check`. `BaseLife.choose` multiplies
its nap, play, chase (tag) and cling odds by `BaseAxes.mult` (rules `weights`). Crossing +-`band` writes one journal line.

## Consequences
Save v22 -> v23 (`BaseAxes.migrate` gives every kin the zero lean). Golden `save_v23_*`. No Net change (a farm
record, never synced). Checks: `--base-life-check` (axes part), `--garden-sim-check` (a row per care style after
10 days), `--save-compat-check`.
