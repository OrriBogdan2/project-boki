"""Kael's Finishing Slam (RMB tap, clip `slam`) re-keyed as a two-handed overhead smash (owner 11-17: "he's like
lowering it - it's meant to be an overhead swing smash"). Blender only keys the bones (no mesh is touched): the
clip is built pose by pose at 60 fps from a few beats, each solved with a two-bone IK for the arms and legs, and only
the `slam` action is exported; tools/art1/glb_add_clips.py then puts it into the game glb, every other byte kept.

Beats (s; the kit's wind-up is juggernaut.json rmb.windup = 0.6 s, the damage tick, so the blade lands at 0.6):
  0.00 ready (the clip's own first pose)
  0.20 raised: both hands on the grip over the head, blade straight up and tipping back (the read from above)
  0.48 loaded: sunk, chest open, the blade laid back behind the head
  0.48-0.60 the arc: over the top and down in front, accelerating (ease-in), the lead foot stepping in
  0.60 impact: blade tip at the ground ahead, crouched, torso over it; a hard stop
  0.60-0.78 hold (a small compression), 0.78-1.15 recover into the ready pose

Run:
  blender -b --factory-startup --python tools/art1/kael_slam_smash.py -- art/wardens/kael/kael.glb OUT_slam.glb
  python3 tools/art1/glb_add_clips.py art/wardens/kael/kael.glb OUT_slam.glb =slam
"""
import math
import sys

import bpy
from mathutils import Matrix, Quaternion, Vector

FPS = 60
LENGTH = 1.15
IMPACT = 0.60
SRC, OUT = sys.argv[-2], sys.argv[-1]

bpy.context.scene.render.fps = FPS
bpy.ops.import_scene.gltf(filepath=SRC)
arm = [o for o in bpy.data.objects if o.type == "ARMATURE"][0]
P = arm.pose.bones
src = bpy.data.actions["slam"]
arm.animation_data.action = src
bpy.context.scene.frame_set(0)
vl = bpy.context.view_layer
vl.update()
READY = {b.name: (b.location.copy(), b.rotation_quaternion.copy(), b.scale.copy()) for b in P}
READY_M = {b.name: b.matrix.copy() for b in P}
arm.animation_data.action = None


def anchor_local(name, bone="hand.R"):
    return READY_M[bone].inverted() @ bpy.data.objects[name].matrix_world.translation


# the blade in the hand's own frame: its axis (root -> mid anchors), its flat's normal (the sword verts' thinnest axis)
a_root, a_mid = anchor_local("anchor_blade_root"), anchor_local("anchor_blade_mid")
BLADE = (a_mid - a_root).normalized()
body = bpy.data.objects["Body"]
gi = body.vertex_groups["hand.R"].index
sword_mats = {i for i, m in enumerate(body.data.materials) if m and ("sword" in m.name or "grip" in m.name)}
vs = set()
for p in body.data.polygons:
    if p.material_index in sword_mats:
        vs.update(p.vertices)
rest_h = arm.data.bones["hand.R"].matrix_local.inverted() @ body.matrix_world
pts = [rest_h @ body.data.vertices[i].co for i in vs
       if any(g.group == gi and g.weight > 0.5 for g in body.data.vertices[i].groups)]
along = [(p - a_root).dot(BLADE) for p in pts]
TIP = a_root + BLADE * max(along)
# thinnest axis across the blade: try directions perpendicular to BLADE, keep the one with the least spread
ref = Vector((1, 0, 0)) if abs(BLADE.x) < 0.9 else Vector((0, 1, 0))
e1 = BLADE.cross(ref).normalized()
e2 = BLADE.cross(e1).normalized()
best = None
for k in range(36):
    ang = math.pi * k / 36
    n = e1 * math.cos(ang) + e2 * math.sin(ang)
    vals = [(p - a_root).dot(n) for p in pts if (p - a_root).dot(BLADE) > 0.1]
    spread = max(vals) - min(vals)
    if best is None or spread < best[0]:
        best = (spread, n)
