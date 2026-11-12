"""Clips every four-legged Boki shares. A clip is a function of t (0..1) returning bone -> (rx, ry, rz) in the creature's
own axes: rx lifts the nose (or swings a limb forward), ry turns it toward its left, rz rolls.
Keys: "root_at" / "hips_at" (metres; any other bone without a parent takes one too), "root_sc" (squash), and prop
bones set to "on". Bones a species lacks are ignored."""
import math

from vespyx_sides import SIDES

TAU = math.tau
TAIL_N = 7         # plates or joints in the tail; set by the species
LOOK_UP = 0.36     # standing, it looks up at you: the high cameras then see its face, not the top of its head


def s(t, n=1.0, ph=0.0):
    return math.sin(TAU * (n * t + ph))


def c(t, n=1.0, ph=0.0):
    return math.cos(TAU * (n * t + ph))


def ease(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def sweep(t, n=1.0, ph=0.0):
    """s(t, n, ph), a paw's swing round the hip from 1 forward to -1 back, but its stance (the back half) is a
    straight line, so the planted paw goes back at one pace; the swing forward keeps the sine's ease."""
    u = (n * t + ph) % 1.0
    return 2.0 - 4.0 * u if 0.25 <= u < 0.75 else math.sin(TAU * u)


def seq(t, keys):
    """keys: (t, value), eased between. Values may be numbers."""
    if t <= keys[0][0]:
        return keys[0][1]
    for (t0, v0), (t1, v1) in zip(keys, keys[1:]):
        if t <= t1:
            k = ease((t - t0) / max(t1 - t0, 1e-6))
            return v0 + (v1 - v0) * k
    return keys[-1][1]


def add(pose, bone, rx=0.0, ry=0.0, rz=0.0):
    o = pose.get(bone, (0, 0, 0))
    pose[bone] = (o[0] + rx, o[1] + ry, o[2] + rz)


def _side(v):
    """A point's (y, z) as y + iz: a turn by rx is then a multiply by e^(i rx)."""
    return complex(v[1], v[2])


def pitch_at(bones, pose, name):
    """Seen from the side, the pitch of `name`'s parent and where `name`'s head sits under the pose's rx and its
    root/hips offsets (ry and rz are left out: a gait keeps them small)."""
    chain = []
    b = bones[name][2]
    while b:
        chain.insert(0, b)
        b = bones[b][2]
    turn, at = 0.0, 0j
    for b in chain:
        h = _side(bones[b][0])
        w = _side(pose.get(b + "_at", (0, 0, 0))) if b in ("root", "hips") else 0j
        rx = pose.get(b, (0, 0, 0))[0]
        at += complex(math.cos(turn), math.sin(turn)) * (h + w - complex(math.cos(rx), math.sin(rx)) * h)
        turn += rx
    return turn, at + complex(math.cos(turn), math.sin(turn)) * _side(bones[name][0])


def plant(pose, bones, leg, target, paw_pitch=0.0, bend=1.0):
    """Puts a two-bone leg's ankle on `target` ((y, z) in the creature's axes) by setting the rx of `leg` ("hleg"
    and ".L" make hleg1.L, hleg2.L, hpaw.L), the knee folding the way it does at rest (`bend`'s way for a straight leg),
    the paw `paw_pitch` from its rest angle. Out of reach, the leg points straight at it."""
    pre, sd = leg
    upper, lower, paw = pre + "1" + sd, pre + "2" + sd, pre.replace("leg", "paw") + sd
    turn, hip = pitch_at(bones, pose, upper)
    u1 = _side(bones[lower][0]) - _side(bones[upper][0])
    u2 = _side(bones[paw][0]) - _side(bones[lower][0])
    d = complex(*target) - hip
    k = (abs(d) ** 2 - abs(u1) ** 2 - abs(u2) ** 2) / (2 * abs(u1) * abs(u2))
    rest = math.atan2((u2 / u1).imag, (u2 / u1).real)
    knee = math.copysign(math.acos(max(-1.0, min(1.0, k))), rest if abs(rest) > 0.05 else bend) - rest
    reach = u1 + u2 * complex(math.cos(knee), math.sin(knee))
    hip_rx = math.atan2(d.imag, d.real) - math.atan2(reach.imag, reach.real)
    hip_rx = (hip_rx + math.pi) % TAU - math.pi
    pose[upper] = (hip_rx - turn, 0.0, 0.0)
    pose[lower] = (knee, 0.0, 0.0)
    pose[paw] = (paw_pitch - hip_rx - knee, 0.0, 0.0)


def stride_leg(u, duty, front, back, ground, lift, sweep=0.06):
    """Where a paw is at `u` (0..1) of its step, as (y, z): down for the first `duty` of it, then up through a `lift`
    arc and forward. It goes back from `front` to `back` at one speed from `sweep` before it lands to `sweep` after it
    lifts (an animal matches the ground's pace before touch-down), so it is in the air by the time it turns."""
    u %= 1.0
    air = (u - duty) / (1.0 - duty) if u >= duty else 0.0
    y = ground + lift * (1.0 - (1.0 - math.sin(math.pi * air)) ** 3)
    v = (u + sweep) % 1.0
    if v < duty + 2 * sweep:
        return y, front + (back - front) * v / (duty + 2 * sweep)
    w = (v - duty - 2 * sweep) / (1.0 - duty - 2 * sweep)
    return y, back + (front - back) * (w - math.sin(TAU * w) / TAU)


def tail_wave(pose, phase, amp, up=0.0, side=0.0, roll=0.0, lag=0.09):
    """Sends a wave down the tail: each plate repeats the one before, a little late (follow-through)."""
    for i in range(TAIL_N):
        k = 0.45 + 0.55 * i / max(TAIL_N - 1, 1)
        add(pose, "tail%d" % (i + 1), rx=up / TAIL_N + amp * math.sin(TAU * (phase - i * lag)) * k,
            ry=side / TAIL_N + roll * math.sin(TAU * (phase - i * lag - 0.15)) * k)


def ear_pose(pose, back=0.0, out=0.0, flick=0.0):
    for sd, sx in SIDES:
        add(pose, "ear1." + sd, rx=back, rz=-sx * out + (flick if sd == "R" else 0))
        add(pose, "ear2." + sd, rx=back * 0.6)


def idle(t):
    p = {}
    br = s(t, 2)
    add(p, "spine", rx=br * 0.02)
    add(p, "neck", rx=-br * 0.01, ry=s(t, 1) * 0.05, rz=s(t, 1, 0.2) * 0.02)
    add(p, "head", rx=LOOK_UP + br * 0.03, ry=s(t, 1, 0.1) * 0.08, rz=s(t, 1, 0.3) * 0.04)
    p["root_at"] = (0, -0.006 + br * 0.004, 0)
    tw = seq(t, [(0, 0), (0.7, 0), (0.74, 1), (0.8, 0), (0.84, 1), (0.9, 0), (1, 0)])
    ear_pose(p, back=0.02 + br * 0.015, flick=tw * 0.22)
    tail_wave(p, t * 2, 0.022, roll=0.04)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=br * 0.04)
        add(p, "nip." + sd, ry=sx * seq(t, [(0, 0), (0.3, 0), (0.34, 0.5), (0.38, 0), (0.42, 0.5), (0.46, 0), (1, 0)]))
    for leg, sgn in (("fleg1.L", 1), ("fleg1.R", 1), ("hleg1.L", 1), ("hleg1.R", 1)):
        add(p, leg, rx=br * 0.012 * sgn)
    return p


