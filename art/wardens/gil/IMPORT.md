# Gil (the Novice Mage): import note, v1 (2026-11-10)

`gil.glb` is the owner's Gil turnaround (refs in ~/meshy/gill/refs: gill_turnaround, gill_portrait) through the
ART-1 pipeline (docs/art/wardens/PIPELINE.md steps 5-9). Raw files in ~/meshy/gill/ (never in git).

    B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    $B tools/meshy/bake_warden.py -- art/wardens/src/gil_bake.json        # s_g2 scan -> 30k low + 4096 atlas
    godot --headless -- --warden-rig-json --warden=gil                    # -> art/wardens/src/gil_rig.json
    $B tools/meshy/fit_warden.py -- art/wardens/src/gil_fit.json          # -> ~/meshy/gill/fit/fit.glb
    $B tools/meshy/gil_parts.py -- ~/meshy/gill/fit/fit.glb ~/meshy/gill/m_sf/glb.glb ~/meshy/gill/parts.glb
    $B tools/blender/decimate_warden.py -- ~/meshy/gill/parts.glb --tris=14000 --out=art/wardens/gil/gil.glb
    $B tools/art1/gil_clips.py -- art/wardens/gil/gil.glb                     # foot bones, tail skin, the clips (in place)

- **Scan:** Meshy s_g2 (hat, polka-dot coat, satchel, striped curl-toe boots, the fish face). No new Meshy credits.
- **Rig:** the body numbers in BODY.json (size 1.0, head 0.71, legs 1.03, torso 1.0, shoulder 1.14, arms 0.92,
  hit_r 0.38) put the rig's joints on the scan's; they belong in content/archetypes/gil.json `body` (kit's file).
- **Fit:** slots by region + colour (cloth coat and hat, skin face/hands/legs, leather satchel and boot soles),
  14k body triangles, fit weights, ink room in COLOR_0 alpha, atlas 2048.
- **Swordfish (skinned, its own mesh):** Meshy's m_sf swordfish cut to 1.6k triangles, texture 1024, 0.74 m bill to
  fork, held by the root of the tail in the RIGHT fist, bill forward and down (as Kael's sword); weighted 1.0 to
  hand.R, material `metal-swordfish`. `weapon_empty` hides the procedural weapon; FX empties weapon_muzzle (bill
  tip), anchor_blade_mid and anchor_blade_root sit on hand.R. The kit may want `skinned_weapon` in
  content/rules/warden_anim/gil.json, as Kael has.
- **Fish tail and dorsal fin (turnaround; scripted, gil_parts.py):** a tapered tube from under the coat's back hem,
  down and back to a forked caudal fin at boot height (`skin-tail` / `skin-fin`), and a ray fin on the upper back
  (`skin-fin`, blue root to orange edge); both rigid on hips. Simple stand-ins: no spring bones, flat from behind.
- **Clips (v2, 2026-11-11, tools/art1/gil_clips.py):** foot.L / foot.R added at the ankles (the boots below 3.5 cm and
  the curled toes moved onto them from the shins, blended to 8.5 cm) so the boots stay flat as the shins tilt, and the
  Tail mesh moved from hips onto the `tail` bone (fully past 15 cm from where it leaves the coat) so it swishes. 19
  clips keyed in fistkit (the right fist's `br` points the bill): idle, stance (en garde), walk and run f/b/l/r, rise,
  fall, glide, thrust_a, thrust_b, lunge (the Fencer, KMovesDJ gil_*), hit_f, hit_b, death (knocked down onto his back,
  flops twice). Mapped in content/rules/warden_anim/gil.json; the rest of the rig, mesh, images and materials go out
  as they came in. The script reruns on its own output (it reads the bill's direction with the rig at rest).
- **Clips (v3, 2026-11-11):** 16 more, so every state he has is keyed: crouch (idle, sneak f/b/l/r, in, out), land,
  stun, emote (a fencer's salute, a bow too deep, two giddy bounces), revive (on one knee, fanning the Boki), fuse
  (mf_xform), and his casts, kit moves with a clip and no procedural keys: toss (Grab Bag, upper while moving), spin
  (Riptide: five turns on his toes, the longest spin), spout, swim (Ground Swim: a dive, then only the back fin and the
  tail fork cut the ground), surface, surf (Tidal Wave, side-on on the crest) and wave_land.
- **Toss re-keyed (2026-11-12):** the Grab Bag toss is a reach into the satchel on his right hip (the swordfish
  swung wide) and a yank of the potion up over his hat brim on 4/30 s, the frame the kit lets it go (gil.json rmb
  `draw`, `--clip-check` row), then a settle to 0.4 s. Baked with pip `bpy` 4.5 (no Blender on the worker) and copied
  on with `glb_add_clips.py toss`, so the rest of the file is byte for byte the same.
- **Import:** `meshes/generate_lods=false`, `force_disable_compression=true` in gil.glb.import.