FLAT = best[1]
print("SMASH blade len %.3f m from the hand, %d sword verts, flat spread %.3f" % ((TIP).length, len(pts), best[0]))


def ss(u):
    u = min(1.0, max(0.0, u))
    return u * u * (3 - 2 * u)


def lerp(a, b, u):
    return a + (b - a) * u


def vlerp(a, b, u):
    return a.lerp(b, u)


# --------------------------------------------------------------------------- the beats
W0 = READY_M["hand.R"].translation.copy()
B0 = (READY_M["hand.R"].to_3x3() @ BLADE).normalized()
PHI0 = math.degrees(math.atan2(B0.y, B0.z))           # sagittal angle of the blade: 0 up, +90 ahead, -90 behind
FOOT_L0 = READY_M["shin.L"] @ Vector((0, arm.data.bones["shin.L"].length, 0))
FOOT_R0 = READY_M["shin.R"] @ Vector((0, arm.data.bones["shin.R"].length, 0))
HL0 = READY_M["hand.L"].translation.copy()

RAISE = {"t": 0.20, "W": Vector((0.07, -0.03, 1.58)), "phi": -35.0, "lean": 9.0, "drop": 0.03, "fwd": -0.03, "yaw": -6.0}
LOAD = {"t": 0.48, "W": Vector((0.08, -0.10, 1.55)), "phi": -112.0, "lean": 22.0, "drop": 0.08, "fwd": -0.06, "yaw": -12.0}
HIT = {"t": IMPACT, "W": Vector((0.04, 0.50, 0.62)), "phi": 116.0, "lean": -38.0, "drop": 0.17, "fwd": 0.10, "yaw": 4.0}
SETTLE = {"t": 0.70, "dW": Vector((0, 0.01, -0.02)), "lean": -41.0, "drop": 0.20}
HOLD_END = 0.78
STEP_L = Vector((-0.22, 0.40, FOOT_L0.z))
BACK_R = Vector((0.23, -0.26, FOOT_R0.z))


def beat(t):
    """The pose's controls at t: grip W (hand.R head), blade angle phi, torso lean (deg, + back), root drop/forward,
    yaw (deg), feet targets, left-hand weight on the grip, blend to the ready pose."""
    c = {"ready_w": 0.0, "lw": 1.0}
    if t <= RAISE["t"]:
        u = t / RAISE["t"]
        e = 1 - (1 - u) ** 2                                       # ease-out: the raise snaps up
        c["W"] = vlerp(W0, RAISE["W"], e) + Vector((0, 0.06, 0.05)) * math.sin(math.pi * e)
        c["phi"] = lerp(PHI0, RAISE["phi"], e)
        for k in ("lean", "drop", "fwd", "yaw"):
            c[k] = lerp(0.0, RAISE[k], ss(u))
        c["lw"] = ss(u / 0.6)
        c["ready_w"] = 1 - ss(u / 0.25)
        c["fl"], c["fr"] = FOOT_L0, vlerp(FOOT_R0, BACK_R, ss(u)) + Vector((0, 0, 0.05 * math.sin(math.pi * u)))
    elif t <= LOAD["t"]:
        u = ss((t - RAISE["t"]) / (LOAD["t"] - RAISE["t"]))
        c["W"] = vlerp(RAISE["W"], LOAD["W"], u)
        c["phi"] = lerp(RAISE["phi"], LOAD["phi"], u)
        for k in ("lean", "drop", "fwd", "yaw"):
            c[k] = lerp(RAISE[k], LOAD[k], u)
        c["fl"], c["fr"] = FOOT_L0, BACK_R
    elif t <= IMPACT:
        u = (t - LOAD["t"]) / (IMPACT - LOAD["t"])
        e = u * u                                                  # ease-in: fastest at the impact
        c["phi"] = lerp(LOAD["phi"], HIT["phi"], e)
        c["W"] = vlerp(LOAD["W"], HIT["W"], ss(e)) + Vector((0, 0.10, 0.10)) * math.sin(math.pi * e)
        for k in ("lean", "drop", "fwd", "yaw"):
            c[k] = lerp(LOAD[k], HIT[k], ss(e))
        s = min(1.0, max(0.0, (t - 0.46) / 0.12))
        c["fl"] = vlerp(FOOT_L0, STEP_L, ss(s)) + Vector((0, 0, 0.07 * math.sin(math.pi * s)))
        c["fr"] = BACK_R
    else:
        c["fl"], c["fr"] = STEP_L, BACK_R
        if t <= SETTLE["t"]:
            u = ss((t - IMPACT) / (SETTLE["t"] - IMPACT))
            c["W"] = HIT["W"] + SETTLE["dW"] * u
            c["phi"] = HIT["phi"]
            c["lean"], c["drop"] = lerp(HIT["lean"], SETTLE["lean"], u), lerp(HIT["drop"], SETTLE["drop"], u)
            c["fwd"], c["yaw"] = HIT["fwd"], HIT["yaw"]
        else:
            u = ss((t - HOLD_END) / (LENGTH - HOLD_END)) if t > HOLD_END else 0.0
            c["W"] = vlerp(HIT["W"] + SETTLE["dW"], W0, u)
            c["phi"] = lerp(HIT["phi"], PHI0, u)
            c["lean"], c["drop"] = lerp(SETTLE["lean"], 0.0, u), lerp(SETTLE["drop"], 0.0, u)
            c["fwd"], c["yaw"] = lerp(HIT["fwd"], 0.0, u), lerp(HIT["yaw"], 0.0, u)
            c["lw"] = 1 - ss((t - HOLD_END) / 0.25)
            s = ss((t - 0.84) / 0.24)
            c["fl"] = vlerp(STEP_L, FOOT_L0, s) + Vector((0, 0, 0.05 * math.sin(math.pi * s)))
            c["fr"] = vlerp(BACK_R, FOOT_R0, ss((t - 0.9) / 0.22))
            c["ready_w"] = ss((t - 0.95) / (LENGTH - 0.95))
    return c


