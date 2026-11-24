import bpy, sys, numpy as np
from mathutils import Vector

A = sys.argv[sys.argv.index("--") + 1 :]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=A[0])
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
sk = bpy.data.objects["Skirt"]
me = sk.data
M = sk.matrix_world
h = M @ arm.data.bones["Hips"].head_local
ms = [m.name for m in me.materials]
fs = [p for p in me.polygons if ms[p.material_index] == "skirt-meshy"]
n = len(fs) // 2
uvl = me.uv_layers.active.data


def outw(p):
    c = M @ p.center
    return (M.to_3x3() @ p.normal).dot(Vector((c.x - h.x, c.y - h.y, 0)))


out = []
inn = []
for a, b in zip(fs[:n], fs[n:]):
    o, i = (a, b) if outw(a) >= outw(b) else (b, a)
    for p, L in ((o, out), (i, inn)):
        L.append(np.mean([uvl[l].uv[:] for l in range(p.loop_start, p.loop_start + p.loop_total)], 0))
np.savez(A[1], out=np.array(out), inn=np.array(inn))
print("faces", len(out), len(inn))
