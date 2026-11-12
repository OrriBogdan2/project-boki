"""Grimble, the Scrap King (ART-1; id and files stay `dredge`): the shapes, as signed distance fields on the rig's own joints.
Refs: briefs/art-refs/grimble_FINAL_sheet (master), grimble_turnaround, grimble_weapons. One eye behind the monocle, always.
Space: Blender's, he faces +Y, his right +X, up +Z, metres at the class-neutral size. The hoard is big simple shapes: it is a
silhouette from the match camera first, and it has to fit the 20k budget with him."""
import json
import math

import numpy as np

from hem_sdf import Field, Prim, box, cap, cyl, ell, path, smooth, sph

F = np.float32

# labels (below 100: materials; 100 and up: one hoard item each, HOARD)
SKIN, LIP, MOUTH, TOOTH, IRON, RUST, BRASS, LEATHER, LOIN, WOOD, BURLAP, GOLD, GLASS, EYE, LAMP, ROPE, DARK = range(1, 18)
HOARD_BASE = 100
HOARD = []          # {id, kind, c, R}: the painter reads an item's own frame from here

# v2's scan head, fitted (grimble_source.py): it hangs far ahead of the neck joint, the art's hunch
HEAD_C = np.array((0.004, 0.426, 1.237), F)     # the head's middle
HEAD_TOP = np.array((0.0, 0.42, 1.41), F)
EYE_C = np.array((0.086, 0.525, 1.277), F)      # his right eye, behind the loupe's big lens
ANKLE = 0.075


def joints(rig_path):
    with open(rig_path) as f:
        rig = json.load(f)
    return {k: np.array([v["head"][0], -v["head"][2], v["head"][1]], F) for k, v in rig["bones"].items()}


def rot(yaw=0.0, pitch=0.0, roll=0.0):
    """Item frame -> model: yaw about Z, pitch about X, roll about Y (radians)."""
    cz, sz, cx, sx, cy, sy = math.cos(yaw), math.sin(yaw), math.cos(pitch), math.sin(pitch), math.cos(roll), math.sin(roll)
    Rz = np.array(((cz, -sz, 0), (sz, cz, 0), (0, 0, 1)), F)
    Rx = np.array(((1, 0, 0), (0, cx, -sx), (0, sx, cx)), F)
    Ry = np.array(((cy, 0, sy), (0, 1, 0), (-sy, 0, cy)), F)
    return Rz @ Rx @ Ry


def custom(fn, lo, hi):
    return Prim(fn, lo, hi)


def fixed(c, R, fn, e):
    """A prim written in an item's frame: fn(u, v, w) -> distance. e: its bounding radius."""
    c = np.array(c, F)

    def world(x, y, z):
        px, py, pz = x - c[0], y - c[1], z - c[2]
        return fn(R[0, 0] * px + R[1, 0] * py + R[2, 0] * pz, R[0, 1] * px + R[1, 1] * py + R[2, 1] * pz,
                  R[0, 2] * px + R[1, 2] * py + R[2, 2] * pz)
    return Prim(world, c - e, c + e)


def L(c, R, p):
    """An item's local point -> model."""
    return tuple(np.array(c, F) + R @ np.array(p, F))


# ------------------------------------------------------------------ the head: the grin is the character
MOUTH_W = 0.089


def grin_z(x):
    """The mouth's centre line, head space: a wide upturned curve, crooked (his left corner higher)."""
    return -0.046 + 2.1 * x * x - 0.10 * x


def grin_h(x):
    return 0.0395 * np.clip(1 - (x / MOUTH_W) ** 2, 0, 1) ** 0.62


MONO_AX = np.array((0.04, 1.0, 0.06), F) / np.linalg.norm((0.04, 1.0, 0.06))
MONO_C = EYE_C + MONO_AX * 0.040
MONO_R = 0.0505
LENS = (((-0.058, 0.012, 0.070), 0.0205), ((-0.082, 0.012, 0.032), 0.0165))       # the two small lenses, his left of the big one


def _ring(c, ax, r, t, wide=0.8):
    """A flat ring round axis ax (a torus of a squashed section)."""
    c = np.array(c, F)
    ax = np.array(ax, F)

    def fn(x, y, z):
        px, py, pz = x - c[0], y - c[1], z - c[2]
        along = px * ax[0] + py * ax[1] + pz * ax[2]
        qx, qy, qz = px - ax[0] * along, py - ax[1] * along, pz - ax[2] * along
        rad = np.sqrt(qx * qx + qy * qy + qz * qz)
        return np.sqrt((rad - r) ** 2 + (along / wide) ** 2) - t
    return Prim(fn, c - r - t - 0.01, c + r + t + 0.01)


