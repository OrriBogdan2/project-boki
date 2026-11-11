"""Gil's clips (ART-1), keyed by hand on the contract armature (fistkit, the right fist holds the swordfish) and timed to
his kit (content/archetypes/gil.json lmb, KMovesDJ gil_*), with the foot bones his boots plant on and the fish tail
skinned to its bone, then the .glb export:
  blender -b --factory-startup --python tools/art1/gil_clips.py -- art/wardens/gil/gil.glb [out.glb]
A pet fish a spell stood up on two legs, and thrilled by all of it: he never quite stands still, his head darts to
every new thing and holds there, the tail swishes when he is pleased, the free hand flutters like a fin, and he fences
like he read about it this morning: eager, on his toes, a beat too far into every thrust."""
import math
import os
import sys

import bpy
from mathutils import Vector

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "blender"))
import fistkit as A  # noqa: E402
import warden_kit as K  # noqa: E402

a = sys.argv[sys.argv.index("--") + 1:]
SRC = a[0]
OUT = a[1] if len(a) > 1 else SRC
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
arm = bpy.data.objects["Armature"]
tau = math.tau

# ---------------------------------------------------------------------- the rig's additions
FOOT_LEN = 0.1                 # m: the foot bone, ankle to the ball of the boot
FOOT_TOP, FOOT_BLEND = 0.085, 0.05   # m: the boot is all foot below FOOT_TOP - FOOT_BLEND, all shin above FOOT_TOP
TOE_Y = 0.02                   # m ahead of the ankle: the curled toe is foot whatever its height
TAIL_ROOT = Vector((0.0, -0.12, 0.40))   # where the tail leaves the coat: stays on hips
TAIL_FREE = 0.15               # m from there: fully on the tail bone


def sstep(x):
    x = min(1.0, max(0.0, x))
    return x * x * (3 - 2 * x)


def add_feet_and_tail():
    """foot.L / foot.R at the ankles (shin's end) with the boots moved onto them, and the Tail mesh onto the tail bone
    (it rode hips rigidly), so the boots stay flat on the ground as the shins tilt and the tail can swish."""
    if "foot.R" in arm.data.bones:
        return
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for s in ("L", "R"):
        shin = arm.data.edit_bones["shin." + s]
        eb = arm.data.edit_bones.new("foot." + s)
        eb.head = shin.tail.copy()
        eb.tail = shin.tail + Vector((0, FOOT_LEN, 0))
        eb.parent = shin
    bpy.ops.object.mode_set(mode="OBJECT")
    body = bpy.data.objects["Body"]
    for s in ("L", "R"):
        shin, foot = body.vertex_groups["shin." + s], body.vertex_groups.new(name="foot." + s)
        ank = arm.data.bones["foot." + s].head_local
        for v in body.data.vertices:
            w = next((g.weight for g in v.groups if g.group == shin.index), 0.0)
            if w <= 0.0:
                continue
            k = sstep((FOOT_TOP - v.co.z) / FOOT_BLEND)
            if v.co.z < 0.12:
                k = max(k, sstep((v.co.y - ank.y - TOE_Y) / 0.04))
            if k > 1e-3:
                shin.add([v.index], w * (1 - k), "REPLACE")
                foot.add([v.index], w * k, "REPLACE")
    tail = bpy.data.objects["Tail"]
    hips, tb = tail.vertex_groups["hips"], tail.vertex_groups["tail"]
    for v in tail.data.vertices:
        k = sstep((v.co - TAIL_ROOT).length / TAIL_FREE)
        hips.add([v.index], 1 - k, "REPLACE")
        tb.add([v.index], k, "REPLACE")


add_feet_and_tail()
for act in list(bpy.data.actions):      # (a rerun on its own output bakes the clips afresh)
    bpy.data.actions.remove(act)
if arm.animation_data:
    for tr in list(arm.animation_data.nla_tracks):
        arm.animation_data.nla_tracks.remove(tr)
REST = {b.name: b.head_local.copy() for b in arm.data.bones}
AX, AZ = float(REST["foot.R"].x), float(REST["foot.R"].z)
SX, SZ = float(REST["upper_arm.R"].x), float(REST["upper_arm.R"].z)
arm.data.pose_position = "REST"      # (a rerun's import leaves a clip's pose on the hand: read the bill at rest)
bpy.context.view_layer.update()
BLADE = bpy.data.objects["weapon_muzzle"].matrix_world.translation - REST["hand.R"]
arm.data.pose_position = "POSE"
C = A.Clips(arm, blade=BLADE)


def m(*ps, **kw):
    o = {}
    for p in ps:
        o.update(p)
    o.update(kw)
    return o


def add(p, c, v):
    p[c] = tuple(x + y for x, y in zip(p[c], v)) if not isinstance(p[c], (int, float)) else p[c] + v


def hand(x, y, z):
    """The right wrist, from the right shoulder (torso frame)."""
    return (SX + x, y, SZ + z)


def lhand(x, y, z):
    """The left wrist, from the left shoulder; + x is out."""
    return (-SX - x, y, SZ + z)


