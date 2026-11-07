"""Painted previews of tarek.blend: blender -b <blend> --python tools/art1/tarek_view.py -- <out prefix> [body|head|both]"""
import math
import sys

import bpy
from mathutils import Matrix, Vector

A = sys.argv[sys.argv.index("--") + 1:]
OUT, WHAT = A[0], (A[1] if len(A) > 1 else "both")
sc = bpy.context.scene
sc.render.engine = "CYCLES"
sc.cycles.samples = 16
sc.cycles.device = "CPU"
sc.view_settings.view_transform = "Standard"
sc.render.image_settings.file_format = "PNG"
w = bpy.data.worlds.new("w")
w.use_nodes = True
w.node_tree.nodes["Background"].inputs[0].default_value = (0.42, 0.44, 0.47, 1)
w.node_tree.nodes["Background"].inputs[1].default_value = 1.0
sc.world = w
for m in bpy.data.materials:
    if not m.use_nodes:
        continue
    b = m.node_tree.nodes.get("Principled BSDF")
    tex = [n for n in m.node_tree.nodes if n.type == "TEX_IMAGE"]
    if not tex:
        continue
    em = m.node_tree.nodes.new("ShaderNodeEmission")
    m.node_tree.links.new(tex[0].outputs[0], em.inputs[0])
    out = m.node_tree.nodes["Material Output"]
    m.node_tree.links.new(em.outputs[0], out.inputs[0])
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"


def shots(tag, centre, scale, views, res):
    cam.data.ortho_scale = scale
    sc.render.resolution_x, sc.render.resolution_y = res
    for i, a in enumerate(views):
        r = math.radians(a)
        d = Vector((math.sin(r), math.cos(r), 0.06))
        cam.location = Vector(centre) + d * 6
        cam.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
        sc.render.filepath = "%s_%s_%d.png" % (OUT, tag, i)
        bpy.ops.render.render(write_still=True)


if WHAT in ("body", "both"):
    shots("body", (0, 0, 1.16), 2.5, (0, 40, 90, 180), (520, 900))
if WHAT in ("head", "both"):
    hc = bpy.data.objects["Armature"].data.bones["head"].head_local
    shots("head", (0, 0, hc.z + 0.14), 0.9, (0, 35, 90), (640, 640))
