"""ART-1 Kael v2 (briefs/art-refs/kael_v2/): the pieces built by script around the scan, as data (meshkit Pieces).
Body pieces are in the Blender frame (Z up, he faces +Y, his right hand is +X), on the rig of art/wardens/src/kael_rig.json.
The sword is built in a Gun's space (+Y along the blade, the grip about the origin; sword_matrix puts it in his fist, where it
is skinned to the hand: the clips carry it): the turnaround's broad cracked blade, the guard, the red wrapped grip, the ring pommel with its hooked chain.
Its size is the turnaround's against his height (FIDELITY_CHECKLIST weapon scale): whole sword 0.80 of his height, blade
0.61, blade width 0.10; the Gun scale (1.42) and the owner's 0.85 (Nov 4) go on top, so one Gun metre
is GUN_M of his model metres."""
import os, json
import numpy as np
from meshkit import Piece, norm, sweep, chain_along

RIG = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "wardens", "src", "kael_rig.json")))
CROWN = RIG["land"]["crown"]                  # his height, model metres
GUN_M = 1.42 * 0.85                           # model metres per Gun metre (heavy Gun scale x the owner's 0.85, Nov 4)
HAND = {sd: np.array([x, -z, y]) for sd, (x, y, z) in ((sd, RIG["bones"]["hand." + sd]["head"]) for sd in "RL")}     # Blender frame


def gun(frac):
    """A share of his height in Gun metres."""
    return frac * CROWN / GUN_M


BLADE_L = gun(0.61)
BLADE_W = gun(0.103) * 0.5                    # half width
BLADE_T = 0.016                               # half thickness at the flat
GUARD_Y = 0.075                               # the guard's grip side; the fist closes just below it
GRIP_L = gun(0.15)
BLADE_Y0 = GUARD_Y + 0.034


def _half_width(t):
    """The blade's half width along its length (0 guard, 1 tip): a narrow neck, the shoulders, a long straight run, the point."""
    if t < 0.06:
        return BLADE_W * (0.8 + 0.2 * t / 0.06)
    if t < 0.86:
        return BLADE_W * (1.0 - 0.06 * (t - 0.06) / 0.8)
    return BLADE_W * 0.94 * max(0.0, 1.0 - (t - 0.86) / 0.14) ** 0.8


def blade():
    """A slab with bevelled edges: the flat (both faces), the bevels to a thin edge, the point."""
    sec = [(1.0, 0.0), (0.78, 1.0), (-0.78, 1.0), (-1.0, 0.0), (-0.78, -1.0), (0.78, -1.0)]
    rings = 26
    v, f = [], []
    for i in range(rings):
        t = i / (rings - 1)
        y = BLADE_Y0 + BLADE_L * t
        w = max(_half_width(t), 0.002)
        th = BLADE_T * (0.35 + 0.65 * min(1.0, w / BLADE_W))
        for a, b in sec:
            v.append((a * w, y, b * th))
    m = len(sec)
    flat, bevel = [], []
    for i in range(rings - 1):
        for j in range(m):
            q = [i * m + j, i * m + (j + 1) % m, (i + 1) * m + (j + 1) % m, (i + 1) * m + j]
            (flat if j in (1, 4) else bevel).append(q)
    base = list(range(m))[::-1]
    return [Piece("blade", "metal-sword", v, flat), Piece("bevel", "metal-sword_edge", v, bevel + [base])]


def cracks(seed=7):
    """The white-hot cracks on both faces (glow-sword): a long wandering crack, plates broken off it toward the edges."""
    rng = np.random.default_rng(seed)
    lines = []
    y, x = BLADE_Y0 + 0.06, 0.0
    main = []
    while y < BLADE_Y0 + BLADE_L * 0.86:
        main.append((x, y))
        y += rng.uniform(0.05, 0.09)
        x = float(np.clip(x + rng.uniform(-0.025, 0.025), -BLADE_W * 0.35, BLADE_W * 0.35))
    lines.append(main)
    for k in range(1, len(main) - 1, 2):
        x0, y0 = main[k]
        sgn = 1.0 if (k // 2) % 2 == 0 else -1.0
        tgt = sgn * BLADE_W * 0.78
        lines.append([(x0, y0), ((x0 + tgt) * 0.5, y0 + rng.uniform(0.02, 0.06)), (tgt, y0 + rng.uniform(0.07, 0.13))])
    v, f = [], []
    for side in (1.0, -1.0):
        for ln in lines:
            p = np.array(ln, float)
            for i in range(len(p) - 1):
                d = norm(p[i + 1] - p[i])
                n = np.array([-d[1], d[0]]) * 0.0042
                o = len(v)
                z = side * (BLADE_T + 0.0012)
                for q in (p[i] - n, p[i] + n, p[i + 1] + n, p[i + 1] - n):
                    v.append((q[0], q[1], z))
                f.append([o, o + 1, o + 2, o + 3] if side > 0 else [o + 3, o + 2, o + 1, o])
    return Piece("cracks", "glow-sword", v, f)


def _box(name, mat, c, h):
    c, h = np.asarray(c, float), np.asarray(h, float)
    v = [c + h * np.array([sx, sy, sz]) for sz in (-1, 1) for sy in (-1, 1) for sx in (-1, 1)]
    f = [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
    return Piece(name, mat, v, f)


def _ring(name, mat, c, axis, side, r, th, n=10):
    """A torus round `axis` through c."""
    axis, side = norm(np.asarray(axis, float)), norm(np.asarray(side, float))
    up = np.cross(axis, side)
    path = [c + (side * np.cos(t) + up * np.sin(t)) * r for t in np.linspace(0, 2 * np.pi, n + 1)]
    sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 5, endpoint=False)]
    return sweep(name, mat, path, sec, np.full(n + 1, th), side_hint=axis, tip=False)


