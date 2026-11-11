# 0060: One save chain for the release line and the garden

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** save format

## Problem
Two lines each took save v12 for something else. 0.24.4 (the release line) ships v12 = evolution by species (`Evo.migrate`). The garden line (ext/garden-integrated and the hub stacked on it) used v12 = base life (`rec["bonds"]`) and v13 = garden zones (`GardenZones.migrate`). 0.24.5 merges both, so a shipped 0.24.4 save (Evo, no bonds) and a garden dev save at v12 (bonds, no Evo) must both load.

## Options
1. Renumber: v13 = bonds, v14 = zones. Cons: a garden dev save at v12/v13 would skip or re-run the wrong step.
2. One chain where every step only adds what is missing: v11 -> v12 runs Evo and the bonds step, v12 -> v13 runs both again and then GardenZones.

## Decision
Option 2, Save.VERSION 13 (the shaping items step of the garden-items line, its v13 -> v14, folds into v12 -> v13 as `Care.ensure` on every Boki). `Evo.migrate` is idempotent (it clamps levels and skips a Boki that already has `was`), the bonds step only adds a missing key, and `GardenZones.migrate` only adds the zone fields, so running v11 -> v12 again inside v12 -> v13 is safe for every v12 save from either line.

## Consequences
scripts/core/save.gd only. No Net change. Checks: the garden line's zone/raising checks and the release line's save/evo checks load saves through the same chain.
