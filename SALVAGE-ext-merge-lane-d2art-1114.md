# SALVAGE: Albert's i1 swap left out of ext/merge-lane-d2art-1114 (PR #97)

Main's `art/wardens/breaker/breaker.glb` gained Albert's 16 directional walk/run loops and a new idle since this lane
swapped his live i1 master in (commits b640179173, 24af840519 on this branch). The glb cannot be merged as a binary and the
swap needs Blender plus `~/meshy/v95/Albert/r3/meshy1112/candidates/i1/glb.glb`, neither on worker w2. So this merge keeps
main's Albert: breaker.glb, atlas/emit textures, `breaker_v95.json`, IMPORT.md, `warden_mood.gdshader` (face) and the
`bulwark` `height_3d` 1.55 in `warden_model_check` are main's. Left over from the swap: the generic `emit_paint` / `screen_uvs`
keys in `tools/art1/v95_swap.py`.

To redo the swap on a box with Blender: `git show b640179173 -- art/wardens/src/breaker_v95.json art/wardens/breaker/IMPORT.md`
and `git show 24af840519 -- shaders/warden_mood.gdshader`, then run the command in that IMPORT.md on main's breaker.glb
(all points in the spec are absolute, clips come through untouched) and set `height_3d` to 1.77.
