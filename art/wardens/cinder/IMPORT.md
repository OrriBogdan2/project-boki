# Cinder (ashwick): import note, ART-1 v2, the Flame Queen (2026-11-07)

`cinder.glb`: the owner's v2 sheets (briefs/art-refs/cinder_v2/, master sheet's longer hair), on the shared armature, one 2048 atlas
plus its emission map and a small hair-card sheet, hand-keyed clips (docs/art/wardens/CLIPS.md, content/rules/warden_anim/cinder.json).
Owner override (DECISIONS 'Cinder the Flame Queen'): no tank, no hose, no flamethrower, no goggles, no fins; empty hands. Raw files in
~/meshy/cinder_v2, never in git.

    python3 -I tools/meshy/meshy_task.py edit ...      # x4: tank, hoses, weapon and goggles out of the turnaround's views
    python3 -I tools/meshy/meshy_task.py create ...    # runA: the edited views
    godot --headless -- --warden-rig-json --warden=ashwick                             # after any body change
    blender -b --factory-startup --python tools/art1/cinder_source.py -- scan.glb art/wardens/src/cinder_rig.json source.blend
    blender -b --factory-startup --python tools/art1/cinder_finish.py -- source.blend art/wardens/src/cinder_rig.json cinder.glb
    blender -b --factory-startup --python tools/art1/cinder_clips.py -- cinder.blend cinder_final.glb

`cinder.glb.import`: `generate_lods=false`, `force_disable_compression=true`, `remove_immutable_tracks=false`.

From the scan: body, face, horns, shards. The scan welded her forearms to the hip plates: `part_arms` cuts that seam and closes both sides.
Added: the spined tail (9 spring bones, `cinder_pieces.py`), hair cards with ember ends and flame strips (`flame-hair`), heel jets on `jet.*`
(`flame-jet`, for Flue Flight). The seams are the emission map, white-yellow core to orange; `PipStars.pulse` brightens it while she casts.
The flame on the tail is not mesh: `smoke` and `bloom` on `anchor_tail_tip` in warden_look.json. `weapon_muzzle` is her right palm (the kit's
fire point); `anchor_tank`, `anchor_vial_*` and `anchor_gun_mid` stay as contract names only. Her fire stream keeps the rules' NOZZLE.
