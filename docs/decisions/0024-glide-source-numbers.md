# 0024: Glide and air numbers the game data does not give

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
SUPERVIVE_FEEL listed values locked in the game's encrypted C++ defaults: base glide speed, glide gravity
factor, glide braking, hoop boost, jump hold time and air-dash multipliers. The dive (32.5 m/s) is sourced
(0021). The rest had to come from footage or stay ours.

## Options
1. Fit every value from the frame notes, however loose.
2. Set only values the footage pins to under 15 % error, assert those in `--move-feel-check`, and mark
   the rest `[?]` on our current tuning.

## Decision
Option 2. The notes have no glide clip and the raw 4-5 fps frames are not on the worker, so only measured
numbers in `briefs/hero-ref/*.md` and `briefs/supervive-data/` count. Only the glide cruise speed is tight
(~5 m/s, about a run, matching MaxGlide 500): already `GLIDE_SPEED` 5.0, now also asserted against run
speed (`glide_vs_run`). The gravity factor, braking, hoop boost (no hoops in our match), jump hold (the
source's glide is a separate bind) and air-dash multiplier (1.9-3.1x, ~25 %) stay ours, tagged `[?]`.
Ranges and frames are in the SUPERVIVE_FEEL table. Alternative not taken: fit the air-dash multiplier to
dancer's ~2.3x midpoint; one hero's clip with a following camera is too weak for a global change.

The standing rules are unchanged: an overheated glider still lifts you out of the abyss at half strength,
and walking off ledges is never blocked.

## Consequences
- No tuning change; one new check row; `[?]` tags on six `hunter.gd` constants (comments only).
- Net.VERSION bump: no.
- A 30-60 fps glide clip (a straight glide over ground, a reversal, a hoop pass) would close the `[?]` rows.
