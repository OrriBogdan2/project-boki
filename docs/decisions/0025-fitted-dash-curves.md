# 0025: Fitted dash speed curves for three heroes

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Decision 0020 left every dash at a constant speed that hands over at run speed, because the source's DashCurves
are encrypted. The hero-ref sheets track Ghost's slide, Brall's Quick Dash and Myth's roll at 1/15 s: all three
ramp to ~1.8x their mean in 0.04-0.15 s and bleed off in a straight line through run speed.

## Options
1. Keep constant speeds (0020) until the curves are decoded.
2. Fit each tracked dash and run it on that shape, in its own time and at its own distance, for heroes whose
   samples pin a curve (three or more); the rest stay constant and are marked [?].
3. Also take the source's durations and distances. That undoes owner-set kit numbers (Rampage 0.17 s, item 113).

## Decision
Option 2. `content/rules/dash_feel.json` gives a hero an optional `curve` ([u, k] knots, mean 1); a kit's measured
ground dash calls `travel(..., {"curved": true})` and `ArchKit._tick_curve` sets the speed each step
(`HunterMove.dash_k`, which the thief's vault curve now shares). The hand-over stays `HunterMove.dash_exit`
(at most run speed). Ghost's old straight skid in gunslinger_kit is replaced. Felix has no per-frame samples [?].

## Consequences
Distances and times are unchanged (`--move-feel-check` dash_curve_dist), the peaks move to the source's share
of the dash. Rampage's short time makes its peak ~34 m/s. Fits and errors: docs/SUPERVIVE_FEEL.md.

## Addendum (2026-11-12)
Two more curves from the sheets' samples: Albert's 360 Smash (Oath, 1/30 s rise to the 0.17 s peak) and Meeko's air
glide (Elluna, 0.1 s track of the 731.1 s dash), the glide replacing tender.json's hand shape (ramp / burst / out_k).
The curve is now the hero's one fitted dash, not always the ground one. Meeko's ground hop and Albert's lumber have
no per-frame samples: [?], constant.
