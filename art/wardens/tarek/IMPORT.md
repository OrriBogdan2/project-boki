# Tarek (dolm): import note (ART-1 v2, 2026-11-07)

`tarek.glb` is the v2 model of the stone-arm monk (briefs/art-refs/tarek_v2/, index.md canon, tarek_v2_turnaround.jpg final).
His body is one Meshy multi-image scan of the turnaround (huge stone left arm, stone gauntlet on the right forearm, cream
blindfold, locs, prayer beads, cream wrap, burnt-orange sash, brown trousers, wrapped feet), baked and fitted to the contract
armature (art/wardens/src/tarek_bake.json, tarek_fit.json). tools/art1/tarek_scan.py adds the rest: foot, lip and jaw bones,
the stone arm faces moved to the stone (`leather`) slot, the jade glyph emission map keyed from the atlas (the dark seams
never glow; the in-game colour is dolm.json "model_glow"), the three floating eye stones and fist shards on their orbit
points, the ground rings and the kit anchors.

Rebuild (Blender under ulimit -v 12000000; raw files in ~/meshy/tarek_v2):

    godot --headless --path . -- --warden-rig-json --warden=dolm
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/tarek_bake.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/tarek_fit.json
    blender -b --factory-startup --python tools/art1/tarek_scan.py -- ~/meshy/tarek_v2/fit.blend WORK
    blender -b WORK/tarek.blend --python tools/art1/tarek_clips.py -- WORK/tarek_anims.blend art/wardens/tarek/tarek.glb

tarek_clipcheck.py measures arms into the chest across the clips. In game: --clip-shots (--true-cam, --ground=<hex>), --clip-check,
--rig-standard-check. Kit FX read `weapon_muzzle`, `anchor_wrist_R`, `anchor_fist_L/R`, `anchor_gauntlet_L/R`, `anchor_stones_<i>`.

walk and run b, l, r, fl, fr, bl, br (2026-11-11): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/tarek/tarek.glb OUT.glb 2.2 5.0`,
then `python3 tools/art1/glb_add_clips.py art/wardens/tarek/tarek.glb OUT.glb walk_b,walk_l,walk_r,walk_fl,walk_fr,walk_bl,walk_br,run_b,run_l,run_r,run_fl,run_fr,run_bl,run_br`
(judge: docs/art/wardens/dirloops/JUDGE.md).

run_f on the ring's recipe (2026-11-12, ext/anim-dir-all-1112; the pilot run_f planted 0.75..8.89 m/s): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/tarek/tarek.glb OUT.glb 2.2 5.0 f 0 0 1 1,1 40 run`, then `glb_add_clips.py tarek.glb OUT.glb run_f` and run_fl, run_fr copied back from the old file.
