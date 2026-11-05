# Pip (tender; was Moosh Moosh / Burple): import note, ART-1 rebuild (2026-11-05, items 76b + 108)

`pip.glb` is built by script in Blender, no scan and no Meshy credits: SDF sculpts (body, arms, head) and scripted pieces on the rig's own
joints, a per-texel paint from rest-pose position and piece, and 38 clips keyed as targets. 12.9k triangles with the lantern (S1's budget:
15k, weapon included). Atlas 2048, emission 2048 (same layout), wing cards RGBA 1024. Seven slots: skin, cloth, leather, brass, eyes, glow, card.

    tools/art1/pip_build.sh WORK            # pip_art1.py (shapes pip_sculpt.py + hem_sdf.py, paint pip_paint.py), pip_clips.py (posekit.py), copies, imports
    tools/art1/pip_build.sh WORK clips      # the clips only

- **Refs:** briefs/art-refs/pip_FINAL_sheet.png (master, the gold constellations), pip_turnaround.png, pip_props.png. Portrait and splash stay on the portraits lane.
- **Proportions (tender.json body):** legs 0.98, torso 1.32, shoulder 1.12: short legs and a long pear body, as the sheet. size 0.68 and hit_r 0.34 (item 108) unchanged.
- **Lantern (76b):** skinned on `spring_hanglantern_0..2` under hand.R, the runtime's hang chain: it always hangs and swings, whatever the arm does.
  `"skinned_weapon": true`, `blade` on anchor_lantern_top and weapon_muzzle. Sync.apply_blade runs again after the springs for it.
  FX points are empties: weapon_muzzle, anchor_hang_lantern, anchor_lantern_top, anchor_palm_L, anchor_flower, anchor_tail_tip, anchor_chest, anchor_head_top.
- **Rig extras (warden_anim/pip.json):** lid, brow, ear (L/R), jaw, fingers.L, thumb.L, foot, wing (keyed flutter), apron; springs spring_tail, spring_capeback, spring_wingR/L.
- **Wings:** alpha cards in a plane leaned to face up and back, so the 65 degree match camera never sees them edge-on; that makes them a little narrower from a low front camera than the sheet.
- **Constellations:** gold lines and stars painted into the atlas and the emission layer (pip_paint.py CONST, drawn in a projection on each piece). `emit` in warden_look is the resting glow;
  PipStars.pulse (scripts/heroes/pip_stars.gd) lifts it on every heal tick from TenderKit.
- **Imports:** pip.glb.import `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures VRAM compressed high quality, mipmapped, at most 2048.
- `pip_fit.json`, `pip_bake.json`, `pip_recipe.json` belong to the old scan pipeline and no longer build this model.