def monocle(vox=0.0012):
    m = Field(EYE_C - (0.14, 0.05, 0.09), EYE_C + (0.08, 0.09, 0.11), vox)
    m.add(_ring(MONO_C, MONO_AX, MONO_R, 0.0105, 1.2), 0.0, BRASS)
    m.add(_ring(MONO_C - MONO_AX * 0.024, MONO_AX, MONO_R - 0.004, 0.0100, 2.2), 0.002, BRASS)
    for off, r in LENS:
        c = MONO_C + np.array(off, F) * (1, 0, 1)
        m.add(_ring(c, MONO_AX, r, 0.0060, 1.3), 0.0, BRASS)
        m.add(cap(MONO_C + (off[0] * 0.70, 0, off[2] * 0.70), c, 0.0060, 0.0052), 0.002, BRASS)
    # the chain's lug on the ring's far side
    m.add(sph(tuple(MONO_C + (MONO_R + 0.012, -0.004, -0.008)), 0.0085), 0.002, BRASS)
    return m




# the blunderbuss: lies across his left hip on a swivel, a flared mouth. Local: +Y to the muzzle; the swivel at the origin
GUN_AT = np.array((-0.122, 0.150, 0.655), F)
GUN_R = rot(yaw=math.radians(-42.0), pitch=math.radians(-7.0))        # (rest: muzzle forward and to his right)


def gun(vox=0.0020):
    g = Field((-0.09, -0.36, -0.13), (0.09, 0.38, 0.11), vox)
    # barrel, lock, stock, the flare
    g.add(cap((0, -0.015, 0.012), (0, 0.285, 0.012), 0.0175, 0.0200), 0.0, IRON)
    def flare(x, y, z):
        u = np.clip((y - 0.255) / 0.095, 0, 1)
        r = 0.022 + 0.052 * u ** 2.0
        d = np.sqrt(x * x + (z - 0.012) ** 2)
        wall = np.abs(d - r + 0.006) - 0.0072
        return np.maximum(wall, np.maximum(0.255 - y, y - 0.350))
    g.add(custom(flare, (-0.1, 0.24, -0.09), (0.1, 0.36, 0.11)), 0.0, IRON)
    g.add(box((0, -0.030, 0.014), (0.019, 0.040, 0.021), 0.005), 0.0, IRON)
    g.add(cap((0, -0.010, 0.040), (0, -0.044, 0.058), 0.0065, 0.0045), 0.0, BRASS)             # the hammer
    g.add(_ring((0, -0.022, -0.020), (1, 0, 0), 0.016, 0.0034), 0.0, BRASS)                    # the guard
    g.add(path([(0, -0.045, 0.006), (0, -0.115, -0.010), (0, -0.200, -0.042), (0, -0.300, -0.070)], [0.024, 0.024, 0.030, 0.039]), 0.0, WOOD)
    g.add(box((0, -0.326, -0.074), (0.020, 0.012, 0.046), 0.008, (math.radians(-18), 0, 0)), 0.0, IRON)
    g.add(path([(0, 0.0, -0.018), (0, 0.13, -0.012), (0, 0.21, -0.008)], [0.015] * 3), 0.0, WOOD)
    return g


def gun_xf(p):
    return GUN_AT + np.asarray(p, F) @ GUN_R.T


# ------------------------------------------------------------------ the hoard: big simple shapes
def _item(kind, c, R):
    i = len(HOARD)
    HOARD.append({"id": HOARD_BASE + i, "kind": kind, "c": np.array(c, F), "R": R})
    return HOARD_BASE + i


