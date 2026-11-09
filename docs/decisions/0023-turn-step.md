# 0023: Hunters re-plant their feet when they turn on the spot

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** animation (stacked on ext/feel-facing-turn, decision 0022)

## Problem
With `Hunter.FACE_TURN` the body is on the cursor in 1-2 sim steps. The keyed idle and stance clips then spin on fixed feet like a turntable; the procedural shuffle (`HunterAnim.lag`) only runs under the procedural pose, never over a clip. The source's heroes re-plant their feet when they turn on the spot (DECISIONS 2026-11-07 evening).

## Options
1. A short turn clip per weight class: three clips times 12 rigs, rebakes in Blender (not on this worker), and a clip cannot follow a cursor that keeps moving.
2. Procedural foot plant on the bones, over whatever clip plays (`scripts/heroes/warden_turn.gd`).
3. Delay or ease the facing so the feet keep up: breaks decision 0022 and would delay casts.

## Decision
Option 2. `WardenTurn` keeps `trail`, how far the feet are turned off the body. A standing Hunter (grounded, under 0.25 m/s, loco clips or an upper-body move, not procedural) lets the body turn and the feet stay. When the trail passes 90 degrees one foot lifts and the legs swing round (one step takes out up to 100 degrees, so 180 takes two, alternating feet); a leftover under 20 degrees settles. Only the root and hips bones turn (the legs go, the body keeps the clip's pose), and the thigh and shin of the stepping leg lift on top of the clip, so every Hunter keeps its own idle or stance between steps. Light/medium/heavy step in 0.12/0.15/0.22 s and lift 0.55/0.45/0.3 rad. Moving or a full-body move unwinds the feet in about 0.1 s. It runs after the rig-root pass in `WardenGlb.Sync._play`, because a hover Hunter (Motley) drives the root bone there.

## Consequences
Bones only: `face`, aim, casts and hits are never read or written, so nothing is delayed or turned. No Net or save change. `HunterAnim.lag` stays for the procedural poses. Checks: `--turn-step-check` (12 Hunters), strip `--turn-step-shots`.
