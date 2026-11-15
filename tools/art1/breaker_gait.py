"""Albert's walk_f and run_f, the animation pilot's recipe built by hand (no retarget fits a ball on 14 cm legs):
a closed left + right cycle, each stance sole pinned to a floor that passes under him at his loco speed, and the soles
set on the floor from the skinned foot verts. His stride is longer than his legs: the hip sockets twist with the root,
the foot rolls from heel to toe, and the hull above turns late, so the drum's weight arrives after the step.
  blender -b --factory-startup --python tools/art1/breaker_gait.py -- art/wardens/breaker/breaker.glb OUT.glb
  python3 tools/art1/glb_add_clips.py art/wardens/breaker/breaker.glb OUT.glb walk_f,run_f
Every other clip stays as tools/art1/breaker_anims.py bakes it. The arms, hands, weapon and fish start from the first
key of its side-step clips (`carry_from`), so a second run on the shipped GLB bakes the same two clips again."""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
SIZE = 2.0          # game metres per model metre (content/archetypes/bulwark.json body size)
FPS = 48            # keys per second: a run stance is 0.14 s
CONTACT = 0.006     # m: a sole vert this close to the floor is planted
TAU = math.tau
# Per gait. speed: game m/s (warden_anim/breaker.json loco). period: s for a left + right pair. duty: the part of the
# period a foot is planted. reach: where the planted sole meets the floor, m ahead of the root. sink, bob: the root's
# mean drop and its swing, m (vault 1 rides high over the planted leg, -1 dips into it and rises in flight).
# Angles in degrees: toe_up at the strike, heel_up at the push, twist of the hip sockets, hull the yaw left on the
# drum, roll onto the planted foot, lean forward, rock per step, arm swing (shield arm, hammer arm). carry: how
# high the hammer's head hangs off the floor, m. The head tips back by 0.6 of the lean, as in his other loco clips.
GAITS = {
    "walk_f": dict(speed=2.0, period=0.75, duty=0.5, reach=0.178, lift=0.05, toe_up=8.0, heel_up=32.0, twist=22.0,
                   hull=7.0, roll=5.0, hull_roll=2.5, sway=0.02, lean=-3.0, rock=1.2, sink=-0.03, bob=0.011, vault=1,
                   surge=0.006, arms=(9.0, 3.0), late=0.07, push=0.72, turn=(0.0, 0.0), carry=0.0, carry_from="walk_l"),
    "run_f": dict(speed=4.8, period=0.625, duty=0.22, reach=0.172, lift=0.095, toe_up=5.0, heel_up=38.0, twist=24.0,
                  hull=9.0, roll=6.0, hull_roll=3.5, sway=0.016, lean=-11.0, rock=2.5, sink=-0.034, bob=0.018, vault=-1,
                  surge=0.01, arms=(16.0, 5.0), late=0.09, push=0.68, turn=(0.04, 0.12), carry=0.03, carry_from="run_l"),
}
LEGS = ("thigh", "shin", "x_foot")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = bpy.data.objects["breaker"]
hammer = bpy.data.objects["hammer"]
scene = bpy.context.scene
layer = bpy.context.view_layer
PB = arm.pose.bones
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
for pb in PB:
    pb.rotation_mode = "QUATERNION"


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def verts(obj, idx=None):
    """The skinned mesh's vertices in the world (x his right, y ahead, z up), as the pose stands."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = obj.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    co = co.reshape(-1, 3) @ np.array(obj.matrix_world.to_3x3()).T + np.array(obj.matrix_world.translation)
    return co if idx is None else co[idx]


def foot_idx(side):
    g = body.vertex_groups["x_foot." + side].index
    return np.array([v.index for v in body.data.vertices if any(e.group == g and e.weight > 0.3 for e in v.groups)])


FOOT = {s: foot_idx(s) for s in "LR"}
layer.update()
SOLE = {}           # per side: the ankle's rest place, and the heel and toe ends of the sole from it (m, along y)
for s in "LR":
    co = verts(body, FOOT[s])
    low = co[co[:, 2] < co[:, 2].min() + 0.012]
    ankle = REST["x_foot." + s].translation
    SOLE[s] = (ankle.copy(), float(low[:, 1].min() - ankle.y), float(low[:, 1].max() - ankle.y), float(co[:, 2].min()))


def base_pose(clip):
    """A clip's first key on every bone: his carry (arms, hands, weapon, fish) as breaker_anims.py poses it."""
    arm.animation_data.action = bpy.data.actions[clip]
    scene.frame_set(0)
    return {pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB}


def about(name, turn):
    """Turns a bone about its own head, in armature space (x his right, y ahead, z up)."""
    pb = PB[name]
    at = Matrix.Translation(pb.head)
    pb.matrix = at @ turn @ at.inverted() @ pb.matrix
    layer.update()


def leg_ik(side, ankle, foot_turn):
    """Two bones from the hip to the ankle, the knee ahead; then the foot at its own angle. Returns the miss, m."""
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
    ft.matrix = Matrix.Translation(ft.head) @ foot_turn @ REST[ft.name].to_3x3().to_4x4()
    layer.update()
    for pb in (th, sh, ft):
        pb.location = (0, 0, 0)
    layer.update()
    return (ft.head - ankle).length, d / (l1 + l2)


