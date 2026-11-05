# Tarek (dolm): import note (ART-1, 2026-11-05)

`tarek.glb` is the ART-1 rebuild: no scan in it. Every part is a scripted sculpt (signed distance fields) on the contract
armature, painted from the fields, 19,985 tris with his bracers, stones and shards. The fists are the weapon, skinned in
the body (item 76b); kit FX read `weapon_muzzle` and `anchor_wrist_R` on the right hand (content/rules/warden_anim/tarek.json,
`blade`), and `anchor_fist_L/R`, `anchor_gauntlet_L/R`, `anchor_stones_<i>`. References: ext/imagegen wardens_r2 tarek_front,
tarek_head_sheet, tarek_stone_sheet. The Meshy recipe (art/wardens/src/tarek_fit.json, tarek_bake.json) is history.

Rebuild (Blender 4.5, ~3 min; numpy and ffmpeg, no Cycles):

    godot --headless --path . -- --warden-rig-json --warden=dolm
    blender -b --factory-startup --python tools/art1/tarek_build.py -- art/wardens/src/tarek_rig.json WORK full
    blender -b WORK/tarek.blend --python tools/art1/tarek_clips.py -- WORK/tarek_anims.blend art/wardens/tarek/tarek.glb

tools/art1: sdf_kit.py (the sculpt kit), tarek_shape.py (his forms), tarek_paint.py, tarek_rigging.py, fistkit.py (two-fist
pose solver), tarek_clips.py (the 39 clips, timed to KMovesStone), tarek_view.py and tarek_sheet.py (Blender previews).
In game: --clip-shots, --clip-check, --rig-standard-check. His .import keeps remove_immutable_tracks off.
