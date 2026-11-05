# Tarek (dolm): import note (ART-1, 2026-11-05)

`tarek.glb` is the ART-1 rebuild to the stone-arm monk master (briefs/art-refs/tarek_FINAL_sheet.png): no scan in it. Every part
is a scripted sculpt (signed distance fields) on the contract armature, painted from the fields, under 20k tris with the
stones and shards. The huge stone arm and fist are the weapon, skinned in the body slab by slab, each slab on one bone (item
76b); a small stone bracer on the other forearm. Kit FX read `weapon_muzzle` and `anchor_wrist_R` on the stone fist
(content/rules/warden_anim/tarek.json, `blade`), and `anchor_fist_L/R`, `anchor_gauntlet_L/R`, `anchor_stones_<i>`. The Meshy recipe
(art/wardens/src/tarek_fit.json, tarek_bake.json) is history.

Rebuild (Blender 4.5, ~3 min; numpy and ffmpeg, no Cycles):

    godot --headless --path . -- --warden-rig-json --warden=dolm
    blender -b --factory-startup --python tools/art1/tarek_build.py -- art/wardens/src/tarek_rig.json WORK full
    blender -b WORK/tarek.blend --python tools/art1/tarek_clips.py -- WORK/tarek_anims.blend art/wardens/tarek/tarek.glb

tools/art1: sdf_kit.py (the sculpt kit), tarek_shape.py (his forms), tarek_paint.py, tarek_rigging.py, fistkit.py (two-fist
pose solver), tarek_clips.py (the clips, timed to KMovesStone), tarek_view.py and tarek_sheet.py (Blender previews).
Match-camera read: the stone arm, the orange sash (material cloth-accent) and the eye-stones; copper rings, shards and the
ground rings are separate nodes hidden past 13 m (warden_look far_hide). In game: --clip-shots (--true-cam, --ground=<hex>), --clip-check,
--rig-standard-check. His .import keeps remove_immutable_tracks off.