def trot(t, swing, bob, tail_up, pitch):
    p = {}
    # diagonal pairs
    phases = {"fleg1.L": 0.0, "hleg1.R": 0.0, "fleg1.R": 0.5, "hleg1.L": 0.5}
    for leg, ph in phases.items():
        a = s(t, 1, ph)
        add(p, leg, rx=a * swing)
        low = leg.replace("1.", "2.")
        add(p, low, rx=-max(0.0, -c(t, 1, ph)) * swing * 1.2 if leg[0] == "f" else max(0.0, -c(t, 1, ph)) * swing * 1.2)
        paw = leg.replace("leg1.", "paw.")
        add(p, paw, rx=-a * swing * 0.5)
    p["root_at"] = (0, abs(c(t, 1)) * bob - bob * 0.3, 0)
    add(p, "root", rz=s(t, 1) * 0.035, ry=s(t, 1) * 0.04)
    add(p, "spine", rx=-pitch)
    add(p, "neck", rx=pitch * 0.6 + c(t, 2) * 0.03)
    add(p, "head", rx=LOOK_UP + pitch * 0.4 + c(t, 2, 0.1) * 0.04, ry=-s(t, 1) * 0.04)
    ear_pose(p, back=0.14, out=0.03)
    tail_wave(p, t * 2, 0.05, up=tail_up, roll=0.06)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=-s(t, 1, 0.5 if sd == "L" else 0) * 0.12)
    return p


def walk(t):
    return trot(t, 0.5, 0.012, 0.0, 0.0)


