"""v95 swap, step 1 (docs/art/wardens/V95_SWAP.md): gridded flat renders to read a master's joints from, in the fit frame
(his front +Y, his right +X, soles on z 0; a Meshy master is turned 180 degrees and lifted by its sole). 1000 px = 2 m, the
grid every 0.05 m (red every 0.25 m), z 0 at row 975. front: from +Y (image left = his right, col 500 = x 0); side: from his
right (image right = his front, col 500 = y 0). A game .glb (`--rest`) renders in its rest pose, unturned.
Run: blender -b --factory-startup --python tools/art1/v95_grid.py -- GLB OUT_PREFIX [--rest]"""
import sys

import bpy
import numpy as np
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
glb, out, rest = a[0], a[1], "--rest" in a
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.data.objects if o.type == "MESH"]
for m in bpy.data.materials:            # (Workbench shows the active image node: the base colour, not Meshy's emission map)
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m.node_tree else None
    if bsdf and bsdf.inputs["Base Color"].links:
        m.node_tree.nodes.active = bsdf.inputs["Base Color"].links[0].from_node
if rest:
    for o in bpy.data.objects:
        if o.type == "ARMATURE":
            o.data.pose_position = "REST"
else:
    sole = min((o.matrix_world @ Vector(c)).z for o in meshes for c in o.bound_box)
    for o in bpy.data.objects:
        if o.parent is None:
            o.matrix_world.translation.z -= sole
            o.rotation_mode = "XYZ"
            o.rotation_euler.z += np.pi
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "FLAT"
sc.display.shading.color_type = "TEXTURE"
sc.render.resolution_x = sc.render.resolution_y = 1000
sc.view_settings.view_transform = "Standard"
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.0
for name, loc in (("front", (0, 5, 0.95)), ("side", (5, 0, 0.95))):
    cam.location = loc
    cam.rotation_euler = (Vector((0, 0, 0.95)) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()
    path = "%s_%s.png" % (out, name)
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)
    img = bpy.data.images.load(path)
    px = np.array(img.pixels[:], np.float32).reshape(1000, 1000, 4)
    for i in range(-20, 21):
        c = 500 + i * 25
        col = np.array((0.9, 0.1, 0.1, 1) if i % 5 == 0 else (0.1, 0.6, 0.1, 1))
        if c < 1000:
            px[:, c] = px[:, c] * 0.6 + col * 0.4
        r = 25 + i * 25          # (pixel rows count from the bottom: z = i * 0.05 m above the sole)
        if 0 <= r < 1000:
            px[r, :] = px[r, :] * 0.6 + col * 0.4
    img.pixels = px.ravel()
    img.save()
print("GRID done")
