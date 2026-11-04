# Boki 3D pipeline (Meshy image-to-3D -> bake -> parts -> KinGlb)

Boki were built in code (`scripts/match/kin_models.gd`). A species with `art/kin/<id>/<id>.glb` is drawn from that model
instead (`KinGlb`); the rest keep their primitives. Pilot: Gravadillo (`pebbit`). Raw files live under `~/meshy/<id>/` (never in git).
B = `~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python`. T = `python3 -I tools/meshy/meshy_task.py`.

1. **Sheet from the current design.** `--kin-shots --species=<id> --shots-dir=<dir>` writes `flat_front/three_quarter/side/back.png`
   (flat light, grey) and the face. These are the references for the image model. Add `--procedural` for the old look.
2. **Concept pass (Meshy image-to-image, nano-banana-pro, 9 credits each).** `T edit <out> flat_front.png flat_three_quarter.png --prompt ...`
   redraws the crude render as appealing creature art: keep the species identity (animal blend, markings, glow colour), rounder
   and chunkier, huge glossy eyes with catch-lights, blush, a lighter palette that reads in dark biomes, plain grey ground.
   Make 2 variants, pick one. Then derive the other views from the picked 3/4 with explicit orthographic wording ("FRONT
   ORTHOGRAPHIC VIEW: camera directly in front, perfectly symmetrical", "SIDE PROFILE: only ONE eye visible"), plus an explicit
   colour list: the model ignores a bare "front view" and drifts colours on the side view (Gravadillo's first side came out khaki).
3. **Body run (40 credits).** `T create <out> front.png 34.png side.png back.png --texture-refs <same four> --enhance off --pose ""`
   (a quadruped has no A-pose). Defaults are Meshy's best: meshy-7.1, Ultra geometry, 8k PBR.
4. **Bake.** `B tools/meshy/bake_warden.py -- art/kin/src/<id>_bake.json` (a game mesh of ~14k tris, the head richer, one 4k atlas).
5. **Parts.** `B tools/meshy/kin_parts.py -- art/kin/src/<id>_parts.json` cuts the baked mesh into Hull, Tail, Ears (EarL/EarR),
   Legs (Leg0..Leg3) with each origin at its joint, scales it to a Boki, faces it -Z and exports the .glb with a 2k JPEG atlas.
   Read the part positions off orthographic renders of the bake (side, top, bottom, front), not off numbers. Legs and ears are cut out of the hull,
   so keep their radii tight or shell fringe goes with them.
6. **Engine.** Copy the .glb into `art/kin/<id>/`, `godot --headless --path . --import`, add the species to `KinGlb.FRAME` (head and top),
   run `--kin-glb-check`, `--kin-shots` (old vs new, day, night, match zoom), and the usual Boki checks.

Eyes are painted into the atlas, so the puppet's blink has nothing to scale on a modelled species (open work: a blink mask in the shader).

## Credits (Gravadillo): 2 concept variants 18, 3 derived views 27 + 2 retries 18, body run 40 = 103.
