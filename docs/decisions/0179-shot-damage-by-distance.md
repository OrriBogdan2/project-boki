# 0179: Shot damage by distance (fall-off and ramp-up)

- **Status:** accepted (owner rule 11-27: the reference is right on every metric unless proven otherwise)
- **Date:** 2026-11-27
- **Area:** combat

## Problem
No weapon lost damage with distance except two ad hoc keys (`far_mult` on the smg, `close_mult` on the sniper). The reference gives each shot a fall-off class (full to a start distance, a straight line to a floor share at an end distance) and a few a ramp-up (weak up close). Source: the reference's projectile globals (8 fall-off classes, 3 ramps), sv-refs hit-detection page, COMPARE-HIT-1126 section 4.

## Options
1. Use the reference metres as they are (decided). Our ranges (6-16 m) end before most class starts, so only the long reach weapons lose damage.
2. Squeeze each class into the weapon's own range (the first build of this branch): every weapon would do 25-50% at max range. Rejected: it invents distances the reference does not have, and the one footage reading (Elluna's pistol about 5% weaker at about 8 m) shows the reference is gentler than its class line, not harsher.
3. Per-weapon numbers by hand: a second set of values that drifts from the reference.

## Decision
Option 1. `content/rules/shot_falloff.json` holds the classes in metres, `ShotFalloff.add` puts a weapon's `"falloff"` / `"ramp"` on the shot (`farf` / `near`), `Match._shot_apply` multiplies by `ShotFalloff.mult`. The ad hoc keys are removed. Classes per weapon: the reference names Ghost's rifle Medium (Vex's quill rifle), Joule's bolt Long (Sparkle's coilcaster), Elluna's pistol Seraph (Meeko's lantern crook), the minigun and the bow their own classes; the other rifles take Medium and the sniper and spellstaff Long. Not the shotgun (fixed stop range only), melee, fire, or kit abilities.

## Consequences
- No wire change (damage is computed on the shooter's side before `hurt`), no save change.
- Share at max range: sniper 58% (and half damage point-blank), Meeko 79% (62% for the 8.4 m empowered ember), minigun 79%, Vex 92%, Sparkle 94%; the others never fall off.
- Kit-ability shots the reference names (Sparkle's Storm Rod, 13 m lane, Long: at most 6% off at the lane end; Sable's Encore blades, 5.4 m ring, Medium: never) are left out: their damage runs through the kin stage callback, not `_shot_apply`, and the reference metres barely touch them.
- `--shot-falloff-check`: the classes, then a shot at several distances for the sniper, the crook and the rifle.
