"""Meeko's walk and run loops (f, b, l, r) with her soles locked to the floor. pip_clips.py's gait() steps 3.2 and 5 times a second on
legs of 0.24 game m, so at her loco speeds (2.2 and 4.55 m/s) every planted foot skates. Here the cadence goes up and
each step carries a short float (she is small and light: a skipping trot and a bounding run), each stance sole is
pinned to a floor that passes under her at her loco speed, and the soles are set on the floor from the skinned verts.
Everything above the root (arms, the sun and cloud on the pauldrons, head, ears, wings) is her old clip's, resampled
by step phase, so her carry and personality stay hand-keyed; the root keeps its old turn and gets a new bob.
  python3 tools/art1/pip_feet_weights.py art/wardens/pip/pip.glb      # the paws on the foot bones first
  blender -b --factory-startup --python tools/art1/pip_gait.py -- art/wardens/pip/pip.glb OUT.glb
  python3 tools/art1/glb_add_clips.py art/wardens/pip/pip.glb OUT.glb \
      walk_f,walk_b,walk_l,walk_r,run_f,run_b,run_l,run_r
A second run on the shipped GLB starts from these clips' upper body, which is the old one, so it bakes the same."""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Quaternion, Vector

SRC, OUT = sys.argv[sys.argv.index("--") + 1:][:2]
SIZE = 0.68         # game metres per model metre (content/archetypes/tender.json body size)
FPS = 48            # keys per second (pip.glb.import bakes at this rate too): a run stance is 0.08 s
CONTACT = 0.006     # model m: a sole vert this close to the floor is planted
TAU = math.tau
# s for a left + right pair, every loop: WardenClips' BlendSpace2D (synced by pip.json loco.cycle_s) blends a
# ring's loops at a diagonal and the walk ring into the run ring between their speeds, and only loops of one length
# stay in step
PERIOD = 0.34
# Per gait. speed: game m/s (warden_anim/pip.json loco). duty: the part of the period a foot is planted (under 0.5: a
# float between steps). ahead: the share of the stance sweep in front of the hip. lift: swing foot's peak, model m.
# sink: the root's mean drop, bob: its rise in the float, model m. toe_up at the strike, heel_up at the push, degrees.
# Walk and run share duty and roll: between their speeds WardenClips blends the two at one phase (loco.cycle_s), and
# only feet that strike, roll and lift together stay down in the blend (--foot-slide-check: unequal duties put one
# foot in the air while the other is planted, 3.5 m/s slips at 3.5 m/s).
GAITS = {
    "walk": dict(speed=2.2, duty=0.25, ahead=0.52, lift=0.05, sink=-0.06, bob=0.012, toe_up=5.0,
                   heel_up=35.0, push=0.55),
    "run": dict(speed=4.55, duty=0.25, ahead=0.55, lift=0.085, sink=-0.075, bob=0.02, toe_up=5.0,
                  heel_up=35.0, push=0.55),
}
# A swing leaves and meets the floor at the floor's speed (x the move speed at its ends): a slower foot near the floor
# reads as a slide in the audits' 30 % band
SWING_ENDS = 1.0
# heading in degrees (as pip_clips.py's gait(): l is her left, -x) and the duty's share: her legs reach less behind
# and to the side than ahead, so those soles sweep less floor: down for less of the same period, a longer float
HEADINGS = {"f": (0.0, 1.0), "b": (180.0, 0.8), "l": (90.0, 0.62), "r": (-90.0, 0.62)}
LEGS = ("thigh", "shin", "foot")

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = bpy.data.objects["Pip"]
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


