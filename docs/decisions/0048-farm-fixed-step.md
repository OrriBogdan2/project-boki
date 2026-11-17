# 0048: The farm avatar moves in the match's fixed steps

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement / farm

## Problem
The match steps a Hunter 60 times a second whatever the display does (`Match.DT`), but the farm moved its avatar once per drawn frame on the raw frame time. The same jump peaked at about 1.46 m at 30 fps, 1.52 m at 60 and 1.55 m at 144, a stop and a dash slid by different amounts, and the farm had neither coyote time nor a jump buffer, so the first ten seconds of the game (the farm) felt different from a match and different between machines.

## Options
1. Keep the frame-time step and correct each formula (exact integration of jump, brake and drag): many edits inside frozen `home.gd`, and every later movement rule needs the same care.
2. Make the farm avatar a real `Hunter` stepped by the match code: the right end state, but a rewrite of the farm's mover (swim, mantle, ride, build mode) and far past this slice.
3. Run the farm's existing step from a small clock (`FarmStep`): fixed `Match.DT` steps, key presses latched for exactly one step, the body shown between its last two steps, the pose played once per frame.

## Decision
Option 3. It makes every number in the farm's step frame-rate independent at once without touching the formulas, and it is a few lines of wiring in `home.gd`. The jump's two grace timers live on the clock and read the match's rows (`coyote_s`, `jump_buffer_s` in `content/rules/hunter_move.json`); the match and the farm share `HunterMove.near_landing`. The sneak speed becomes one row too (`sneak_speed` 0.5, the source's multiplier; it was 0.55 in two places). Option 2 stays the long-term direction.

## Consequences
New `scripts/home/farm_step.gd`; wiring in `home.gd` (net -1 line), `hunter.gd` (net -3), `hunter_move.gd`, three rows in `hunter_move.json`. No Net or save change. New check `--move-rate-check` (`tools/move_rate_check.gd`): run, stop, jump, dash, coyote and buffer at 30/60/144 fps, in a match and on the farm. `feel_golden.json`: the crouch-walk traces re-recorded for the new sneak speed. Debt: the avatar's facing still turns per step (not blended), and the interior and town movers still step on frame time (docs/MOVEMENT_PARITY.md follow-ups).
