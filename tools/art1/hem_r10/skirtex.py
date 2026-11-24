"""skirtex.py IN.glb OUT.glb TEX.png [inner=median|r,g,b] : (1) skirt-meshy -> TEX (a Meshy retexture of the same gen with
enable_original_uv, so the UVs match); (2) the skirt is face + reversed-twin pairs (r8 two_sided: first half / second
half); the inward-facing face of each pair and the liner get a solid inner colour (default: median of TEX under the
outward faces), because Meshy painted the gen's legs on the skirt's inner UVs (pink/white inside the slit).
Texture/material assignment only, geometry untouched."""

import bpy, sys, numpy as np
from mathutils import Vector

A = sys.argv[sys.argv.index("--") + 1 :]
IN, OUT, TEX = A[:3]
O = dict(a.split("=") for a in A[3:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=IN)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
sk = bpy.data.objects["Skirt"]
me = sk.data
M = sk.matrix_world
h = M @ arm.data.bones["Hips"].head_local
img = bpy.data.images.load(TEX)
img.scale(2048, 2048)
img.name = "r10_skirt"
W, H = img.size
px = np.empty(W * H * 4, np.float32)
img.pixels.foreach_get(px)
px = px.reshape(H, W, 4)
ms = [m.name for m in me.materials]
mi = {n: i for i, n in enumerate(ms)}
fs = [p for p in me.polygons if ms[p.material_index] == "skirt-meshy"]
n = len(fs) // 2


def outw(p):
    c = M @ p.center
    return (M.to_3x3() @ p.normal).dot(Vector((c.x - h.x, c.y - h.y, 0)))


uvl = me.uv_layers.active.data
inner = []
cols = []
for a, b in zip(fs[:n], fs[n:]):
    o, i = (a, b) if outw(a) >= outw(b) else (b, a)
    inner.append(i)
    u, v = uvl[o.loop_start].uv
    cols.append(px[min(int(v * H), H - 1), min(int(u * W), W - 1), :3])
for p in inner:
    p.material_index = mi["skirt-liner"]
if O.get("inner", "median") == "median":
    c = np.median(np.array(cols), 0)
else:
    c = np.array([float(x) for x in O["inner"].split(",")])
print("inner faces", len(inner), "colour (linear)", c.round(3))
sol = bpy.data.images.new("r10_skirt_inner", 16, 16)
sol.pixels.foreach_set(np.tile(np.r_[c, 1.0], 256).astype(np.float32))
for m in bpy.data.materials:
    if m.name.startswith("skirt-") and m.use_nodes:
        for nd in m.node_tree.nodes:
            if nd.type == "TEX_IMAGE":
                nd.image = sol if m.name == "skirt-liner" else img
                print("tex ->", m.name, nd.image.name)
bpy.ops.export_scene.gltf(
    filepath=OUT,
    export_format="GLB",
    export_animation_mode="ACTIONS",
    export_apply=False,
    export_skins=True,
    export_morph=False,
    export_image_format="JPEG",
)
