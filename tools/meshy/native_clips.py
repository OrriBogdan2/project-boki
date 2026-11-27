"""Pose clips every native Hunter shares, written on each Hunter's own Meshy skeleton (art/wardens/<art>/<art>_clips.glb).

  /home/boki/venv-img/bin/python3 tools/meshy/native_clips.py [ART ...] [--sheet DIR]

No art: every Hunter WardenNative draws (content/rules/warden_native.json). Meshy's library gave each Hunter only
idle, walk, run, jump, crouch and attack; these fill three gaps of tools/anim_coverage.py the same way for all of them:
  <art>_downed  the knocked-down beat (HunterFall, 0.4-0.5 s): staggers back off the hit, drops to both knees and
                slumps forward onto the hands. WardenNative runs it as far in as the beat is (not on its own clock).
  <art>_dash    (not OWN_DASH) the Shift dash: a low push into a long forward lunge, arms swept back, held.
  <art>_idle    (CASUAL only) the out-of-combat stand: both arms hang at the sides, the weapon low in the hand, a
                breath and a weight shift. Meshy's own Idle (weapon held out front) becomes the combat idle.
Poses are measured from each skeleton (arm, thigh and shin lengths, the shoulders), so one recipe fits Pip and
Dredge alike. Lace's file is written by lace_clips.py with these clips added beside her bow clips.
--sheet writes the stick-figure sheets (lace_clips.sheet layout) for a check before any render.
"""

import json
import math
import os
import struct
import sys

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lace_clips as L  # noqa: E402

ROOT = os.path.join(L.HERE, "..", "..")
DATA = os.path.join(ROOT, "content", "rules", "warden_native.json")
CASUAL = {"gil", "vex"}  # Meshy's idle holds the weapon out front (tools/anim_coverage.py WEAPON_OUT_IDLE)
OWN_WRITER = {"hem": "lace_clips"}  # Hunters whose clip file another script writes (it adds these clips)
Y, A = L.Y, np.array([0.0, 0.0, 1.0])  # up; the way every clip faces (the game turns the model)
DOWN_LEN = 0.45  # s: HunterFall's medium beat (the game seeks it by the beat's share, so only the shape matters)
IDLE_LEN = 4.0  # s: one breath-and-shift loop
DASH_LEN = 0.3  # s: into the lunge, then held to the dash's end (WardenNative holds a slot clip's last frame)
OWN_DASH = {"vex", "hem"}  # Hunters with their own dash (Vex: a clip; Lace: her pin_roll kit moves)


class Body:
    """The skeleton's measures the poses are built from."""

    def __init__(self, rig):
        self.rig = rig
        self.thigh, self.shin = rig.length("LeftUpLeg"), rig.length("LeftLeg")
        self.arm = rig.length("LeftArm") + rig.length("LeftForeArm")
        self.ankle = rig.pos("LeftFoot")[1]
        self.drop = rig.hips_t[1] - rig.pos("LeftUpLeg")[1]  # Hips bone over the hip joints
        self.wide = float(np.linalg.norm(rig.pos("LeftArm") - rig.pos("RightArm")))
        self.toe = {s: rig.bind[rig.id[s + "Foot"]][:3, :3] @ Y for s in ("Left", "Right")}


def lerp(a, b, k):
    return a + (b - a) * k


def pose(b, q):
    """The fk pose of the parameters q (all numbers, so key frames blend): lean/head deg (forward +), back m (hips
    behind), kneel 0..1 (standing legs -> both knees on the ground), sit 0..1 (kneeling upright -> back on the heels),
    hands 0..1 (at the sides -> on the ground ahead), fling 0..1 (arms thrown out), sway m, look deg."""
    rig = b.rig
    S = np.cross(Y, A)
    kneel, sit = q["kneel"], q["sit"]
    # hips: from the stand down to the knees' height plus the thigh (upright) or less (sat back on the heels)
    knee_y = b.ankle * 0.7
    hip_up = knee_y + b.thigh * lerp(1.0, 0.62, sit) + b.drop
    hy = lerp(rig.hips_t[1] - q.get("crouch", 0.0) - q.get("dip", 0.0) * b.thigh, hip_up, kneel)
    hips = (q.get("sway", 0.0), hy - rig.hips_t[1], -q["back"])
    split = {"Hips": 0.25, "Spine": 0.25, "Spine01": 0.25, "Spine02": 0.25}
    turn = {k: (q["lean"] * v, 0.0, 0.0) for k, v in split.items()}
    turn["neck"] = (q["head"] * 0.5, q.get("look", 0.0) * 0.45, 0.0)
    turn["Head"] = (q["head"] * 0.5, q.get("look", 0.0) * 0.55, 0.0)
    base = {"turn": turn, "hips": hips}
    pre = L.fk(rig, base)[1]
    ik, aim = [], {}
    for side, sgn in (("Left", 1.0), ("Right", -1.0)):
        out = S * sgn
        hj = pre[rig.id[side + "UpLeg"]]
        step = A * q.get("step_" + side[0], 0.0) * b.thigh + Y * q.get("lift_" + side[0], 0.0) * b.thigh
        stand = rig.pos(side + "Foot") + step
        # kneeling: the knee on the ground ahead of the hip joint, the shin back along the floor
        rise = min(hj[1] - knee_y, b.thigh * 0.999)
        fwd = math.sqrt(b.thigh**2 - rise**2)
        knee = np.array([hj[0] + out[0] * 0.03, knee_y, hj[2] + fwd])
        foot_k = knee - A * b.shin * 0.97 + Y * (b.ankle * 0.5 - knee_y)
        foot = lerp(stand, foot_k, kneel)
        pole = L.unit(lerp(A, L.unit(knee - (hj + foot) / 2), kneel) + out * 0.05)
        ik.append((side + "UpLeg", side + "Leg", side + "Foot", foot, pole))
        aim[side + "Foot"] = (L.unit(lerp(b.toe[side], -A + Y * -0.15, kneel)), 0.0)
        # hands: hanging by the thigh, flung out, or flat on the ground ahead under the shoulders
        sh = pre[rig.id[side + "Arm"]]
        hang = sh + out * (0.1 * b.arm) + A * (0.06 * b.arm) - Y * (0.93 * b.arm)
        hang = hang + A * q.get("swing_" + side[0], 0.0) * b.arm
        flung = sh + out * (0.55 * b.arm) - Y * (0.55 * b.arm) + A * (0.25 * b.arm)
        ground = np.array([sh[0] + out[0] * 0.04, b.ankle * 0.3, knee[2] + 0.45 * b.arm])
        hand = lerp(lerp(hang, flung, q["fling"]), ground, q["hands"])
        ik.append((side + "Arm", side + "ForeArm", side + "Hand", hand, -A * 0.8 + out * 0.6 - Y * 0.2))
    p = dict(base)
    p["ik"] = ik
    p["aim"] = aim
    return p


