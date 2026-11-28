"""A Hunter's own hand-keyed clips (the 14-bone contract file) laid on Meshy's skeleton: art/wardens/<art>/<art>_clips.glb.
Each contract clip is sampled at FPS and FK'd on the contract rig; the torso lean, the head's turn, each wrist (at the same
reach from its shoulder, scaled to Meshy's arm), elbow side and hand direction and roll are read off it and solved on Meshy's
bones by the two-bone IK of cinder_native_clips.py (no Blender). A `full` clip also takes the hips' height and the ankles'
travel (scaled to Meshy's leg), so planted feet stay planted. Names are `<art>_<clip>` (Meshy's own are Attack, walk ...).
Upper clips key only the torso, head and arms (the game lays them over the legs' clip, WardenNativeUpper).
Run: python3 -I tools/meshy/native_retarget.py <art> [--moves] <clip>[:full][:stride=K] ... [--shot] [--out=FILE]
  stride=K: a full clip's feet travel K times as far fore and aft (a crouch walk too slow for the ground speed).
  --moves: also every kit move of content/rules/warden_anim/<art>.json (prints the data's kmoves rows); --upper: all of
  them as upper clips (a contract rig with no legs)
  e.g. native_retarget.py ryzz lmb_l lmb_r crouch_f:full ult:full      (--shot prints each clip's worst wrist miss)"""

import json
import math
import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "art1"))
sys.path.insert(0, HERE)
import cinder_native_clips as C  # noqa: E402
import glb_add_clips as G  # noqa: E402

FPS = C.FPS
FLIP = np.diag([-1.0, 1.0, -1.0])  # the contract faces -Z, Meshy +Z: the same body turned half a way about Y
SIDE = {s: ("upper_arm." + s, "forearm." + s, "hand." + s, "thigh." + s, "foot." + s) for s in "RL"}
TORSO_W = {"Spine02": 0.3, "Spine01": 0.3, "Spine": 0.4}  # the share of the torso's lean each spine bone takes
HIPS_W = 0.35  # a full clip: the share of that lean the Hips bone takes (the legs are re-solved from the ankles)
NECK_W = 0.4  # the head's turn over the torso: the neck's share, the head bone the rest
POLE_BIAS = np.array([0.3, -0.9, -0.4])  # (r, u, f) the elbow's rest side, so a straight arm has a pole


def slerp(a, b, k):
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        q = a + (b - a) * k
        return q / np.linalg.norm(q)
    th = math.acos(d)
    return (math.sin((1 - k) * th) * a + math.sin(k * th) * b) / math.sin(th)


def frac(m, w):
    """The rotation matrix m turned by the share w of its angle about its own axis."""
    ax = np.array([m[2, 1] - m[1, 2], m[0, 2] - m[2, 0], m[1, 0] - m[0, 1]])
    s = np.linalg.norm(ax)
    ang = math.atan2(s / 2, (np.trace(m) - 1) / 2)
    if s < 1e-9:
        return np.eye(3)
    return C.rot_axis(ax / s, ang * w)


