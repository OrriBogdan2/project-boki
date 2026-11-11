# 0062: Time-trial personal bests in the save

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save

## Problem
The Training Grounds' time trial (scripts/match/time_trial.gd) keeps a personal best per Hunter, so the save needs somewhere to put it, and saves made before the course existed must load.

## Options
1. A new top-level `d["time_trial"]` (Hunter id -> best seconds) with its own migration step. Pros: one small key, nothing else touched. Cons: one more step in the numbered chain.
2. Put the best on each roster Hunter. Cons: bests are per Hunter class (arch), not per owned Hunter, and the roster changes shape on other branches.

## Decision
Option 1. `fresh()` has `"time_trial": {}`, and `TimeTrial.migrate` only adds the key when it is missing or not a dictionary (decision 0060's rule), so running it twice or out of order is safe. `TimeTrial.record` saves through `Save.save_game` only on a new best.

## Consequences
scripts/core/save.gd (VERSION 12 -> 13 on this branch's ext/release-integ-0244c base) and scripts/match/time_trial.gd. 0.24.5 already uses v13 (garden zones, 0060), so when this lands on the 0.24.5 chain (docs/SAVE_CHAIN_0245.md) it takes the next free number. Only the step number changes, not its body. No Net change: the course is local to --arena. `--time-trial-check` covers a v12 save and a fresh save.
