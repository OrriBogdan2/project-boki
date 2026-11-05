"""ART-1 Claire, stage B: the fitted scan and all the pieces, flat coloured, ortho views: a shape pass before the bake.
Run: blender -b --factory-startup --python tools/art1/claire_assemble.py -- <source.blend> <out prefix>"""
import sys, os
import bpy
import numpy as np
from mathutils import Vector
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import claire_pieces as K
a = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = a[0], a[1]
bpy.ops.wm.open_mainfile(filepath=SRC)
bpy.data.objects["Src"].hide_render = True
low = bpy.data.objects["Low"]
ps = K.hand("R", K.GRIP_K, (1.25, 1.35, 0.85)) + K.hand("L", (0.0, 1.0, -0.15), (0.3, 0.4, 0.3), 0.06)
ps += [K.ear(1.0), K.ear(-1.0), K.horn(1.0), K.horn(-1.0), K.tail()] + K.bow() + [K.ribbon(1.0), K.ribbon(-1.0), K.blade(1.0), K.blade(-1.0)] + K.spear()
for s in (1.0, -1.0):
    w, r = K.wing(s)
    ps += [w] + r
ps.append(K.heart_solid("tailheart", "glow-blade", K.tail().path[-1] + np.array([-0.05, 0.02, -0.03]), (-0.7, 0.3, -0.6), (0.5, 0.8, 0.0), 0.065, 0.016))
COL = {"leather": (0.9, 0.9, 0.95), "fur": (0.92, 0.93, 0.97), "ice": (0.45, 0.72, 0.95), "skin": (0.6, 0.78, 0.95), "cloth": (0.5, 0.72, 0.92), "ice-bright": (0.45, 0.85, 1.0)}
mats = {}
for k, c in COL.items():
    m = bpy.data.materials.new(k)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs[0].default_value = c + (1,)
    mats[k] = m
tot = {}
for p in ps:
    me = bpy.data.meshes.new("P_" + p.name)
    me.from_pydata(p.v.tolist(), [], [list(f) for f in p.f])
    me.update()
    me.materials.append(mats[p.mat.split("-")[0]])
    me.polygons.foreach_set("use_smooth", [True] * len(me.polygons))
    ob = bpy.data.objects.new("P_" + p.name, me)
    bpy.context.scene.collection.objects.link(ob)
    tot[p.name.rstrip("RL0123456789")] = tot.get(p.name.rstrip("RL0123456789"), 0) + p.tris()
print(tot, "pieces", sum(tot.values()), "low", sum(len(q.vertices) - 2 for q in low.data.polygons))
bpy.ops.wm.save_as_mainfile(filepath=OUT + ".blend")
