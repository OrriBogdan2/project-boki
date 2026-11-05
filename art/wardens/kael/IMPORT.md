# Kael (juggernaut): import note, ART-1 final design (2026-11-05)

`kael.glb`: the owner's final design (briefs/art-refs/kael_FINAL_sheet.png, kael_turnaround_apose.png, kael_weapons.png), on
the shared armature, about 16.6k triangles with the greatsword, one 2048 atlas, 42 hand-keyed clips
(docs/art/wardens/CLIPS.md, content/rules/warden_anim/kael.json). Raw files in ~/meshy/kael_f (never in git).

    B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    python3 -I tools/meshy/meshy_task.py edit ...      # x4: tails, chain and long hair out; prompt in edit_*/request.json
    python3 -I tools/meshy/meshy_task.py create ~/meshy/kael_f/runA in/front.png in/left.png in/back.png in/right.png \
        --texture-refs in/front.png in/left.png in/back.png in/right.png --enhance off
    godot --headless -- --warden-rig-json --warden=juggernaut                  # after any body change
    $B tools/art1/kael_source.py -- ~/meshy/kael_f/runA/glb.glb art/wardens/src/kael_rig.json stage/source.blend
    $B tools/art1/kael_finish.py -- stage/source.blend art/wardens/src/kael_rig.json build/kael.glb
    $B tools/art1/kael_clips.py -- build/kael.blend build/kael_a.glb           # clips; copy this glb here

`kael.glb.import`: `generate_lods=false`, `force_disable_compression=true`, `remove_immutable_tracks=false`.
Rebuilt as geometry: head and face (SDF sculpt, brows and lids on bones), scarf funnel, its two long tails on spring
chains, mane, hands, the right wrist's chain and hook, greatsword. From the scan: torso, arms, trousers, armour, boots.
The blade's demon smoke and sparks are ART-2's.
