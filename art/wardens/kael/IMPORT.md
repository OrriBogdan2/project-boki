# Kael (juggernaut): import note, ART-1 rebuild (2026-11-05)

`kael.glb`: rebuilt on the shared armature, 17.1k triangles with the greatsword, one 2048 atlas, 42 hand-keyed clips
(docs/art/wardens/CLIPS.md, content/rules/warden_anim/kael.json). The old stages (Meshy bake, fit, paint-over) gave the
body scan; the accuracy pilot's fitted model (ext/warden-3d-kael-acc a0c8c098, kael.glb) is the only input kept, as
geometry and paint source; it stays on that branch.

    B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    godot --headless -- --warden-rig-json --warden=juggernaut                  # after any body change
    $B tools/art1/kael_source.py -- <a3 kael.glb> stage/source.blend           # warp, cut, weld, decimate
    $B tools/art1/kael_finish.py -- stage/source.blend art/wardens/src/kael_rig.json build/kael.glb   # pieces, UV, paint, skin
    $B tools/art1/kael_clips.py -- build/kael.blend build/kael_a.glb           # clips; copy this glb here

`kael.glb.import`: `generate_lods=false`, `force_disable_compression=true`, `remove_immutable_tracks=false`.
Rebuilt: head and face (SDF sculpt, brows and lids on bones), mask, cowl, torn scarf end, collar, mane (spring chains),
hands, all chains, greatsword, thighs under the skirt. From the scan: torso, arms, legs, skirt plates, belt, greaves.
The blade's demon smoke left with the old weapon; it belongs to ART-2's VFX pass.
