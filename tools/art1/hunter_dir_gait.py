"""A Hunter's walk/run back, side and diagonal loops on the animation pilot's recipe (tools/art1/breaker_gait.py on
ext/anim-pilot-albert-neve, the Tarek/Vex walk_f/run_f of ext/anim-tarek-pilot): a closed left + right cycle, each
stance sole pinned to a floor that passes under him at his loco speed, the soles set on the floor from the skinned
foot verts. Each loop takes its length, right-foot strike key, fore-aft lean and floor from the shipped forward loop,
so a ring's neighbours blend in step. A stance never travels further than an upright leg reaches (REACH): a step
longer than that is flown. The hip rides a set height over the planted leg (RIDE) and dips only where a stride end
outreaches it, so mid stance stands tall. Off the forward line the pelvis turns up to
TURN degrees into the move (back half: its back to the move), so the feet pass and never cross, while the chest keeps
the source clip's facing. The upper body (arms, head, weapon, springs) is the shipped clip of that direction (a
diagonal takes the forward or back one), resampled to the new length and put in phase with the new legs.
  blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- SRC.glb OUT.glb WALK_SPEED RUN_SPEED
  python3 tools/art1/glb_add_clips.py SRC.glb OUT.glb walk_b,walk_l,...,run_br"""
import math
import sys

import bpy
import numpy as np
from mathutils import Matrix, Vector

SRC, OUT, WALK, RUN, *MORE = sys.argv[sys.argv.index("--") + 1:]
BUILD = [d for d in (MORE[0] if MORE else "b,l,r,fl,fr,bl,br").split(",") if d]   # the directions to rebuild; "" only measures
LENGTH = {"walk": float(MORE[1]) if len(MORE) > 1 else 0.0, "run": float(MORE[2]) if len(MORE) > 2 else 0.0}   # s, 0 = the f loop's
SPEED = {"walk": float(WALK), "run": float(RUN)}   # model m/s: the game's loco m/s over the model's in-game scale
                                                  # (Neve stands at 0.867: 2.2 / 4.6 m/s in game are 2.54 / 5.31 here)