def foot_path(g, side, ph, off):
    """One foot at phase ph (0 = its strike): the flat-foot ankle place, its pitch (toe up +), and whether it is planted."""
    ankle, _heel, _toe, _z = SOLE[side]
    v = g["speed"] / SIZE
    duty, period = g["duty"], g["period"]
    travel = v * duty * period
    front = g["reach"]
    if ph < duty:
        u = ph / duty
        pitch = g["toe_up"] * (1 - smooth(0.0, 0.16, u)) - g["heel_up"] * smooth(g["push"], 1.0, u) ** 1.4
        return Vector((ankle.x, front - travel * u, 0.0)) + off, pitch, True
    s = (ph - duty) / (1 - duty)
    # (a Hermite pass forward: it leaves the floor already folding up, and meets it near its speed, so no scuff)
    m0, m1 = -0.3 * v * (1 - duty) * period, -0.6 * v * (1 - duty) * period
    h = (2 * s ** 3 - 3 * s * s + 1, s ** 3 - 2 * s * s + s, -2 * s ** 3 + 3 * s * s, s ** 3 - s * s)
    y = h[0] * (front - travel) + h[1] * m0 + h[2] * front + h[3] * m1
    out = 0.012 * math.sin(s * math.pi) * (1 if side == "R" else -1)
    pitch = -g["heel_up"] + (g["heel_up"] + g["toe_up"]) * smooth(0.08, 0.92, s)
    lift = g["lift"] * math.sin(s ** 0.75 * math.pi) ** 0.9
    return Vector((ankle.x + out, y, lift)) + off * (1 - smooth(0.0, 0.6, s)), pitch, False


def place_foot(side, flat, pitch):
    """The ankle for a sole that pivots on its heel (toe up) or its toe (heel up) at the flat-foot place `flat`."""
    ankle, heel, toe, _z = SOLE[side]
    pivot = Vector((flat.x, flat.y + (heel if pitch > 0 else toe), flat.z))
    turn = rot("X", pitch)
    return pivot + turn.to_3x3() @ (Vector((flat.x, flat.y, flat.z + ankle.z)) - pivot), turn


def pose(g, base, ph, feet):
    """The whole body at phase ph of the cycle (0 = the right foot strikes, 0.5 = the left). `feet` carries each
    foot from key to key: its sole verts, whether it was planted, and how far the lock has moved it off its path."""
    duty = g["duty"]
    for pb in PB:
        pb.location, pb.rotation_quaternion = base[pb.name]
    for name in ["root"] + ["%s.%s" % (n, s) for n in LEGS for s in "LR"]:
        PB[name].matrix_basis = Matrix()
    mid = ph - duty / 2                                  # 0 at the right foot's mid stance
    onto = math.cos(mid * TAU)                           # +1 weight on the right foot, -1 on the left
    step = math.cos(mid * 2 * TAU)                       # +1 at each mid stance
    early, after = g["turn"]                             # the hip sockets start to turn before the strike, end after the push
    twist = (g["twist"] * (1 - 2 * smooth(-early, duty + after, (ph + early) % 0.5 - early))
             * (1 if (ph + early) % 1.0 < 0.5 else -1))
    late = g["late"]
    hull_yaw = g["hull"] * math.cos((ph - duty / 2 - late) * TAU + TAU / 4 * 0.6)
    hull_roll = g["hull_roll"] * math.cos((mid - late) * TAU)
    drop = math.cos((mid - late) * 2 * TAU)              # the drum's own step, behind the legs'
    z = g["sink"] + g["vault"] * g["bob"] * math.cos((mid - 0.03) * 2 * TAU)
    y = g["surge"] * math.sin((mid - 0.03) * 2 * TAU)
    PB["root"].matrix = (Matrix.Translation((g["sway"] * onto, y, z)) @ rot("Z", twist) @ rot("Y", g["roll"] * onto)
                         @ rot("X", g["lean"] - g["rock"] * g["vault"] * step) @ REST["root"])
    layer.update()
    about("hips", rot("Z", hull_yaw - twist) @ rot("Y", hull_roll) @ rot("X", -g["rock"] * 0.6 * g["vault"] * drop))
    about("head", rot("Z", -0.7 * hull_yaw) @ rot("Y", -0.6 * (g["roll"] * onto + hull_roll)) @ rot("X", 1.5 * drop - 0.6 * g["lean"]))
    about("skirt", rot("Y", -0.8 * g["hull_roll"] * math.cos((mid - 2.5 * late) * TAU)) @ rot("X", -1.5 * drop))
    for side, sign in (("L", 1), ("R", -1)):
        about("pauldron." + side, rot("Y", sign * 2.5 * g["vault"] * math.cos((mid - 1.6 * late) * 2 * TAU)))
        swing = sign * g["arms"][0 if side == "L" else 1]
        about("upper_arm." + side, rot("X", swing * math.cos((ph - 0.04) * TAU)) @ rot("Y", sign * 1.5 * drop))
        about("forearm." + side, rot("X", 0.6 * swing * math.cos((ph - 0.04 - 1.4 * late) * TAU)))
    want = g["carry"] + 0.012 * (1 - math.cos((mid - 2 * late) * 2 * TAU))
    for _ in range(3):                                   # the hull rocks round the hammer: its head keeps its height
        co = verts(hammer)
        at = Vector(co[co[:, 2].argmin()])
        lever = (at - PB["upper_arm.R"].head).xy
        about("upper_arm.R", Matrix.Rotation((want - at.z) / lever.length, 4, Vector((lever.y, -lever.x, 0.0))))
    step_y = -g["speed"] / SIZE / FPS
    for side, start in (("R", 0.0), ("L", 0.5)):
        was = feet[side]
        _flat, pitch, planted = foot_path(g, side, (ph + start) % 1.0, Vector())
        if planted and not was["planted"]:
            was["off"] = Vector()
        for turn_no in range(5):
            flat, pitch, planted = foot_path(g, side, (ph + start) % 1.0, was["off"])
            ankle, turn = place_foot(side, flat, pitch)
            miss, ext = leg_ik(side, ankle, turn)
            for _ in range(2):                           # the sole on the floor from the skinned verts: no hover, no sink
                low = float(verts(body, FOOT[side])[:, 2].min())
                if planted or low < 0:
                    ankle.z -= low
                    miss, ext = leg_ik(side, ankle, turn)
            now = verts(body, FOOT[side])
            both = (now[:, 2] < CONTACT) & (was["co"][:, 2] < CONTACT) if planted and was["planted"] else None
            if both is None or not both.any() or turn_no == 4:
                break
            slip = (now[both, :2] - was["co"][both, :2]).mean(0)     # the lock: the planted patch moves with the floor
            was["off"] -= Vector((slip[0], slip[1] - step_y, 0.0))
        was.update(co=now, planted=planted, miss=miss, ext=ext)


