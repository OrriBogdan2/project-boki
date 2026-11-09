"""A quick Cycles look at the current object set: blender -b -P this -- out.png az el cz size px [file.blend]"""
import bpy, math, sys
from mathutils import Vector


def rig_scene():
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 12
    sc.cycles.use_denoising = False
    sc.cycles.device = "CPU"
    sc.render.threads_mode = "FIXED"
    sc.render.threads = 8
    sc.view_settings.view_transform = "Standard"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    w.node_tree.nodes["Background"].inputs[0].default_value = (0.8, 0.8, 0.82, 1)
    w.node_tree.nodes["Background"].inputs[1].default_value = 0.8
    sc.world = w
    sun = bpy.data.lights.new("s", "SUN")
    sun.energy = 2.2
    sun.angle = 0.3
    so = bpy.data.objects.new("s", sun)
    sc.collection.objects.link(so)
    cam = bpy.data.cameras.new("c")
    cam.type = "ORTHO"
    co = bpy.data.objects.new("c", cam)
    sc.collection.objects.link(co)
    sc.camera = co
    return sc, co, cam, so


def aim(co, cam, so, az, el, c, size):
    x, e = math.radians(az), math.radians(el)
    d = Vector((math.sin(x) * math.cos(e), math.cos(x) * math.cos(e), math.sin(e)))
    co.location = Vector(c) + d * 6
    co.rotation_euler = (-d).to_track_quat("-Z", "Y").to_euler()
    cam.ortho_scale = size
    so.rotation_euler = (-d + Vector((0.5, 0, 0.8))).to_track_quat("Z", "Y").to_euler()
