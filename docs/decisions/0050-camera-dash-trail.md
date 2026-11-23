# 0050: The camera trails a dash and eases in, as the source does

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
Our follow was one exponential rate (15/s) for everything, so a dash dragged the view along: a 4.6 m dash
in 0.12 s pans at ~1600 px/s and is caught up in 0.2 s. The source trails it: about 700 px/s, down to
~300 px/s, and stopped about 0.5 s after the dash (briefs/hero-ref/dredge.md 4; ~0.4 s for a blink, 8),
while a run stays centred and stops with you in ~0.2 s (mooshmoosh.md 2), and a teleport cuts (ostra.md 2-3).

## Options
1. A slower exponential rate: trails a dash, but leaves you ~1 m behind at a run and drifts after a stop.
2. min(rate x gap, sqrt(2 x decel x gap)): the exponential near you (a run is unchanged), a steady
   deceleration when far behind (the dash curve), capped at max_gap, cut above cut_speed.
3. Lock the follow (ext/feel-camera-fast): no trail at all, which the dash footage doesn't show.

## Decision
Option 2, in CamRig._trail_xz, numbers in content/rules/camera.json "trail" (decel 28 m/s^2 fitted
to the 700 -> 300 px/s pan; max_gap 3.5 m so a 40 m/s Wirerun keeps you on screen).

## Consequences
cam.gd only; recording mode keeps its own rates. No Net or save change. --camera-follow-check asserts the
source curve and catch-up per dash type; move-feel's cam_lag_m and cam_settle_t still pass. A follow target
that jumps (a spectate switch, the death camera) now cuts instead of panning.