def run(t):
    """A bounding gallop: the spine bunches and stretches, ears pinned, tail streaming back."""
    p = {}
    fr = s(t, 1, 0.0)
    hi = s(t, 1, 0.5)
    for sd, sx in SIDES:
        off = 0.05 if sd == "R" else 0.0
        a = s(t, 1, off)
        b = s(t, 1, 0.42 + off)
        add(p, "fleg1." + sd, rx=a * 0.95)
        add(p, "fleg2." + sd, rx=-max(0.0, -c(t, 1, off)) * 0.9)
        add(p, "fpaw." + sd, rx=-a * 0.45)
        add(p, "hleg1." + sd, rx=b * 0.85)
        add(p, "hleg2." + sd, rx=max(0.0, -c(t, 1, 0.42 + off)) * 0.8)
        add(p, "hpaw." + sd, rx=-b * 0.4)
        add(p, "arm." + sd, rx=-0.25, rz=-sx * 0.2)
    p["root_at"] = (0, 0.012 + 0.05 * max(0.0, s(t, 1, 0.2)), 0)
    add(p, "hips", rx=fr * 0.2)
    add(p, "spine", rx=-fr * 0.34)
    add(p, "root", rx=fr * 0.08)
    add(p, "neck", rx=fr * 0.2 - 0.12)
    add(p, "head", rx=fr * 0.14 - 0.04)
    ear_pose(p, back=0.62 + fr * 0.08, out=0.08)
    tail_wave(p, t, 0.09, up=0.7, roll=0.03, lag=0.07)
    return p


def hop(t):
    """A happy hop: down, up with the legs tucked and a spin of the tail, a soft landing."""
    p = {}
    air = seq(t, [(0, 0), (0.18, -0.55), (0.3, 0.2), (0.48, 1), (0.66, 0.2), (0.76, -0.45), (1, 0)])
    up = max(air, 0)
    down = max(-air, 0)
    p["root_at"] = (0, 0.21 * up - 0.08 * down, 0)
    p["root_sc"] = (1 + 0.14 * down - 0.05 * up, 1 - 0.20 * down + 0.10 * up, 1 + 0.06 * down)
    add(p, "root", rx=0.22 * (seq(t, [(0.2, 0), (0.4, 1), (0.6, -0.8), (0.75, 0)])))
    add(p, "head", rx=0.22 * up - 0.14 * down, rz=s(t, 2) * 0.1)
    add(p, "neck", rx=0.08 * up)
    ear_pose(p, back=-0.2 * up + 0.5 * down + 0.2, out=0.26 * down)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-0.7 * up + 0.3 * down)
        add(p, "fleg2." + sd, rx=-0.9 * up - 0.5 * down)
        add(p, "hleg1." + sd, rx=0.7 * up - 0.3 * down)
        add(p, "hleg2." + sd, rx=0.9 * up + 0.5 * down)
        add(p, "arm." + sd, rx=0.8 * up, rz=sx * 0.6 * up)
        add(p, "nip." + sd, ry=sx * up * 0.5)
    tail_wave(p, t, 0.09, up=0.15 * up - 0.3 * down, roll=0.12, lag=0.05)
    return p


def pet(t):
    """Leans up into a hand, eyes shut: a slow push of the head, ears flat, the tail wagging."""
    p = {}
    lean = 0.5 + 0.5 * s(t, 1)
    add(p, "neck", rx=0.10 + lean * 0.06, rz=lean * 0.10)
    add(p, "head", rx=0.08 + lean * 0.08, rz=0.16 + lean * 0.2, ry=lean * 0.1)
    ear_pose(p, back=0.6 - lean * 0.15, out=0.5)
    add(p, "spine", rx=0.05)
    p["root_at"] = (0, 0.012 * lean, 0)
    for i in range(TAIL_N):
        k = 0.4 + 0.6 * i / max(TAIL_N - 1, 1)
        add(p, "tail%d" % (i + 1), ry=0.17 * k * math.sin(TAU * (3 * t - i * 0.06)), rx=-0.02)
    for sd, sx in SIDES:
        add(p, "hleg1." + sd, rx=0.07)
        add(p, "fleg1." + sd, rx=-0.06)
    return p


def carry(t):
    """Trots with its load hugged in both pincers (home's own Held item, BokiRig.CARRY_AT), head up, leaning back."""
    p = trot(t, 0.42, 0.010, -0.14, -0.05)
    for sd, sx in SIDES:
        add(p, "arm." + sd, rx=0.6, rz=-sx * 0.08)
        add(p, "claw." + sd, rx=0.25, ry=sx * 0.25)
    add(p, "neck", rx=0.1)
    add(p, "head", rx=0.1)
    return p


def tend(t):
    """Any other farm job: head down over the work, pincers snipping in turn, the tail ticking along."""
    p = {}
    bob = s(t, 2)
    add(p, "spine", rx=-0.14)
    add(p, "neck", rx=-0.20 + bob * 0.04)
    add(p, "head", rx=LOOK_UP * 0.5 + bob * 0.06, ry=s(t, 1) * 0.12)
    p["root_at"] = (0, -0.02 + bob * 0.006, 0)
    for sd, sx in SIDES:
        ph = 0.0 if sd == "L" else 0.5
        add(p, "arm." + sd, rx=-0.15 + 0.35 * max(0.0, s(t, 2, ph)), ry=sx * 0.2)
        add(p, "nip." + sd, ry=sx * (0.25 + 0.25 * s(t, 4, ph)))
    ear_pose(p, back=0.16)
    tail_wave(p, t * 2, 0.03, roll=0.05)
    return p




