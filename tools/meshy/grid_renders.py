"""Gridded orthographic flat renders of a Meshy glb (Meshy frame: +Z up, facing -Y): 1000 px = 2 m, centred on the
origin; grid every 0.05 m (darker every 0.25 m). front: from -Y (image right = +X); right: from -X (image right =
-Y... see label)."""
import sys, math
import bpy
import numpy as np
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
for ob in bpy.context.scene.objects:
    if ob.type != "MESH": continue
    for m in ob.data.materials:
        nt = m.node_tree
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
        em = nt.nodes.new("ShaderNodeEmission")
        if tex: nt.links.new(tex.outputs[0], em.inputs[0])
        nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs[0])
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
sc.render.resolution_x = sc.render.resolution_y = 1000
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.75, 0.75, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = 2.0
for name, loc in (("front", (0, -5, 0)), ("right", (-5, 0, 0))):
    cam.location = loc
    cam.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat("-Z", "Z").to_euler()
    path = "%s_%s.png" % (out, name)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
    for i in range(-20, 21):
        c = int(round(500 + i * 25))
        if 0 <= c < w:
            col = (0.9, 0.1, 0.1, 1) if i % 5 == 0 else (0.1, 0.6, 0.1, 1)
            px[:, c] = px[:, c] * 0.5 + np.array(col) * 0.5
            px[c, :] = px[c, :] * 0.5 + np.array(col) * 0.5
    img.pixels = px.ravel(); img.save()
print("GRID done")