def verts(idx):
    """The skinned body's vertices in armature space (x her right, y ahead, z up), as the pose stands."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    to_arm = arm.matrix_world.inverted() @ body.matrix_world
    co = co.reshape(-1, 3) @ np.array(to_arm.to_3x3()).T + np.array(to_arm.translation)
    return co[idx]


def foot_idx(side):
    g = body.vertex_groups["foot." + side].index
    return np.array([v.index for v in body.data.vertices if any(e.group == g and e.weight > 0.5 for e in v.groups)], int)


FOOT = {s: foot_idx(s) for s in "LR"}
layer.update()
SOLE = {}           # per side: the ankle's rest place, and the heel and toe ends of the sole from it (m, along y)
for s in "LR":
    co = verts(FOOT[s])
    low = co[co[:, 2] < co[:, 2].min() + 0.01]
    ankle = REST["foot." + s].translation
    SOLE[s] = (ankle.copy(), float(low[:, 1].min() - ankle.y), float(low[:, 1].max() - ankle.y))


def old_keys(name, n):
    """The old clip at n even phases: every bone's local pose (the upper body carries over from it)."""
    act = bpy.data.actions[name]
    arm.animation_data.action = act
    end = act.frame_range[1]
    out = []
    for k in range(n):
        scene.frame_set(int(end * k / n), subframe=(end * k / n) % 1.0)
        out.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB})
    arm.animation_data.action = None
    act.name = name + "_was"
    return out


def about(name, turn):
    pb = PB[name]
    at = Matrix.Translation(pb.head)
    pb.matrix = at @ turn @ at.inverted() @ pb.matrix
    layer.update()


def leg_ik(side, ankle, foot_turn):
    """Two bones from the hip to the ankle, the knee ahead; then the foot at its own angle. Returns the miss and reach."""
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
    """One foot at phase ph (0 = its strike): the flat-foot ankle place, its pitch (toe up +), and whether it is planted.
    Along the heading d the foot runs the forward path; a backward step lands on the toe, a side step flat."""
    ankle = SOLE[side][0]
    d = g["d"]
    v = g["speed"] / SIZE
    duty, period = g["duty"], g["period"]
    travel = v * duty * period
    front = travel * g["ahead"]
    if ph < duty:
        u = ph / duty
        pitch = g["toe_up"] * (1 - smooth(0.0, 0.2, u)) - g["heel_up"] * smooth(g["push"], 1.0, u) ** 1.4
        return Vector((ankle.x, ankle.y, 0.0)) + d * (front - travel * u) + off, pitch * d.y, True
    s = (ph - duty) / (1 - duty)
    m0 = m1 = -SWING_ENDS * v * (1 - duty) * period
    h = (2 * s ** 3 - 3 * s * s + 1, s ** 3 - 2 * s * s + s, -2 * s ** 3 + 3 * s * s, s ** 3 - s * s)
    y = h[0] * (front - travel) + h[1] * m0 + h[2] * front + h[3] * m1
    pitch = -g["heel_up"] + (g["heel_up"] + g["toe_up"]) * smooth(0.1, 0.9, s)
    lift = g["lift"] * math.sin(s ** 0.75 * math.pi) ** 0.9
    return Vector((ankle.x, ankle.y, lift)) + d * y + off * (1 - smooth(0.0, 0.6, s)), pitch * d.y, False


def place_foot(side, flat, pitch):
    """The ankle for a sole that pivots on its heel (toe up) or its toe (heel up) at the flat-foot place `flat`."""
    ankle, heel, toe = SOLE[side]
    pivot = Vector((flat.x, flat.y + (heel if pitch > 0 else toe), flat.z))
    turn = rot("X", pitch)
    return pivot + turn.to_3x3() @ (Vector((flat.x, flat.y, flat.z + ankle.z)) - pivot), turn


def level_root():
    """The old clip's forward lean (pitch about x) off the root, onto the hips: the thighs hang from the root, so walk_f
    (7 deg) and run_f (12 deg) with their own lean put the hips in two places, and the walk-run blend slid the feet
    (2.7 m/s at 3.5-4 m/s). The upper body keeps its pose: the hips' armature matrix is put back."""
    hips = PB["hips"].matrix.copy()
    m = PB["root"].matrix.copy()
    rest = REST["root"].to_quaternion()
    d = m.to_quaternion() @ rest.inverted()
    pitch = Quaternion((d.w, d.x, 0.0, 0.0)).normalized()
    PB["root"].matrix = Matrix.Translation(m.translation) @ ((d @ pitch.inverted()) @ rest).to_matrix().to_4x4()
    layer.update()
    PB["hips"].matrix = hips
    layer.update()