def chest(h, c, hw, hd, hb, hl, R):
    """A chest: a box of hb under an arched lid of hl; iron corners and two straps."""
    wid = _item("chest", c, R)

    def lid_fn(u, v, w):
        ov = (v * v / (hd * hd) + (w / hl) ** 2)
        a = (np.sqrt(ov) - 1.0) * min(hd, hl)
        return np.maximum(np.maximum(a, -w), np.abs(u) - hw)

    def body(u, v, w):
        q = np.abs(np.stack(np.broadcast_arrays(u, v, w + hb), 0)) - np.array((hw, hd, hb), F)[:, None, None, None]
        return np.sqrt(np.sum(np.maximum(q, 0) ** 2, 0)) + np.minimum(np.max(q, 0), 0) - 0.0
    e = math.sqrt(hw * hw + hd * hd + (hb * 2 + hl) ** 2)
    h.add(fixed(c, R, body, e), 0.0, wid)
    h.add(fixed(c, R, lid_fn, e), 0.0, wid)
    # the seam under the lid
    h.sub(fixed(c, R, lambda u, v, w: np.maximum(np.abs(w + 0.002) - 0.0045, -(np.maximum(np.abs(u) - hw + 0.004, np.abs(v) - hd + 0.009))), e), 0.0, DARK)
    # iron: end caps and two straps, proud of the wood
    for ux in (-hw * 0.60, hw * 0.60):
        def band(u, v, w, ux=ux):
            ov = np.sqrt(v * v / ((hd + 0.008) ** 2) + (w / (hl + 0.008)) ** 2) - 1.0
            top = np.where(w > 0, ov * min(hd, hl), np.maximum(np.abs(v) - hd - 0.008, -w - hb * 2 - 0.008))
            return np.maximum(top, np.abs(u - ux) - 0.024)
        h.add(fixed(c, R, band, e), 0.0, IRON)
    def edge(u, v, w):
        return np.maximum(np.maximum(np.abs(u) - hw - 0.005, np.abs(np.abs(u) - hw) - 0.016), np.where(w > 0, (np.sqrt(v * v / ((hd + 0.006) ** 2) + (w / (hl + 0.006)) ** 2) - 1.0) * min(hd, hl), np.maximum(np.abs(v) - hd - 0.006, -w - hb * 2 - 0.006)))
    h.add(fixed(c, R, edge, e), 0.0, IRON)
    # the lock, on the front (+v)
    fr = L(c, R, (0, hd + 0.006, -0.012))
    h.add(box(fr, (0.034, 0.008, 0.040), 0.004, R), 0.0, IRON)


def barrel(h, c, r, hl, R):
    wid = _item("barrel", c, R)

    def fn(u, v, w):
        q = np.sqrt(u * u + v * v)
        rad = r * (0.80 + 0.20 * np.clip(1 - (w / hl) ** 2, 0, 1))
        return np.maximum(q - rad, np.abs(w) - hl)
    e = math.hypot(r, hl) + 0.02
    h.add(fixed(c, R, fn, e), 0.0, wid)
    for t, wd in ((0.86, 0.020), (0.42, 0.016), (-0.42, 0.016), (-0.86, 0.020)):
        def hoop(u, v, w, t=t, wd=wd):
            q = np.sqrt(u * u + v * v)
            rad = r * (0.80 + 0.20 * np.clip(1 - (t) ** 2, 0, 1)) + 0.007
            return np.maximum(np.abs(q - rad + 0.004) - 0.006, np.abs(w - t * hl) - wd)
        h.add(fixed(c, R, hoop, e), 0.0, IRON)
    # the sunk end
    h.sub(fixed(c, R, lambda u, v, w: np.maximum(np.sqrt(u * u + v * v) - r * 0.68, np.abs(w) * -1 + hl - 0.014), e), 0.004, wid)


def shield(h, c, R, sz):
    """A heater shield: wood face, iron rim, a boss."""
    wid = _item("shield", c, R)

    def outline(u, w):
        # top straight, sides curving to the point at the bottom (normalised)
        wn = w / sz
        half = np.where(wn > 0.25, 0.86 + (1 - wn) * 0.06, 0.92 * np.sqrt(np.clip((wn + 1.25) / 1.5, 0, 1)) * (1 - 0.15 * np.clip(-wn, 0, 1)))
        top = wn - 1.0 - 0.10 * np.abs(u / sz) * -1
        return np.maximum(np.abs(u / sz) - half, np.maximum(top, -wn - 1.25)) * sz

    def plate(u, v, w):
        d = outline(u, w)
        return np.maximum(d, np.abs(v - 0.02 * (u / sz) ** 2 * -2) - 0.016)
    e = sz * 1.8
    h.add(fixed(c, R, plate, e), 0.0, wid)
    h.add(fixed(c, R, lambda u, v, w: np.maximum(np.maximum(outline(u, w), -outline(u, w) - 0.028), np.abs(v) - 0.026), e), 0.0, IRON)
    h.add(ell(L(c, R, (0, 0.022, 0.03 * sz)), (0.058, 0.040, 0.058), R), 0.006, IRON)


