# PLAN: Boki eyes are part of the model (owner ruling 11-24)

Owner: "i dont like any of the eyes looking glued on, they should be part of the model".

## Surfaces that draw a Boki
Every in-game surface builds a rigged Boki through one path: `Models` -> `KinModels.build` -> `BokiRig.build` ->
`BokiRig._dress`. That covers the match, home/farm, wild Boki, Bokidex 3D / Model Room (`dex_view`), the summon
burst, Fusion previews and every tool render (`boki_rig_shots`, `boki_world_shots`, `boki_eyes_shots`). The switch in
`_dress` therefore reaches all of them. Not affected: `creator_panel.gd` (Hunter look, no Boki),
`boss_models.gd` (its "Face" is a sundial, not a Boki). Site Bokidex art is pre-rendered: it changes on the next
site re-export (not in this branch).

## Switch
`BokiRig.face_overlay` (static, default `false`): off = a species drops the Face mesh at load and shows its coat's
painted eyes. `content/rules/boki_eyes.json` lists the species whose coat has no usable eyes under the overlay; they
keep the overlay until an eye-paint pass (later art job). `true` brings the overlay back on all 48. `face.py` and the
Face in every glb stay. No glb bytes change.

## Per species (GPU close-ups, overlay off, plus a 4-side turnaround for the 31 kept-eye species)
31 coats show their own painted eyes and drop the overlay. 17 do not (painted out by the scan's `"cover"`, smeared,
or blank): cindle, puddlet, burrlet, pebbit, selenfin, zapple, gibbelle, goliathite, hoarheron, floenatee, duskapi,
moundvark, murmurling, nacrolin, sentrikat, threadwyrm, lilybara (`content/rules/boki_eyes.json`). The head close-up
misses the face on kilnbadger, spatewader, tuatrune and glomwort (the head bone's box is a prop or the back); the
`--turn` front view shows their painted eyes. Sheet: /home/boki/gens/boki-eyes-in-model-1124/a3/eyes48_final.png.

## Expressions (step 3)
Not built here: flush expressions need a coat-shader eye mask per species (UV region of the painted eyes) to darken
a lid band for blinks and tint for anger. Proposal in the PR; not cheap enough for this pass (48 masks by hand or a
detector).