def hilt():
    """The guard bar with its point over the blade, the red wrapped grip, the ring pommel, the chain and its hook."""
    gw = BLADE_W * 1.12
    out = [_box("guard", "metal-sword_dk", (0, GUARD_Y + 0.017, 0), (gw, 0.017, 0.03))]
    tri = [(-BLADE_W * 0.55, BLADE_Y0, 0), (BLADE_W * 0.55, BLADE_Y0, 0), (0, BLADE_Y0 + 0.06, 0)]
    for s in (1.0, -1.0):
        v = [(x, y, s * (BLADE_T + 0.004)) for x, y, _ in tri]
        out.append(Piece("guardplate", "metal-sword_dk", v, [[0, 1, 2] if s > 0 else [2, 1, 0]]))
    ys = np.linspace(GUARD_Y, GUARD_Y - GRIP_L, 7)
    sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    out.append(sweep("grip", "leather-grip", [(0, y, 0) for y in ys], sec, np.full(7, 0.021), side_hint=(1, 0, 0), tip=False))
    py = GUARD_Y - GRIP_L
    out.append(sweep("pommel", "metal-sword_dk", [(0, py + 0.004, 0), (0, py - 0.018, 0)], sec, np.array([0.027, 0.024]), side_hint=(1, 0, 0)))
    ring_c = np.array([0.0, py - 0.036, 0.0])
    out.append(_ring("pring", "metal-sword_dk", ring_c, (0, 0, 1), (1, 0, 0), 0.016, 0.0045))
    # the chain hangs from the ring beside the grip, then the hook curls up (the turnaround's sword, held point up)
    hang = [ring_c + (0.018, -0.006, 0), ring_c + (0.05, 0.01, 0), ring_c + (0.068, 0.07, 0), ring_c + (0.072, 0.15, 0)]
    out.append(chain_along("pchain", hang, step=0.029, ln=0.034, wid=0.019, th=0.0048))
    h0 = hang[-1]
    hook = [h0, h0 + (0.002, 0.03, 0), h0 + (0.0, 0.07, 0), h0 + (-0.022, 0.092, 0), h0 + (-0.046, 0.08, 0), h0 + (-0.05, 0.058, 0)]
    out.append(sweep("hook", "metal-sword_dk", hook, sec, np.array([0.0085, 0.009, 0.0085, 0.0075, 0.006, 0.003]), side_hint=(0, 0, 1)))
    for p in out[-2:]:
        p.mat = "metal-sword_dk"
    return out


def sword():
    """Every piece of the weapon, in the Gun's frame."""
    return blade() + [cracks()] + hilt()


GRIP_DIR = norm(np.array([0.0, 0.76, -0.65]))    # the blade from the fist at rest (he faces +Y, the hand hangs): forward and down


def sword_matrix(fist):
    """The sword is skinned to the hand (the clips move it): Gun space -> model metres, the grip's middle in the fist at `fist`,
    the blade along GRIP_DIR, its flats facing sideways. Returns (3x3, offset)."""
    e = norm(np.cross(GRIP_DIR, (1.0, 0, 0)))
    e = e if e[2] > 0 else -e
    m = np.column_stack([-e, GRIP_DIR, np.cross(GRIP_DIR, e)]) * GUN_M
    return m, np.asarray(fist, float) - m @ np.array([0.0, GUARD_Y - GRIP_L / 2, 0.0])


def wrist_chain(side, bones):
    """A short iron chain hanging from the cuff's outer edge to mid-thigh, on two hang bones (WardenGlb.Springs)."""
    sx = 1.0 if side == "R" else -1.0
    top = HAND[side] + np.array([sx * 0.045, 0.0, 0.02])
    path = [top + (0, 0, -0.17 * k / 5) + (sx * 0.006 * np.sin(k), 0.004 * k, 0) for k in range(6)]
    pc = chain_along("cuffchain" + side, path, step=0.032, ln=0.038, wid=0.021, th=0.0056)
    pc.mat = "metal-chain"
    k = np.clip((top[2] - pc.v[:, 2]) / 0.17, 0, 1)
    pc.w = {bones[0]: 1.0 - k, bones[1]: k}
    return pc, [top, top + (0, 0, -0.085), top + (0, 0, -0.17)]


def card(name, path, width, side_hint, v_rect, weights):
    """A strip of alpha card along a path (one quad per segment), u across, v down the path inside v_rect (a card cell)."""
    path = np.asarray(path, float)
    n = len(path)
    s = norm(np.asarray(side_hint, float))
    v, f, uv = [], [], []
    u0, v0, u1, v1 = v_rect
    for i in range(n):
        w = width[i]
        v += [path[i] - s * w, path[i] + s * w]
    for i in range(n - 1):
        a = i * 2
        f.append([a, a + 1, a + 3, a + 2])
        ya, yb = v0 + (v1 - v0) * i / (n - 1), v0 + (v1 - v0) * (i + 1) / (n - 1)
        uv.append([(u0, ya), (u1, ya), (u1, yb), (u0, yb)])
    pc = Piece(name, "card-kael", v, f, uv, room=0.0)
    pc.w = {b: np.repeat(np.asarray(wt, float), 2) for b, wt in weights.items()}
    return pc