# --------------------------------------------------------------------------- solving a pose
def reset():
    for b in P:
        loc, rot, scl = READY[b.name]
        b.location, b.rotation_quaternion, b.scale = loc, rot, scl
    vl.update()


def set_rot(name, q_arm):
    """Bone `name` turned to the armature-space rotation q_arm, its head where it is."""
    b = P[name]
    b.matrix = Matrix.LocRotScale(b.head.copy(), q_arm, None)
    vl.update()


def turn_to(name, child_head, want_dir):
    """Turn bone `name` (minimal turn) so the line from its head to `child_head` points along want_dir."""
    b = P[name]
    cur = (child_head() - b.head).normalized()
    q = cur.rotation_difference(want_dir.normalized())
    set_rot(name, q @ b.matrix.to_quaternion())


def two_bone(upper, lower, end_head, target, pole):
    S = P[upper].head.copy()
    l1 = (P[lower].head - S).length
    l2 = (end_head() - P[lower].head).length
    d = target - S
    dist = min(max(d.length, abs(l1 - l2) + 1e-3), (l1 + l2) * 0.999)
    u = d.normalized()
    a = (l1 * l1 + dist * dist - l2 * l2) / (2 * dist)
    h = math.sqrt(max(0.0, l1 * l1 - a * a))
    pp = (pole - u * pole.dot(u)).normalized()
    E = S + u * a + pp * h
    turn_to(upper, lambda: P[lower].head, E - S)
    turn_to(lower, end_head, S + u * dist - P[lower].head)


def hand_frame(phi, sign):
    d = Vector((0.0, math.sin(math.radians(phi)), math.cos(math.radians(phi)))).normalized()
    n = Vector((sign, 0.0, 0.0))
    n = (n - d * n.dot(d)).normalized()
    a, b = BLADE, (FLAT - BLADE * FLAT.dot(BLADE)).normalized()
    m_local = Matrix((a, b, a.cross(b))).transposed()
    m_want = Matrix((d, n, d.cross(n))).transposed()
    return (m_want @ m_local.inverted()).to_quaternion(), d


