# Pip (tender; was Moosh Moosh / Burple): import note, ART-1 rebuild (2026-11-05, items 76b + 108)

`pip.glb`: head and body are Meshy scans fitted to the rig in Blender; arms, hands, lantern, eye domes and wings are scripted. 13,970 triangles with the lantern (S1's budget: 15k, weapon included).
Eight materials: skin-fur, cloth-body, leather-body (the body's own 2048 colour, normal, emission), skin-face (the head's own 2048 colour, normal, emission), skin-hand, brass-pip, glow-pip (one 2048 atlas), card-wing.

    # credits: 36 (image edits) + 40 (body) + 40 (head); requests and outputs in ~/meshy/pip_f
    B=~/tools/blender-4.5.15-linux-x64/blender
    $B -b --factory-startup --python tools/art1/pip_head_scan.py -- ~/meshy/pip_f/head/run1/glb.glb WORK 6000   # head: fit, decimate, bake
    $B -b --factory-startup --python tools/art1/pip_source.py -- ~/meshy/pip_f/run1/glb.glb WORK 6200           # body: fit, arms and head cut, tail swung up, bake
    tools/art1/pip_build.sh WORK            # pip_art1.py (assembly, atlas), pip_clips.py (posekit.py), copies, imports

- **Refs:** briefs/art-refs/pip_head.png (head scan, eye size), pip_turnaround.png edited with the wings out (body scan), pip_FINAL_sheet.png, pip_props.png. Portrait and splash stay on the portraits lane.
- **Owner notes 11:40:** eyes are the scan's paint at pip_head.png's size (about 13% of the head's width). Scan beat the scripted head and body (both kept in git history, eff09bcc); scripted arms and hands stay because the rig hangs them where the A-pose scan cannot.
- **Proportions (tender.json body):** legs 0.98, torso 1.02, shoulder 1.12, neck -0.036: rig fitted to the scan. size 0.68 and hit_r 0.34 (item 108) unchanged. Clips key the hands through posekit's `dz`.
- **Lantern (76b):** skinned on `spring_hanglantern_0..2` under hand.R, the runtime's hang chain. `"skinned_weapon": true`, `blade` on anchor_lantern_top and weapon_muzzle. Sync.apply_blade runs again after the springs for it.
  FX points are empties: weapon_muzzle, anchor_hang_lantern, anchor_lantern_top, anchor_palm_L, anchor_flower, anchor_tail_tip, anchor_chest, anchor_head_top.
- **Rig extras (warden_anim/pip.json):** lid (a skin dome slid out through the painted eye to shut it), ear, jaw, fingers.L, thumb.L, foot, wing (keyed flutter), apron; springs spring_tail, spring_capeback, spring_wingR/L.
- **Wings:** alpha cards in a plane leaned to face up and back, so the 65 degree match camera never sees them edge-on; a little narrower from a low front camera than the sheet.
- **Constellations:** gold marks in the emission layers (the head's masked from its paint, the body's drawn by pip_paint.py). `emit` in warden_look is the resting glow; PipStars.pulse lifts it on every heal tick from TenderKit.
- **Imports:** pip.glb.import `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures VRAM compressed high quality, mipmapped, at most 2048. Normal maps through hero_toon `use_nrm` (from ext/art1-hem).
- `pip_fit.json`, `pip_bake.json`, `pip_recipe.json` belong to the old pipeline and no longer build this model.
