"""ART-1 Kael, stage B: all pieces as Blender objects (P_*), flat coloured for a shape pass. stage/pieces.blend"""
import sys, os, pickle
import bpy, bmesh
import numpy as np
from mathutils.bvhtree import BVHTree
sys.path.insert(0, os.path.dirname(__file__))
import importlib, meshkit, kael_pieces as K
a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
bpy.ops.wm.open_mainfile(filepath=SRC)
low = bpy.data.objects["Low"]
dg = bpy.context.evaluated_depsgraph_get()
bvh = BVHTree.FromObject(low, dg)
U = {"chain": (0, 0, 1, 1)}
pieces = [K.face_patch(), K.skull(), K.mask(), K.cowl(), K.tail(bvh)]
for s in (1.0, -1.0):
    pieces.append(K.eyeball(s))
    pieces += K.lids(s)
    pieces += K.brows(s)
pieces += K.collar() + K.under_thighs()
pieces += K.hand("R", K.GRIP_DIR, (1.25, 1.35, 0.9), 0.0)
pieces += K.hand("L", (0.0, 1.0, -0.15), (0.55, 0.75, 0.5), 0.05)
locks = K.mane()
K.mane_chains(locks)
pieces += locks
ch = K.wrist_chain(U["chain"])
hang, hook, hang_pts = K.hanging_chain(U["chain"])
cuff, cuff_pts = K.cuff_chain(U["chain"])
pieces += [ch, hang, hook, cuff]
pieces += K.blade() + K.hilt(U["chain"])
tot = {}
for p in pieces:
    me = bpy.data.meshes.new("P_" + p.name)
    me.from_pydata(p.v.tolist(), [], p.f)
    me.update()
    ob = bpy.data.objects.new("P_" + p.name, me)
    bpy.context.scene.collection.objects.link(ob)
    ob["mat"] = p.mat
    tot[p.mat] = tot.get(p.mat, 0) + p.tris()
print(tot, sum(tot.values()))
bpy.ops.wm.save_as_mainfile(filepath=OUT)
