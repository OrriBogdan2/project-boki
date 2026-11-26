# Every 3D model on the same cel-shade (11-26)

Rule: every Boki and Hunter the game draws wears the shared toon material and sits in the approved range of the set, so
a new model fits in. The gate is `--toon-consistency-check` (`tools/toon_consistency_check.gd`, ranges and waivers in
`content/rules/toon_consistency.json`; headless, in the suite like any registered check).

## What it reads
It builds each model the way the game does (`Models.kin` for each Boki with a `BokiRig` .glb, `Models.hunter` for each
`Arch.ORDER` Hunter) and reads the finished surfaces:
- shader: only the shared `toon`/`hero_toon` bodies plus the named special surfaces in the rules (eye, aura, halo, glow
  and flame, ring); a soft transparent effect quad is `(fx)`. Anything else (a PBR `StandardMaterial3D` body) fails.
- ink: the textured body surface has the outline pass.
- look: the shadow-defining uniforms (`ramp`, `sky_ao`, `sss`, `self_shadow`; a Boki's `shade` too) equal the shared
  values; a Hunter's shadow floor `shade` stays in [0.8, 0.95].
- atlas (the painted albedo, from the material): mean linear luminance, baked-shade share (texels under 0.6 of the
  atlas's own median) and mean HSV saturation (times the material's `tex_sat`) stay inside the approved set's range.

Do not widen a range to go green. Fix the albedo (a delit/flat-albedo pass, never a pixel recolour) or the material. A
model whose fix belongs to another job (a Hunter's .glb or look) is listed under `waived` with the exact fix; the check
fails once a waived model is fine, so the entry goes away with the fix.

## Crofthorn (`heatherhorn`)
Material: not the cause. It wears the same `hero_toon` material as 47 of 48 Boki (`ramp 2.6, shade 0.86, sky_ao 0.12`,
default coat look) with the same ink. Albedo luminance is not low either: mean 0.30 (Boki median 0.24), baked-shade share
0.33 (typical 0.2-0.39), rendered luminance in the brighter half at both cameras. What stands out is the atlas
saturation: 0.537, the highest of all 48 (next 0.491, median 0.345), with dark red speckle on a vivid orange, which the
warm light turns pure red at the match camera. Fix: the Boki coat look takes `tex_sat` (new `hero_toon` uniform, 1 =
as painted); Crofthorn's row in `BokiRig.FRAME` sets 0.85 (effective 0.46).

## Waived Hunters (not touched here: their rounds own them)
- Bulwark: `warden_look.json` `breaker.no_ink` lists the body's `scan` tag, so the body has no ink shell. Drop `scan`.
- Ostra: `warden_look.json` `ostra.painted.shade` is 0.6 (shadow floor; others 0.8-0.95). Set 0.82.

## Lineups
`--toon-lineup-shots` (match camera) and `--toon-lineup-farm-shots` (farm third-person camera; needs the farm camera) draw
every model one after another on the same spot under the same light; `--close` takes the match wheel's closest zoom.
They write `lineup_<id>.png`, `lineup_sheet.png` and `lineup_stats.tsv` (rendered luminance of the model's own pixels).
Run through `jobq submit --needs gpu`, with `--shots-dir` a path relative to the tree.
