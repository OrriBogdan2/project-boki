"""ART-1 Kael, stage A: the fitted scan body (a3) -> narrower shoulders, no head / neck / hands, skirt split off,
decimated. In: the a3 kael.glb (~/boki-3d-kael). Out: stage/source.blend with objects Src (the whole warped scan, the
paint source), Low (the torso and legs to ship), Skirt.
Run: blender -b --factory-startup --python tools/art1/kael_source.py -- <a3.glb> <out.blend>"""
import sys, os
import bpy, bmesh
import numpy as np
sys.path.insert(0, os.path.dirname(__file__))
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
SHIFT = 0.2608 * 0.10           # the arms move in by this much (archetype body.chest 0.9)
LOW_TRIS, SKIRT_TRIS = 7000, 1400

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
for o in list(bpy.data.objects):
    if o.name != "Body" and o.type == "MESH":
        bpy.data.objects.remove(o)
body = bpy.data.objects["Body"]
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body.parent = None
body.modifiers.clear()
bpy.context.view_layer.objects.active = body
for o in list(bpy.data.objects):
    if o is not body:
        bpy.data.objects.remove(o)
me = body.data
n = len(me.vertices)
gid = {g.index: g.name for g in body.vertex_groups}
W = {g.name: np.zeros(n) for g in body.vertex_groups}
for v in me.vertices:
    for g in v.groups:
        W[gid[g.group]][v.index] = g.weight
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
x, y, z = co.T
arm_w = sum(W[b] for b in ["upper_arm.L", "upper_arm.R", "forearm.L", "forearm.R", "hand.L", "hand.R"])
arm_w = arm_w + sum(W.get(b, 0 * x) for b in ["pauldron.L", "pauldron.R"])
arm_w = np.clip(arm_w * 1.2, 0, 1)
# the shoulder girdle slides in with the arms, the waist stays
torso_k = smooth(0.10, 0.23, np.abs(x)) * smooth(0.86, 1.0, z)
k = np.maximum(arm_w, torso_k)
co[:, 0] -= np.sign(x) * SHIFT * k
# the deltoids a little leaner
cx = np.sign(x) * (0.2608 - SHIFT)
d = (co[:, 0] - cx)
slim = 1.0 - 0.1 * k * smooth(0.95, 1.08, z)
co[:, 0] = cx + d * slim
me.vertices.foreach_set("co", co.ravel())
me.update()

src = body
src.name = "Src"
low = src.copy()
low.data = src.data.copy()
low.name = "Low"
bpy.context.scene.collection.objects.link(low)
mname = [m.name for m in low.data.materials]
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
dl = bm.verts.layers.deform.verify()
hid = [next(i for i, g in gid.items() if g == s) for s in ("hand.L", "hand.R")]
kill, skirt = [], []
for f in bm.faces:
    c = f.calc_center_median()
    hw = max(sum(v[dl].get(h, 0.0) for h in hid) for v in f.verts)
    if c.z > 1.26 or hw > 0.5:
        kill.append(f)
    elif "cloth" in mname[f.material_index] and c.z < 0.77:
        skirt.append(f)
bmesh.ops.delete(bm, geom=kill, context="FACES")
bm.to_mesh(low.data)
bm.free()
# the skirt on its own
bpy.context.view_layer.objects.active = low
sk = low.copy()
sk.data = low.data.copy()
sk.name = "Skirt"
bpy.context.scene.collection.objects.link(sk)
for ob, keep in ((low, False), (sk, True)):
    bm = bmesh.new()
    bm.from_mesh(ob.data)
    bm.faces.ensure_lookup_table()
    drop = [f for f in bm.faces if (("cloth" in mname[f.material_index] and f.calc_center_median().z < 0.77) != keep)]
    bmesh.ops.delete(bm, geom=drop, context="FACES")
    bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
    bm.to_mesh(ob.data)
    bm.free()


def decimate(ob, tris):
    now = sum(len(p.vertices) - 2 for p in ob.data.polygons)
    m = ob.modifiers.new("d", "DECIMATE")
    m.ratio = min(1.0, tris / max(now, 1))
    m.use_collapse_triangulate = True
    bpy.ops.object.select_all(action="DESELECT")
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.modifier_apply(modifier=m.name)


decimate(low, LOW_TRIS)
decimate(sk, SKIRT_TRIS)
for o in (low, sk):
    print(o.name, "tris", sum(len(p.vertices) - 2 for p in o.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
