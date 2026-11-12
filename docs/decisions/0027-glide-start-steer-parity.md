# 0027: Glide steer force and start fall from the source data

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Two glide rows in `briefs/supervive-data/PHYSICS_PARITY.md` were never settled: GlideTargetXYForce 162,500
against our steer acceleration (a hunter.gd const on main, tuning.json on ext/supervive-movement), and
GlideStartFallSpeedMin -85 uu/s against our canopy catch (60 m/s², ours). The hero-ref notes
(`briefs/hero-ref/*.md`) track dashes and casts, not gliders: no reversal or canopy-catch frames exist. The
only glide footage is in SUPERVIVE_FEEL.md: the glider opens "instantly", and a lift from ~8 m deep is back
at the lip ~1.25 s later.

## Options
1. Keep both as live feel knobs in tuning.json. Pro: tunable. Con: the source pins the force, and the start rule is not modelled.
2. Steer = 162,500 / Mass 100 = 16.25 m/s² as [game data] in hunter_move.json; model GlideStartFallSpeedMin as a
   clamp the step the glider opens (fall at least 0.85 m/s, so a rising jump is cut); keep the catch rate ours,
   since GlideStartFallSpeedMax (the fastest fall an open leaves you with) is locked in the encrypted defaults.

## Decision
Option 2. The 16.25 number was already in use (a 90° turn 0.38 s, a reversal 0.6 s at cruise 5 m/s); it is now
pinned and asserted. The start clamp follows the owner rule "glide start adds no speed" and replaces the jump
pad's own 2 m/s cap. The catch stays 60 m/s² (0.18 s from the 12 m/s fall cap): the footage reads instant and
nothing in the data contradicts it.

## Consequences
`hunter_move.json` physics `glide_accel`, `glide_start_vy` (HunterMove); `Loco.glide_start` shared by Hunter (press,
hold/auto, pad) and the farm (Home); tuning.json glide.accel removed. `--move-feel-check`: glide_start_vy row plus
the two data asserts. Feathering: a re-open mid-lift starts from -0.85 m/s (the spring kick still applies once per
lift; feather_gain unchanged at 2.55). No Net or save change.
