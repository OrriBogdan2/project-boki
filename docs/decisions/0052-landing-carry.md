# 0052: Landing carry under strong air control

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** movement

## Problem
How fast a Hunter is moving when it lands decides whether movement flows. Under `Loco.air_step` (owner 11-08,
strong WASD air control) a hop or a 4-terrace drop with the keys held already lands at run speed (1.00x). Letting
go of the glider did not: for 0.6 s ([est] FEATHER_KEEP) the glide's speed and steering were kept
(`Loco.glide_step`), so a let-go 2 m up landed at 1.14x run, on a second air rule.

## Options
1. Keep the 0.6 s glide keep (1.14x, two air rules after a let-go).
2. A let-go falls by `Loco.air_step` like any jump: the extra over run bleeds at tuning.json `air.drag` (1.05x).
3. Also brake to run at the source's 0.75/s (1.00x): a third air rule, against the owner's 11-08 model.

## Decision
Option 2. The keep branch in `Hunter._physics` is removed; FEATHER_KEEP still marks "just off the glider" for
ledges and the wall shove. tuning.json is unchanged: a let-go jump keeps `air.idle_drag` 0.4/s (3.4 m carry vs the
source's 2.9 m at 0.75/s) and `air.drag` stays 2/s; both are the owner's numbers.

## Consequences
`--move-feel-check` land_carry_{hop,drop4,glide}_held: 1.00x / 1.00x / 1.05x. feather_gain 2.55x -> 2.49x
(target >= 1.15x).
