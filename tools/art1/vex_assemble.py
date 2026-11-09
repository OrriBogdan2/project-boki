"""ART-1 Vex, stage B: all pieces as Blender objects (P_*), flat coloured, and a four-view shape pass (workbench, fast). stage/pieces.blend, stage/shape_*.png
Run: blender -b --factory-startup --python tools/art1/vex_assemble.py -- <headed.blend> <out.blend> <png prefix>"""
import sys, os
import bpy
import numpy as np
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import vex_parts as VP

a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT, PNG = a[0], a[1], a[2]
bpy.ops.wm.open_mainfile(filepath=SRC)
src, low = bpy.data.objects["Src"], bpy.data.objects["Low"]
dg = bpy.context.evaluated_depsgraph_get()
bvh_src = BVHTree.FromObject(src, dg)
bvh_low = BVHTree.FromObject(low, dg)
parts = VP.build(bvh_src, bvh_low, BVHTree.FromObject(bpy.data.objects["HeadSrc"], dg))
COL = {"skin": (.86, .62, .55), "cloth": (.5, .75, .3), "leather": (.1, .1, .1), "metal": (.55, .55, .58), "brass": (.75, .58, .22), "hair": (.1, .55, .35), "eyes": (.9, .9, .9), "glow": (.3, 1, .3)}
tot = {}
for p in parts["pieces"]:
    me = bpy.data.meshes.new("P_" + p.name)
    me.from_pydata(p.v.tolist(), [], p.f)
    me.update()
    ob = bpy.data.objects.new("P_" + p.name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["mat"] = p.mat
    k = p.mat.split("-")[0]
    ob.color = COL.get(k, (1, 0, 1)) + (1,)
    tot[k] = tot.get(k, 0) + p.tris()
print("tris by slot", tot, "pieces", sum(tot.values()), "low", sum(len(q.vertices) - 2 for q in low.data.polygons))
bpy.data.objects.remove(src)
sc = bpy.context.scene
sc.render.engine = "BLENDER_WORKBENCH"
sc.display.shading.light = "STUDIO"
sc.display.shading.color_type = "OBJECT"
sc.display.shading.show_cavity = True
sc.render.resolution_x, sc.render.resolution_y = 520, 760
low.color = (.55, .6, .5, 1)
cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
sc.collection.objects.link(cam)
sc.camera = cam
cam.data.type = "ORTHO"
cam.data.ortho_scale = 2.1
for name, loc in (("front", (0, 5, .9)), ("back", (0, -5, .9)), ("side", (5, 0, .9)), ("left", (-5, 0, .9)), ("top", (0.001, 0.001, 6))):
    cam.location = loc
    tgt = Vector((0, 0, .9))
    cam.rotation_euler = (tgt - Vector(loc)).to_track_quat("-Z", "X" if name == "top" else "Y").to_euler()
    sc.render.filepath = PNG + name + ".png"
    bpy.ops.render.render(write_still=True)
bpy.ops.wm.save_as_mainfile(filepath=OUT)
