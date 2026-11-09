"""A clay contact sheet of a sculpt, for looking at shapes while they are made:
  blender -b --factory-startup --python tools/art1/sculpt_preview.py -- OUT.png mesh.npz [mesh.npz ...] [--head]"""
import math
import os
import sys

import bpy
import numpy as np
from mathutils import Vector

sys.path.insert(0, os.path.dirname(__file__))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "meshy"))


def mesh_ob(name, v, q, col=(0.5, 0.56, 0.66)):
    me = bpy.data.meshes.new(name)
    me.vertices.add(len(v))
    me.vertices.foreach_set("co", v.astype(np.float32).ravel())
    n = q.shape[1]
    me.loops.add(len(q) * n)
    me.polygons.add(len(q))
    me.loops.foreach_set("vertex_index", q.astype(np.int32).ravel())
    me.polygons.foreach_set("loop_start", np.arange(0, len(q) * n, n, dtype=np.int32))
    me.update()
    me.polygons.foreach_set("use_smooth", np.ones(len(q), bool))
    me.update()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    m.node_tree.nodes["Principled BSDF"].inputs[0].default_value = (*col, 1)
    m.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 0.55
    me.materials.append(m)
    return ob


def setup(sc, res):
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = False
    sc.cycles.device = "CPU"
    sc.render.threads = 6
    sc.render.threads_mode = "FIXED"
    sc.render.resolution_x, sc.render.resolution_y = res
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.65, 0.7, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.65
    sc.world = w
    sc.view_settings.view_transform = "Standard"
    sun = bpy.data.lights.new("s", "SUN")
    sun.energy = 2.2
    so = bpy.data.objects.new("s", sun)
    sc.collection.objects.link(so)
    so.rotation_euler = (math.radians(50), 0.0, math.radians(30))
    cam = bpy.data.cameras.new("c")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return co, cam, so


def shot(sc, co, cam, so, c, r, az, el, path):
    a, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(a) * math.cos(e), -math.cos(a) * math.cos(e), math.sin(e)))
    co.location = Vector(c) + d * 4
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = r
    so.rotation_euler = (math.radians(55), 0, a + math.radians(25))
    sc.render.filepath = path
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:]
    head = "--head" in argv
    argv = [a for a in argv if not a.startswith("--")]
    out, files = argv[0], argv[1:]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    for f in files:
        d = np.load(f)
        ob = mesh_ob(os.path.basename(f), d["v"], d["q"], tuple(d["col"]) if "col" in d else (0.5, 0.56, 0.66))
    co, cam, so = setup(sc, (620, 620))
    views = [(180, 8), (225, 15), (270, 8), (0, 10)] if not head else [(180, 2), (215, 6), (270, 2), (180, 40)]
    c, r = ((0, 0.0, 0.77), 1.75) if not head else ((0, 0.08, 1.41), 0.5)
    ims = []
    for i, (az, el) in enumerate(views):
        p = "/tmp/_pv_%d_%d.png" % (os.getpid(), i)
        shot(sc, co, cam, so, c, r, az, el, p)
        ims.append(p)
    import subprocess
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y"] + sum([["-i", p] for p in ims], [])
                   + ["-filter_complex", "hstack=inputs=%d" % len(ims), out], check=True)
    for p in ims:
        os.remove(p)
