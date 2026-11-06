"""ART-1 Cinder, stage B: the fitted scan and all pieces, flat coloured, four ortho views: a shape pass before the bake.
Run: blender -b --factory-startup --python tools/art1/cinder_assemble.py -- <source.blend> <out prefix>"""
import sys, os, math
import bpy
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cinder_pieces as K
a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
bpy.ops.wm.open_mainfile(filepath=SRC)
src = bpy.data.objects["Src"]
src.hide_render = True
low = bpy.data.objects["Low"]
print("Low bounds", [round(x, 3) for x in np.min([v.co[:] for v in low.data.vertices], 0)], [round(x, 3) for x in np.max([v.co[:] for v in low.data.vertices], 0)])


def all_pieces():
    tl = K.tail()
    fl = K.tail_flames(tl)
    hr, chains = K.hair()
    tk, tips = K.tank()
    v, spots = K.vials()
    ps = K.face_parts() + [K.mouth_back(), K.teeth(), K.skull()] + K.fangs() + K.goggles() + [K.fin(1.0), K.fin(-1.0)] + hr + [tl] + fl + tk + K.jet_flames(tips) + K.gun() + K.hoses() + v
    for s in (1.0, -1.0):
        ps.append(K.lids(s))
        ps += K.brows(s)
    ps += K.hand("R", K.GRIP_K, (1.3, 1.4, 0.9), 0.0)
    ps += K.hand("L", (0.0, 1.0, -0.15), (0.45, 0.6, 0.4), 0.05)
    return ps


pieces = all_pieces()
COL = {"skin-cinderhead-hot": (0.13, 0.12, 0.15, 1), "skin-cinder-hot": (0.13, 0.12, 0.15, 1), "flame-hair": (1, 0.45, 0.05, 1), "flame-jet": (1, 0.6, 0.1, 1), "flame-liquid": (1, 0.5, 0.0, 1), "metal-cinder": (0.5, 0.25, 0.12, 1), "leather-cinder": (0.16, 0.08, 0.05, 1)}
mats = {}
for k, c in COL.items():
    m = bpy.data.materials.new(k)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs[0].default_value = c
    if k.startswith("flame"):
        b.inputs["Emission Color"].default_value = c
        b.inputs["Emission Strength"].default_value = 0.8
    mats[k] = m
tot = {}
for p in pieces:
    me = bpy.data.meshes.new("P_" + p.name)
    me.from_pydata(p.v.tolist(), [], [list(f) for f in p.f])
    me.update()
    me.materials.append(mats[p.mat])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    ob = bpy.data.objects.new("P_" + p.name, me)
    bpy.context.scene.collection.objects.link(ob)
    tot[p.mat] = tot.get(p.mat, 0) + p.tris()
print(tot, "pieces", sum(tot.values()), "low", sum(len(q.vertices) - 2 for q in low.data.polygons))
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.device = "CPU"
sc.cycles.samples = 8
sc.render.resolution_x, sc.render.resolution_y = 520, 760
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.55, 0.57, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.4
sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.3
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
sc.collection.objects.link(sun)
sun.data.energy = 2.0
sun.rotation_euler = (0.9, 0.2, 0.3)
c = Vector((0.1, -0.2, 0.95))
for nm, d in (("front", (0, 5, 0)), ("side", (5, 0, 0)), ("back", (0, -5, 0)), ("top", (0.001, -1.2, 5))):
    cam.location = c + Vector(d)
    cam.rotation_euler = (-Vector(d)).to_track_quat("-Z", "Y" if nm != "top" else "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (OUT, nm)
    bpy.ops.render.render(write_still=True)
print("shapes done")
