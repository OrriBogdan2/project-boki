"""Flat (emission) or lit Cycles renders of a .glb from several angles:
  blender -b --factory-startup --python tools/meshy/look_renders.py -- GLB OUT_PREFIX [--face=-Y|+Y] [--lit] [--res=900] [--scale=2.0]
  [--centre=x,y,z] [--views=front,tq,side,back,tqL,sideL] [--res_y=...]
Views are named from the model's own front (face=-Y: Meshy's raw frame; +Y: a fitted/exported Warden)."""
import sys, math, os
import bpy
from mathutils import Vector
a = sys.argv[sys.argv.index("--") + 1:]
glb, out = a[0], a[1]
opt = dict(x[2:].split("=", 1) if "=" in x else (x[2:], "1") for x in a[2:])
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=glb)
meshes = [o for o in bpy.context.scene.objects if o.type == "MESH"]
lit = opt.get("lit") == "1"
for ob in meshes:
    for m in ob.data.materials:
        if not m or not m.use_nodes: continue
        nt = m.node_tree
        tex = next((n for n in nt.nodes if n.type == "TEX_IMAGE"), None)
        outn = next(n for n in nt.nodes if n.type == "OUTPUT_MATERIAL")
        if lit:
            continue
        em = nt.nodes.new("ShaderNodeEmission")
        if tex:
            nt.links.new(tex.outputs[0], em.inputs[0])
        nt.links.new(em.outputs[0], outn.inputs[0])
sc = bpy.context.scene
sc.render.engine = "CYCLES"; sc.cycles.device = "CPU"; sc.cycles.samples = int(opt.get("samples", 6))
sc.cycles.use_denoising = False
sc.render.resolution_x = int(opt.get("res", 900)); sc.render.resolution_y = int(opt.get("res_y", opt.get("res", 900)))
sc.world = bpy.data.worlds.new("w"); sc.world.use_nodes = True
bg = sc.world.node_tree.nodes["Background"]; bg.inputs[0].default_value = (0.62, 0.62, 0.62, 1); bg.inputs[1].default_value = 1.0 if lit else 0.0
sc.view_settings.view_transform = "Standard"
if not lit:
    sc.render.film_transparent = False
    bg.inputs[1].default_value = 1.0
if lit:
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN")); sc.collection.objects.link(sun)
    sun.data.energy = 3.0; sun.rotation_euler = (math.radians(50), 0, math.radians(30))
# bounds
lo = Vector((1e9,) * 3); hi = Vector((-1e9,) * 3)
for ob in meshes:
    for c in ob.bound_box:
        w = ob.matrix_world @ Vector(c)
        lo = Vector(map(min, lo, w)); hi = Vector(map(max, hi, w))
centre = Vector(map(float, opt["centre"].split(","))) if "centre" in opt else (lo + hi) * 0.5
scale = float(opt.get("scale", (hi - lo).z * 1.08))
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam")); sc.collection.objects.link(cam); sc.camera = cam
cam.data.type = "ORTHO"; cam.data.ortho_scale = scale
cam.data.clip_end = 100
front = -1.0 if opt.get("face", "-Y") == "-Y" else 1.0
# azimuth from the model's front, positive toward her LEFT side (her left is +X when facing -Y, -X facing +Y)
VIEWS = {"front": 0, "tq": 35, "side": 90, "back": 180, "tqL": -35, "sideL": -90, "tqback": 145}
for v in opt.get("views", "front,tq,side,back").split(","):
    az = math.radians(VIEWS[v])
    # camera direction toward the model: start at the front (y = front * d)
    d = 6.0
    fx, fy = 0.0, front
    # rotate the front vector about Z by az, toward the model's right? (for face -Y, her right is -X)
    rx = fx * math.cos(az) - fy * math.sin(az) * (-1 if front < 0 else 1)
    ry = fx * math.sin(az) * (-1 if front < 0 else 1) + fy * math.cos(az)
    cam.location = centre + Vector((rx * d, ry * d, 0))
    direction = centre - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    sc.render.filepath = "%s_%s.png" % (out, v)
    bpy.ops.render.render(write_still=True)
print("LOOK done", out)