def bake(name, g):
    base = base_pose(g["carry_from"])
    old = bpy.data.actions[name]
    arm.animation_data.action = old
    old_low = []
    for f in range(int(old.frame_range[1]) + 1):
        scene.frame_set(f)
        old_low.append(float(verts(hammer)[:, 2].min()))
    arm.animation_data.action = None
    old.name = name + "_was"
    n = int(round(g["period"] * FPS))
    feet = {s: dict(co=verts(body, FOOT[s]), planted=False, off=Vector()) for s in "LR"}
    for lap in range(2):                                 # twice round: the first lap hands each swing its start
        keys, soles, miss, ext, low = [], [], 0.0, [0.0, 0.0], []
        for k in range(n):
            pose(g, base, k / n, feet)
            keys.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB})
            soles.append({s: (feet[s]["planted"], feet[s]["co"].copy()) for s in "LR"})
            for s in "LR":
                on = feet[s]["planted"]
                miss = max(miss, feet[s]["miss"] if on else 0.0)
                ext[0 if on else 1] = max(ext[0 if on else 1], feet[s]["ext"])
            low.append(float(verts(hammer)[:, 2].min()))
    keys.append(keys[0])
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    last = {}
    for k, key in enumerate(keys):
        for pb in PB:
            if pb.name not in base or pb.name.startswith(("anchor_", "weapon_")):
                continue
            q = key[pb.name][1].copy()
            if pb.name in last and last[pb.name].dot(q) < 0:
                q.negate()
            last[pb.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=k)
            if pb.name == "root":
                pb.location = key[pb.name][0]
                pb.keyframe_insert("location", frame=k)
    for fc in (c for lay in act.layers for st in lay.strips for bag in st.channelbags for c in bag.fcurves):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    speeds = []
    for s in "LR":                                       # the floor's speed under each planted sole, key to key
        for k in range(n):
            (p0, v0), (p1, v1) = soles[k][s], soles[(k + 1) % n][s]
            both = (v0[:, 2] < CONTACT) & (v1[:, 2] < CONTACT)
            if p0 and p1 and both.any():
                speeds.append(float(np.linalg.norm((v1[both, :2] - v0[both, :2]).mean(0))) * FPS * SIZE)
    sp = np.array(speeds)
    near = 100.0 * np.mean(np.abs(sp / g["speed"] - 1) < 0.05)
    print("GAIT %s %d keys %.3f s, %.2f steps/s, step %.2f m; planted sole %.2f m/s (%.0f%% of its keys within 5%% of loco %.1f, %.2f to %.2f); "
          "leg reach %.3f planted %.3f in the air, ankle miss %.4f m; hammer head %.3f to %.3f m off the floor (was %.3f)" % (
              name, n + 1, g["period"], 2 / g["period"], g["speed"] * g["period"] / 2, np.median(sp), near, g["speed"], sp.min(),
              sp.max(), ext[0], ext[1], miss, min(low), max(low), min(old_low)))


for gait_name, gait in GAITS.items():
    bake(gait_name, gait)
arm.animation_data.action = None
for ac in list(bpy.data.actions):
    if ac.name not in GAITS:
        bpy.data.actions.remove(ac)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS")
