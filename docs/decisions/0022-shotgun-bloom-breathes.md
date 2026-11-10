# 0022: The shotgun's bloom breathes between shots

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** combat (weapon spread)

## Problem
Grimble's scattergun (the only `shotgun` user) rested at a 30 degree fan and its per-shot bloom only recovered
once fire had been idle for `rate + 0.2` s, so held fire never tightened. The owner asked for Kingpin's lines:
footage shows the spread kick wide on each shot and converge back tight before the next, which lets you time
a tight shot (source ~30 degrees, 20 rested). Our edge lines also snapped to the fan instead of moving.

## Options
1. Keep the 30 degree rest and only animate the lines (they would lie about where the slugs go).
2. Give weapons a `bloom_wait` (s idle before the bloom recovers; default `rate + 0.2`, as before), set the
   shotgun to 0.1 with a bigger kick, and draw the lines at the real fan on a spring.

## Decision
Option 2. Shotgun: `fan_deg` 20, `bloom_deg` 10, `bloom_max_deg` 15, `bloom_recover` 24, `bloom_wait` 0.1.
Held fire swings 25-35 degrees each cycle; a patient shot is back at 20 in about 0.5 s. Slug count, damage,
size and range are unchanged. Every other weapon keeps its old recovery (no `bloom_wait` set).

## Consequences
The rested shotgun is tighter than before (20 vs 30 degrees), so a patient shot lands more slugs at range;
spam is about as wide as before. Checked by `--dredge-combo-check` (lines at the real fan, breathe while held,
brass at rest).
