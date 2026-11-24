"""blender -b -P handpts.py -- GLB OUT.npy : left hand + bow verts over all clip frames, mapped into LeftUpLeg / RightUpLeg rest space (glTF coords)."""

import bpy, sys, numpy as np

A = sys.argv[sys.argv.index("--") + 1 :]
G, OUT = A[:2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=G)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
ob = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
body = ob["head_graft"]
bow = [o for n, o in ob.items() if n.startswith("head_graft.001") or n == "Bow"][0]
print("mesh objs", list(ob))
gi = {g.index: g.name for g in body.vertex_groups}
hidx = np.array(
    [
        v.index
        for v in body.data.vertices
        if v.groups
        and (
            "Hand" in gi[max(v.groups, key=lambda g: g.weight).group]
            or "ForeArm" in gi[max(v.groups, key=lambda g: g.weight).group]
        )
    ]
)


def ev(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    me = e.to_mesh()
    n = len(me.vertices)
    co = np.empty(n * 3, np.float32)
    me.vertices.foreach_get("co", co)
    e.to_mesh_clear()
    M = np.array(o.matrix_world)
    co = co.reshape(-1, 3)
    return co @ M[:3, :3].T + M[:3, 3]


out = {"L": [], "R": []}
arm.animation_data_create()
for act in bpy.data.actions:
    arm.animation_data.action = act
    f0, f1 = map(int, act.frame_range)
    for f in range(f0, f1 + 1, 2):
        bpy.context.scene.frame_set(f)
        P = np.vstack([ev(body)[hidx], ev(bow)])
        for s, bn in (("L", "LeftUpLeg"), ("R", "RightUpLeg")):
            pb = arm.pose.bones[bn]
            Mp = np.array(arm.matrix_world @ pb.matrix)
            Mr = np.array(arm.matrix_world @ pb.bone.matrix_local)
            T = Mr @ np.linalg.inv(Mp)
            Q = P @ T[:3, :3].T + T[:3, 3]
            g = np.stack([Q[:, 0], Q[:, 2], -Q[:, 1]], 1)  # blender -> glTF
            out[s].append(g[(g[:, 1] > 0.70) & (g[:, 1] < 1.0)])
np.savez(OUT, L=np.vstack(out["L"]), R=np.vstack(out["R"]))
print("saved", {k: len(np.vstack(v)) for k, v in out.items()})
