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