def bite(t):
    """No pincers: crouch, spring, a snap of the jaws, settle."""
    p = {}
    wind = seq(t, [(0, 0), (0.3, 1), (0.42, -1), (0.56, -1), (1, 0)])
    p["root_at"] = (0, -0.04 * max(wind, 0) + 0.03 * max(-wind, 0), 0.08 * max(wind, 0) - 0.18 * max(-wind, 0))
    add(p, "hips", rx=wind * 0.14)
    add(p, "spine", rx=wind * 0.2)
    add(p, "neck", rx=max(wind, 0) * 0.15 - max(-wind, 0) * 0.1)
    add(p, "head", rx=max(wind, 0) * 0.3 + max(-wind, 0) * 0.12)
    ear_pose(p, back=0.3 + max(-wind, 0) * 0.4)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=-wind * 0.5)
        add(p, "hleg1." + sd, rx=wind * 0.4)
    tail_wave(p, t * 2, 0.04, up=wind * 0.2)
    return p


def eat_ground(t):
    """A berry on the ground: head down, three nibbles, a pleased chew."""
    p = idle(t)
    chomp = 0.5 + 0.5 * s(t, 3)
    add(p, "spine", rx=-0.16)
    add(p, "neck", rx=-0.3)
    add(p, "head", rx=-LOOK_UP - 0.2 - chomp * 0.12)
    p["root_at"] = (0, -0.012, 0)
    ear_pose(p, back=0.14 - chomp * 0.1)
    p["prop_berry"] = "on"
    return p


def mouth_tool(t, keys, tool, rear, dip):
    """A tool in its teeth: rears up on its hind legs and brings its whole front down on the work."""
    p = {}
    v = seq(t, keys)
    up = max(v, 0)
    down = max(-v, 0)
    add(p, "root", rx=up * rear - down * 0.08)
    add(p, "hips", rx=up * rear * 0.4)
    add(p, "spine", rx=up * rear * 0.4 - down * dip)
    add(p, "neck", rx=up * 0.2 - down * dip)
    add(p, "head", rx=LOOK_UP * 0.4 + up * 0.25 - down * dip * 1.4)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=up * 0.7 - down * 0.2)
        add(p, "hleg1." + sd, rx=-up * rear * 0.8)
    p["root_at"] = (0, up * 0.03 - down * 0.02, up * 0.03)
    ear_pose(p, back=0.2 + down * 0.3)
    tail_wave(p, t * 2, 0.04, up=up * 0.2)
    p[tool] = "on"
    return p


def chop_mouth(t):
    return mouth_tool(t, [(0, 0.1), (0.4, 1), (0.52, -1), (0.68, -1), (1, 0.1)], "prop_axe", 0.55, 0.22)


def mine_mouth(t):
    return mouth_tool(t, [(0, 0), (0.38, 1), (0.5, -1), (0.58, -0.7), (1, 0)], "prop_pick", 0.4, 0.34)


def flop(t):
    """Sleep for a low body: flat on its belly, legs out, chin on the ground, the tail laid round."""
    br = s(t, 1)
    p = {}
    p["root_at"] = (0, DROP, 0)
    p["root_sc"] = (1 + br * 0.018, 1 + br * 0.03, 1)
    add(p, "spine", ry=0.14)
    add(p, "neck", rx=-0.16, ry=0.2)
    add(p, "head", rx=-0.12 + br * 0.02, ry=0.22, rz=0.2)
    for sd, sx in SIDES:
        add(p, "fleg1." + sd, rx=1.1, rz=-sx * 0.5)
        add(p, "hleg1." + sd, rx=-1.1, rz=-sx * 0.5)
    ear_pose(p, back=0.5, out=-0.25)
    for i in range(TAIL_N):
        add(p, "tail%d" % (i + 1), ry=-0.3 + br * 0.01)
    return p


def part_bones(parts):
    """The bones of a species' grown parts."""
    out = {}
    for pid, (parent, head, _, _, _) in parts.items():
        if head is not None:
            out["part_" + pid] = (tuple(head), (head[0], head[1] + 0.1, head[2]), parent)
    return out


DROP = -0.09       # how far a flop lowers it (m); set by the species
SHARED = {"idle": (2.8, True, idle), "walk": (0.7, True, walk), "run": (0.44, True, run), "hop": (0.95, True, hop),
          "pet": (2.2, True, pet), "carry": (0.8, True, carry), "tend": (1.3, True, tend)}
