# Gil (the Novice Mage): import note, v1 (2026-11-10)

`gil.glb` is the owner's Gil turnaround (refs in ~/meshy/gill/refs: gill_turnaround, gill_portrait) through the
ART-1 pipeline (docs/art/wardens/PIPELINE.md steps 5-9). Raw files in ~/meshy/gill/ (never in git).

    B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    $B tools/meshy/bake_warden.py -- art/wardens/src/gil_bake.json        # s_g2 scan -> 30k low + 4096 atlas
    godot --headless -- --warden-rig-json --warden=gil                    # -> art/wardens/src/gil_rig.json
    $B tools/meshy/fit_warden.py -- art/wardens/src/gil_fit.json          # -> ~/meshy/gill/fit/fit.glb
    $B tools/meshy/gil_parts.py -- ~/meshy/gill/fit/fit.glb ~/meshy/gill/m_sf/glb.glb ~/meshy/gill/parts.glb
    $B tools/blender/decimate_warden.py -- ~/meshy/gill/parts.glb --tris=14000 --out=art/wardens/gil/gil.glb

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
- **Import:** `meshes/generate_lods=false`, `force_disable_compression=true` in gil.glb.import.

## v95 swap (2026-11-13, ext/showcase-1113)
`gil.glb` is now his v95 master (`~/meshy/v95/Gil/r2/v95a/cand_B.glb`, current.json, the first v95 face; its own
swordfish rapier left out: `gil_v95_B_body.glb`) on this file's skeleton and anchors, by `tools/art1/v95_swap.py` with
`art/wardens/src/gil_v95.json` (the game .glb before the swap is origin/main's v1):

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/gil_v95.json WORK art/wardens/gil/gil.glb

The master's real fish tail (on the `tail` bone) and dorsal fin replace the scripted stand-ins (`drop_meshes`: Tail,
Dorsal; their textures gil_Image_0.png and gil_gil_fin.png went with them). The skinned Swordfish mesh stays, its
texture now `gil_Image_0.jpg`. The satchel rides the hips (bone heat had put it on the right hand). 12.5k body
triangles, 2048 atlas. gil.glb carries no clips (the game keys his moves), so skin_relax is skipped and
`--stretch-check --wardens=gil` reports "no clips", as on the base. warden_model_check's `height_3d` is 0.9 (the
v95 hat stands lower than the v1 floppy one).
