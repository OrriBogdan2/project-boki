"""Renders a fitted Warden glb with each toon slot in a flat colour (and, side by side, the flat texture):
  blender -b --factory-startup --python tools/meshy/slot_map.py -- GLB OUT_PREFIX centre_z scale [views]"""
import sys, math
import bpy
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
glb, out, cz, scale = a[0], a[1], float(a[2]), float(a[3])
views = (a[4] if len(a) > 4 else "front,tq").split(",")
COL = {"skin": (0.95, 0.75, 0.6), "hair": (0.2, 0.8, 0.3), "cloth": (0.25, 0.35, 0.9), "metal": (0.6, 0.6, 0.6),
       "leather": (0.55, 0.3, 0.15), "glow": (1.0, 1.0, 0.0), "eyes": (1.0, 0.0, 1.0)}
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
for ob in bpy.context.scene.objects:
    if ob.type != "MESH": continue
    for m in ob.data.materials:
        nt = m.node_tree
        for n in list(nt.nodes):
            if n.type not in ("OUTPUT_MATERIAL",):
                nt.nodes.remove(n)
        em = nt.nodes.new("ShaderNodeEmission")
        em.inputs[0].default_value = (*COL.get(m.name.split("-")[0], (1, 0, 0)), 1)
        nt.links.new(em.outputs[0], next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL").inputs[0])
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.samples = 4; sc.cycles.device = "CPU"
sc.render.resolution_x = sc.render.resolution_y = 800
sc.view_settings.view_transform = "Standard"
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
sc.world.node_tree.nodes["Background"].inputs[0].default_value = (0.1, 0.1, 0.1, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = scale
centre = Vector((0, 0, cz))
for v in views:
    az = {"front": 0.0, "tq": 35.0, "tqR": -35.0, "back": 180.0, "side": 90.0}[v]
    r = math.radians(az)
    # the fitted model faces +Y; az > 0 toward her left (-X)
    cam.location = centre + Vector((-math.sin(r) * 3, math.cos(r) * 3, 0))
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (out, v)
    bpy.ops.render.render(write_still=True)
print("SLOTLOOK done")
