"""ART-1 Claire: a look at a stage's .blend: four shaded ortho views of any objects. blender -b --factory-startup --python claire_shapes.py -- <blend> <out prefix> [hide,objs] [scale]"""
import sys, bpy
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
bpy.ops.wm.open_mainfile(filepath=a[0])
for n in (a[2].split(",") if len(a) > 2 and a[2] else []):
    if n in bpy.data.objects:
        bpy.data.objects[n].hide_render = True
import os
for im_ in bpy.data.images:
    if im_.name.startswith("claire_atlas"):
        im_.filepath = os.path.join(os.path.dirname(a[0]), "atlas.png"); im_.reload()
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = 6
sc.render.resolution_x, sc.render.resolution_y = 480, 760
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.5, 0.52, 0.56, 1); w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sc.world = w
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = float(a[3]) if len(a) > 3 else 2.2
sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun); sun.data.energy = 2.0; sun.rotation_euler = (0.9, 0.2, 0.3)
c = Vector((0, 0, float(a[4]) if len(a) > 4 else 0.95))
for nm, d in (("front", (0, 5, 0)), ("side", (5, 0, 0)), ("back", (0, -5, 0)), ("top", (0.001, -2.2, 5))):
    cam.location = c + Vector(d)
    cam.rotation_euler = (-Vector(d)).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (a[1], nm)
    bpy.ops.render.render(write_still=True)
