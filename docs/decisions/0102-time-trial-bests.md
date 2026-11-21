# 0102: Time-trial personal bests in the save

- **Status:** accepted
- **Date:** 2026-11-19
- **Area:** save

## Problem
The Training Grounds' time trial (`scripts/match/time_trial.gd`: start and finish arch, ten gates, a wall tower, a jump pad) keeps a personal best per Hunter. The save needs a place for it, and saves from before the course must load.

## Options
1. A new top-level `d["time_trial"]` (Hunter id -> best seconds) with its own migration step. One small key, nothing else touched.
2. Reuse `d["drills"]` (`MoveDrills`' best pass time per drill). Rejected: those are per drill, not per Hunter, belong to the Practice bar, and a run's key would mix two meanings.
3. A best on each roster Hunter. Rejected: bests are per Hunter class (arch), not per owned Hunter.

## Decision
Option 1. `Save.VERSION` 21 -> 22. `fresh()` has `"time_trial": {}`; `TimeTrial.migrate` only adds the key when it is missing or not a dictionary (decision 0060's rule), so it is safe to run twice. `TimeTrial.record` saves through `Save.save_game` only on a new best.

## Consequences
- `scripts/core/save.gd` (one migration step) and `scripts/match/time_trial.gd`. The course is local to `--arena`: nothing on the wire, no `Net` change.
- Old golden saves are untouched; new `save_v22_*` goldens are added (docs/SAVES.md).
- `--time-trial-check` covers a v20 save, a fresh save, and a scripted run with real inputs. Dash gates count only while dashing; the wall tower is four terraces (one kick, decision 0100); the pad tower is out of a kick's reach.