def yaw(v, deg):
    """A direction turned about up: the bill kept on the target while the torso turns side-on."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])


def bump(t, a, b, T, k=1.0):
    """0 outside a..b (on a loop of T s), a smooth hill inside it; k > 1 rises slowly and falls fast."""
    t %= T
    return math.sin(math.pi * ((t - a) / (b - a)) ** k) ** 2 if a < t < b else 0.0


def plateau(t, a, b, c, d, T, kind="io"):
    """0 before a, eases up to 1 by b, holds, eases back to 0 from c to d (on a loop of T s). snap: a dart and a hold."""
    t %= T
    u = min(1.0, max(0.0, (t - a) / (b - a))) if t < c else 1.0 - min(1.0, max(0.0, (t - c) / (d - c)))
    return A.ease(u, kind if t < c else "io")


def cyc(t, n, T, ph=0.0):
    return math.sin(tau * n * t / T + ph)


def lift_heel(p, s, deg):
    """The heel up, the boot rolled onto its ball (FOOT_LEN ahead of the ankle, 4 cm below)."""
    r = math.radians(deg)
    add(p, "f" + s, (0, FOOT_LEN * (1 - math.cos(r)) + 0.04 * math.sin(r), FOOT_LEN * math.sin(r) - 0.04 * (1 - math.cos(r))))
    add(p, "f" + s + "a", -deg)


# his rest: square on both feet, toes out, knees soft, the chin up at the world; the swordfish held low and forward,
# bill toward the ground ahead, the free hand a little out from the coat
LOOSE = dict(pos=(0.0, 0.0, -0.014), rot=(0, 0, 0), hips=(-3, 0, 0), head=(7, 0, 0), tail=(0, 0, 0),
             hr=hand(0.05, 0.11, -0.36), br=(0.18, 0.78, -0.6), hl=lhand(0.07, 0.03, -0.37), wl=(0, 0, 0),
             er=(0.8, -0.5, -0.2), el=(-0.8, -0.5, -0.2),
             fr=(AX + 0.02, -0.01, AZ), fl=(-AX - 0.02, 0.02, AZ), fra=0.0, fla=0.0, frt=-12.0, flt=12.0,
             kr=(0.2, 1, 0), kl=(-0.2, 1, 0))
SIDE = 24.0                    # deg: en garde, the torso turned side-on, sword side forward
# en garde as he imagines it: side-on, right foot forward at the target, the back foot turned out, knees well bent,
# the bill level at the foe and the free hand curled up behind his head like a fin
GUARD = m(LOOSE, pos=(0.0, -0.02, -0.055), hips=(-6, 0, SIDE), head=(5, 0, -SIDE + 4), tail=(0, 0, 8),
          hr=hand(-0.03, 0.17, -0.15), br=yaw((0, 1, 0.14), -SIDE), hl=lhand(0.02, -0.14, 0.2), wl=(0, 0, -35),
          er=(0.8, -0.5, -0.3), el=(-0.6, -0.6, 0.4),
          fr=(AX + 0.0, 0.16, AZ), fl=(-AX - 0.05, -0.12, AZ), frt=0.0, flt=50.0, kr=(0.05, 1, 0), kl=(-0.7, 1, 0))
STAND_T, GUARD_T = 4.8, 4.0


def breathe(t, p, T, n=2):
    b = 0.5 - 0.5 * cyc(t, n, T, math.pi / 2)
    add(p, "pos", (0, 0, 0.003 * b))
    add(p, "hips", (-1.2 * b, 0, 0))
    add(p, "head", (1.0 * b, 0, 0))


def idle_life(t, p):
    """Breath, and the world: his head darts to something on his left and holds, to the right and holds, comes back;
    then it is all too much: two bounces up on his toes, the free hand flapping, the tail going, and he settles."""
    T = STAND_T
    breathe(t, p, T)
    add(p, "pos", (0.008 * cyc(t, 1, T), 0, 0))
    add(p, "hips", (0, 1.2 * cyc(t, 1, T), 0))
    left = plateau(t, 0.25, 0.42, 1.5, 1.66, T, "snap")
    right = plateau(t, 1.66, 1.82, 2.6, 2.9, T, "snap")
    add(p, "head", (9.0 * left + 3.0 * right, -10.0 * left + 8.0 * right, 26.0 * left - 22.0 * right))
    add(p, "hips", (0, 0, 5.0 * left - 4.0 * right))
    bounce = bump(t, 3.1, 3.5, T) + bump(t, 3.5, 3.9, T)
    lift_heel(p, "r", 22.0 * bounce)
    lift_heel(p, "l", 22.0 * bounce)
    add(p, "pos", (0, 0.004 * bounce, 0.045 * bounce))
    add(p, "head", (6.0 * bounce, 0, 0))
    giddy = plateau(t, 3.0, 3.15, 3.95, 4.4, T)
    add(p, "hl", (-0.06 * giddy, 0.02 * giddy, 0.07 * giddy + 0.03 * giddy * cyc(t, 18, T)))
    add(p, "wl", (0, 0, 40.0 * giddy * cyc(t, 18, T)))
    add(p, "hr", (0, 0.02 * giddy, 0.03 * bounce))
    add(p, "tail", (6.0 * giddy * cyc(t, 18, T, 1.0), 0, 10.0 * cyc(t, 2, T) + 18.0 * giddy * cyc(t, 12, T)))


def guard_life(t, p):
    """The fencer's bounce, four to the loop, a little high and a little proud; the bill's tip draws small circles at
    the foe; the rear hand flutters; the tail swishes on the bounce."""
    T = GUARD_T
    breathe(t, p, T)
    b = 0.5 - 0.5 * cyc(t, 4, T, math.pi / 2)
    add(p, "pos", (0, 0, 0.016 * b))
    add(p, "head", (-2.0 * b, 0, 0))
    add(p, "br", (0.06 * cyc(t, 2, T), 0, 0.06 * cyc(t, 2, T, math.pi / 2)))
    add(p, "hr", (0.01 * cyc(t, 2, T), 0.012 * cyc(t, 4, T, 1.2), 0.005 * b))
    add(p, "wl", (0, 0, 14.0 * cyc(t, 8, T)))
    add(p, "hl", (0, 0, -0.01 * b))
    add(p, "tail", (0, 0, 14.0 * cyc(t, 4, T, 0.8)))
    add(p, "hips", (0, 0, 3.0 * cyc(t, 1, T)))


C.bake("idle", STAND_T, [(0, LOOSE), (STAND_T, {})], over=idle_life, loop=True)
C.bake("stance", GUARD_T, [(0, GUARD), (GUARD_T, {})], over=guard_life, loop=True)


# ---------------------------------------------------------------------- walk, run
def gait(T, stride, lift, duty, dx, dy, lean, bob, armsw, waddle=0.0, turn=0.0, hop=0.0, sink=0.03):
    """A foot cycle: each foot on the ground runs back through the stride at one speed (planted: stride / (duty T) m/s,
    the loco's foot_mps), the heel rolling up off it at the end; then it swings forward over `lift`. The body bobs and
    waddles over the legs, the free hand pumps like a fin, the bill rides forward and the tail swishes. Phase 0 is the
    right foot's mid-stance in every gait, so a walk and a run blend foot on foot."""
    def foot(u):
        if u < duty:
            k = u / duty
            return 0.5 - k, 0.0, 28.0 * max(0.0, k - 0.7) / 0.3
        k = (u - duty) / (1.0 - duty)
        return -0.5 + k * k * (3 - 2 * k), lift * math.sin(math.pi * k), 28.0 * (1 - k) ** 2 - 10.0 * math.sin(math.pi * k)

    def f(t, p):
        ph = t / T
        for lab, off, sx in (("r", 0.0, 1.0), ("l", 0.5, -1.0)):
            s, z, roll = foot((ph + duty / 2 + off) % 1.0)
            p["f" + lab] = (sx * (AX + 0.01) + s * stride * dx, s * stride * dy, AZ)
            p["f" + lab + "a"] = 0.0
            p["f" + lab + "t"] = sx * -8.0
            if roll > 0.0:
                lift_heel(p, lab, roll)
            elif roll < 0.0:
                add(p, "f" + lab + "a", -roll)
            add(p, "f" + lab, (0, 0, z))
            p["k" + lab] = (0.1 * sx, 1, 0)
        c2, s1 = math.cos(ph * tau * 2), math.sin(ph * tau)
        p["pos"] = (waddle * 0.02 * math.cos(ph * tau), 0, -sink - bob * c2 + hop * max(0.0, -c2))
        p["hips"] = (lean + 2.0 * c2, waddle * 6.0 * s1, 8.0 * s1 * (1 if dy >= 0 else -1) + turn)
        p["head"] = (-lean * 0.6 + 2.5 * c2, -waddle * 4.0 * s1, -6.0 * s1 - turn * 0.6)
        p["rot"] = (0, 0, turn * 0.4)
        p["tail"] = (0, 0, -14.0 * s1 - 10.0 * waddle * s1)
        # (each arm furthest forward as its own side's foot is furthest back, about a quarter after its mid-stance,
        # a beat late: ARM_LAG of the cycle)
        a1 = math.cos(tau * (ph - 0.75 - ARM_LAG))
        ar = math.cos(tau * (ph - 0.25 - ARM_LAG))
        p["hl"] = lhand(0.08 + 0.04 * max(0.0, a1), -0.02 + armsw * a1, -0.34 + 0.12 * armsw * max(0.0, a1))
        p["wl"] = (0, 0, 25.0 * math.sin(ph * tau * 2))
        p["hr"] = hand(0.05, 0.13 + 0.3 * armsw * ar, -0.33)
        p["br"] = (0.15, 0.85, -0.45 if dy >= 0 else -0.6)
    return f


DIRS = {"f": (0, 1), "b": (0, -1), "l": (-1, 0), "r": (1, 0)}
ARM_LAG = 0.04
# (legs of 0.41 m carry him as fast as anyone: short, quick, eager steps; he waddles at a walk and scurries at a run)
WALK = dict(T=1.0 / 3.0, stride=0.44, duty=0.5)
RUN = dict(T=1.0 / 3.0, stride=0.54, duty=0.32)
for nm, (dx, dy) in DIRS.items():
    side = 0.6 if dx else 1.0
    C.bake("walk_" + nm, WALK["T"], [(0, LOOSE), (WALK["T"], {})], loop=True,
           over=gait(WALK["T"], WALK["stride"] * side, 0.07, WALK["duty"], dx, dy, -4.0 if dy >= 0 else 3.0, 0.012, 0.12,
                     waddle=1.0, turn=-dx * 14.0, sink=0.06))
    C.bake("run_" + nm, RUN["T"], [(0, LOOSE), (RUN["T"], {})], loop=True,
           over=gait(RUN["T"], RUN["stride"] * side, 0.11, RUN["duty"], dx, dy, -16.0 if dy >= 0 else 6.0, 0.02, 0.2,
                     waddle=0.3, turn=-dx * 22.0, hop=0.025, sink=0.075))

# ---------------------------------------------------------------------- air
# up: knees tucked, both hands thrown up, "wheee"; the fall: the hands flap like fins, the feet paddle; the glide: the
# arms out wide as fins, the body swimming the air in a slow S, the tail sculling
JUMP = m(LOOSE, pos=(0, 0, 0.06), hips=(-6, 0, 0), head=(14, 0, 0), tail=(25, 0, 0),
         hr=hand(0.12, 0.14, 0.02), br=(0.2, 0.7, 0.68), hl=lhand(0.14, 0.04, 0.05), wl=(0, 0, -30),
         fr=(AX, 0.1, AZ + 0.16), fl=(-AX, -0.04, AZ + 0.08), fra=10.0, fla=-20.0, frt=0.0, flt=0.0)
FALL = m(JUMP, pos=(0, 0, 0.04), hips=(3, 0, 0), head=(-6, 0, 0), tail=(-10, 0, 0),
         hr=hand(0.2, 0.1, -0.05), br=(0.3, 0.8, 0.1), hl=lhand(0.22, 0.02, -0.03))
GLIDE = m(LOOSE, pos=(0, 0, 0.02), hips=(-14, 0, 0), head=(18, 0, 0), tail=(10, 0, 0),
          hr=hand(0.3, 0.04, -0.12), br=(0.5, 0.85, 0.0), hl=lhand(0.32, 0.0, -0.1), wl=(0, 0, -20),
          fr=(AX, -0.12, AZ + 0.1), fl=(-AX, -0.16, AZ + 0.12), fra=-30.0, fla=-30.0)


def flap(T):
    def f(t, p):
        add(p, "hl", (0, 0, 0.07 * cyc(t, 2, T)))
        add(p, "hr", (0, 0, 0.05 * cyc(t, 2, T, 0.5)))
        add(p, "wl", (0, 0, 30.0 * cyc(t, 2, T, -0.6)))
        add(p, "fr", (0, 0.06 * cyc(t, 1, T), 0.04 * cyc(t, 1, T, math.pi / 2)))
        add(p, "fl", (0, -0.06 * cyc(t, 1, T), -0.04 * cyc(t, 1, T, math.pi / 2)))
        add(p, "tail", (0, 0, 20.0 * cyc(t, 2, T)))
    return f


def swim(T):
    def f(t, p):
        add(p, "hips", (0, 4.0 * cyc(t, 1, T), 6.0 * cyc(t, 1, T)))
        add(p, "head", (0, -3.0 * cyc(t, 1, T, 0.5), -5.0 * cyc(t, 1, T, 0.5)))
        add(p, "tail", (0, 0, -24.0 * cyc(t, 1, T, 1.0)))
        add(p, "hl", (0, 0, 0.04 * cyc(t, 1, T, -0.8)))
        add(p, "hr", (0, 0, 0.04 * cyc(t, 1, T, 2.3)))
    return f


C.bake("rise", 0.4, [(0, LOOSE), (0.16, m(JUMP, e="out")), (0.4, JUMP)])
C.bake("fall", 0.5, [(0, FALL), (0.5, {})], loop=True, over=flap(0.5))
C.bake("glide", 1.6, [(0, GLIDE), (1.6, {})], loop=True, over=swim(1.6))

# ---------------------------------------------------------------------- Fencer (lmb: gil.json rate 0.32 s, the third x1.5)
# Each thrust lands on its second frame (the kit's hit is on the press) and steps in on the front foot with a stamp;
# the free hand flies back for balance and the tail whips the other way. The third is a full lunge he overbalances
# out of: a wobble on the front leg and a windmill of the free arm before he finds his guard again.
EXT = yaw((0, 1, 0.0), -30.0)
THRUST = m(GUARD, pos=(0.0, 0.05, -0.08), hips=(-12, 0, 30), head=(9, 0, -24), tail=(0, 0, -26),
           hr=hand(-0.08, 0.42, -0.1), br=EXT, hl=lhand(0.06, -0.26, 0.1), wl=(0, 0, -55),
           fr=(AX - 0.01, 0.28, AZ), el=(-0.6, -0.7, 0.3))
THRUST_LOW = m(THRUST, hips=(-15, 0, 26), head=(12, 0, -20), tail=(0, 0, 24), hr=hand(-0.1, 0.4, -0.19),
               br=yaw((0, 1, -0.16), -26.0), hl=lhand(0.1, -0.22, 0.02))
STAMP = dict(fr=(AX + 0.0, 0.2, AZ + 0.05), fra=12.0)
C.bake("thrust_a", 0.32, [(0, GUARD), (0.035, m(GUARD, STAMP, hr=hand(-0.04, 0.24, -0.13), e="out")),
                          (0.07, m(THRUST, fra=0.0, e="snap")), (0.15, m(THRUST, pos=(0.0, 0.06, -0.085))),
                          (0.32, GUARD)])
C.bake("thrust_b", 0.32, [(0, GUARD), (0.035, m(GUARD, STAMP, br=yaw((0.25, 1, -0.2), -SIDE), e="out")),
                          (0.07, m(THRUST_LOW, fra=0.0, e="snap")), (0.15, m(THRUST_LOW, pos=(0.0, 0.06, -0.085))),
                          (0.32, GUARD)])
COCK = m(GUARD, pos=(0.0, -0.05, -0.02), hips=(4, 0, 34), head=(4, 0, -30), tail=(14, 0, 18),
         hr=hand(0.02, -0.04, -0.06), br=yaw((0, 1, 0.45), -34.0), hl=lhand(0.0, -0.1, 0.26),
         fr=(AX, 0.17, AZ + 0.03), fra=8.0)
LUNGE = m(THRUST, pos=(0.0, 0.15, -0.13), hips=(-24, 0, 36), head=(16, 0, -30), tail=(-10, 0, -30),
          hr=hand(-0.08, 0.44, -0.02), br=yaw((0, 1, 0.04), -36.0), hl=lhand(0.12, -0.32, -0.24), wl=(0, 0, -70),
          fr=(AX - 0.02, 0.42, AZ), fra=0.0, fl=(-AX - 0.06, -0.16, AZ), kl=(-0.5, 1, 0))
WOBBLE = m(LUNGE, pos=(0.04, 0.13, -0.12), hips=(-18, 9, 28), head=(10, 10, -20), tail=(0, 0, 30),
           hl=lhand(0.2, -0.05, 0.12), wl=(0, 0, 40))
C.bake("lunge", 0.48, [(0, GUARD), (0.06, m(COCK, e="out")), (0.105, m(LUNGE, e="snap")),
                       (0.2, m(LUNGE, pos=(0.0, 0.16, -0.135))), (0.29, WOBBLE),
                       (0.36, m(LUNGE, hl=lhand(0.16, -0.2, -0.1), wl=(0, 0, -20))), (0.48, GUARD)])

# ---------------------------------------------------------------------- hits and the knock-down
# a hit from the front throws his head and hands up like a startled fish and rocks him back on his heels; from behind
# he lurches forward and the tail jerks up; both settle with an overshoot, the feet never leave their marks
HIT_F = m(LOOSE, pos=(0.0, -0.04, -0.03), hips=(14, 3, -6), head=(22, 0, 8), tail=(30, 0, 12),
          hr=hand(0.14, 0.12, -0.18), br=(0.3, 0.7, 0.4), hl=lhand(0.18, 0.06, -0.12), wl=(0, 0, -40))
HIT_B = m(LOOSE, pos=(0.0, 0.04, -0.04), hips=(-20, -3, 5), head=(-14, 0, -6), tail=(45, 0, -10),
          hr=hand(0.1, -0.06, -0.26), br=(0.2, 0.6, -0.75), hl=lhand(0.16, -0.1, -0.22))
for nm, pose in (("hit_f", HIT_F), ("hit_b", HIT_B)):
    back = {c: v for c, v in LOOSE.items() if c in pose}
    over = m(back, hips=tuple(-0.25 * x for x in pose["hips"]), head=tuple(-0.2 * x for x in pose["head"]))
    C.bake(nm, 0.42, [(0, LOOSE), (0.06, m(pose, e="snap")), (0.16, pose), (0.3, over), (0.42, LOOSE)])

# knocked down (1.5 s, the "dead_t" the body stays on screen): rocked back, one stumble step, the legs go and he
# lands on his back; there he flops like a landed fish, twice, the tail slapping, and lies still with one last flick
DOWN_T = 1.5
TIPPED = m(HIT_F, pos=(0.0, -0.08, -0.05), hips=(18, 0, -10), fl=(-AX - 0.03, -0.18, AZ), flt=20.0)


def on_back(t, p):
    """From 0.42 s the root turns over onto his back (about the heels) and the legs follow in the body's own frame."""
    u = A.ease(min(1.0, max(0.0, (t - 0.42) / 0.36)), "in")
    flop = 0.0 if t < 0.78 else bump(t, 0.82, 1.0, 99.0) + 0.55 * bump(t, 1.02, 1.16, 99.0)
    r = 88.0 * u - 9.0 * flop
    p["rot"] = (r, 0, 0)
    p["pos"] = (0.0, -0.08 - 0.1 * u, 0.2 * u * u + 0.05 * flop)
    if u <= 0.0:
        return
    q = A.qe(p["rot"])
    rp = Vector(p["pos"])
    kick = flop + 0.6 * bump(t, 1.28, 1.44, 99.0)
    for s, sx, ph in (("r", 1.0, 0.0), ("l", -1.0, 0.6)):
        here = Vector(p["f" + s])
        lie = Vector((sx * (AX + 0.03), 0.16 + 0.08 * kick * (1 + 0.4 * ph), 0.17 + 0.1 * kick))
        p["f" + s] = tuple(here.lerp(rp + q @ lie, u))
        p["f" + s + "a"] = 40.0 * u
        p["k" + s] = (0.2 * sx, 0.2, 1.0)
    add(p, "tail", (-50.0 * flop - 30.0 * bump(t, 1.28, 1.44, 99.0), 0, 0))
    add(p, "head", (-10.0 * flop, 0, 0))


LIE = m(TIPPED, hips=(6, 0, 0), head=(-6, 0, 18), hr=hand(0.26, 0.0, -0.18), br=(0.6, 0.6, 0.1),
        hl=lhand(0.28, 0.06, -0.15), wl=(0, 0, 0), tail=(0, 0, 0))
C.bake("death", DOWN_T, [(0, LOOSE), (0.05, m(HIT_F, e="snap")), (0.24, TIPPED), (0.42, m(TIPPED, hips=(24, 0, -8))),
                         (0.78, m(LIE, e="in")), (DOWN_T, LIE)], over=on_back)

# ---------------------------------------------------------------------- crouch, landing, stun, emote, revive, dive
# the crouch is a cartoon sneak: knees deep, hunched over the bill held up close, the free hand up by his mouth as if
# that hides him, the head low and darting; the sneak ring tiptoes on the balls of his boots
CROUCH = m(LOOSE, pos=(0.0, -0.01, -0.1), hips=(-24, 0, 0), head=(20, 0, 0), tail=(-12, 0, 0),
           hr=hand(0.0, 0.16, -0.2), br=(0.1, 0.9, 0.3), hl=lhand(-0.04, 0.14, -0.04), wl=(0, 0, -25),
           fr=(AX + 0.04, 0.03, AZ), fl=(-AX - 0.04, -0.02, AZ), kr=(0.45, 1, 0), kl=(-0.45, 1, 0))
CROUCH_DIP = m(CROUCH, pos=(0.0, -0.01, -0.125), hips=(-28, 0, 0), head=(24, 0, 0))
CROUCH_T = 3.0


def crouch_life(t, p):
    """Breath, a peek over one shoulder and the other, a tail twitch: he is sure everyone can see him."""
    T = CROUCH_T
    breathe(t, p, T)
    left = plateau(t, 0.3, 0.42, 0.9, 1.05, T, "snap")
    right = plateau(t, 1.5, 1.62, 2.1, 2.3, T, "snap")
    add(p, "head", (0, -6.0 * left + 6.0 * right, 30.0 * left - 30.0 * right))
    add(p, "hips", (0, 0, 6.0 * left - 6.0 * right))
    add(p, "tail", (0, 0, 22.0 * bump(t, 2.4, 2.7, T) * cyc(t, 12, T)))


def sneak(T, dx, dy):
    """The gait low and on tiptoe; the hands stay up where he put them, a small pump only."""
    g = gait(T, 0.5 * (0.6 if dx else 1.0), 0.06, 0.56, dx, dy, -24.0 if dy >= 0 else -16.0, 0.008, 0.0,
             waddle=0.6, turn=-dx * 16.0, sink=0.1)

    def f(t, p):
        g(t, p)
        ph = t / T
        lift_heel(p, "r", 10.0)
        lift_heel(p, "l", 10.0)
        p["head"] = (20.0 + 2.0 * math.cos(ph * tau * 2), 0, 4.0 * math.sin(ph * tau))
        p["hr"] = hand(0.0, 0.16 + 0.02 * math.sin(ph * tau), -0.2)
        p["br"] = CROUCH["br"]
        p["hl"] = lhand(-0.04, 0.14 + 0.02 * math.sin(ph * tau + math.pi), -0.04)
        p["wl"] = CROUCH["wl"]
    return f


C.bake("crouch_idle", CROUCH_T, [(0, CROUCH), (CROUCH_T, {})], over=crouch_life, loop=True)
CROUCH_STEP = 0.4              # s a sneak cycle; its planted foot runs about 2.0 m/s (the map's crouch speed)
for nm, (dx, dy) in DIRS.items():
    C.bake("crouch_" + nm, CROUCH_STEP, [(0, CROUCH), (CROUCH_STEP, {})], loop=True, over=sneak(CROUCH_STEP, dx, dy))
C.bake("crouch_in", 0.3, [(0, LOOSE), (0.12, m(CROUCH_DIP, e="out")), (0.3, CROUCH)])
C.bake("crouch_out", 0.3, [(0, CROUCH), (0.1, m(LOOSE, pos=(0.0, 0.0, 0.01), e="out")), (0.3, LOOSE)])

# a landing: the knees take it deep, both arms flung out like fins for balance, the chin straight back up, the tail
# slapping down; a little bounce back up off it
LAND = m(LOOSE, pos=(0.0, 0.01, -0.09), hips=(-16, 0, 0), head=(12, 0, 0), tail=(-30, 0, 0),
         hr=hand(0.2, 0.08, -0.2), br=(0.6, 0.7, -0.2), hl=lhand(0.24, 0.04, -0.12), wl=(0, 0, -40),
         kr=(0.35, 1, 0), kl=(-0.35, 1, 0))
C.bake("land", 0.36, [(0, m(LAND, e="snap")), (0.06, LAND), (0.2, m(LOOSE, pos=(0.0, 0.0, 0.012), e="out")),
                      (0.36, LOOSE)])

# stunned: he sways round in a slow circle on locked knees, head lolling the other way, the bill drooping to the
# ground, the free hand limp, the tail hanging; a gulp of air at the top of each circle
STUN = m(LOOSE, pos=(0.0, 0.0, -0.03), hips=(-8, 0, 0), head=(-12, 0, 0), tail=(-20, 0, 0),
         hr=hand(0.08, 0.06, -0.4), br=(0.1, 0.4, -0.9), hl=lhand(0.1, 0.0, -0.4), wl=(0, 0, 10))
STUN_T = 1.2


def daze(t, p):
    T = STUN_T
    add(p, "pos", (0.02 * cyc(t, 1, T), 0.02 * cyc(t, 1, T, math.pi / 2), 0))
    add(p, "hips", (5.0 * cyc(t, 1, T, math.pi / 2), 7.0 * cyc(t, 1, T), 0))
    add(p, "head", (-8.0 * cyc(t, 1, T, math.pi), -14.0 * cyc(t, 1, T, 0.6), 10.0 * cyc(t, 1, T, 1.4)))
    add(p, "hl", (0.02 * cyc(t, 1, T, 0.4), 0, 0))
    add(p, "tail", (0, 0, 12.0 * cyc(t, 1, T, 2.0)))


C.bake("stun", STUN_T, [(0, STUN), (STUN_T, {})], over=daze, loop=True)

# the emote: a fencer's salute he has been practising (the bill up before his face, a flourish down to the side),
# then a bow far too deep, and back up into two giddy bounces, the fin-hand flapping and the tail going
SALUTE = m(LOOSE, pos=(0.0, 0.0, 0.01), hips=(2, 0, 0), head=(10, 0, 0), hr=hand(-0.14, 0.14, 0.0),
           br=(0.0, 0.08, 1.0), hl=lhand(0.0, -0.06, -0.3), fr=(AX + 0.0, 0.0, AZ), fl=(-AX - 0.0, -0.02, AZ),
           frt=0.0, flt=0.0)
FLOURISH = m(SALUTE, hips=(-4, 0, -6), hr=hand(0.2, 0.2, -0.24), br=(0.7, 0.6, -0.4), head=(6, 0, 4))
BOW = m(FLOURISH, pos=(0.0, -0.03, -0.03), hips=(-40, 0, 0), head=(-14, 0, 0), tail=(30, 0, 0),
        hl=lhand(-0.08, 0.12, -0.04), wl=(0, 0, -20), fl=(-AX - 0.02, -0.08, AZ))
CHEER = m(LOOSE, hips=(-2, 0, 0), head=(16, 0, 0), hr=hand(0.1, 0.1, 0.1), br=(0.2, 0.4, 0.9),
          hl=lhand(0.12, 0.04, 0.0))


def giddy(t, p):
    b = bump(t, 1.3, 1.5, 9.0) + bump(t, 1.5, 1.7, 9.0)
    lift_heel(p, "r", 20.0 * b)
    lift_heel(p, "l", 20.0 * b)
    add(p, "pos", (0, 0, 0.04 * b))
    w = plateau(t, 1.25, 1.35, 1.75, 1.95, 9.0)
    add(p, "wl", (0, 0, 40.0 * w * cyc(t, 16, 2.0)))
    add(p, "hl", (0, 0, 0.04 * w * cyc(t, 16, 2.0)))
    add(p, "tail", (0, 0, 24.0 * w * cyc(t, 12, 2.0)))


C.bake("emote", 2.0, [(0, LOOSE), (0.25, m(SALUTE, e="out")), (0.55, SALUTE), (0.72, m(FLOURISH, e="snap")),
                      (0.9, m(BOW, e="io")), (1.15, BOW), (1.32, m(CHEER, e="out")), (1.75, CHEER), (2.0, LOOSE)],
       over=giddy)

# reviving a fallen Boki: down on one knee beside it, the swordfish laid across his lap, fanning it with the free hand
# and patting it, now and then looking up for help; the clip plays once and holds on its last fan
KNEEL = m(LOOSE, pos=(0.0, 0.02, -0.17), hips=(-30, 0, 0), head=(-6, 0, 0), tail=(-10, 0, 0),
          hr=hand(0.0, 0.16, -0.26), br=(-0.6, 0.6, -0.4), hl=lhand(-0.06, 0.26, -0.2), wl=(0, 0, 0),
          fr=(AX + 0.02, 0.12, AZ), fl=(-AX - 0.04, -0.14, AZ), fla=40.0, kr=(0.2, 1, 0), kl=(-0.2, 1, -0.6))
REVIVE_T = 1.8


def fan(t, p):
    k = plateau(t, 0.0, 0.3, 9.0, 9.5, 9.0)
    add(p, "hl", (0.04 * k * cyc(t, 6, REVIVE_T), 0, 0.05 * k * cyc(t, 6, REVIVE_T, math.pi / 2)))
    add(p, "wl", (0, 0, 35.0 * k * cyc(t, 6, REVIVE_T)))
    up = plateau(t, 0.8, 0.92, 1.2, 1.35, 9.0, "snap")
    add(p, "head", (30.0 * up, 0, 14.0 * up))
    add(p, "tail", (0, 0, 10.0 * cyc(t, 2, REVIVE_T)))


C.bake("revive", REVIVE_T, [(0, LOOSE), (0.3, m(KNEEL, e="out")), (REVIVE_T, KNEEL)], over=fan)

# a dive head first like a fish into water (Ground Swim's), both hands together ahead, the bill along them, the boots
# together behind
DIVE = m(LOOSE, rot=(-55, 0, 0), pos=(0.0, 0.0, 0.1), hips=(-8, 0, 0), head=(26, 0, 0), tail=(20, 0, 0),
         hr=hand(-0.12, 0.3, 0.3), br=(0.0, 0.6, 0.8), hl=lhand(-0.12, 0.3, 0.3), wl=(0, 0, 0),
         fr=(AX - 0.03, -0.3, AZ + 0.32), fl=(-AX + 0.03, -0.32, AZ + 0.3), fra=-40.0, fla=-40.0, frt=0.0, flt=0.0)

# fusing with his Boki (mf_xform, 0.8 s): a gasp up onto his toes with the arms flung wide, drawn in tight, and out
FUSE_GASP = m(CHEER, hips=(8, 0, 0), head=(24, 0, 0), hr=hand(0.3, 0.0, 0.05), br=(0.8, 0.2, 0.5),
              hl=lhand(0.3, 0.0, 0.05), wl=(0, 0, -40), tail=(30, 0, 0))
FUSE_TIGHT = m(CROUCH_DIP, hr=hand(-0.1, 0.08, -0.1), br=(0.0, 0.3, 1.0), hl=lhand(-0.1, 0.08, -0.1), tail=(-20, 0, 0))


def tiptoe(t, p):
    b = bump(t, 0.05, 0.4, 9.0)
    lift_heel(p, "r", 26.0 * b)
    lift_heel(p, "l", 26.0 * b)
    add(p, "pos", (0, 0, 0.04 * b))


C.bake("fuse", 0.8, [(0, LOOSE), (0.2, m(FUSE_GASP, e="out")), (0.42, m(FUSE_TIGHT, e="in")),
                     (0.6, m(FUSE_GASP, hips=(-4, 0, 0), e="out")), (0.8, LOOSE)], over=tiptoe)

# ---------------------------------------------------------------------- Grab Bag, Riptide, Ground Swim, Tidal Wave
# Grab Bag (rmb): an eager overhand lob from the free hand, the potion gone on the press (the kit throws it then), a
# hop of the front boot after it, the hand left waving it off
TOSS_COCK = m(LOOSE, hips=(2, 0, -18), head=(8, 0, 14), hl=lhand(0.08, -0.14, 0.28), wl=(0, 0, 30), tail=(0, 0, 14),
              hr=hand(0.06, 0.06, -0.3))
TOSS = m(LOOSE, pos=(0.0, 0.03, -0.02), hips=(-10, 0, 16), head=(10, 0, -10), hl=lhand(-0.06, 0.36, 0.12),
         wl=(0, 0, -30), tail=(0, 0, -16), hr=hand(0.1, -0.02, -0.32), fl=(-AX - 0.02, 0.1, AZ))
C.bake("toss", 0.4, [(0, LOOSE), (0.04, m(TOSS_COCK, e="out")), (0.1, m(TOSS, e="snap")),
                     (0.22, m(TOSS, hl=lhand(-0.04, 0.32, 0.02), wl=(0, 0, 20))), (0.4, LOOSE)],
       over=lambda t, p: add(p, "wl", (0, 0, 30.0 * bump(t, 0.18, 0.4, 9.0) * cyc(t, 8, 0.4))))

# Riptide (e): he winds the other way, then twirls on his toes, the swordfish out at arm's length, the free hand out
# for balance, his head thrown back and the tail flying; a turn every SPIN_REV through the longest spin (gil.json e
# spin_t 2 s: the kit lets the spout go at the latest then, and a spin cut short by a stun ends on every screen)
SPIN_IN, SPIN_REV, SPIN_TURNS = 4 / 30, 0.4, 5     # s: the wind-up, one full turn; the turns
SPIN_WIND = m(GUARD, pos=(0.0, 0.0, -0.06), hips=(-6, 0, -40), head=(4, 0, 30), hr=hand(0.1, -0.1, -0.12),
              br=(0.4, -0.8, 0.0), hl=lhand(0.1, 0.12, 0.0))
TWIRL = m(LOOSE, pos=(0.0, 0.0, 0.0), hips=(6, -6, 0), head=(14, 0, 0), tail=(28, 0, 0),
          hr=hand(0.36, 0.06, 0.04), br=(1.0, 0.12, 0.0), hl=lhand(0.3, 0.0, 0.06), wl=(0, 0, -30),
          fr=(AX + 0.03, 0.02, AZ), fl=(-AX - 0.03, -0.02, AZ), frt=0.0, flt=0.0, kr=(0.2, 1, 0), kl=(-0.2, 1, 0))


def turned(p, deg):
    """All of him turned about up by deg: the root, the feet (model space) and their boots."""
    c, s = math.cos(math.radians(deg)), math.sin(math.radians(deg))
    for lab in ("r", "l"):
        x, y, z = p["f" + lab]
        p["f" + lab] = (x * c - y * s, x * s + y * c, z)
        p["f" + lab + "t"] = p.get("f" + lab + "t", 0.0) + deg
    x, y, z = p["pos"]
    p["pos"] = (x * c - y * s, x * s + y * c, z)
    r = p.get("rot", (0, 0, 0))
    p["rot"] = (r[0], r[1], r[2] + deg)


def twirl(t, p):
    toes = A.ease(min(1.0, max(0.0, (t - 0.04) / (SPIN_IN - 0.04))), "io")
    lift_heel(p, "r", 24.0 * toes)
    lift_heel(p, "l", 24.0 * toes)
    if t < SPIN_IN:
        return
    u = (t - SPIN_IN) / SPIN_REV
    for lab, ph in (("r", 0.0), ("l", 0.5)):
        add(p, "f" + lab, (0, 0, 0.035 * max(0.0, math.sin(tau * (u * 2 + ph)))))
    add(p, "pos", (0, 0, 0.012 * math.cos(tau * u * 2)))
    add(p, "tail", (0, 0, 10.0 * math.sin(tau * u)))
    turned(p, 360.0 * u)


SPIN_END = SPIN_IN + SPIN_REV * SPIN_TURNS
C.bake("spin", SPIN_END, [(0, LOOSE), (0.08, m(SPIN_WIND, e="out")), (SPIN_IN, m(TWIRL, e="in")), (SPIN_END, TWIRL)],
       over=twirl)

# the spout let go (e again): he stamps out of the twirl into a thrust at the aim, the free hand thrown back, then
# finds his feet
SPOUT = m(LUNGE, pos=(0.0, 0.1, -0.11), hl=lhand(0.22, -0.3, 0.1), wl=(0, 0, -60), head=(18, 0, -30))
C.bake("spout", 0.4, [(0, m(TWIRL, frt=0.0, flt=0.0)), (0.08, m(SPOUT, e="snap")), (0.2, SPOUT),
                      (0.4, m(GUARD, e="io"))])

# Ground Swim (dash, 0.4 s): a hop and a dive head first into the ground; under it only the back fin and the fork of
# the tail cut the surface, sculling; then (surface) he bursts out arms up, lands in a squash and grins
SWIM_IN, SWIM_STROKE = 4 / 30, 8 / 30   # s: the dive, then one stroke of the tail (the map holds the strokes from SWIM_IN)
HOP = m(DIVE, rot=(-35, 0, 0), pos=(0.0, 0.05, 0.12))
UNDER = m(DIVE, rot=(-88, 0, 0), pos=(0.0, -0.32, -0.16), head=(10, 0, 0), tail=(-20, 0, 0),
          fr=(AX - 0.03, -0.42, -0.16), fl=(-AX + 0.03, -0.44, -0.14), fra=-80.0, fla=-80.0)


def scull(t, p):
    if t < SWIM_IN:
        return
    w = cyc(t - SWIM_IN, 1, SWIM_STROKE)
    add(p, "hips", (0, 6.0 * w, 8.0 * w))
    add(p, "tail", (0, 0, -30.0 * w))
    add(p, "pos", (0.02 * w, 0, 0))


SWIM_END = SWIM_IN + SWIM_STROKE
C.bake("swim", SWIM_END, [(0, LOOSE), (0.08, m(HOP, e="out")), (SWIM_IN, m(UNDER, e="in")), (SWIM_END, UNDER)],
       over=scull)
TADA = m(CHEER, pos=(0.0, 0.04, 0.12), head=(22, 0, 0), hr=hand(0.2, 0.06, 0.2), br=(0.4, 0.3, 0.86),
         hl=lhand(0.22, 0.04, 0.2), wl=(0, 0, -40), tail=(36, 0, 0),
         fr=(AX + 0.02, 0.04, AZ + 0.1), fl=(-AX - 0.02, -0.02, AZ + 0.12), fra=-20.0, fla=-20.0)
C.bake("surface", 0.45, [(0, UNDER), (0.12, m(TADA, e="out")), (0.24, m(LAND, e="in")), (0.3, LAND),
                         (0.45, LOOSE)])

# Tidal Wave (x, 1 s): he hops onto the crest and surfs it side-on, knees bent, both arms out, the swordfish up like
# a banner and his mouth wide; a balance sway every SURF_SWAY; at the end he jumps off into a proud landing
SURF_IN, SURF_SWAY = 4 / 30, 0.6
SURF_TURN = 70.0               # deg: side-on to the line he surfs, the right boot leading
# (in his own frame: a wide stance across him, which the turn lays along the line)
SURF = m(LOOSE, pos=(0.0, 0.0, 0.04), hips=(-8, 0, -50), head=(18, 0, -40), tail=(10, 0, 0),
         hr=hand(0.3, 0.0, 0.12), br=(0.5, 0.3, 0.8), hl=lhand(0.32, 0.0, 0.0), wl=(0, 0, -30),
         fr=(AX + 0.12, 0.0, AZ + 0.08), fl=(-AX - 0.12, 0.0, AZ + 0.08), frt=0.0, flt=0.0,
         kr=(0.6, 1, 0), kl=(-0.6, 1, 0))


def ride(t, p):
    turned(p, SURF_TURN * A.ease(min(1.0, max(0.0, (t - 0.07) / (SURF_IN - 0.07))), "out"))
    if t < SURF_IN:
        return
    u = (t - SURF_IN) / SURF_SWAY
    add(p, "hips", (4.0 * math.sin(tau * u * 2), 8.0 * math.sin(tau * u), 0))
    add(p, "head", (0, -6.0 * math.sin(tau * u), 0))
    add(p, "hl", (0, 0, 0.06 * math.sin(tau * u)))
    add(p, "hr", (0, 0, -0.04 * math.sin(tau * u)))
    add(p, "pos", (0, 0, 0.015 * math.sin(tau * u * 2)))
    add(p, "tail", (0, 0, 18.0 * math.sin(tau * u * 2)))


def hop_off(t, p):
    turned(p, SURF_TURN * (1.0 - A.ease(min(1.0, t / 0.1), "out")))


C.bake("surf", SURF_IN + SURF_SWAY, [(0, LOOSE), (0.07, m(CROUCH_DIP, e="out")), (SURF_IN, m(SURF, e="out")),
                                     (SURF_IN + SURF_SWAY, SURF)], over=ride)
C.bake("wave_land", 0.45, [(0, SURF), (0.1, m(TADA, e="out")), (0.2, m(LAND, e="in")),
                           (0.3, m(LAND, hr=hand(0.1, 0.1, 0.1), br=(0.2, 0.4, 0.9))), (0.45, LOOSE)], over=hop_off)

# ---------------------------------------------------------------------- export
arm.animation_data_create()
bpy.context.scene.render.fps = A.FPS      # (the exporter turns frames into seconds at the scene's rate)
for act in list(bpy.data.actions):
    # (every clip on its own NLA track: the exporter's NLA_TRACKS mode writes each as a clip)
    tr = arm.animation_data.nla_tracks.new()
    tr.name = act.name
    tr.strips.new(act.name, 0, act)
arm.animation_data.action = None
K.ink_back()
keep = [o for o in bpy.data.objects if o == arm or o.parent == arm]
K.export(OUT, keep, colors=True, anims=True)
print("GIL_CLIPS", {k: round(v, 3) for k, v in C.lengths.items()})
