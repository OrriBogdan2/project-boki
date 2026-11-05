"""Pip's head from the Meshy scan of briefs/art-refs/pip_head.png (front, side, back; 40 credits): fitted on the rig, cut at the neck, decimated, baked
to its own 2048 texture (colour and normal, selected to active). Ears, goggles, band, flowers and the bandage are the scan's.
Run: blender -b --factory-startup --python tools/art1/pip_head_scan.py -- <scan.glb> <WORK> [tris]
Out: WORK/head_scan.pkl (verts, faces, per-corner uv), WORK/face.jpg, face_normal.jpg, face_emit.jpg"""
import math
import os
import pickle
import sys

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "meshy"))
import imgio
import pip_sculpt as K
from meshkit import smooth

a = sys.argv[sys.argv.index("--") + 1:]
SCAN, WORK = a[0], a[1]
TRIS = int(a[2]) if len(a) > 2 else 6000
SIZE = 2048
HEAD_W = 0.524               # m, cheek tuft to cheek tuft (pip_head.png scale)
NOSE_Y = 0.255               # the nose tip's y from HC
CUT = -0.215                 # the neck is cut here, from HC, under the collar leaves
F = np.float32

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SCAN)
hi = next(o for o in bpy.data.objects if o.type == "MESH")
mw = hi.matrix_world.copy()
hi.parent = None
hi.matrix_world = mw
bpy.context.view_layer.objects.active = hi
hi.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
me = hi.data
n = len(me.vertices)
co = np.zeros(n * 3)
me.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
P = co * (-1, -1, 1)                                     # to +Y facing, her right on +X
i_nose = int(np.argmax(P[:, 1]))
k = HEAD_W / float(P[:, 0].max() - P[:, 0].min())
P = (P - P[i_nose]) * k + K.HC + (0, NOSE_Y, K.NOSE[2])
P[:, 0] -= (P[:, 0].max() + P[:, 0].min()) / 2 - 0.0
print("scan", n, "k", round(k, 4), P.min(0).round(3), P.max(0).round(3))
me.vertices.foreach_set("co", P.ravel())
me.update()

low = hi.copy()
low.data = me.copy()
low.name = "HeadLow"
bpy.context.scene.collection.objects.link(low)
bm = bmesh.new()
bm.from_mesh(low.data)
bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0002)
zc = K.HC[2] + CUT
bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.calc_center_median().z < zc], context="FACES")
bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
bm.to_mesh(low.data)
bm.free()
vv = np.zeros(len(low.data.vertices) * 3)
low.data.vertices.foreach_get("co", vv)
vv = vv.reshape(-1, 3)
q = vv - K.HC
# the face and the goggles keep more triangles than the back of the skull
wf = np.clip(0.15 + 0.85 * smooth(-0.02, 0.1, q[:, 1]) * smooth(-0.19, -0.12, q[:, 2]), 0, 1)
g = low.vertex_groups.new(name="keep")
for i in np.nonzero(wf > 0.02)[0].tolist():
    g.add([i], float(wf[i]), "REPLACE")
d = low.modifiers.new("d", "DECIMATE")
d.decimate_type = "COLLAPSE"
d.vertex_group = "keep"
d.vertex_group_factor = 6.0
d.ratio = min(1.0, TRIS / max(sum(len(p.vertices) - 2 for p in low.data.polygons), 1))
d.use_collapse_triangulate = True
bpy.ops.object.select_all(action="DESELECT")
low.select_set(True)
bpy.context.view_layer.objects.active = low
bpy.ops.object.modifier_apply(modifier="d")
print("low tris", sum(len(p.vertices) - 2 for p in low.data.polygons))
low.vertex_groups.clear()
while low.data.uv_layers:
    low.data.uv_layers.remove(low.data.uv_layers[0])
low.data.uv_layers.new(name="UVMap")
low.data.materials.clear()
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.uv.smart_project(angle_limit=math.radians(66), island_margin=0.004, scale_to_bounds=True)
bpy.ops.uv.pack_islands(rotate=True, scale=True, margin=0.004, shape_method="CONCAVE")
bpy.ops.object.mode_set(mode="OBJECT")
low.data.polygons.foreach_set("use_smooth", [True] * len(low.data.polygons))
low.data.update()

sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 4
sc.render.threads_mode = "FIXED"
sc.render.threads = 8
sc.render.bake.use_selected_to_active = True
sc.render.bake.cage_extrusion = 0.012
sc.render.bake.max_ray_distance = 0.03
sc.render.bake.margin = 16
mt = bpy.data.materials.new("bake")
mt.use_nodes = True
low.data.materials.append(mt)
node = mt.node_tree.nodes.new("ShaderNodeTexImage")
mt.node_tree.nodes.active = node


def bake(name, kind, **kw):
    im = bpy.data.images.new(name, SIZE, SIZE, float_buffer=True)
    if kind == "NORMAL":
        im.colorspace_settings.name = "Non-Color"
    node.image = im
    bpy.ops.object.select_all(action="DESELECT")
    hi.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.bake(type=kind, **kw)
    px = np.zeros((SIZE, SIZE, 4), F)
    im.pixels.foreach_get(px.ravel())
    return px[..., :3]


col = bake("c", "DIFFUSE", pass_filter={"COLOR"})
print("colour baked", col.mean(0).mean(0))
nor = bake("n", "NORMAL", normal_space="TANGENT")
# (float buffers are linear: to display values for the jpg)
srgb = np.where(col <= 0.0031308, col * 12.92, 1.055 * np.maximum(col, 1e-5) ** (1 / 2.4) - 0.055)
srgb = np.clip(srgb, 0, 1)
gold = smooth(0.2, 0.34, np.minimum(srgb[..., 0], srgb[..., 1]) - srgb[..., 2]) * smooth(0.82, 0.94, srgb[..., 0])
emit = np.stack([gold, gold * 0.85, gold * 0.54], 2)
imgio.save(srgb[::-1], os.path.join(WORK, "face.jpg"))
imgio.save(np.clip(nor, 0, 1)[::-1], os.path.join(WORK, "face_normal.jpg"))
imgio.save(emit[::-1], os.path.join(WORK, "face_emit.jpg"))
lm = low.data
v = np.zeros(len(lm.vertices) * 3)
lm.vertices.foreach_get("co", v)
uv = np.zeros(len(lm.loops) * 2)
lm.uv_layers[0].data.foreach_get("uv", uv)
uv = uv.reshape(-1, 2)
faces = [list(p.vertices) for p in lm.polygons]
fuv = [[tuple(uv[i]) for i in p.loop_indices] for p in lm.polygons]
pickle.dump((v.reshape(-1, 3), faces, fuv), open(os.path.join(WORK, "head_scan.pkl"), "wb"))
print("HEAD_DONE", len(faces))