STAND = dict(lean=0.0, head=0.0, back=0.0, kneel=0.0, sit=0.0, hands=0.0, fling=0.0, crouch=0.01)
# the knocked-down beat: shoved back off the hit, the knees give, down on both, slumped onto the hands
HIT = dict(STAND, lean=-12.0, head=-10.0, back=0.06, fling=0.8, crouch=0.12)
KNEES = dict(STAND, lean=10.0, head=10.0, back=0.04, kneel=1.0, fling=0.3, hands=0.35)
SLUMP = dict(STAND, lean=48.0, head=30.0, back=0.12, kneel=1.0, sit=1.0, hands=1.0)
# the dash (Shift, held while it lasts): a low push off the back foot into a long forward lunge, arms swept back
PUSH = dict(STAND, lean=14.0, head=-8.0, dip=0.2, step_L=0.25, step_R=-0.2, swing_L=-0.15, swing_R=0.1)
LUNGE = dict(STAND, lean=24.0, head=-16.0, dip=0.32, step_L=0.7, step_R=-0.55, lift_R=0.12, swing_L=-0.35, swing_R=0.3)


def clips(art):
    out = {
        art + "_downed": (
            DOWN_LEN,
            [(0.0, STAND, "lin"), (0.3, HIT, "smooth"), (0.6, KNEES, "smooth"), (0.75, SLUMP, "smooth")],
        )
    }
    if art not in OWN_DASH:
        out[art + "_dash"] = (DASH_LEN, [(0.0, PUSH, "lin"), (0.45, LUNGE, "snap"), (1.0, LUNGE, "lin")])
    if art in CASUAL:
        out[art + "_idle"] = (IDLE_LEN, [(0.0, STAND, "lin"), (IDLE_LEN, STAND, "lin")])
    return out


def at(art, name, t):
    length, keys = clips(art)[name]
    q = L.track([(k * length if not name.endswith("_idle") else k, p, e) for k, p, e in keys], t)
    if name.endswith("_idle"):  # a breath, a weight shift and a slow look round (whole periods: it loops)
        ph = 2 * math.pi * t / length
        q["sway"] = 0.012 * math.sin(ph)
        q["lean"] += 1.2 * math.sin(2 * ph)
        q["look"] = 8.0 * math.sin(ph)
        q["swing_L"] = 0.02 * math.sin(ph + 1.0)
        q["swing_R"] = 0.02 * math.sin(ph + 2.5)
    return q


def sample(b, art, name):
    """(times, {joint: [local quats]}, [hips translations]) of a clip at 30 fps."""
    length = clips(art)[name][0]
    n = int(round(length * L.FPS)) + 1
    times = [i / L.FPS for i in range(n)]
    rots = {j: [] for j in b.rig.joints}
    hips = []
    for t in times:
        loc, pos = L.fk(b.rig, pose(b, at(art, name, t)))
        for j in b.rig.joints:
            rots[j].append(L.quat(loc[j]))
        hips.append(pos[b.rig.root])
    for j in b.rig.joints:
        for i in range(1, n):
            if np.dot(rots[j][i], rots[j][i - 1]) < 0:
                rots[j][i] = -rots[j][i]
    return times, rots, hips


def anims(rig, art):
    """[(name, times, rots, hips)] for lace_clips.write_glb's extra clips."""
    b = Body(rig)
    return [(name,) + sample(b, art, name) for name in clips(art)]


