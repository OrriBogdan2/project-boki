"""A Warden's turnaround rendered in Blender (Cycles, CPU): front, three-quarter, side, back side by side,
on a light grey ground like the turnaround sheets, the weapon hanging in the right hand."""
import math

import bpy
import numpy as np
from mathutils import Euler, Matrix, Vector

VIEW_W = 420
VIEW_H = 840
YAWS = [("front", 180.0), ("3/4", 225.0), ("side", 270.0), ("back", 0.0)]


def turnaround(arm, body, gun, hand, path):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    sc.cycles.samples = 32
    sc.render.resolution_x = VIEW_W
    sc.render.resolution_y = VIEW_H
    sc.render.film_transparent = False
    world = bpy.data.worlds.new("w")
    sc.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.62, 0.63, 0.66, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 0.9
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 3.0
    sun.rotation_euler = Euler((math.radians(50), 0, math.radians(30)))
    sc.collection.objects.link(sun)
    # the rifle hanging muzzle-down beside her right leg, in her right hand
    gun.matrix_world = Matrix.Translation(hand + Vector((0.03, 0.0, -0.02))) @ Euler((math.radians(-100), 0, 0)).to_matrix().to_4x4()
    pivot = bpy.data.objects.new("pivot", None)
    sc.collection.objects.link(pivot)
    for ob in (arm, gun):
        ob.parent = pivot
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.1
    cam.location = (0, -6.0, 0.92)
    cam.rotation_euler = Euler((math.radians(90), 0, 0))
    sc.collection.objects.link(cam)
    sc.camera = cam
    frames = []
    for name, yaw in YAWS:
        pivot.rotation_euler = Euler((0, 0, math.radians(yaw)))
        sc.render.filepath = path + "_" + name.replace("/", "") + ".png"
        bpy.ops.render.render(write_still=True)
        img = bpy.data.images.load(sc.render.filepath)
        px = np.array(img.pixels[:]).reshape(VIEW_H, VIEW_W, 4)
        frames.append(px)
    strip = np.concatenate(frames, axis=1)
    out = bpy.data.images.new("turnaround", strip.shape[1], strip.shape[0], alpha=True)
    out.pixels = strip.ravel()
    out.filepath_raw = path
    out.file_format = "PNG"
    out.save()
    print("WARDENRENDER wrote", path)