class Contract:
    """The 14-bone contract file: its nodes and clips, FK at any time."""

    def __init__(self, path):
        self.j, self.bin = G.read(path)
        n = self.j["nodes"]
        self.names = [x.get("name", "") for x in n]
        self.idx = {nm: i for i, nm in enumerate(self.names)}
        self.parent = {c: i for i, x in enumerate(n) for c in x.get("children", [])}
        self.t = [np.array(x.get("translation", [0, 0, 0]), float) for x in n]
        self.q = [np.array(x.get("rotation", [0, 0, 0, 1]), float) for x in n]
        self.order = []
        for r in [i for i in range(len(n)) if i not in self.parent]:
            self._walk(r)
        self.rest = self.fk({})

    def _walk(self, i):
        self.order.append(i)
        for c in self.j["nodes"][i].get("children", []):
            self._walk(c)

    def _acc(self, k):
        a = self.j["accessors"][k]
        v = self.j["bufferViews"][a["bufferView"]]
        w = {"SCALAR": 1, "VEC3": 3, "VEC4": 4}[a["type"]]
        off = v.get("byteOffset", 0) + a.get("byteOffset", 0)
        return (
            np.frombuffer(bytes(self.bin[off : off + a["count"] * w * 4]), np.float32)
            .reshape(a["count"], w)
            .astype(float)
        )

    def clip(self, name):
        """{(node, path): (times, values)} and the clip's length."""
        a = next((x for x in self.j["animations"] if x["name"] == name), None)
        if a is None:
            sys.exit("no clip %s in the contract file" % name)
        out, end = {}, 0.0
        for ch in a["channels"]:
            s = a["samplers"][ch["sampler"]]
            tm = self._acc(s["input"])[:, 0]
            out[(ch["target"]["node"], ch["target"]["path"])] = (tm, self._acc(s["output"]))
            end = max(end, float(tm[-1]))
        return out, end

    def fk(self, tracks, t=0.0):
        out = {}
        for i in self.order:
            tl, ql = self.t[i], self.q[i]
            tr = tracks.get((i, "translation"))
            if tr is not None:
                tl = np.array([np.interp(t, tr[0], tr[1][:, k]) for k in range(3)])
            ro = tracks.get((i, "rotation"))
            if ro is not None:
                tm, v = ro
                k = int(np.searchsorted(tm, t, side="right")) - 1
                if k < 0:
                    ql = v[0]
                elif k >= len(tm) - 1:
                    ql = v[-1]
                else:
                    ql = slerp(v[k], v[k + 1], (t - tm[k]) / (tm[k + 1] - tm[k]))
            Rl = C.mat(ql / np.linalg.norm(ql))
            par = self.parent.get(i)
            Rp, pp = out[par] if par is not None else (np.eye(3), np.zeros(3))
            out[i] = (Rp @ Rl, pp + Rp @ tl)
        return out

    def get(self, g, nm):
        return g[self.idx[nm]]


def char(v, side):
    """A contract-frame vector as the (outward, up, forward) of the pose params (C.V, per side)."""
    return (v[0] if side == "R" else -v[0], v[1], -v[2])


def pose_of(cf, ct, mr, full, ref):
    """The pose dict (C.solve's) of contract globals `cf` on Meshy's rig `mr`. `ref`: lengths and rests of both rigs."""
    p = C.rest_pose()
    hips_c = ct.get(cf, "hips")[0]
    lean = FLIP @ hips_c @ FLIP  # the torso's turn from rest (the contract's rest is upright and square)
    head_d = FLIP @ ct.get(cf, "head")[0] @ FLIP @ lean.T  # the head over the torso, in world axes
    spine_w = 1.0 - (HIPS_W if full else 0.0)
    for b, w in TORSO_W.items():
        p["e_" + b] = frac(lean, w * spine_w)
    p["e_neck"] = frac(head_d, NECK_W)
    p["e_Head"] = frac(head_d, 1.0 - NECK_W)
    if full:
        p["hips_rot"] = frac(lean, HIPS_W)
        hp = ct.get(cf, "hips")[1]
        p["hips"] = (hp[0] * ref["kl"], (hp[1] - ref["hips_y"]) * ref["kl"], -hp[2] * ref["kl"])
    over = {b: ("delta", C.rot_euler(p["e_" + b])) for b in C.SPINE}
    if full:
        over["Hips"] = ("delta", C.rot_euler(p["hips_rot"]))
        over[("off", "Hips")] = np.array([-p["hips"][0], p["hips"][1], p["hips"][2]])
    g = mr.fk(over)
    for s in "RL":
        ua, fa, ha, th, ft = SIDE[s]
        S_c, E_c, W_c = (ct.get(cf, n)[1] for n in (ua, fa, ha))
        sh = mr.pos(g, C.ARM[s][1])  # Meshy's shoulder after the lean, as (outward, up, forward)
        sh_char = np.array([-sh[0] if s == "R" else sh[0], sh[1], sh[2]])
        p["w" + s] = tuple(sh_char + np.array(char(W_c - S_c, s)) * ref["ka"])
        pole = np.array(char(E_c - (S_c + W_c) / 2, s)) + POLE_BIAS * 0.03
        p["pole" + s] = tuple(pole)
        hand_c = ct.get(cf, ha)[0]
        d_m = FLIP @ (hand_c @ ct.get(ct.rest, ha)[0].T) @ FLIP  # the hand's world turn from rest, in Meshy's axes
        want = d_m @ ref["hand_rest"][s]
        tip = (FLIP @ hand_c)[:, 1]
        p["rot" + s] = C.arc(want[:, 1], tip) @ want
        if full:
            A_c = ct.get(cf, ft)[1] - ct.get(ct.rest, ft)[1]
            a0 = ref["ankle_rest"][s]
            p["a" + s] = (
                a0[0] + char(A_c, s)[0] * ref["kl"],
                a0[1] + A_c[1] * ref["kl"],
                a0[2] - A_c[2] * ref["kl"] * ref.get("stride", 1.0),
            )
    return p