def read_glb(path):
    b = open(path, "rb").read()
    n = struct.unpack("<I", b[12:16])[0]
    js = json.loads(b[20 : 20 + n])
    return js, bytearray(b[20 + n + 8 :])


def append_glb(path, rig, extra):
    """Adds the clips to a clip file another tool made (Kael's Blender export), on its nodes matched by bone name;
    a clip of the same name is replaced, everything else in the file is kept byte for byte."""
    js, blob = read_glb(path)
    node = {nd.get("name"): i for i, nd in enumerate(js["nodes"])}
    names = {x[0] for x in extra}
    js["animations"] = [a for a in js.get("animations", []) if a["name"] not in names]
    js["bufferViews"] = js.get("bufferViews", [])
    js["accessors"] = js.get("accessors", [])

    def add(arr, typ, count):
        data = np.asarray(arr, "<f4").tobytes()
        while len(blob) % 4:
            blob.append(0)
        js["bufferViews"].append({"buffer": 0, "byteOffset": len(blob), "byteLength": len(data)})
        blob.extend(data)
        a = {"bufferView": len(js["bufferViews"]) - 1, "componentType": 5126, "count": count, "type": typ}
        if typ == "SCALAR":
            a.update(min=[float(np.min(arr))], max=[float(np.max(arr))])
        js["accessors"].append(a)
        return len(js["accessors"]) - 1

    for name, times, rots, hips in extra:
        t_acc = add(times, "SCALAR", len(times))
        chans, samplers = [], []
        for j in rig.joints:
            nm = rig.name[j]
            if nm not in node or nm.startswith("SkirtSw"):
                continue
            samplers.append({"input": t_acc, "output": add(rots[j], "VEC4", len(times)), "interpolation": "LINEAR"})
            chans.append({"sampler": len(samplers) - 1, "target": {"node": node[nm], "path": "rotation"}})
        samplers.append({"input": t_acc, "output": add(hips, "VEC3", len(times)), "interpolation": "LINEAR"})
        chans.append({"sampler": len(samplers) - 1, "target": {"node": node[rig.name[rig.root]], "path": "translation"}})
        js["animations"].append({"name": name, "channels": chans, "samplers": samplers})
    while len(blob) % 4:
        blob.append(0)
    js["buffers"] = [{"byteLength": len(blob)}]
    j = json.dumps(js, separators=(",", ":")).encode()
    j += b" " * (-len(j) % 4)
    with open(path, "wb") as f:
        f.write(struct.pack("<III", 0x46546C67, 2, 12 + 8 + len(j) + 8 + len(blob)))
        f.write(struct.pack("<II", len(j), 0x4E4F534A) + j)
        f.write(struct.pack("<II", len(blob), 0x004E4942) + bytes(blob))


def sheet(rig, art, outdir):
    os.makedirs(outdir, exist_ok=True)
    b = Body(rig)
    views = [(2, 1, 130), (0, 1, 130), (0, 2, 100)]
    for name, (length, _) in clips(art).items():
        img = Image.new("RGB", (5 * 3 * 150, 330), "white")
        d = ImageDraw.Draw(img)
        for k in range(5):
            t = length * k / 4
            pos = L.fk(rig, pose(b, at(art, name, t)))[1]
            for v, (hx, vy, sc) in enumerate(views):
                ox, oy = (k * 3 + v) * 150 + 75, (300 if v < 2 else 165)
                d.line([ox - 70, oy, ox + 70, oy], fill="green")
                for a, c in L.BONES:
                    p, r = pos[rig.id[a]], pos[rig.id[c]]
                    col = "red" if "Left" in c else "blue" if "Right" in c else "black"
                    d.line([ox + p[hx] * sc, oy - p[vy] * sc, ox + r[hx] * sc, oy - r[vy] * sc], fill=col, width=3)
            d.text((k * 450 + 4, 4), "%s t=%.2f" % (name, t), fill="black")
        img.save(os.path.join(outdir, name + ".png"))


def main():
    args = sys.argv[1:]
    sheet_dir = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet_dir = args[i + 1]
        del args[i : i + 2]
    data = json.load(open(DATA))
    arts = args or [k for k, v in data.items() if isinstance(v, dict) and v.get("meshy_native")]
    for art in arts:
        rig = L.Rig(os.path.join(ROOT, "art", "wardens", art, art + "_meshy.glb"))
        if sheet_dir:
            sheet(rig, art, sheet_dir)
        path = os.path.join(ROOT, "art", "wardens", art, art + "_clips.glb")
        made = os.path.exists(path) and read_glb(path)[0]["asset"].get("generator") != "tools/meshy/native_clips.py"
        if art in OWN_WRITER:  # (her bow clips and these, one file)
            L.write_glb(L.Rig(L.SRC), path, extra=anims(rig, art))
        elif made:  # (another tool's clip file: these are added to it)
            append_glb(path, rig, anims(rig, art))
        else:
            L.write_glb(rig, path, extra=anims(rig, art), own=False)
        print(art, path, ", ".join(clips(art)))


if __name__ == "__main__":
    main()