def scrap(h, c, hw, hh, R, seed):
    """A torn sheet of plate."""
    wid = _item("plate", c, R)

    def fn(u, v, w):
        rim = np.sin(u * 13 + seed) * 0.022 + np.sin(w * 17 + seed * 2) * 0.020 + np.sin((u + w) * 41 + seed) * 0.008
        return np.maximum(np.abs(v) - 0.014, np.maximum(np.abs(u) - hw + rim, np.abs(w) - hh - rim))
    h.add(fixed(c, R, fn, math.hypot(hw, hh) + 0.04), 0.0, wid)


def door(h, c, hw, hh, R):
    """The plank door lashed upright on the back of the pile, two straps crossed over it."""
    wid = _item("door", c, R)

    def fn(u, v, w):
        rim = 0.018 * np.sin(u * 44.0) * (w > 0)
        return np.maximum(np.abs(v) - 0.021, np.maximum(np.abs(u) - hw, np.abs(w) - hh + rim))
    h.add(fixed(c, R, fn, math.hypot(hw, hh) + 0.04), 0.0, wid)
    for sgn in (1, -1):
        a, b = L(c, R, (-hw * 0.92, 0.0, sgn * hh * 0.80)), L(c, R, (hw * 0.92, 0.0, -sgn * hh * 0.80))
        ax = R[:, 2] * -sgn * hh * 1.6 + R[:, 0] * hw * 1.84
        def strap(u, v, w, sgn=sgn):
            t = (u * (hw * 1.84) + w * (-sgn * hh * 1.6)) / float((hw * 1.84) ** 2 + (hh * 1.6) ** 2)
            t = np.clip(t, -0.5, 0.5)
            du, dw = u - t * hw * 1.84, w + t * sgn * hh * 1.6
            return np.maximum(np.sqrt(du * du + dw * dw) - 0.022, np.abs(v) - 0.029)
        h.add(fixed(c, R, strap, math.hypot(hw, hh) + 0.05), 0.0, LEATHER)


HOARD_SHIFT = np.array((0.0, -0.06, 0.0), F)     # v1's hoard onto v2's back: its front inside his lower back, resting on the hump
HB = np.array((0.0, -0.30, 1.12), F) + HOARD_SHIFT      # the hoard bone's head


