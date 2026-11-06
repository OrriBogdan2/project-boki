# Tarek (dolm): import note (ART-1, 2026-11-05)

`tarek.glb` is the ART-1 model of the stone-arm monk (briefs/art-refs/tarek_FINAL_sheet.png, tarek_turnaround_apose.png, tarek_head.png).
His body is a Meshy scan of the turnaround, baked and fitted to the contract armature (art/wardens/src/tarek_bake.json,
tarek_fit.json); his head and locs are a separate Meshy scan of the head sheet with its own atlas (tarek_head_bake.json). The
closed stone fists, the three eye-stones and the ground rings are scripted (tools/art1/tarek_shape.py). tools/art1/tarek_rigging.py
`assemble_scan` joins them: left arm grown, right gauntlet slimmed, hands cut, body skin brought to the head's tone, hot cracks
keyed from the atlas into an emission map, the stone's relief as a normal map, a loc end fused to his back painted out.

Rebuild (Blender under ulimit -v 12000000; raw files in ~/meshy/tarek_m):

    godot --headless --path . -- --warden-rig-json --warden=dolm
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/tarek_bake.json
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/tarek_head_bake.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/tarek_fit.json
    blender -b --factory-startup --python tools/art1/tarek_build.py -- art/wardens/src/tarek_rig.json WORK scan ~/meshy/tarek_m/fit.blend
    blender -b WORK/tarek.blend --python tools/art1/tarek_clips.py -- WORK/tarek_anims.blend art/wardens/tarek/tarek.glb

tarek_clipcheck.py measures arms into the chest across the clips. In game: --clip-shots (--true-cam, --ground=<hex>), --clip-check,
--rig-standard-check. Kit FX read `weapon_muzzle`, `anchor_wrist_R`, `anchor_fist_L/R`, `anchor_gauntlet_L/R`, `anchor_stones_<i>`.
