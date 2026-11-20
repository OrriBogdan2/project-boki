# 0102: Albert's rig takes his new turnaround's leg length

- **Status:** proposed (draft PR, owner visual check first)
- **Date:** 2026-11-20
- **Area:** combat

## Problem
Albert's (bulwark) 3D regen comes from the owner's turnaround pick (r4 C, arms shorter). Its legs are ~2x his rig's
(body "legs" 0.46). Fitting the new model onto the old rig squashed the legs to half (stubby) and over-stretched the
knees and hips (31 clips over the 9.5 ceiling vs 7 live).

## Options
1. Keep the rig, squash the model: no gameplay change; stubby legs, off-model, stretch fails.
2. Edit the turnaround to short legs: changes the owner-picked design (not allowed).
3. Change the rig to the art: body "legs" 0.46 -> 0.84, "torso" 1.06 -> 1.02, "neck" 0 -> -0.05; the .glb rest moves
   onto the new rig (tools/art1/rest_from_rig.py) and each clip's root height keeps the feet on the floor.

## Decision
Option 3: the hips and Aim rise 0.16 rig m (0.23 m in game); shoulders (+0.14) and head (+0.08) rise less, so he
is only ~0.08 rig m taller to the helmet. Hurtbox (hit_h, hit_r) is unchanged.

## Consequences
content/archetypes/bulwark.json, content/rules/warden_rest.json (re-baked). The Gun/Aim node sits higher, so any of
his moves that start from Aim/Muzzle start higher. No save or Net change (Net.VERSION no). Run/walk strides are longer
on the same keys (feet may slide more).