def hoard(vox=0.0052):
    """Front view (his back at y = -0.14): a sack against the spine, then the pile stacked up and behind it."""
    HOARD.clear()
    h = Field((-0.48, -0.74, 0.60), (0.48, 0.02, 1.80), vox)
    bag = lambda x, y, z: 0.014 * np.sin(x * 19 + z * 7) * np.sin(z * 15)
    h.add(ell((0.0, -0.285, 1.05), (0.300, 0.150, 0.300)), 0.0, BURLAP, None, bag)
    h.add(ell((-0.10, -0.32, 0.84), (0.210, 0.150, 0.170)), 0.03, BURLAP, None, bag)
    # the stack, bottom to top
    chest(h, (0.075, -0.495, 0.835), 0.205, 0.120, 0.075, 0.075, rot(yaw=math.radians(190 - 12)), )
    barrel(h, (-0.270, -0.350, 1.055), 0.112, 0.145, rot(yaw=math.radians(-18), pitch=math.radians(78)))
    barrel(h, (0.272, -0.300, 1.075), 0.105, 0.135, rot(yaw=math.radians(26), pitch=math.radians(-74)))
    chest(h, (-0.030, -0.285, 1.270), 0.215, 0.135, 0.090, 0.085, rot(yaw=math.radians(-7)))
    barrel(h, (0.060, -0.360, 1.475), 0.118, 0.170, rot(yaw=math.radians(90 - 9), pitch=math.radians(90)))
    chest(h, (-0.035, -0.300, 1.610), 0.205, 0.128, 0.078, 0.082, rot(yaw=math.radians(13), roll=math.radians(-5)))
    door(h, (0.020, -0.530, 1.440), 0.145, 0.290, rot(yaw=math.radians(180 + 4), roll=math.radians(4)))
    shield(h, (0.235, -0.580, 1.055), rot(yaw=math.radians(180 + 18), roll=math.radians(-8)), 0.155)
    shield(h, (-0.105, -0.115, 1.440), rot(yaw=math.radians(6), pitch=math.radians(-4), roll=math.radians(-7)), 0.125)
    scrap(h, (0.235, -0.150, 1.480), 0.115, 0.125, rot(yaw=math.radians(-16), roll=math.radians(16)), 1.3)
    scrap(h, (-0.215, -0.580, 0.960), 0.130, 0.120, rot(yaw=math.radians(180 - 16), roll=math.radians(-14)), 2.9)
    scrap(h, (-0.235, -0.545, 1.215), 0.090, 0.100, rot(yaw=math.radians(180 - 28), roll=math.radians(21)), 4.4)
    # the coin heap behind his head, spilling to his left (the gold is the pile's bright spot from above)
    coin = lambda x, y, z: 0.0
    coin = lambda x, y, z: 0.018 * np.sin(x * 37 + y * 11) * np.sin(y * 29 + z * 13)
    h.add(ell((0.125, -0.135, 1.265), (0.150, 0.095, 0.085), (0.10, 0.10, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.085, -0.150, 1.285), (0.115, 0.085, 0.070), (0.0, -0.2, 0)), 0.02, GOLD, None, coin)
    h.add(ell((-0.245, -0.125, 1.205), (0.085, 0.080, 0.062)), 0.03, GOLD, None, coin)
    rng = np.random.RandomState(3)
    for i in range(24):
        a = rng.uniform(0, math.tau)
        c = (0.02 + rng.uniform(-0.29, 0.25), -0.135 + rng.uniform(-0.08, 0.07), 1.33 + rng.uniform(-0.07, 0.03))
        ax = np.array((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 1.0), F)
        ax /= np.linalg.norm(ax)
        h.add(cyl(c, ax, 0.040, 0.0075, 0.002), 0.0, GOLD)
    # the frames: timbers fanning out of the pile to carry the bells and lanterns
    for s in (1, -1):
        h.add(path([(s * 0.10, -0.22, 1.30), (s * 0.255, -0.22, 1.56), (s * 0.30, -0.22, 1.62)], [0.024, 0.021, 0.019]), 0.0, _item("beam", (0, 0, 0), np.eye(3, dtype=F)) if s > 0 else HOARD[-1]["id"])
        h.add(path([(s * 0.42, -0.21, 1.33), (s * 0.325, -0.215, 1.57), (s * 0.30, -0.215, 1.625)], [0.021, 0.020, 0.018]), 0.0, HOARD[-1]["id"])
        h.add(path([(s * 0.14, -0.215, 1.46), (s * 0.40, -0.21, 1.42)], [0.0175, 0.0175]), 0.0, HOARD[-1]["id"])
        h.add(sph((s * 0.303, -0.215, 1.640), 0.024), 0.0, IRON)
        # iron arm out from the apex, the lantern's chain hangs from it
        h.add(path([(s * 0.305, -0.215, 1.635), (s * 0.395, -0.215, 1.69), (s * 0.475, -0.215, 1.645)], [0.0115, 0.0105, 0.0095]), 0.0, IRON)
    # two lashings of big-link chain over the pile (one solid rope of links: painted, see P.chainlink)
    h.add(path([(0.27, -0.15, 1.72), (0.215, -0.44, 1.75), (0.19, -0.585, 1.42), (-0.03, -0.635, 1.10), (-0.33, -0.56, 0.84)], [0.0135] * 5), 0.0, ROPE)
    h.add(path([(-0.28, -0.20, 1.40), (-0.28, -0.60, 1.36), (0.0, -0.645, 1.18), (0.31, -0.59, 0.90)], [0.0135] * 4), 0.0, ROPE)
    # the hook on top, the art's crown
    h.add(path([(0.075, -0.385, 1.68), (0.095, -0.395, 1.79)], [0.010, 0.010]), 0.0, IRON)
    h.add(_ring((0.095, -0.395, 1.805), (0, 1, 0), 0.020, 0.0068), 0.0, IRON)
    return h


BELL_R = 0.082
BELL_H = 0.135


