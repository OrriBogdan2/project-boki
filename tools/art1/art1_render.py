"""Review renders of an ART-1 Hunter from its .blend (Cycles, CPU): a turntable and clip strips, lit softly like the toon shader.
  blender -b FILE.blend --python tools/art1/art1_render.py -- OUTDIR turn [px]
  blender -b FILE.blend --python tools/art1/art1_render.py -- OUTDIR clip <action> [frames] [px] [az] [gif]"""
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
sc.cycles.samples = 10
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


if MODE == "turn":
    px = int(a[2]) if len(a) > 2 else 620
    sc.render.resolution_x = sc.render.resolution_y = px
    ims = []
    for i, az in enumerate((180, 135, 90, 0, 270, 225)):
        aim(az, 8, (0, 0.05, 0.62), 2.2)
        sc.render.filepath = os.path.join(OUT, "turn_%d.png" % i)
        bpy.ops.render.render(write_still=True)
        ims.append(sc.render.filepath)
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in ims], [])
                   + ["-filter_complex", "[0][1][2]hstack=3[a];[3][4][5]hstack=3[b];[a][b]vstack", os.path.join(OUT, "turntable.png")], check=True)
    # the close view of the head, and the match camera
    sc.render.resolution_x = sc.render.resolution_y = 620
    for nm, az, el, c, r in (("head", 180, 4, (0, 0.1, 0.9), 0.62), ("head34", 215, 8, (0, 0.1, 0.9), 0.62), ("top", 180, 55, (0, 0, 0.6), 2.6)):
        aim(az, el, c, r)
        sc.render.filepath = os.path.join(OUT, nm + ".png")
        bpy.ops.render.render(write_still=True)

if MODE in ("clip", "sheet"):
    arm = bpy.data.objects["Armature"]
    arm.animation_data_create()
    px = int(a[3]) if len(a) > 3 else 300
    sc.render.resolution_x = sc.render.resolution_y = px
    sc.cycles.samples = 6

    def fr(act, name, n=None, az=205, el=22, r=2.5, c=(0, 0.1, 0.8)):
        arm.animation_data.action = bpy.data.actions[act]
        slot = arm.animation_data.action.slots
        if len(slot):
            arm.animation_data.action_slot = slot[0]
        f0, f1 = bpy.data.actions[act].frame_range
        n = n or max(2, int((f1 - f0) / 2) + 1)
        aim(az, el, c, r)
        out = []
        for i in range(n):
            sc.frame_set(int(round(f0 + (f1 - f0) * i / max(n - 1, 1))))
            p = os.path.join(OUT, "_%s_%03d.png" % (act, i))
            sc.render.filepath = p
            bpy.ops.render.render(write_still=True)
            out.append(p)
        return out
    if MODE == "clip":
        for act in a[2].split(","):
            ims = fr(act, act)
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-framerate", "15", "-i", os.path.join(OUT, "_%s_%%03d.png" % act),
                            "-vf", "split[a][b];[a]palettegen=max_colors=96[p];[b][p]paletteuse", "-loop", "0", os.path.join(OUT, act + ".gif")], check=True)
    else:
        rows = []
        for act in a[2].split(","):
            ims = fr(act, act, 6)
            rows.append(os.path.join(OUT, "_row_%s.png" % act))
            subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in ims], [])
                           + ["-filter_complex", "hstack=inputs=6,drawtext=text='%s':x=8:y=8:fontsize=22:fontcolor=white:box=1:boxcolor=black@0.5" % act, rows[-1]], check=True)
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in rows], [])
                       + ["-filter_complex", "vstack=inputs=%d" % len(rows), os.path.join(OUT, "sheet_%s.png" % a[4] if len(a) > 4 else "sheet.png")], check=True)
