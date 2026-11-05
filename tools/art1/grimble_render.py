"""Review renders of an ART-1 Hunter from its .blend (Cycles, CPU): a turntable and clip strips, lit softly like the toon shader.
  blender -b FILE.blend --python tools/blender/art1_render.py -- OUTDIR turn [px]
  blender -b FILE.blend --python tools/blender/art1_render.py -- OUTDIR clip <action> [frames] [px] [az] [gif]"""
import math
import os
import subprocess
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT, MODE = a[0], a[1]
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 20
sc.cycles.use_denoising = False
sc.cycles.device = "CPU"
sc.render.threads_mode = "FIXED"
sc.render.threads = 6
sc.view_settings.view_transform = "Standard"
sc.render.film_transparent = False
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.55, 0.58, 0.63, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.15
sc.world = w
sun = bpy.data.lights.new("s", "SUN")
sun.energy = 1.4
so = bpy.data.objects.new("s", sun)
sc.collection.objects.link(so)
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co
gr = bpy.data.meshes.new("g")
gr.from_pydata([(-8, -8, 0), (8, -8, 0), (8, 8, 0), (-8, 8, 0)], [], [(0, 1, 2, 3)])
go = bpy.data.objects.new("g", gr)
sc.collection.objects.link(go)
gm = bpy.data.materials.new("gm")
gm.use_nodes = True
gm.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (0.5, 0.53, 0.58, 1)
gr.materials.append(gm)


def aim(az, el, c, r):
    x, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(x) * math.cos(e), -math.cos(x) * math.cos(e), math.sin(e)))
    co.location = Vector(c) + d * 6
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = r
    so.rotation_euler = (math.radians(50), 0, x + math.radians(30))


if len(a) > 4:            # (a pose: ... turn <px> <action> <frame>)
    arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
    arm.animation_data_create()
    arm.animation_data.action = bpy.data.actions[a[3]]
    sc.frame_set(int(a[4]))

if MODE == "turn":
    px = int(a[2]) if len(a) > 2 else 620
    sc.render.resolution_x = sc.render.resolution_y = px
    ims = []
    for i, az in enumerate((180, 135, 90, 0, 270, 225) if not os.environ.get("HEADS") else ()):
        aim(az, 6, (0, -0.1, 0.92), 2.1)
        sc.render.filepath = os.path.join(OUT, "turn_%d.png" % i)
        bpy.ops.render.render(write_still=True)
        ims.append(sc.render.filepath)
    if ims: subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in ims], [])
                   + ["-filter_complex", "[0][1][2]hstack=3[a];[3][4][5]hstack=3[b];[a][b]vstack", os.path.join(OUT, "turntable.png")], check=True)
    # the close view of the head, and the match camera
    sc.render.resolution_x = sc.render.resolution_y = 620
    for nm, az, el, c, r in (("head", 180, 4, (0.0, 0.2, 1.15), 0.5), ("head34", 215, 8, (0, 0.2, 1.15), 0.5), ("side", 90, 4, (0, 0.1, 1.05), 0.8), ("top", 180, 58, (0, -0.1, 0.8), 2.3)):
        aim(az, el, c, r)
        sc.render.filepath = os.path.join(OUT, nm + ".png")
        bpy.ops.render.render(write_still=True)
