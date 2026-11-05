"""Review renders from a Pip .blend (Cycles, CPU): turnaround and head, or the shape pass.
  blender -b FILE.blend --python tools/art1/pip_render.py -- OUTDIR turn|shape [px]"""
import math
import os
import subprocess
import sys

import bpy
from mathutils import Vector

a = sys.argv[sys.argv.index("--") + 1:]
OUT, MODE = a[0], a[1]
px = int(a[2]) if len(a) > 2 else 500
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 16
sc.cycles.use_denoising = False
sc.cycles.device = "CPU"
sc.render.threads_mode = "FIXED"
sc.render.threads = 6
sc.view_settings.view_transform = "Standard"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.6, 0.62, 0.66, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.2
sc.world = w
sun = bpy.data.lights.new("s", "SUN")
sun.energy = 1.5
so = bpy.data.objects.new("s", sun)
sc.collection.objects.link(so)
cam = bpy.data.cameras.new("c")
cam.type = "ORTHO"
co = bpy.data.objects.new("c", cam)
sc.collection.objects.link(co)
sc.camera = co


def aim(az, el, c, r):
    x, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(x) * math.cos(e), -math.cos(x) * math.cos(e), math.sin(e)))
    co.location = Vector(c) + d * 6
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = r
    so.rotation_euler = (math.radians(50), 0, x + math.radians(30))


sc.render.resolution_x = sc.render.resolution_y = px
ims = []
V = [("front", 180, 6, (0, 0, 0.8), 2.0), ("left", 90, 6, (0, -0.1, 0.8), 2.0), ("back", 0, 6, (0, 0, 0.8), 2.0), ("q34", 215, 12, (0, 0, 0.8), 2.0),
     ("top", 180, 65, (0, -0.1, 0.8), 2.0), ("topb", 0, 65, (0, -0.1, 0.8), 2.0), ("head", 180, 4, (0, 0.03, 1.35), 0.72), ("head34", 212, 8, (0, 0.03, 1.35), 0.72)]
if MODE == "head":
    V = V[-2:] + [("head_l", 110, 6, (0, 0.03, 1.35), 0.72)]
for nm, az, el, c, r in V:
    aim(az, el, c, r)
    sc.render.filepath = os.path.join(OUT, nm + ".png")
    bpy.ops.render.render(write_still=True)
    ims.append(sc.render.filepath)
ff = "[0][1][2]hstack=3" if MODE == "head" else "[0][1][2][3]hstack=4[a];[4][5][6][7]hstack=4[b];[a][b]vstack"
subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in ims], []) + ["-filter_complex", ff, os.path.join(OUT, "sheet.png")], check=True)