FPS = 48            # keys per second
CONTACT = 0.012     # m: a sole vert this close to the floor is planted
TURN = 40.0         # deg: the most the pelvis turns into the move, the chest stays on the source clip's facing
WIDEN = 0.035       # m: each foot steps this much wider in a side step
ROLL = 4.0          # deg: the pelvis rolls onto the planted foot (the weight shift)
SWAY = 0.018        # m: and the pelvis rides over it
REACH = 0.8        # leg lengths: the most a stance sole travels (a longer step is flown: a shorter stance, not a crouch)
SWING = 0.2        # leg lengths: the highest a swing sole lifts
RIDE = {"walk": 0.985, "run": 0.95}   # leg lengths: the hip over a planted leg (a walk stands tall, a run rides a bent knee)
G = 9.8            # m/s2: a flown step rises and falls on it
MEET = 0.95        # of the loco speed: how fast a swing foot comes back to meet the floor (1: no scuff at the strike)
PIVOT_MAX = 65.0   # deg: how far a sole may pivot on its heel or toe to stay in reach
TOE_UP, HEEL_UP = 10.0, 30.0   # deg: the sole's pitch at the strike and at the push (mirrored walking backwards)
DIRS = {"f": Vector((0, 1, 0)), "b": Vector((0, -1, 0)), "l": Vector((-1, 0, 0)), "r": Vector((1, 0, 0))}
DIRS.update({a + b: (DIRS[a] + DIRS[b]).normalized() for a in "fb" for b in "lr"})
LEGS = ("thigh", "shin", "foot")
LEG_BONES = ["%s.%s" % (n, s) for n in LEGS for s in "LR"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = next(o for o in bpy.data.objects if o.type == "ARMATURE")
body = max((o for o in bpy.data.objects if o.type == "MESH" and "foot.L" in o.vertex_groups),
           key=lambda o: len(o.data.vertices))
layer = bpy.context.view_layer
PB = arm.pose.bones
REST = {b.name: b.matrix_local.copy() for b in arm.data.bones}
TO_ARM = arm.matrix_world.inverted()
for pb in PB:
    pb.rotation_mode = "QUATERNION"


def rot(axis, deg):
    return Matrix.Rotation(math.radians(deg), 4, axis)


def smooth(a, b, x):
    u = min(1.0, max(0.0, (x - a) / (b - a)))
    return u * u * (3 - 2 * u)


def verts(idx):
    """Skinned foot verts in armature space (x his right, y ahead, z up), as the pose stands."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = body.evaluated_get(dg)
    me = ev.to_mesh()
    co = np.empty(len(me.vertices) * 3, np.float32)
    me.vertices.foreach_get("co", co)
    ev.to_mesh_clear()
    m = TO_ARM @ body.matrix_world
    return co.reshape(-1, 3)[idx] @ np.array(m.to_3x3()).T + np.array(m.translation)


def foot_idx(side):
    g = body.vertex_groups["foot." + side].index
    return np.array([v.index for v in body.data.vertices if any(e.group == g and e.weight > 0.3 for e in v.groups)])


FOOT = {s: foot_idx(s) for s in "LR"}
arm.animation_data_create()
arm.animation_data.action = None
for pb in PB:
    pb.matrix_basis = Matrix()
layer.update()
SOLE = {}           # per side: the ankle's rest place, the heel and toe ends of the sole from it (m, along y), its height
for s in "LR":
    co = verts(FOOT[s])
    low = co[co[:, 2] < co[:, 2].min() + 0.012]
    ankle = REST["foot." + s].translation
    SOLE[s] = (ankle.copy(), float(low[:, 1].min() - ankle.y), float(low[:, 1].max() - ankle.y), float(ankle.z - co[:, 2].min()))


def action(clip):
    """The imported clip's armature action (the importer may suffix it with the object's name)."""
    act = bpy.data.actions.get(clip) or next((a for a in bpy.data.actions if a.name.startswith(clip + "_") and
                                              not a.name.endswith("_was") and "Armature" in a.name), None)
    if act is None:
        raise SystemExit("no action %s in %s" % (clip, sorted(a.name for a in bpy.data.actions)[:20]))
    return act


LEG = ((REST["shin.L"].translation - REST["thigh.L"].translation).length
       + (REST["foot.L"].translation - REST["shin.L"].translation).length)
HIP_IN_ROOT = REST["root"].inverted() @ ((REST["thigh.L"].translation + REST["thigh.R"].translation) / 2)


def frames(clip):
    act = action(clip)
    arm.animation_data.action = act
    return int(round(act.frame_range[1]))


def read(clip):
    """A shipped loop, key by key: each bone's basis, the root's armature matrix, and each sole's lowest point."""
    n = frames(clip)
    out = []
    for f in range(n):
        scene.frame_set(f)
        out.append(dict(basis={pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB},
                        hips=PB["hips"].matrix.copy(), root=PB["root"].matrix.copy(),
                        low={s: float(verts(FOOT[s])[:, 2].min()) for s in "LR"},
                        co={s: verts(FOOT[s]) for s in "LR"},
                        ankle={s: PB["foot." + s].head.copy() for s in "LR"},
                        hc=(PB["thigh.L"].head + PB["thigh.R"].head) / 2))
    floor = float(np.percentile([k["low"][s] for k in out for s in "LR"], 20))
    on = np.array([k["low"]["R"] < floor + CONTACT for k in out])
    strikes = [i for i in range(n) if on[i] and not on[i - 1]]
    lifts = [i for i in range(n) if not on[i] and on[i - 1]]
    strike = strikes[0] if strikes else 0
    lift = next((i for i in lifts if (i - strike) % n > 0), (strike + n // 2) % n)
    return dict(keys=out, n=n, floor=floor, strike=strike, duty=float(on.mean()), lift_at=lift,
                swing=max(k["low"]["R"] for k in out) - floor)


def leg_ik(side, ankle, foot_turn, pole):
    """Two bones from the hip to the ankle, the knee toward `pole`; then the foot at its own angle. Returns the miss."""
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
    side_pole = pole - u * u.dot(pole)
    knee_to = hip + u * x + side_pole.normalized() * math.sqrt(max(0.0, l1 * l1 - x * x))
    turn_about(th, (knee - hip).rotation_difference(knee_to - hip).to_matrix().to_4x4())
    turn_about(sh, (ft.head - sh.head).rotation_difference(hip + u * d - sh.head).to_matrix().to_4x4())
    ft.matrix = Matrix.Translation(ft.head) @ foot_turn @ REST[ft.name].to_3x3().to_4x4()
    layer.update()
    for pb in (th, sh, ft):
        pb.location = (0, 0, 0)
    layer.update()
    return (ft.head - ankle).length


def turn_about(pb, turn):
    at = Matrix.Translation(pb.head)
    pb.matrix = at @ turn @ at.inverted() @ pb.matrix
    layer.update()


class Gait:
    """One directional loop shaped by the shipped forward loop of the same gait."""

    def __init__(self, gait, k, fwd):
        self.speed = SPEED[gait]
        self.n, self.floor = round(LENGTH[gait] * FPS) or fwd["n"], fwd["floor"]
        self.period = self.n / FPS
        self.duty = min(fwd["duty"], REACH * LEG / (self.speed * self.period))
        self.shift = round(fwd["strike"] * self.n / fwd["n"])   # the right strike falls on the forward loop's key
        self.d = DIRS[k]
        off = math.degrees(math.atan2(self.d.x, self.d.y))    # the move: 0 ahead, 90 to his right, 180 back
        into = min(abs(off), TURN) if abs(off) <= 90 else -min(180 - abs(off), TURN)
        self.yaw = -math.copysign(1.0, off) * into         # (z up: a right step turns the pelvis clockwise)
        self.face = rot("Z", self.yaw)
        self.widen = WIDEN * abs(self.d.x)
        self.along = self.face.to_3x3().inverted() @ self.d   # the path in the pelvis's frame
        self.travel = self.speed * self.duty * self.period
        a = fwd["keys"][fwd["strike"]]["ankle"]["R"].y
        b = fwd["keys"][fwd["lift_at"]]["ankle"]["R"].y
        hips = float(np.mean([key["hc"].y for key in fwd["keys"]]))
        self.lean = Vector((0, min(max(0.5 * (a + b) - hips, -0.04), 0.04), 0))   # the stance's middle ahead of the hips
        self.lift = min(max(fwd["swing"], 0.04), SWING * LEG)
        flown = max(0.0, 0.5 - self.duty) * self.period    # s in the air between two stances
        self.hip = self.floor + SOLE["R"][3] + RIDE[gait] * LEG
        self.bob = min(0.05, G * flown * flown / 8)

    def path(self, side, ph, off):
        """One foot at phase ph (0 = its strike): the flat-foot ankle place, its pitch and whether it is planted."""
        ankle = SOLE[side][0]
        sgn = 1 if side == "R" else -1
        home = self.face.to_3x3() @ Vector((ankle.x + sgn * self.widen, ankle.y, 0.0))
        home.z = self.floor
        front = self.travel / 2
        roll = self.along.y                                # +1 heel-to-toe, -1 backwards (toe first)
        if ph < self.duty:
            u = ph / self.duty
            pitch = roll * (TOE_UP * (1 - smooth(0.0, 0.16, u)) - HEEL_UP * smooth(0.7, 1.0, u) ** 1.4)
            return home + self.lean + self.d * (front - self.travel * u) + off, pitch, True
        s = (ph - self.duty) / (1 - self.duty)
        span = self.speed * (1 - self.duty) * self.period
        m0, m1 = -0.3 * span, -MEET * span                   # (a Hermite pass: it leaves the floor folding up, meets it near speed)
        h = (2 * s ** 3 - 3 * s * s + 1, s ** 3 - 2 * s * s + s, -2 * s ** 3 + 3 * s * s, s ** 3 - s * s)
        x = h[0] * (front - self.travel) + h[1] * m0 + h[2] * front + h[3] * m1
        side_out = self.face.to_3x3() @ Vector((sgn * 0.012 * math.sin(s * math.pi), 0, 0))
        pitch = roll * (-HEEL_UP + (HEEL_UP + TOE_UP) * smooth(0.08, 0.92, s))
        lift = Vector((0, 0, self.lift * math.sin(s ** 0.75 * math.pi) ** 0.9))
        return home + self.lean + self.d * x + side_out + lift + off * (1 - smooth(0.0, 0.6, s)), pitch, False

    def place(self, side, flat, pitch):
        """The ankle and foot turn for a sole that pivots on its heel (toe up) or its toe (heel up)."""
        _ankle, heel, toe, height = SOLE[side]
        ahead = self.face.to_3x3() @ Vector((0, 1, 0))
        axis = self.face.to_3x3() @ Vector((1, 0, 0))
        pivot = flat + ahead * (heel if pitch > 0 else toe)
        turn = Matrix.Rotation(math.radians(pitch), 4, axis)
        return pivot + turn.to_3x3() @ (flat + Vector((0, 0, height)) - pivot), turn @ self.face


    def reach(self, side, flat, pitch):
        """place(), the sole pivoting further onto its heel (ahead) or toe (behind) while the hip can't reach it."""
        hip = PB["thigh." + side].head
        ahead = (flat - hip).dot(self.face.to_3x3() @ Vector((0, 1, 0)))
        sign = 1.0 if ahead > 0 else -1.0
        ankle, turn = self.place(side, flat, pitch)
        while (ankle - hip).length > 0.995 * LEG and abs(pitch) < PIVOT_MAX:
            pitch = pitch + 4.0 * sign if pitch * sign >= 0 else 0.0
            nearer = self.place(side, flat, pitch)
            if (nearer[0] - hip).length >= (ankle - hip).length:   # (a heel pivot lowers the ankle: past a point it costs reach)
                break
            ankle, turn = nearer
        return ankle, turn


def source_at(src, ph):
    """The shipped directional clip at phase ph of the new cycle (0 = right strike), by its own right strike."""
    t = (src["strike"] + ph * src["n"]) % src["n"]
    i = int(t)
    return src["keys"][i], src["keys"][(i + 1) % src["n"]], t - i


def pose(g, src, ph, feet, drop):
    a, b, u = source_at(src, ph)
    for pb in PB:
        (la, qa), (lb, qb) = a["basis"][pb.name], b["basis"][pb.name]
        pb.location, pb.rotation_quaternion = la.lerp(lb, u), qa.slerp(qb, u)
    for name in ["root"] + LEG_BONES:
        PB[name].matrix_basis = Matrix()
    mid = ph - g.duty / 2                                 # 0 at the right foot's mid stance
    onto = math.cos(mid * math.tau)                       # +1 weight on the right foot, -1 on the left
    rest_q = REST["root"].to_quaternion()
    src_q = a["root"].to_quaternion().slerp(b["root"].to_quaternion(), u)
    src_rot = (src_q @ rest_q.inverted()).to_euler("ZXY")   # (the source's pelvis pitch and roll; its yaw is ours)
    src_rot.z = 0.0
    turn = g.face @ rot("Y", ROLL * onto) @ src_rot.to_matrix().to_4x4() @ REST["root"].to_3x3().to_4x4()
    height = g.hip - g.bob * math.cos(2 * mid * math.tau)   # a flown step: lowest over each stance, highest between
    want = Vector((SWAY * onto, 0.0, height + drop))
    PB["root"].matrix = Matrix.Translation(want - turn.to_3x3() @ HIP_IN_ROOT) @ turn
    layer.update()
    hips = a["hips"].to_quaternion().slerp(b["hips"].to_quaternion(), u)    # the chest keeps the source's facing
    PB["hips"].matrix = Matrix.Translation(PB["hips"].head) @ rot("Y", 0.4 * ROLL * onto) @ hips.to_matrix().to_4x4()
    layer.update()
    pole = g.face.to_3x3() @ Vector((0, 1, 0))
    step = -g.d * g.speed / FPS
    worst = 0.0
    for side, start in (("R", 0.0), ("L", 0.5)):
        was = feet[side]
        _f, _p, planted = g.path(side, (ph + start) % 1.0, Vector())
        if planted and not was["planted"]:
            was["off"] = Vector()
        for turn_no in range(4):
            flat, pitch, planted = g.path(side, (ph + start) % 1.0, was["off"])
            ankle, turn = g.reach(side, flat, pitch)
            miss = leg_ik(side, ankle, turn, pole)
            low = float(verts(FOOT[side])[:, 2].min()) - g.floor
            if planted or low < 0:                        # the sole on the floor from the skinned verts: no hover, no sink
                ankle.z -= low - (PB["foot." + side].head.z - ankle.z)   # (less what a leg that fell short hangs above it)
                miss = leg_ik(side, ankle, turn, pole)
            now = verts(FOOT[side])
            both = ((now[:, 2] < g.floor + CONTACT) & (was["co"][:, 2] < g.floor + CONTACT)
                    if planted and was["planted"] else None)
            if both is None or not both.any() or turn_no == 3:
                break
            slip = (now[both, :2] - was["co"][both, :2]).mean(0)    # the lock: the planted patch moves with the floor
            was["off"] -= Vector((slip[0] - step.x, slip[1] - step.y, 0.0))
        was.update(co=now, planted=planted)
        worst = max(worst, miss if planted else 0.0)
    return worst


def bake(name, g, src):
    feet = {s: dict(co=verts(FOOT[s]), planted=False, off=Vector()) for s in "LR"}
    drop = np.zeros(g.n)
    for lap in range(5):     # lap 0 hands each swing its start; laps 1-3 dip the pelvis where a step outreaches the leg
        keys, soles, miss = [], [], np.zeros(g.n)
        for k in range(g.n):
            miss[k] = pose(g, src, (k - g.shift) % g.n / g.n, feet, drop[k])
            keys.append({pb.name: (pb.location.copy(), pb.rotation_quaternion.copy()) for pb in PB})
            soles.append({s: (feet[s]["planted"], feet[s]["co"].copy()) for s in "LR"})
        if lap in (1, 2, 3) and miss.max() > 0.003:
            need = miss * 1.15
            w = max(1, g.n // 12)                         # (widened, then smoothed round the loop: a dip, not a jolt)
            need = np.max([np.roll(need, i) for i in range(-w, w + 1)], 0)
            for _ in range(w):
                need = (np.roll(need, 1) + 2 * need + np.roll(need, -1)) / 4
            drop -= need
    worst = float(miss.max())
    keys.append(keys[0])
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm.animation_data.action = act
    last = {}
    for k, key in enumerate(keys):
        for pb in PB:
            if pb.name.startswith(("anchor_", "weapon_")):
                continue
            q = key[pb.name][1].copy()
            if pb.name in last and last[pb.name].dot(q) < 0:
                q.negate()
            last[pb.name] = q
            pb.rotation_quaternion = q
            pb.keyframe_insert("rotation_quaternion", frame=k)
            pb.location = key[pb.name][0]
            pb.keyframe_insert("location", frame=k)
    for fc in (c for lay in act.layers for st in lay.strips for bag in st.channelbags for c in bag.fcurves):
        for kp in fc.keyframe_points:
            kp.interpolation = "LINEAR"
    speeds = []
    for s in "LR":                                        # the floor's speed under each planted sole, key to key
        for k in range(g.n):
            (p0, v0), (p1, v1) = soles[k][s], soles[(k + 1) % g.n][s]
            both = (v0[:, 2] < g.floor + CONTACT) & (v1[:, 2] < g.floor + CONTACT)
            if p0 and p1 and both.any():
                speeds.append(float(np.linalg.norm((v1[both, :2] - v0[both, :2]).mean(0))) * FPS)
    sp = np.array(speeds) if speeds else np.zeros(1)
    print("GAIT %s %d keys %.3f s duty %.2f; planted sole %.2f m/s (%.0f%% within 5%% of %.2f, p90 off %.2f); worst ankle "
          "miss %.4f m, hip %.3f m, pelvis dip %.3f..%.3f m, bob %.3f; right strike key %d" % (
              name, g.n + 1, g.period, g.duty, np.median(sp), 100 * np.mean(np.abs(sp / g.speed - 1) < 0.05), g.speed,
              np.percentile(np.abs(sp - g.speed), 90), worst, g.hip, drop.min(), drop.max(), g.bob, g.shift))


def measure(name, src, speed):
    """The shipped loop's floor: the speed under each planted sole against the loco speed, and the pelvis's rise and fall."""
    sp = []
    for s in "LR":
        for k in range(src["n"]):
            a, b = src["keys"][k], src["keys"][(k + 1) % src["n"]]
            both = (a["co"][s][:, 2] < src["floor"] + CONTACT) & (b["co"][s][:, 2] < src["floor"] + CONTACT)
            if both.any():
                sp.append(float(np.linalg.norm((b["co"][s][both, :2] - a["co"][s][both, :2]).mean(0))) * FPS)
    sp = np.array(sp) if sp else np.zeros(1)
    hz = np.array([k["hc"].z for k in src["keys"]])
    print("WAS %s %d keys %.3f s duty %.2f; planted sole median %.2f p10 %.2f p90 %.2f m/s vs loco %.2f; hip height %.3f..%.3f"
          % (name, src["n"], src["n"] / FPS, src["duty"], np.median(sp), np.percentile(sp, 10), np.percentile(sp, 90), speed,
             hz.min(), hz.max()))


made = []
for gait in ("walk", "run"):
    shipped = {k: read("%s_%s" % (gait, k)) for k in "fblr"}
    fwd = shipped["f"]
    print("FWD %s_f %d keys floor %.3f strike %d lift %d duty %.2f swing %.3f" % (
        gait, fwd["n"], fwd["floor"], fwd["strike"], fwd["lift_at"], fwd["duty"], fwd["swing"]))
    for k in shipped:
        measure("%s_%s" % (gait, k), shipped[k], SPEED[gait])
    for k in BUILD:
        name = "%s_%s" % (gait, k)
        if k in shipped:
            action(name).name = name + "_was"
        arm.animation_data.action = None
        bake(name, Gait(gait, k, fwd), shipped[k[0]])
        made.append(name)
arm.animation_data.action = None
if not made:
    raise SystemExit(0)
for ac in list(bpy.data.actions):
    if ac.name not in made:
        bpy.data.actions.remove(ac)
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", export_animation_mode="ACTIONS")
