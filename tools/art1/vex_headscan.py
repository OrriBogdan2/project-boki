"""ART-1 Vex, stage A2 (fine-detail pass): the Meshy scan of the owner's head sheet -> her head on the rig: placed by its eye line and chin, the scan's braid cut (the braid
is the rebuilt spring chain), weighted (head above the jaw, chest for the neck collar), a denser budget on the face. Added to source.blend as HeadSrc (the paint source) and HeadLow.
Run: blender -b --python tools/art1/vex_headscan.py -- <source.blend> <head scan.glb> <out.blend>"""
import sys, os
import bpy, bmesh
import numpy as np
from mathutils import Matrix
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from meshkit import smooth
import vex_head as VH

a = sys.argv[sys.argv.index("--") + 1:]
SRC, SCAN, OUT = a[0], a[1], a[2]
HEAD_TRIS = 3900
# the head scan, its own metres (flipped to face +Y, her right +X), read on grid_h_front / grid_h_right
EYE_Z, CHIN_Z, NAPE_Y, NAPE_Z = float(os.environ.get("H_EYE", 1.25)), float(os.environ.get("H_CHIN", 0.88)), float(os.environ.get("H_NAPE_Y", -0.2)), float(os.environ.get("H_NAPE_Z", 0.75))
FACE_Y = float(os.environ.get("H_FACE_Y", 0.3))        # the nose bridge's y
AXIS_X = float(os.environ.get("H_AXIS_X", 0.0))
T_EYE, T_CHIN = VH.EYE_Z, VH.GRID_CHIN + 0.003
bpy.ops.wm.open_mainfile(filepath=SRC)
bpy.ops.import_scene.gltf(filepath=SCAN)
ms = [o for o in bpy.context.selected_objects if o.type == "MESH"]
src = ms[0]
for o in list(bpy.context.selected_objects):
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
print("head scan", n, P.min(0).round(3), P.max(0).round(3))
s = (T_EYE - T_CHIN) / (EYE_Z - CHIN_Z)
Q = (P - [AXIS_X, FACE_Y, EYE_Z]) * s + [0, VH.EYE_FRONT_Y[0], T_EYE]
print("placed", Q.min(0).round(3), Q.max(0).round(3), "scale", round(s, 4))
me.vertices.foreach_set("co", Q.ravel())
me.update()
src.name = "HeadSrc"
# weights: the collar on the chest, the head and all its hair on the head
jaw_z = T_CHIN - 0.012
neck = (np.abs(Q[:, 0]) < 0.16) & (Q[:, 1] > -0.14)
green = None
w_hips = (1 - smooth(jaw_z - 0.05, jaw_z + 0.01, Q[:, 2]))
g_h = src.vertex_groups.new(name="head")
g_c = src.vertex_groups.new(name="hips")
low = src.copy()
low.data = src.data.copy()
low.name = "HeadLow"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new()
bm.from_mesh(low.data)
bm.faces.ensure_lookup_table()
bm.verts.ensure_lookup_table()
# the scan's braid goes: everything behind the neck, below the nape
kz, ky = T_EYE + (NAPE_Z - EYE_Z) * s, VH.EYE_FRONT_Y[0] + (NAPE_Y - FACE_Y) * s
kill = [f for f in bm.faces if Q[f.verts[0].index, 2] < kz and Q[f.verts[0].index, 1] < ky and abs(Q[f.verts[0].index, 0]) < 0.075]
bmesh.ops.delete(bm, geom=kill, context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0004)
bm.to_mesh(low.data)
bm.free()
low.data.update()
m_ = len(low.data.vertices)
lc = np.zeros(m_ * 3)
low.data.vertices.foreach_get("co", lc)
lc = lc.reshape(-1, 3)
# a denser budget on the face
gf = low.vertex_groups.new(name="dense")
d = np.sqrt(((lc - [0, VH.EYE_FRONT_Y[0], T_EYE - 0.03]) / [0.12, 0.13, 0.11]) ** 2).sum(1)
gf.add(np.nonzero(d < 1.8)[0].tolist(), 1.0, "REPLACE")
now = sum(len(p.vertices) - 2 for p in low.data.polygons)
md = low.modifiers.new("d", "DECIMATE")
md.ratio = min(1.0, HEAD_TRIS / max(now, 1))
md.use_collapse_triangulate = True
md.vertex_group = "dense"
md.invert_vertex_group = True
md.vertex_group_factor = 3.0
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier=md.name)
low.vertex_groups.remove(low.vertex_groups["dense"])
m_ = len(low.data.vertices)
lc = np.zeros(m_ * 3)
low.data.vertices.foreach_get("co", lc)
lc = lc.reshape(-1, 3)
gh, gc = low.vertex_groups["head"], low.vertex_groups["hips"]
wh = 1 - smooth(jaw_z - 0.045, jaw_z + 0.015, lc[:, 2])
# (only the collar: hair strands that fall past the jaw stay on the head)
collar = (np.abs(lc[:, 0]) < 0.17) & (lc[:, 1] > ky - 0.03) & (lc[:, 1] < VH.EYE_FRONT_Y[0] - 0.02)
for i in range(m_):
    c = float(wh[i]) if collar[i] else 0.0
    if c > 0.005:
        gc.add([i], c, "REPLACE")
    if c < 0.995:
        gh.add([i], 1 - c, "REPLACE")
print("HeadLow tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
