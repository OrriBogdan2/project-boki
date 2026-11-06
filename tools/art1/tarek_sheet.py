"""A contact sheet of clips: blender -b tarek_anims.blend --python tools/art1/tarek_sheet.py -- <out dir> <clip[:frames],...> [yaw deg] [gif]
Renders each clip's sampled frames with the painted atlas, flat lit. gif: every frame, for GIFs (ffmpeg joins them)."""
import math
import os
import sys

import bpy
from mathutils import Vector

A = sys.argv[sys.argv.index("--") + 1:]
OUT, CLIPS = A[0], A[1].split(",")
YAW = float(A[2]) if len(A) > 2 else 35.0
GIF = len(A) > 3 and A[3] == "gif"
os.makedirs(OUT, exist_ok=True)
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 6
sc.cycles.device = "CPU"
sc.cycles.use_denoising = False
sc.view_settings.view_transform = "Standard"
sc.render.image_settings.file_format = "PNG"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
sc.world = w
for m in bpy.data.materials:
    if m.use_nodes and "Principled BSDF" in m.node_tree.nodes:
        tex = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"]
        if not tex:
            continue
        em = m.node_tree.nodes.new("ShaderNodeEmission")
        m.node_tree.links.new(tex[0].outputs[0], em.inputs[0])
        m.node_tree.links.new(em.outputs[0], m.node_tree.nodes["Material Output"].inputs[0])
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 3.3
sc.render.resolution_x, sc.render.resolution_y = (420, 420)
r = math.radians(YAW)
d = Vector((math.sin(r), math.cos(r), 0.16))
cam.location = Vector((0, 0.2, 1.2)) + d * 6
cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
arm = bpy.data.objects["Armature"]
arm.animation_data_create()
for c in CLIPS:
    nm, _, cnt = c.partition(":")
    act = bpy.data.actions[nm]
    arm.animation_data.action = act
    a, b = act.frame_range
    n = int(cnt or 8)
    frames = list(range(int(a), int(b) + 1, 1)) if GIF else [int(round(a + (b - a) * i / max(n - 1, 1))) for i in range(n)]
    for i, f in enumerate(frames):
        sc.frame_set(f)
        sc.render.filepath = os.path.join(OUT, "%s_%03d.png" % (nm, i))
        bpy.ops.render.render(write_still=True)
