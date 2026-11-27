# 0179: Shot damage by distance (fall-off and ramp-up)

- **Status:** accepted (owner rule 11-27: the reference is right on every metric unless proven otherwise)
- **Date:** 2026-11-27
- **Area:** combat

## Problem
No weapon lost damage with distance except two ad hoc keys (`far_mult` on the smg, `close_mult` on the sniper). The reference gives each shot a fall-off class (full to a start distance, a straight line to a floor share at an end distance) and a few a ramp-up (weak up close). Duels had no kiting-versus-close trade.

## Options
1. Use the reference metres as they are. Our weapon ranges (6-16 m) end before most class ends (14-17.5 m), so almost nothing would fall off.
2. Per-weapon numbers by hand: a second set of values that drifts from the reference.
3. Keep the reference classes in one rules file; a weapon names its class; a shorter weapon squeezes the class into its own range (decided).

## Decision
Option 3. `content/rules/shot_falloff.json` holds the classes, `ShotFalloff.add` turns a weapon's `"falloff"` / `"ramp"` into the shot's existing `farf` / `near` keys, and `Match._shot_apply` reads them (`near` gets an optional start distance). The ad hoc keys are removed. Named weapons only: rifles, arc bolts, sniper, coilcaster, spellstaff, smg, minigun, longbow. Not the shotgun (the reference gives its slugs a fixed stop range only), melee, fire, or kit abilities.

## Consequences
- No wire change (damage is computed on the shooter's side before `hurt`), no save change.
- Every named weapon now does 25-50% of its damage at max range; TTK at range rises, up close it is unchanged. Balance may want a second pass.
- `--shot-falloff-check`: class squeeze, then a shot at point-blank, mid-slope and max range for the rifle and the sniper.
