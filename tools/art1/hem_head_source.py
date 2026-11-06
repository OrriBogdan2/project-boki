"""ART-1 Lisette, the head pass: the Meshy scan of the owner's head sheet (briefs/art-refs/hem_head.png, the needle edited out; face, hair, ponytail, tie, cowl in one mesh)
set on the neck and decimated, the face holding its detail. Out: objects HSrc (the set scan, the paint source) and HLow (what ships).
Run: blender -b --factory-startup --python tools/art1/hem_head_source.py -- <scan.glb> <out.blend>"""
import sys
import bpy
import bmesh
import numpy as np
from mathutils import Matrix
from mathutils.bvhtree import BVHTree

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, OUT = a[0], a[1]
K = 0.325                      # scan m -> model m: big enough to read at the match camera, as the sheet's proportions
EYE_S = (0.0, 0.41, 0.33)      # the eyes' middle on the scan (flipped to face +Y), read off grid_front / grid_right
EYE_T = (0.0, 0.093, 1.6065)   # where it goes
LOW_TRIS = 6600

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
src = [o for o in bpy.data.objects if o.type == "MESH"][0]
for o in list(bpy.data.objects):
    if o is not src:
        bpy.data.objects.remove(o)
src.parent = None
me = src.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
mw = np.array(src.matrix_world)
co = co @ mw[:3, :3].T + mw[:3, 3]
src.matrix_world = Matrix.Identity(4)
P = np.stack([-co[:, 0], -co[:, 1], co[:, 2]], 1)
Q = (P - np.array(EYE_S)) * K + np.array(EYE_T)
me.vertices.foreach_set("co", Q.ravel())
me.update()
print("set", Q.min(0).round(3), Q.max(0).round(3))
src.name = "HSrc"
low = src.copy()
low.data = src.data.copy()
low.name = "HLow"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.00015)
bm.to_mesh(low.data)
bm.free()
vs = np.zeros(len(low.data.vertices) * 3)
low.data.vertices.foreach_get("co", vs)
vs = vs.reshape(-1, 3)
# the face keeps its triangles: more where the eyes and mouth are
d = np.linalg.norm((vs - np.array((0, 0.09, 1.57))) * (1, 0.7, 0.8), axis=1)
w = np.clip(1.25 - d / 0.075, 0.02, 1) * (vs[:, 1] > 0.0) + 0.02
vg = low.vertex_groups.new(name="keep")
for i, wi in enumerate(w.tolist()):        # (every vertex: one left out of the group is held and nothing collapses)
    vg.add([i], wi, "REPLACE")
now = sum(len(p.vertices) - 2 for p in low.data.polygons)
m = low.modifiers.new("d", "DECIMATE")
m.ratio = min(1.0, LOW_TRIS / max(now, 1))
m.use_collapse_triangulate = True
m.vertex_group = "keep"
m.vertex_group_factor = 6.0
bpy.context.view_layer.objects.active = low
low.select_set(True)
bpy.ops.object.modifier_apply(modifier=m.name)
low.vertex_groups.clear()
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.triangulate(bm, faces=bm.faces)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
tree = BVHTree.FromPolygons([v.co.copy() for v in bm.verts], [[v.index for v in f.verts] for f in bm.faces], all_triangles=True)
flip = []
for f in bm.faces:
    nn = f.normal
    o = f.calc_center_median() + nn * 2e-4
    hits = 0
    for _ in range(16):
        h = tree.ray_cast(o, nn)
        if h[0] is None:
            break
        hits += 1
        o = h[0] + nn * 2e-4
    if hits % 2:
        flip.append(f)
print("faces turned out", len(flip), "of", len(bm.faces))
bmesh.ops.reverse_faces(bm, faces=flip)
bm.to_mesh(low.data)
bm.free()
print("HLow tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
