"""ART-1 Cinder v2: what the scan can't give, as data. The curved lizard horns, the spined tail, the jets at her heels and the licks of fire at her hair's ends.
The body, face, shards and heels are the scan (cinder_source.py). Blender frame: Z up, she faces +Y, her right hand is +X.
Flame pieces are strips with raw UV (u across, v root to tip) and their seed in the vertex colour: shaders/hero_flame.gdshader."""
import json, os
import numpy as np
from meshkit import Piece, catmull, norm, smooth, sweep, frames

HERE = os.path.dirname(os.path.abspath(__file__))
_rig = json.load(open(os.path.join(HERE, "..", "..", "art", "wardens", "src", "cinder_rig.json")))["bones"]


def J(b):
    x, y, z = _rig[b]["head"]
    return np.array([x, -z, y], float)


SH = J("upper_arm.R")[0]
SHOULDER_Z, ELBOW_Z, HAND_Z = J("upper_arm.R")[2], J("forearm.R")[2], J("hand.R")[2]
NECK_Z = J("head")[2]
HIPS_Z = J("hips")[2]
THIGH_Z, THIGH_X = J("thigh.R")[2], J("thigh.R")[0]
ANKLE_Z = 0.13
FORE = HAND_Z - ELBOW_Z
# The empty casting hand, in the solver's "weapon" frame: its palm's normal, the thumb's side (the palm's centre: scene["palm"], from the scan's hand)
GUN_B, GUN_E = np.array((-1.0, 0.0, 0.0)), np.array((0.0, 1.0, 0.0))
MUZZLE_OFF = 0.04                                      # m off the palm, along its normal: where her fire leaves her hand
TAIL_C = "#3a3440"                                     # the grey-violet back of the tail
OBSIDIAN = "metal-obsidian"                            # (its own flat cell: see CELL in cinder_finish)
TAIL_N = 9
TAIL_RINGS = 29
TAIL_FLOOR = 0.13                                      # m at rest: her stance sinks the root .085, and the game holds joints over Springs.FLOOR_UP (.04)
TAIL_R = 0.066                                         # m, at its root
# Out of the small of her back, down behind her, then along the floor round her right side, the tip curling up by her knee
TAIL_PTS = [(0, -.085, HIPS_Z + .07), (0, -.17, HIPS_Z - .06), (.035, -.265, HIPS_Z - .27), (.12, -.345, HIPS_Z - .50), (.27, -.39, HIPS_Z - .665), (.45, -.35, HIPS_Z - .71),
            (.59, -.21, HIPS_Z - .715), (.65, -.03, HIPS_Z - .675), (.625, .10, HIPS_Z - .555)]
DORSAL = np.array((0.0, -0.8, 0.6))
HORN_M = "metal-horn"                                  # (its own painted strip: HORN_UV in cinder_finish)
HORN_C, HORN_TIP = "#4a4452", "#1a1520"                # grey-violet stone at the root, near black at the tip
# Her right horn, off the head joint: out of the skull's side-top, up and out, then back (the sheet's curve); the left is its mirror
HORN_PTS = [(.078, -.035, .238), (.098, -.045, .280), (.116, -.065, .323), (.126, -.090, .360), (.124, -.115, .386)]
HORN_R = 0.027                                         # m, at its root
HORN_RINGS = 16
HORN_SEC = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
SEC = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 10, endpoint=False)]


def tail(uv_rect):
    """The long lizard tail, a tapering tube whose UV runs down a strip of the atlas; its flame is the anchor at its tip (an FX, not a mesh)."""
    path = catmull(TAIL_PTS, TAIL_RINGS)
    path[:, 2] = np.maximum(path[:, 2], TAIL_FLOOR)
    k = np.linspace(0, 1, TAIL_RINGS)
    wd = TAIL_R * (1 - k) ** 0.8 + 0.006
    p = sweep("tail", "skin-cinder", path, SEC, wd, side_hint=np.array([0, 0, 1.0]), uv_rect=uv_rect, depth=wd * 0.94)
    p.t = np.concatenate([np.repeat(k, len(SEC)), np.ones(len(p.v) - len(k) * len(SEC))])
    p.path, p.wd = path, wd
    return p


def horns(uv_rect):
    """The curved lizard horns: tapering tubes rigid on the head, every other ring a slight swell (growth rings). UV: u round, v root to tip."""
    k = np.linspace(0, 1, HORN_RINGS)
    swell = np.where((np.arange(HORN_RINGS) % 2 == 1) & (k > 0.1) & (k < 0.9), 1.06, 0.97)
    wd = HORN_R * ((1 - k) ** 0.85 + 0.08) * swell
    out = []
    for sd, m in (("R", (1, 1, 1)), ("L", (-1, 1, 1))):
        path = catmull([(x * m[0], y, NECK_Z + z) for x, y, z in HORN_PTS], HORN_RINGS)
        out.append(sweep("horn." + sd, HORN_M, path, HORN_SEC, wd, side_hint=np.array([0, 1.0, 0]), uv_rect=uv_rect, depth=wd * 0.9).rigid("head"))
    return out


