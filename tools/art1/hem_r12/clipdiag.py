"""clipdiag.py GLB [NF] : like clipcheck11 but prints, per clip, hits by bone, z band, sector (8 x 45deg, k0=+X CCW) and depth."""

import bpy, sys, math, numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree

A = sys.argv[sys.argv.index("--") + 1 :]
G = A[0]
NF = int(A[1]) if len(A) > 1 else 8
CX, CY = -0.027, -0.042
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=G)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
ob = {o.name: o for o in bpy.data.objects if o.type == "MESH"}
body = ob["head_graft"]
sk = ob["Skirt"]
SEG = {
    "LeftUpLeg": "LeftLeg",
    "LeftLeg": "LeftFoot",
    "LeftFoot": "LeftToeBase",
    "RightUpLeg": "RightLeg",
    "RightLeg": "RightFoot",
    "RightFoot": "RightToeBase",
}
gi = {g.index: g.name for g in body.vertex_groups}
own = {}
for v in body.data.vertices:
    b = max(v.groups, key=lambda g: g.weight, default=None)
    if b and gi[b.group] in SEG:
        own[v.index] = gi[b.group]
idx = np.array(sorted(own))
bones = [own[i] for i in idx]


def ev(o):
    dg = bpy.context.evaluated_depsgraph_get()
    e = o.evaluated_get(dg)
    me = e.to_mesh()
    P = np.array([e.matrix_world @ v.co for v in me.vertices])
    F = [tuple(p.vertices) for p in me.polygons]
    e.to_mesh_clear()
    return P, F


for act in bpy.data.actions:
    arm.animation_data_create()
    arm.animation_data.action = act
    f0, f1 = act.frame_range
    for f in np.linspace(f0, f1, NF):
        fi = int(round(f))
        bpy.context.scene.frame_set(fi)
        bpy.context.view_layer.update()
        SP, SF = ev(sk)
        tree = BVHTree.FromPolygons([Vector(p) for p in SP], SF)
        BP, _ = ev(body)
        z0, z1 = SP[:, 2].min(), SP[:, 2].max()
        S = {
            b: (
                np.array(arm.matrix_world @ arm.pose.bones[b].head),
                np.array(arm.matrix_world @ arm.pose.bones[b].tail),
            )
            for b in SEG
        }
        hits = []
        for i, b in zip(idx, bones):
            p = BP[i]
            if not (z0 < p[2] < z1 - 0.05):
                continue
            a, c = S[b]
            d = c - a
            t = np.clip(np.dot(p - a, d) / max(np.dot(d, d), 1e-9), 0, 1)
            q = a + t * d
            r = p - q
            L = np.linalg.norm(r)
            if L < 1e-4:
                continue
            h = tree.ray_cast(Vector(q), Vector(r / L), L - 0.002)
            if h[0] is not None:
                hits.append((b, p[2], math.degrees(math.atan2(p[1] - CY, p[0] - CX)), L - h[3]))
        if hits:
            from collections import Counter

            bz = Counter(round(h[1], 1) for h in hits)
            sc = Counter(int(((h[2] + 22.5) % 360) // 45) for h in hits)
            bc = Counter(h[0] for h in hits)
            dp = np.array([h[3] for h in hits])
            print(
                "%-10s f%3d n%4d depth med %.3f p90 %.3f | z %s | sec %s | %s"
                % (
                    act.name[:10],
                    fi,
                    len(hits),
                    np.median(dp),
                    np.percentile(dp, 90),
                    dict(sorted(bz.items())),
                    dict(sorted(sc.items())),
                    dict(bc),
                )
            )
