"""A flat front render of a Meshy-frame glb's face (camera on -Y looking +Y: image right = +X = her left) at a
known mapping: col = W/2 + (x - cx) * ppm, row = H/2 - (z - cz) * ppm. Saves OUT.png (plain) and OUT_grid.png
(grid every 5 mm, red every 25 mm through the centre).
  blender -b --factory-startup --python tools/meshy/face_grid.py -- GLB OUT cx cz size_m [px]"""
import sys, math
import bpy
import numpy as np
a = sys.argv[sys.argv.index("--") + 1:]
glb, out, cx, cz, size = a[0], a[1], float(a[2]), float(a[3]), float(a[4])
px = int(a[5]) if len(a) > 5 else 1000
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
sc.render.engine = "CYCLES"; sc.cycles.samples = 8; sc.cycles.device = "CPU"
sc.render.resolution_x = sc.render.resolution_y = px
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.75, 0.75, 0.75, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = size; cam.data.clip_end = 50
cam.location = (cx, -5.0, cz); cam.rotation_euler = (math.pi / 2, 0, 0)
sc.render.filepath = out + ".png"
bpy.ops.render.render(write_still=True)
img = bpy.data.images.load(out + ".png")
w, h = img.size
p = np.array(img.pixels[:], np.float32).reshape(h, w, 4)
ppm = px / size
for i in range(-60, 61):
    c = int(round(px / 2 + i * 0.005 * ppm))
    if 0 <= c < px:
        col = np.array((0.9, 0.1, 0.1, 1)) if i % 5 == 0 else np.array((0.15, 0.6, 0.15, 1))
        k = 0.5 if i % 5 == 0 else 0.3
        p[:, c] = p[:, c] * (1 - k) + col * k
        p[c, :] = p[c, :] * (1 - k) + col * k
img.pixels = p.ravel(); img.filepath_raw = out + "_grid.png"; img.save()
print("FACEVIEW ppm %.1f, centre (%.4f, %.4f)" % (ppm, cx, cz))