# which side the flat faces: the sign that keeps the ready pose's flat (continuity)
F0 = READY_M["hand.R"].to_3x3() @ FLAT
SIGN = 1.0 if F0.x >= 0 else -1.0


def pose(t):
    c = beat(t)
    reset()
    root = P["root"]
    m = root.matrix.copy()
    m.translation = m.translation + Vector((0, c["fwd"], -c["drop"]))
    root.matrix = m
    vl.update()
    tq = Quaternion((0, 0, 1), math.radians(c["yaw"])) @ Quaternion((1, 0, 0), math.radians(c["lean"]))
    set_rot("hips", tq @ P["hips"].matrix.to_quaternion())
    set_rot("head", Quaternion((1, 0, 0), math.radians(-0.55 * c["lean"])) @ P["head"].matrix.to_quaternion())
    # right arm to the grip, then the hand turned so the blade points along phi (flat across the swing)
    W = c["W"]
    two_bone("upper_arm.R", "forearm.R", lambda: P["hand.R"].head, W, Vector((1.0, -0.2, -0.5)))
    qh, d = hand_frame(c["phi"], SIGN)
    set_rot("hand.R", qh)
    # left hand on the grip below the right (blended in from its ready place)
    grip = P["hand.R"].matrix @ a_root - d * 0.30
    hl = vlerp(HL0, grip + Vector((-0.04, 0, 0)), c["lw"])
    two_bone("upper_arm.L", "forearm.L", lambda: P["hand.L"].head, hl, Vector((-1.0, -0.2, -0.5)))
    # legs to the feet targets, knees ahead
    for side, f in (("L", c["fl"]), ("R", c["fr"])):
        sh = P["shin." + side]
        two_bone("thigh." + side, "shin." + side, lambda sh=sh: sh.tail, f,
                 Vector((0.3 if side == "R" else -0.3, 1.0, 0.0)))
    tip = P["hand.R"].matrix @ TIP
    # blend to the ready pose at the start and the end
    out = {}
    for b in P:
        loc, rot = b.location.copy(), b.rotation_quaternion.copy()
        rl, rr, _ = READY[b.name]
        if rot.dot(rr) < 0:
            rot.negate()
        out[b.name] = (loc.lerp(rl, c["ready_w"]), rot.slerp(rr, c["ready_w"]))
    return out, tip


act = bpy.data.actions.new("slam_new")
arm.animation_data.action = act
nf = int(round(LENGTH * FPS))
prev = {}
for f in range(nf + 1):
    t = f / FPS
    if f % 2 and not 0.40 <= t <= 0.72:
        continue                                          # 30 keys/s, 60 through the arc and the impact
    out, tip = pose(t)
    if f % 6 == 0 or abs(t - IMPACT) < 1e-6:
        print("SMASH t=%.2f tip (%.2f, %.2f, %.2f) grip %s" % (t, tip.x, tip.y, tip.z,
              tuple(round(x, 2) for x in P["hand.R"].head)))
    for b in P:
        loc, rot = out[b.name]
        if b.name in prev and rot.dot(prev[b.name]) < 0:
            rot.negate()                                  # (no flips between keys)
        prev[b.name] = rot
        b.location, b.rotation_quaternion = loc, rot
        if b.name == "root":
            b.keyframe_insert("location", frame=f)        # (only the root moves; every other head stays put)
        b.keyframe_insert("rotation_quaternion", frame=f)
for fc in act.fcurves:
    for k in fc.keyframe_points:
        k.interpolation = "LINEAR"

# only the new slam goes out: every other action dropped, the new one named slam
for a in list(bpy.data.actions):
    if a != act:
        bpy.data.actions.remove(a)
act.name = "slam"
for o in bpy.data.objects:
    o.select_set(o == arm)
bpy.context.scene.frame_start, bpy.context.scene.frame_end = 0, nf
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True, export_animations=True,
                          export_animation_mode="ACTIONS", export_force_sampling=False, export_skins=True,
                          export_optimize_animation_size=False)
print("SMASH wrote", OUT)