def bell(vox=0.0022):
    """Local: the crown at the origin, hanging down -Z."""
    b = Field((-0.11, -0.11, -0.18), (0.11, 0.11, 0.05), vox)

    def fn(x, y, z):
        d = np.sqrt(x * x + y * y)
        u = np.clip(-z / BELL_H, 0, 1)
        r = 0.040 + 0.012 * u + 0.030 * u ** 5
        wall = np.abs(d - r) - 0.0075
        return np.maximum(wall, np.maximum(z + 0.0, -z - BELL_H))
    b.add(custom(fn, (-0.1, -0.1, -0.15), (0.1, 0.1, 0.01)), 0.0, IRON)
    b.add(ell((0, 0, -0.002), (0.041, 0.041, 0.022)), 0.0, IRON)
    b.add(_ring((0, 0, 0.022), (0, 1, 0), 0.015, 0.0055), 0.0, IRON)
    b.add(sph((0, 0, -0.125), 0.014), 0.0, BRASS)
    return b


LANTERN_H = 0.20


def lantern(vox=0.0020):
    """Local: the ring at the origin, hanging down -Z. Hexagonal cage, the glow inside."""
    l = Field((-0.075, -0.075, -0.23), (0.075, 0.075, 0.03), vox)
    l.add(cyl((0, 0, -0.105), (0, 0, 1), 0.040, 0.058, 0.002), 0.0, LAMP)
    for i in range(4):
        a = math.tau * (i + 0.5) / 4
        cx, cy = math.cos(a) * 0.044, math.sin(a) * 0.044
        l.add(cap((cx * 0.8, cy * 0.8, -0.040), (cx, cy, -0.170), 0.0060), 0.0, BRASS)
    l.add(cyl((0, 0, -0.044), (0, 0, 1), 0.055, 0.007, 0.002), 0.0, BRASS)
    l.add(cap((0, 0, -0.034), (0, 0, -0.005), 0.034, 0.008), 0.0, BRASS)
    l.add(cyl((0, 0, -0.170), (0, 0, 1), 0.056, 0.007, 0.002), 0.0, BRASS)
    l.add(cap((0, 0, -0.176), (0, 0, -0.205), 0.030, 0.005), 0.0, BRASS)
    l.add(_ring((0, 0, 0.010), (0, 1, 0), 0.0125, 0.0040), 0.0, BRASS)
    return l


# the junk ball: built at true size round the origin, the mesh is shrunk into the sack at rest (bone `ball`); the roll scales it back up
BALL_R = 0.52
BALL_REST = 1.0 / 3.8        # (at rest it hides inside the sack)
BALL_AT = np.array((0.0, -0.29, 1.04), F) + HOARD_SHIFT


def ball(vox=0.030):
    """Panel d of the sheet: a ball of bent plates and planks in chains, one window the grin looks out of (+Y)."""
    b = Field((-0.62, -0.62, -0.62), (0.62, 0.62, 0.62), vox)
    b.add(sph((0, 0, 0), BALL_R * 0.95), 0.0, IRON)
    rng = np.random.RandomState(11)
    wid = _item("ballplate", (0, 0, 0), np.eye(3, dtype=F))
    wood = _item("ballwood", (0, 0, 0), np.eye(3, dtype=F))
    # plates laid on the sphere, on a fibonacci spiral, skipping the window
    N = 18
    for i in range(N):
        zz = 1 - 2 * (i + 0.5) / N
        r = math.sqrt(1 - zz * zz)
        a = i * 2.39996
        n = np.array((r * math.cos(a), r * math.sin(a), zz), F)
        if n[1] > 0.70:
            continue
        up = np.array((0.1, 0.2, 1.0), F)
        u = np.cross(up, n)
        u /= max(np.linalg.norm(u), 1e-5)
        w = np.cross(n, u)
        R = np.stack((u, n, w), 1)
        tw = rng.uniform(0, 3.1)
        Rt = R @ rot(roll=tw)
        c = n * BALL_R * 0.97
        hw, hh = rng.uniform(0.20, 0.30), rng.uniform(0.15, 0.24)
        lab = wood if i % 4 == 2 else (RUST if i % 4 == 0 else wid)
        b.add(box(tuple(c), (hw, 0.030, hh), 0.012, Rt), 0.012, lab)
    # the window: a deep pocket for the head
    b.sub(ell((0, 0.46, 0.0), (0.27, 0.30, 0.27)), 0.02, DARK)
    return b


def ball_frame(vox=0.012):
    """The brass frame round the ball's window."""
    b = Field((-0.40, 0.30, -0.40), (0.40, 0.60, 0.40), vox)
    b.add(_ring((0, 0.44, 0), (0, 1, 0), 0.285, 0.030, 1.2), 0.0, BRASS)
    return b


def ball_xf(p):
    return BALL_AT + np.asarray(p, F) * BALL_REST
