"""Meeko's land clip held at its bottom. pip_clips.py's land bottoms out at 0.07 s and is back up by 0.22 s, but a
landing blends in over 0.1 s (WardenClips.FADE), so out of a run the clip owns her only once it is on its way up, and
since her sole-locked run (pip_gait.py) carries her hips low, the landing read as no dip at all (docs/DEBT.md).
Here the root holds the bottom, DEEPER lower, from the bottom to HOLD and then rejoins the old clip by BACK; the legs
are re-solved to the old clip's ankle places and foot angles, so the paws stay where they were. Everything else
(upper body, ears, wings, face) is the old clip's, key for key.
  blender -b --factory-startup --python tools/art1/pip_land.py -- art/wardens/pip/pip.glb OUT.glb
  python3 tools/art1/glb_add_clips.py art/wardens/pip/pip.glb OUT.glb land
A second run on the shipped GLB holds the same bottom again (the hold is a floor under the old curve, never a lift)."""
import math
import sys

import bpy
from mathutils import Matrix, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
FPS = 50            # keys per second: the 0.4 s clip on whole frames (the game imports it at 48)
DEEPER = 0.012      # model m: the held bottom this far under the old one
HOLD = 0.17         # s: the root stays at the bottom until here (a run landing's land clip is fully in at 0.1-0.13 s)
BACK = 0.3          # s: and is back on the old clip's curve here (the clip is 0.4 s: the end pose is the old one)
LEGS = ("thigh", "shin", "foot")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
layer = bpy.context.view_layer
PB = arm.pose.bones
for pb in PB:
    pb.rotation_mode = "QUATERNION"


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def about(name, turn):
    pb = PB[name]
    at = Matrix.Translation(pb.head)
    pb.matrix = at @ turn @ at.inverted() @ pb.matrix
    layer.update()


def leg_ik(side, ankle, foot_rot):
    """Two bones from the hip to the ankle, the knee ahead (pip_gait.py's), then the foot at its old armature-space turn."""
    th, sh, ft = (PB["%s.%s" % (n, side)] for n in LEGS)
    for pb in (th, sh, ft):
        pb.matrix_basis = Matrix()
    layer.update()
    hip, knee, old = th.head.copy(), sh.head.copy(), ft.head.copy()
    l1, l2 = (knee - hip).length, (old - knee).length
    want = ankle - hip
    d = min(max(want.length, abs(l1 - l2) + 1e-4), l1 + l2 - 1e-4)
    u = want.normalized()
    x = (l1 * l1 - l2 * l2 + d * d) / (2 * d)
    pole = Vector((0, 1, 0)) - u * u.y
    knee_to = hip + u * x + pole.normalized() * math.sqrt(max(0.0, l1 * l1 - x * x))
    about(th.name, (knee - hip).rotation_difference(knee_to - hip).to_matrix().to_4x4())
    about(sh.name, (ft.head - sh.head).rotation_difference(hip + u * d - sh.head).to_matrix().to_4x4())
    ft.matrix = Matrix.Translation(ft.head) @ foot_rot
    layer.update()
    for pb in (th, sh, ft):
        pb.location = (0, 0, 0)
    layer.update()
    return (ft.head - ankle).length, d / (l1 + l2)


act = bpy.data.actions["land"]
arm.animation_data.action = act
n = int(round(act.frame_range[1]))
old = []
for k in range(n + 1):
    bpy.context.scene.frame_set(k)
    layer.update()
    old.append(dict(pose={pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB},
                    hips=PB["hips"].head.z,
                    feet={s: (PB["foot." + s].head.copy(), PB["foot." + s].matrix.to_3x3().to_4x4()) for s in "LR"}))
arm.animation_data.action = None
act.name = "land_was"
kb = min(range(n + 1), key=lambda k: old[k]["hips"])
bottom = old[kb]["hips"] - DEEPER
keys, miss, reach = [], 0.0, 1.0
for k in range(n + 1):
    t = k / FPS
    o = old[k]
    held = bottom if t <= HOLD else bottom + (o["hips"] - bottom) * smooth(HOLD, BACK, t)
    want = o["hips"] - DEEPER * smooth(0.0, kb / FPS, t) if t < kb / FPS else held
    drop = min(0.0, want - o["hips"])
    for pb in PB:
        pb.location, pb.rotation_quaternion = o["pose"][pb.name]
    layer.update()
    PB["root"].matrix = Matrix.Translation((0, 0, drop)) @ PB["root"].matrix
    layer.update()
    for s in "LR":
        m, r = leg_ik(s, *o["feet"][s])
        miss, reach = max(miss, m), min(reach, r)
    keys.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB})
new = bpy.data.actions.new("land")
new.use_fake_user = True
arm.animation_data.action = new
last = {}
for k, key in enumerate(keys):
    for pb in PB:
        q = key[pb.name][1].copy()
        if pb.name in last and last[pb.name].dot(q) < 0:
            q.negate()
        last[pb.name] = q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=k)
        pb.location = key[pb.name][0]
        pb.keyframe_insert("location", frame=k)
print("LAND %d keys, bottom %.4f at %.3f s held to %.2f s, back by %.2f s; ankle miss %.4f m, shortest leg %.2f of reach"
      % (n + 1, bottom, kb / FPS, HOLD, BACK, miss, reach))
arm.animation_data.action = None
for ac in list(bpy.data.actions):
    if ac.name != "land":
        bpy.data.actions.remove(ac)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS")