def pose(g, key, ph, feet):
    """The whole body at phase ph (0 = the right foot strikes, 0.5 = the left): the old clip's key `key` above the root,
    the root's old turn on a new bob (lowest mid stance, highest in the float), and the legs locked to the floor."""
    for pb in PB:
        pb.location, pb.rotation_quaternion = key[pb.name]
    for name in ["%s.%s" % (n, s) for n in LEGS for s in "LR"]:
        PB[name].matrix_basis = Matrix()
    mid = ph - g["duty"] / 2
    PB["root"].location = (key["root"][0].x, key["root"][0].y, 0.0)
    layer.update()
    level_root()
    z = g["sink"] - g["bob"] * math.cos(mid * 2 * TAU)
    PB["root"].matrix = Matrix.Translation((0, 0, z)) @ PB["root"].matrix
    layer.update()
    step = -g["d"] * g["speed"] / SIZE / FPS
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
                low = float(verts(FOOT[side])[:, 2].min())
                if planted or low < 0:
                    ankle.z -= low
                    miss, ext = leg_ik(side, ankle, turn)
            now = verts(FOOT[side])
            both = (now[:, 2] < CONTACT) & (was["co"][:, 2] < CONTACT) if planted and was["planted"] else None
            if both is None or not both.any() or turn_no == 4:
                break
            slip = (now[both, :2] - was["co"][both, :2]).mean(0)     # the lock: the planted patch moves with the floor
            was["off"] -= Vector((slip[0] - step.x, slip[1] - step.y, 0.0))
        was.update(co=now, planted=planted, miss=miss, ext=ext)


def bake(name, g):
    n = int(round(g["period"] * FPS))
    old = old_keys(name, n)
    feet = {s: dict(co=verts(FOOT[s]), planted=False, off=Vector()) for s in "LR"}
    for _lap in range(2):                                # twice round: the first lap hands each swing its start
        keys, soles, miss, ext = [], [], 0.0, [0.0, 0.0]
        for k in range(n):
            pose(g, old[k], k / n, feet)
            keys.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB})
            soles.append({s: (feet[s]["planted"], feet[s]["co"].copy()) for s in "LR"})
            for s in "LR":
                on = feet[s]["planted"]
                miss = max(miss, feet[s]["miss"] if on else 0.0)
                ext[0 if on else 1] = max(ext[0 if on else 1], feet[s]["ext"])
    keys.append(keys[0])
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
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
    speeds = []
    for s in "LR":                                       # the floor's speed under each planted sole, key to key
        for k in range(n):
            (p0, v0), (p1, v1) = soles[k][s], soles[(k + 1) % n][s]
            both = (v0[:, 2] < CONTACT) & (v1[:, 2] < CONTACT)
            if p0 and p1 and both.any():
                speeds.append(float(np.linalg.norm((v1[both, :2] - v0[both, :2]).mean(0))) * FPS * SIZE)
    sp = np.array(speeds)
    print("GAIT %s %d keys %.3f s, %.2f steps/s, step %.2f m; planted sole %.2f m/s (%.2f to %.2f, loco %.2f); "
          "leg reach %.3f planted %.3f in the air, ankle miss %.4f m" % (
              name, n + 1, g["period"], 2 / g["period"], g["speed"] * g["period"] / 2, np.median(sp), sp.min(),
              sp.max(), g["speed"], ext[0], ext[1], miss))


for gait_name, gait in GAITS.items():
    for tag, (heading, share) in HEADINGS.items():
        h = math.radians(heading)
        bake("%s_%s" % (gait_name, tag), dict(gait, d=Vector((-math.sin(h), math.cos(h), 0.0)),
                                               period=PERIOD, duty=gait["duty"] * share))
arm.animation_data.action = None
for ac in list(bpy.data.actions):
    if ac.name.rsplit("_", 1)[0] not in GAITS:
        bpy.data.actions.remove(ac)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS")
