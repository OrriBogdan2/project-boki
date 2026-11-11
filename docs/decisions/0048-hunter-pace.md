# 0048: Far, calm bot Hunters step at 30 Hz (HunterPace)

- **Status:** superseded by 0022 (SimLod): main's 0.24.4 already steps far (45 m+), calm bots at 20 Hz, think
  and sim together; ext/perf-owner-hw-rebased dropped HunterPace rather than stack the two
- **Date:** 2026-11-10
- **Area:** movement (sim cost)

## Problem
The owner's PC spends about 9.5 ms a frame in `Hunter.sim` for a full 20-Hunter match (`--perf-bench --bench-real
--bench-teams=10 --bench-squad=2`, docs/PERF_OWNER_HW.md). No single part dominates: the kit tick, physics, timers
and belt each cost 0.1-0.4 ms. Boki (`KinPace`) and far bots' decisions (`Bot.tick`) already run less often far
away, but every Hunter still ran its whole sim at 60 Hz, even 200 m away with nothing happening.

## Options
1. Micro-optimise each part of `Hunter.sim`: many small wins spread across many files, already partly done by the
   perf train.
2. Run a far, calm bot's whole sim every 2nd step with the skipped time added (30 Hz), as KinPace does for Boki.
3. Fewer Hunters a match: this is gameplay, so it is the owner's call (see docs/PERF_OWNER_HW.md).

## Decision
Option 2 (`scripts/match/hunter_pace.gd`). A bot steps at 30 Hz only when every one of these holds:
- it is past 60 m from you (out of the camera's view at every zoom);
- it is grounded, not dashing, downed, riding or dropping;
- it has no target and took no hit in the last 3 s.

Anything else runs every step. Offline only, as KinPace is.

## Consequences
A wiring line in `Match.step` and `Hunter.pace_dt`. A far bot's walk integrates at 1/30 s (0.25 m a step at a run),
which is well inside the wall and edge tests' margins. Nothing changes near you or in a fight. No Net or save change.
Checks: `--perf-throttle-check` covers the rule; bot checks unchanged.
