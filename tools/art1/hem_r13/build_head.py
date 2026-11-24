# r13 build stage (prepended to rig11's rig stage by make_rig13.py): live glb + Meshy skirt A -> welded, decimated, fitted, skinned-ready 'Skirt'
import bpy, bmesh, sys, math, numpy as np  # noqa: F401,E401 (math/np are used by the rig stage appended by make_rig13.py)
from mathutils import Vector, Quaternion, kdtree  # noqa: F401

A = sys.argv[sys.argv.index("--") + 1 :]
SRC, OUT = A[0], A[1]
O = dict(a.split("=") for a in A[2:])
F = lambda k, d: float(O.get(k, d))
MODE = O.get("mode", "A")
SKG = O.get("sk", "/home/boki/gens/hunter-round-1124/lace/r13/m/A/glb.glb")
SKT = O.get("sktex", "/home/boki/gens/hunter-round-1124/lace/r13/m/A/tex2k.jpg")
ZTOP, ZHEM, WW, WD, CX, CY, KW, TRIS = (
    F("ztop", 1.03),
    F("zhem", 0.16),
    F("ww", 0.42),
    F("wd", 0.32),
    F("cx", -0.04),
    F("cy", -0.019),
    F("kw", 0.35),
    int(F("tris", 24000)),
)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
body = bpy.data.objects["head_graft"]
old = bpy.data.objects["Skirt"]
pinv = old.matrix_parent_inverse.copy()
oldm = [m for m in old.data.materials]
oldme = old.data
bpy.data.objects.remove(old, do_unlink=True)
bpy.data.meshes.remove(oldme)
for m in oldm:
    if m:
        bpy.data.materials.remove(m)
before = set(bpy.data.objects.keys())
bpy.ops.import_scene.gltf(filepath=SKG)
new = [o for o in bpy.data.objects if o.name not in before and o.type == "MESH"][0]
for o in [o for o in bpy.data.objects if o.name not in before and o is not new]:
    bpy.data.objects.remove(o, do_unlink=True)
new.parent = None
new.matrix_world.identity()
new.name = "Skirt"
new.data.name = "Mesh_0"
bpy.context.view_layer.objects.active = new
sme = new.data
bm = bmesh.new()
bm.from_mesh(sme)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
bm.to_mesh(sme)
bm.free()
print("welded tris", len(sme.polygons))
md = new.modifiers.new("d", "DECIMATE")
md.ratio = min(1.0, TRIS / len(sme.polygons))
md.use_collapse_triangulate = True
bpy.ops.object.modifier_apply(modifier="d")
sme = new.data
P = np.array([v.co[:] for v in sme.vertices])
lo, hi = P.min(0), P.max(0)
band = P[P[:, 2] > hi[2] - 0.02]
cxs = (band[:, 0].max() + band[:, 0].min()) / 2
cys = (band[:, 1].max() + band[:, 1].min()) / 2
sw = np.ptp(band[:, 0])
sd = np.ptp(band[:, 1])
sx, sy, sz = WW / sw, WD / sd * F("syk", 1.0), (ZTOP - ZHEM) / (hi[2] - lo[2])
zb = np.linspace(lo[2], hi[2], 60)
hx = np.zeros(len(zb))
for j, z in enumerate(zb):
    m = np.abs(P[:, 2] - z) < 0.03
    hx[j] = np.percentile(np.abs(P[m, 0] - cxs), 95) if m.sum() > 20 else (hx[j - 1] if j else 0.2)
hx = np.maximum.accumulate(hx[::-1])[::-1]
r = hx / hx[-1]
fz = (1 + (r - 1) * KW) / r
print(
    "waist w/d %.3f %.3f scale sx %.3f sy %.3f sz %.3f; profile r(top..hem)" % (sw, sd, sx, sy, sz),
    np.round(r[::-1][::10], 2),
)
for v in sme.vertices:
    c = v.co
    f = float(np.interp(c.z, zb, fz))
    zn = ZTOP + (c.z - hi[2]) * sz
    dy = (c.y - cys) * sy * f
    if dy > 0:
        dy *= 1 + (F("bk", 1.0) - 1) * float(np.clip((ZTOP - 0.02 - zn) / 0.12, 0, 1)) ** 2 * (
            3 - 2 * float(np.clip((ZTOP - 0.02 - zn) / 0.12, 0, 1))
        )  # back-only depth (bustle)
    v.co = Vector((CX + (c.x - cxs) * sx * f, CY + dy, zn))
sme.update()
bm = bmesh.new()
bm.from_mesh(sme)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.to_mesh(sme)
bm.free()
mat = bpy.data.materials.new("skirt-meshy")
mat.use_nodes = True
mat.use_backface_culling = False
bsdf = mat.node_tree.nodes["Principled BSDF"]
ti = mat.node_tree.nodes.new("ShaderNodeTexImage")
ti.image = bpy.data.images.load(SKT)
ti.image.pack()
mat.node_tree.links.new(ti.outputs["Color"], bsdf.inputs["Base Color"])
bsdf.inputs["Roughness"].default_value = 0.9
bsdf.inputs["Metallic"].default_value = 0.0
sme.materials.clear()
sme.materials.append(mat)
new.parent = arm
md = new.modifiers.new("Armature", "ARMATURE")
md.object = arm
new.matrix_parent_inverse = pinv
sk = new
print("skirt verts", len(sme.vertices), "tris", sum(len(p.vertices) - 2 for p in sme.polygons))