def refs(ct, mr):
    """Lengths and rests that scale the contract onto Meshy's body."""
    cl = lambda a, b: float(np.linalg.norm(ct.get(ct.rest, a)[1] - ct.get(ct.rest, b)[1]))  # noqa: E731
    ml = lambda a, b: float(np.linalg.norm(mr.pos(mr.rest, a) - mr.pos(mr.rest, b)))  # noqa: E731
    arm_c = cl("upper_arm.R", "forearm.R") + cl("forearm.R", "hand.R")
    arm_m = ml("RightArm", "RightForeArm") + ml("RightForeArm", "RightHand")
    legless = "foot.R" not in ct.idx  # a hovering Hunter (Motley): no legs to scale
    leg_c = 1.0 if legless else cl("thigh.R", "shin.R") + cl("shin.R", "foot.R")
    leg_m = ml("RightUpLeg", "RightLeg") + ml("RightLeg", "RightFoot")
    ankle = {}
    for s in "RL":
        a = mr.pos(mr.rest, C.LEG[s][2])
        ankle[s] = (-a[0] if s == "R" else a[0], a[1], a[2])
    return {
        "ka": arm_m / arm_c,
        "kl": 1.0 if legless else leg_m / leg_c,
        "hips_y": float(ct.get(ct.rest, "hips")[1][1]),
        "ankle_rest": ankle,
        "hand_rest": {s: mr.rest[mr.idx[C.ARM[s][3]]][0] for s in "RL"},
    }


def retarget(art, specs, out_path, shot=False):
    C.RIG = "art/wardens/%s/%s_meshy.glb" % (art, art)
    C.RIGS = None
    mr = C.rig()
    ct = Contract("art/wardens/%s/%s.glb" % (art, art))
    ref = refs(ct, mr)
    print("arm x%.2f leg x%.2f" % (ref["ka"], ref["kl"]))
    defs = {}
    for spec in specs:
        name, *flags = spec.split(":")
        tracks, length = ct.clip(name)
        full = "full" in flags
        stride = next((float(f[7:]) for f in flags if f.startswith("stride=")), 1.0)
        poses = []
        for f in range(int(round(length * FPS)) + 1):
            poses.append(pose_of(ct.fk(tracks, f / FPS), ct, mr, full, dict(ref, stride=stride)))
        defs["%s_%s" % (art, name)] = (poses, full)
        if shot:
            worst = 0.0
            for p in poses:
                over, g = C.solve(p, full)
                for s in "RL":
                    got = mr.pos(g, C.ARM[s][3])
                    want = np.array(C.V(*p["w" + s], side=s))
                    worst = max(worst, float(np.linalg.norm(got - want)))
            print(
                "%s_%s: %d frames, %.2f s, %s, worst wrist miss %.3f m"
                % (art, name, len(poses), length, "full" if full else "upper", worst)
            )
    C.build(out_path, shot=False, defs=defs)


def move_specs(art, upper_only=False):
    """The clip specs and the data's kmoves rows of the contract's own kit moves (content/rules/warden_anim/<art>.json):
    a row the contract lays on the legs' clip (upper, or "moving") stays an upper clip, any other is a full-body one."""
    rows = json.load(open("content/rules/warden_anim/%s.json" % art))["kmoves"]
    specs, out = {}, {}
    for km, r in rows.items():
        up = upper_only or r.get("upper") in (True, "moving")
        specs.setdefault(r["clip"], r["clip"] + ("" if up else ":full"))
        out[km] = {"clip": "%s_%s" % (art, r["clip"])}
        if "hold_from" in r:
            out[km]["hold_from"] = r["hold_from"]
        if up:
            out[km]["upper"] = True
    return list(specs.values()), out


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    art, specs = args[0], args[1:]
    rows = None
    if "--moves" in sys.argv:
        more, rows = move_specs(art, "--upper" in sys.argv)
        specs = more + specs
    out = next((a[6:] for a in sys.argv[1:] if a.startswith("--out=")), "art/wardens/%s/%s_clips.glb" % (art, art))
    retarget(art, specs, out, "--shot" in sys.argv)
    if rows:
        print('"kmoves": ' + json.dumps(rows))
