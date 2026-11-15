"""Vex's armature alone (no mesh, no scan): the contract bones from vex_rig.json plus the extra bones vex_finish.py adds, so vex_clips.py can bake
re-keyed clips on a worker without the 72 MB vex.blend. Only the bones' directions matter to the clips; the face bones sit at the head.
Run: blender -b --factory-startup --python tools/art1/vex_rig_only.py -- <rig.json> <out.blend>"""
import sys, os, json
import bpy
import numpy as np
from mathutils import Vector
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import vex_cannon as VC, vex_arm as VA
import warden_kit as WK

RIG, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
arm = WK.build_armature(json.load(open(RIG)))
bpy.context.view_layer.objects.active = arm
bpy.ops.object.mode_set(mode="EDIT")
eb = arm.data.edit_bones


def bone(name, parent, head, d):
    e = eb.new(name)
    e.head, e.tail = Vector(head), Vector(head) + Vector(d)
    e.parent = eb[parent]
    e.use_connect = False


hd = VC.J("head")
bone("lid.L", "head", hd, (0, 0.03, 0))
for side in "LR":
    bone("brow." + side, "head", hd, (0, 0.03, 0))
for sd in "RL":
    th = VC.J("shin." + sd)
    bone("foot." + sd, "shin." + sd, (th[0], 0.0, 0.16), (0, 0.12, 0))
kn = VA.WR + np.array([0, 0, -0.082])
bone("fingers.L", "hand.L", kn, (0, 0, -0.06))
bone("thumb.L", "hand.L", VA.WR + np.array([0, 0.04, -0.024]), (0, 0.02, -0.05))
bone("coin", "hand.L", VA.WR, (0, 0, 0.04))
bone("launcher", "forearm.R", VC.C(VC.PIVOT_S, 0, VC.DRUM_F), (0, 0, 0.1))
bone("gatling", "forearm.R", VC.C(VC.REC_S1, 0, VC.GATLING_F), (0, 0, -0.1))
bpy.ops.object.mode_set(mode="OBJECT")
bpy.ops.wm.save_as_mainfile(filepath=OUT)
