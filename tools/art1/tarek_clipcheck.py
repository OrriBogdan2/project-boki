"""Arm-into-body check of the clips: blender -b tarek_anims.blend --python tools/art1/tarek_clipcheck.py
For each clip at 8 frames, how deep the arm and fist vertices go inside the chest (an ellipsoid riding the hips bone). Prints
the clips deeper than LIMIT, worst first. A proxy: it sees the chest only, not the head, legs or sash."""
import bpy
import numpy as np
from mathutils import Vector

LIMIT = 0.02                   # m
R3 = np.array((0.15, 0.11, 0.24))      # the chest's half sizes, m
arm = bpy.data.objects["Armature"]
hips = arm.pose.bones["hips"]
sh = arm.data.bones["upper_arm.R"].head_local
C0 = Vector((0, 0, (sh.z + arm.data.bones["hips"].head_local.z) * 0.5))
parts = []
for nm in ("tarek_body",):
    ob = bpy.data.objects[nm]
    gi = {g.index: g.name for g in ob.vertex_groups}
    ids = [v.index for v in ob.data.vertices if len(v.groups) and gi[max(v.groups, key=lambda g: g.weight).group].split(".")[0] in ("upper_arm", "forearm", "hand")]
    parts.append((ob, np.array(ids)))
arm.animation_data_create()
out = []
for act in bpy.data.actions:
    arm.animation_data.action = act
    a, b = act.frame_range
    worst = 0.0
    at = 0
    for i in range(8):
        f = int(a + (b - a) * i / 7)
        bpy.context.scene.frame_set(f)
        dg = bpy.context.evaluated_depsgraph_get()
        M = (arm.matrix_world @ hips.matrix @ hips.bone.matrix_local.inverted()).inverted()
        for ob, ids in parts:
            me = ob.evaluated_get(dg).to_mesh()
            co = np.zeros(len(me.vertices) * 3, np.float32)
            me.vertices.foreach_get("co", co)
            co = co.reshape(-1, 3)[ids]
            ob.evaluated_get(dg).to_mesh_clear()
            q = np.c_[co, np.ones(len(co))] @ np.array(M).T
            d = 1.0 - np.sqrt((((q[:, :3] - np.array(C0)) / R3) ** 2).sum(1))
            w = float(d.max()) * 0.15
            if w > worst:
                worst, at = w, f
    out.append((worst, act.name, at))
for w, nm, f in sorted(out, reverse=True):
    if w > LIMIT:
        print("CLIPDEPTH %.3f m %s @%d" % (w, nm, f))
print("CLIPCHECK_DONE, %d of %d clips deeper than %.2f" % (sum(1 for o in out if o[0] > LIMIT), len(out), LIMIT))