def spines(tl, count=24):
    """Her dorsal row: obsidian barbs along the tail, biggest near the root. Each sits on the ridge, raking back. u: its place on the tail."""
    out = []
    path, wd = tl.path, tl.wd
    t_, s_, n_ = frames(path, np.array([0, 0, 1.0]))
    n = len(path)
    for i in range(count):
        u = 0.1 + 0.86 * i / (count - 1)
        c = min(int(u * (n - 1)), n - 2)
        up = norm(DORSAL - t_[c] * (t_[c] @ DORSAL))        # her tail's back: away from her legs, then up
        at = path[c]
        ln = (0.075 * (1 - u) ** 0.7 + 0.018) * (1.0 if i % 2 else 0.78)
        along, side = t_[c] * ln * 0.9, np.cross(up, t_[c]) * ln * 0.2
        base = at + up * wd[c] * 0.72
        v = [base - along * 0.5 - side, base - along * 0.5 + side, base + along * 0.5, base + up * ln + along * 0.55]
        p = Piece("spine%d" % i, OBSIDIAN, v, [[0, 1, 3], [1, 2, 3], [2, 0, 3], [0, 2, 1]], room=0.0)
        p.tail_u = u
        out.append(p)
    return out


def strip(name, mat, pts, width, rows=6, hint=(0, 1, 0), seed=None, bright=0.0, tent=0.22, peak=0.3, root=0.5):
    """One tongue of fire: three columns of verts along a path (a shallow tent, so it's no flat card). Raw UV: u across, v along.
    width: the widest, m; root: its share at the root; it narrows to a point. One-sided faces, drawn from both (cull_disabled)."""
    path = catmull(pts, rows)
    k = np.linspace(0, 1, rows)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(peak, 1.0, k)) ** 0.75
    wd = width * np.maximum(prof, 0.05)
    t, s, nn = frames(path, np.asarray(hint, float))
    v, uv = [], []
    for i in range(rows):
        for u, off in ((0.0, -1.0), (0.5, 0.0), (1.0, 1.0)):
            v.append(path[i] + s[i] * off * wd[i] * 0.5 + nn[i] * (1 - abs(off)) * wd[i] * tent)
            uv.append((u, k[i]))
    f, fuv = [], []
    for i in range(rows - 1):
        for j in range(2):
            a = i * 3 + j
            q = [a, a + 1, a + 4, a + 3]
            f.append(q)
            fuv.append([uv[x] for x in q])
    p = Piece(name, mat, v, f, fuv, room=0.0)
    p.flame = True
    p.t = np.repeat(k, 3)
    p.path = path
    sd = (hash(name) % 997) / 997.0 if seed is None else seed
    p.fire = (sd, bright, 1.0)
    return p


def weight_tail(tl, spns):
    names = ["spring_scarftail_tail_%d" % i for i in range(TAIL_N)]
    nb = TAIL_N - 1

    def set_w(pc, ts):
        w = {n: np.zeros(len(pc.v)) for n in names[:-1]}
        w["root"] = np.zeros(len(pc.v))
        for i, t in enumerate(ts):
            u = float(smooth(0.0, 0.08, t))
            x = np.clip(t, 0, 0.9999) * (nb - 1 + 0.999)
            b = int(x)
            q = x - b
            w["root"][i] = 1 - u
            w[names[min(b, nb - 1)]][i] += u * (1 - q)
            w[names[min(b + 1, nb - 1)]][i] += u * q
        pc.w = w
    set_w(tl, tl.t)
    for s in spns:
        set_w(s, np.full(len(s.v), s.tail_u))


def jet_flames(tips):
    """The fire at her heels: crossed strips on their own bones, nearly nothing at rest; the flight clip stretches them into jets."""
    out = []
    for i, (p, ax) in enumerate(tips):
        k1 = norm(np.cross(ax, (0.2, 1, 0)))
        for j, a in enumerate((0.0, 1.05, 2.1)):
            side = k1 * np.cos(a) + np.cross(ax, k1) * np.sin(a)
            ln = 0.27 - 0.04 * j
            o = strip("jet%d_%d" % (i, j), "flame-jet", [p - ax * 0.015, p + ax * ln * 0.35 + side * 0.012, p + ax * ln * 0.7 - side * 0.015, p + ax * ln + side * 0.012], 0.135 - 0.02 * j,
                      rows=5, hint=side, seed=0.11 + 0.17 * i + 0.21 * j, bright=0.45, root=0.9)
            out.append(o.rigid("jet.%d" % i))
    return out
