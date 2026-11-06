"""ART-1 Kael: the rebuilt pieces (head and face, mask, cowl, mane, collar, hands, chains, greatsword) as data.
Blender frame: Z up, he faces +Y, his right hand is +X. See /home/boki/shots-s2/art1/STYLE_NOTES.md."""
import numpy as np
from meshkit import (Piece, catmull, norm, smooth, sweep, sd_ell, sd_cap, smin, smax, rot_about, frames, holed_sheet)

# ---- the rig (kael_rig.json with archetype body.chest 0.9), Blender frame
SH = 0.2608 * 0.9
ARM = {"R": 1.0, "L": -1.0}
HAND_Z, ELBOW_Z, SHOULDER_Z = 0.8228, 1.0578, 1.2678
ANKLE_Z = 0.10
NECK_Z = 1.3729
HS = 0.8                                      # head size: small on a tall hero (the sheet is 8 heads)
C = np.array([0.0, 0.012, 1.482])             # the head's centre
EYE = np.array([0.036, 0.0625, 0.008])        # head-local; x mirrored
EYE_R = 0.0215
SCAR_SIDE = -1.0                              # -1: his left, as the brief; 1: his right, as the sheet and splash draw it
GLOW_EYE = "L"                                # the eye that glows


def hl(p):
    """Head-local -> world."""
    return C + np.asarray(p, dtype=np.float64) * HS


def head_sdf(p):
    d = sd_ell(p, (0, -0.012, 0.03), (0.083, 0.098, 0.085))
    d = smin(d, sd_ell(p, (0, 0.018, -0.035), (0.070, 0.074, 0.088)), 0.02)
    d = smin(d, sd_ell(p, (0, 0.02, -0.09), (0.058, 0.058, 0.044)), 0.02)
    for s in (-1.0, 1.0):
        # the heavy brow ridge, sloping down toward the nose: the scowl lives in the bone
        d = smin(d, sd_cap(p, (s * 0.010, 0.084, 0.024), (s * 0.066, 0.052, 0.046), 0.0125), 0.014)
        d = smin(d, sd_ell(p, (s * 0.056, 0.058, -0.024), (0.022, 0.022, 0.014)), 0.014)     # cheekbone
        d = smax(d, -sd_ell(p, (s * 0.037, 0.095, 0.009), (0.023, 0.021, 0.0185)), 0.008)    # the socket
    d = smin(d, sd_cap(p, (0, 0.082, 0.016), (0, 0.104, -0.03), 0.0105), 0.012)              # the nose bridge
    d = smax(d, -sd_cap(p, (0, 0.11, 0.04), (0, 0.11, 0.016), 0.0026), 0.005)             # the frown furrow
    return d


def ray_y(x, z, y0=0.17, steps=48):
    """The head's surface along -Y from in front at each (x, z): a heightfield y(x, z)."""
    x, z = np.asarray(x, float), np.asarray(z, float)
    y = np.full(x.shape, y0)
    for _ in range(steps):
        d = head_sdf(np.stack([x, y, z], -1))
        y = y - np.clip(d, -0.01, 0.02) * 0.9
    return y


def ray_out(ang, z, extra=None, r0=0.2, steps=48):
    """The surface along the ray from the axis at height z, angle `ang` from +Y round Z (toward +X)."""
    ang, z = np.asarray(ang, float), np.asarray(z, float)
    dirx, diry = np.sin(ang), np.cos(ang)
    r = np.full(ang.shape, r0)
    for _ in range(steps):
        p = np.stack([dirx * r, diry * r, z], -1)
        d = head_sdf(p)
        if extra is not None:
            d = np.minimum(d, extra(p))
        r = np.maximum(r - np.clip(d, -0.01, 0.03) * 0.9, 0.004)
    return r


def grid_faces(rows, cols, wrap=False):
    f = []
    for i in range(rows - 1):
        for j in range(cols - (0 if wrap else 1)):
            a = i * cols + j
            b = i * cols + (j + 1) % cols
            f.append([a, b, b + cols, a + cols])
    return f


def face_patch():
    xs = np.concatenate([np.linspace(-0.094, -0.066, 3), np.linspace(-0.058, 0.058, 19), np.linspace(0.066, 0.094, 3)])
    zs = np.concatenate([np.linspace(-0.05, -0.028, 3), np.linspace(-0.02, 0.05, 13), np.linspace(0.06, 0.098, 4)])
    X, Z = np.meshgrid(xs, zs)
    Y = np.maximum(ray_y(X, Z), 0.0)
    v = hl(np.stack([X, Y, Z], -1).reshape(-1, 3))
    return Piece("face", "skin-kael", v, grid_faces(len(zs), len(xs))).rigid("head")


def skull():
    """The rest of the head, coarse: all of it sits under the hair and the mask."""
    rows, cols = 8, 14
    zs = np.linspace(0.105, -0.14, rows)
    angs = np.linspace(0, 2 * np.pi, cols, endpoint=False)
    A, Z = np.meshgrid(angs, zs)
    R = ray_out(A, Z, r0=0.14) * 0.985
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    return Piece("skull", "skin-kael", v, grid_faces(rows, cols, True)).rigid("head")


def eyeball(s):
    """The front cap of the eye, facing out a touch. Corner UVs are a flat view of it, painted by paint_eye."""
    c = EYE * [s, 1, 1]
    rows, cols = 5, 9
    v, uv = [], []
    for i in range(rows):
        for j in range(cols):
            a, b = (j / (cols - 1) - 0.5) * 2.0, (i / (rows - 1) - 0.5) * 1.5
            d = norm(np.array([np.sin(a) * np.cos(b), np.cos(a) * np.cos(b), np.sin(b)]))
            d = rot_about(d, (0, 0, 1), -s * 0.1)
            v.append(c + d * EYE_R)
            uv.append((a, b))
    p = Piece("eye" + ("R" if s > 0 else "L"), "eyes-kael", hl(v), grid_faces(rows, cols)).rigid("head")
    p.eye_uv = np.array(uv)
    return p


def lid_up(az):
    """The upper lid's edge (elevation, radians, at az from the eye's front, + away from the nose): narrowed, sloping to the nose."""
    return -0.05 + 0.30 * (1 - (az / 1.05) ** 2) + 0.2 * az


def lid_down(az):
    return -0.05 - 0.2 * (1 - (az / 1.05) ** 2) + 0.2 * az


def lids(s):
    """Shells on a sphere round the eye: the upper lid turns on its bone, the lower stays; together they cut the almond.
    The upper edge is nearly straight and slopes down toward the nose: narrowed, cold."""
    c = EYE * [s, 1, 1]
    out = []
    for up in (True, False):
        rows, cols = 4, 8
        v = []
        for i in range(rows):
            for j in range(cols):
                az = (j / (cols - 1) - 0.5) * 2.1                 # + is outward, away from the nose
                bow = 1 - (az / 1.05) ** 2
                if up:
                    edge = lid_up(az)
                    top = 1.15
                else:
                    edge = lid_down(az)
                    top = -1.1
                el = edge + (top - edge) * i / (rows - 1)
                d = np.array([np.sin(az) * s * np.cos(el), np.cos(az) * np.cos(el), np.sin(el)])
                v.append(c + d * (EYE_R * (1.1 + (0.05 * i / (rows - 1)))))
        f = grid_faces(rows, cols)
        p = Piece("lid%s%s" % ("U" if up else "D", "R" if s > 0 else "L"), "skin-kael", hl(v), f)
        p.rigid(("lid.%s" % ("R" if s > 0 else "L")) if up else "head")
        out.append(p)
    return out


def brows(s):
    """The white brow: a heavy wedge from the frown out past the temple, with feathered tips."""
    out = []
    side = "R" if s > 0 else "L"
    pts = [(0.010, 0.0975, 0.029), (0.030, 0.094, 0.036), (0.052, 0.080, 0.046), (0.074, 0.056, 0.060)]
    for k, (dz, wid, tipz, tipx) in enumerate([(0.0, 0.0105, 0.012, 0.004), (-0.005, 0.0075, -0.004, 0.012),
                                               (0.007, 0.006, 0.02, -0.012)]):
        p = np.array(pts) * [s, 1, 1] + [0, 0.003, dz]
        p[-1] += [s * tipx, 0, tipz]
        path = catmull(p, 6)
        wd = wid * np.array([0.45, 0.95, 1.0, 0.85, 0.5, 0.05])
        b = sweep("brow%d%s" % (k, side), "hair-brow", hl(path), [(-1, 0), (0, 0.28), (1, 0), (0, -0.28)], wd * HS,
                  side_hint=np.array([0, 1.0, 0.3]), uv_rect=(0.1, 0.5, 0.3, 0.6), room=0.0)
        out.append(b.rigid("brow." + side))
    return out


def mask():
    """The scarf over the nose and mouth: a shell on the head with the nose tented, one lip along its top edge."""
    tent = lambda p: np.minimum(sd_cap(p, (0, 0.094, 0.002), (0, 0.114, -0.036), 0.0135),
                                sd_ell(p, (0, 0.056, -0.075), (0.066, 0.056, 0.066)))
    cols = 21
    angs = np.linspace(-1.95, 1.95, cols)
    rows = 7
    top = -0.03 + 0.024 * np.exp(-(angs / 0.16) ** 2) + 0.012 * smooth(0.7, 1.6, np.abs(angs))
    v = []
    for i in range(rows):
        k = i / (rows - 1)
        z = top + (-0.165 - top) * k ** 0.9
        r = ray_out(angs, z, tent, r0=0.17)
        r = r + 0.0065 + 0.0022 * np.sin(angs * 7.0 + k * 5.0) * smooth(0.0, 0.3, k)
        v.append(np.stack([np.sin(angs) * r, np.cos(angs) * r, z], -1))
    v = np.array(v).reshape(-1, 3)
    # the lip: the top edge turned in against the skin
    lip = v[:cols].copy()
    rad = norm(lip * [1, 1, 0])
    lip = lip - rad * 0.0075 + [0, 0, -0.002]
    verts = np.vstack([lip, v])
    return Piece("mask", "cloth-kael", hl(verts), grid_faces(rows + 1, cols)).rigid("head")


def cowl():
    """The ENORMOUS scarf: one heavy funnel from under the eyes to a torn drape on the shoulders, its folds real relief: thick swags of cloth
    that hang across the front and lap the one below (each swells out, then undercuts), so it reads as a wrapped mass, not a sheet."""
    cols, rows = 36, 26
    z = C[2]
    prof = [(0.018, 0.092, 0.1), (0.05, 0.116, 0.124), (0.1, 0.138, 0.14), (0.15, 0.168, 0.156), (0.19, 0.212, 0.166), (0.225, 0.262, 0.172), (0.252, 0.284, 0.174)]
    pz = np.array([q[0] for q in prof])
    # swags: (height on the funnel, dip at the front, sideways tilt, size, swell)
    swags = [(0.05, 0.012, 0.02, 0.05, 0.026), (0.098, 0.024, -0.028, 0.056, 0.03), (0.15, 0.03, 0.03, 0.058, 0.028), (0.2, 0.04, -0.024, 0.05, 0.02)]
    rng = np.random.RandomState(5)
    jag = rng.uniform(-1, 1, cols)
    jag[::3] -= 1.5
    G = np.zeros((rows, cols, 3))
    for i in range(rows):
        k = i / (rows - 1)
        dz = np.interp(k, np.linspace(0, 1, len(pz)), pz)
        hw = np.interp(dz, pz, [q[1] for q in prof])
        hd = np.interp(dz, pz, [q[2] for q in prof])
        for j in range(cols):
            a = j / cols * 2 * np.pi
            sx, cy = np.sin(a), np.cos(a)
            front = (0.5 + 0.5 * cy) ** 1.3
            bulge, lift = 0.0, 0.0
            for s0, dip, tilt, size, swell in swags:
                u = (dz - s0 - dip * front + tilt * sx) / size + 0.25 * np.sin(a * 2 + s0 * 40) * 0.2
                if 0.0 < u < 1.0:
                    # (rounded over the top, a sharp tuck under)
                    bulge = max(bulge, swell * (np.sin(np.pi * u ** 1.5) ** 0.7) * (0.75 + 0.25 * np.sin(a * 3 + s0 * 60)))
            lobes = (0.009 * np.sin(a * 5 + 2.1 - k * 3) + 0.006 * np.sin(a * 9 + 1.0 + k * 3)) * smooth(0.1, 0.6, k)
            r = bulge + lobes
            hem = 0.034 * jag[j] * k ** 14
            G[i, j] = (sx * (hw + r), 0.016 + cy * (hd + r), z - dz - 0.018 * front * k + hem)
    holes = [(5.5, 31.5, 0.8, 1), (8.0, 4.0, 0.8, 2), (12.5, 33.0, 0.8, 3), (15.5, 29.0, 0.9, 4), (17.0, 6.0, 0.9, 5), (20.5, 2.0, 0.7, 6), (19.5, 31.0, 0.7, 7)]
    p = holed_sheet("cowl0", "cloth-kael", G, wrap=True, holes=holes)
    w = 1.0 - smooth(0.3, 0.72, p.rowf)
    p.w = {"head": w, "hips": 1 - w}
    p.burns = [tuple(p.at(r_, c_)) + (0.02 + 0.012 * q_,) for r_, c_, q_, _ in holes]
    return [p] + _cowl_core()


def _cowl_core():
    z = C[2]
    # the dark inside, seen through the burn holes
    rows2, cols2 = 4, 16
    H = np.zeros((rows2, cols2, 3))
    for i, (dz, r) in enumerate(((0.03, 0.078), (0.08, 0.1), (0.14, 0.125), (0.2, 0.16))):
        for j in range(cols2):
            a = j / cols2 * 2 * np.pi
            H[i, j] = (np.sin(a) * r, 0.014 + np.cos(a) * r, z - dz)
    core = holed_sheet("cowlcore", "cloth-kael", H, wrap=True)
    wc = 1.0 - smooth(0.2, 0.8, core.rowf)
    core.w = {"head": wc, "hips": 1 - wc}
    return [core]


def scarf_tail(side):
    """One of the two very long tattered tails: two thin sheets back to back on a path from the nape, streaming back and down; real burn
    holes, bitten edges, a forked end. Its rest shape leans back, so the spring trails it behind him (his top-down signature)."""
    s = 1.0 if side == "R" else -1.0
    z0 = C[2] - 0.2
    pts = [(s * 0.075, -0.13, z0), (s * 0.10, -0.24, z0 - 0.14), (s * 0.115, -0.36, z0 - 0.36), (s * 0.135, -0.48, z0 - 0.60),
           (s * 0.15, -0.60, z0 - 0.84), (s * 0.165, -0.72, z0 - 1.06)]
    rows, cols = 20, 5
    path = catmull(pts, rows)
    k = np.linspace(0, 1, rows)
    rng = np.random.RandomState(3 if s > 0 else 8)
    wd = (0.058 + 0.052 * smooth(0.0, 0.25, k)) * (1 - 0.3 * smooth(0.8, 1.0, k))
    t, sd, nr = frames(path, np.array([0, 0.8, -0.6]))
    G = np.zeros((rows, cols, 3))
    for i in range(rows):
        bite_l = rng.uniform(0.7, 1.0) if i > 5 else 1.0
        bite_r = rng.uniform(0.7, 1.0) if i > 5 else 1.0
        for j in range(cols):
            u = j / (cols - 1) * 2 - 1
            u2 = u * (bite_l if u < 0 else bite_r)
            G[i, j] = path[i] + sd[i] * u2 * wd[i] + nr[i] * 0.012 * np.sin(k[i] * 9 + u * 2)
    # the fork: the middle column stops short
    for i in range(rows - 4, rows):
        G[i, 2] = G[rows - 5, 2] + (G[i, 2] - G[rows - 5, 2]) * 0.12
    holes = [(5.5, 1.5, 0.75, 11), (9.5, 2.6, 0.8, 12), (12.5, 1.2, 0.7, 13), (15.0, 2.5, 0.75, 14)]
    front = holed_sheet("stail" + side, "cloth-kael", G + nr[:, None, :] * 0.0035, holes=holes, room=0.0)
    back = holed_sheet("x", "cloth-kael", G - nr[:, None, :] * 0.0035, holes=holes, room=0.0)
    back.f = [q[::-1] for q in back.f]
    n0 = len(front.v)
    # (front faces out of the sheet's +normal)
    q = front.f[len(front.f) // 2]
    if np.dot(np.cross(front.v[q[1]] - front.v[q[0]], front.v[q[2]] - front.v[q[0]]), nr[rows // 2]) < 0:
        front.f = [q[::-1] for q in front.f]
        back.f = [q[::-1] for q in back.f]
    p = Piece("stail" + side, "cloth-kael", np.vstack([front.v, back.v]), front.f + [[i + n0 for i in q] for q in back.f], room=0.0)
    p.t = np.concatenate([front.rowf, back.rowf])
    p.path = path
    p.burns = [tuple(front.at(r, c)) + (0.03,) for r, c, _, _ in holes]
    return p


def collar():
    """His relic: the broken gold collar, two chunky plates cracked open at the throat."""
    out = []
    for s in (-1.0, 1.0):
        angs = np.linspace(0.16, 0.86, 7)
        path, wd = [], []
        for k, a in enumerate(angs):
            drop = 0.05 * (1.0 - a / 1.02)
            path.append([s * np.sin(a) * 0.165, 0.016 + np.cos(a) * 0.146, 1.172 - drop + 0.03 * a])
            wd.append([0.028, 0.027, 0.022, 0.024, 0.020, 0.016, 0.006][k])
        sec = [(-1, 0.0), (-0.55, 0.42), (0.55, 0.42), (1, 0.0), (0.55, -0.3), (-0.55, -0.3)]
        p = sweep("collar" + ("R" if s > 0 else "L"), "brass-kael", path, sec, wd,
                  side_hint=np.array([0, 0.9, 0.5]), depth=np.array(wd) * 0.42 + 0.004)
        # snapped ends: a jagged step at the broken end
        p.v[:6] += [s * -0.012, 0.012, -0.01]
        out.append(p.rigid("hips"))
    return out


def under_thighs():
    """The thighs the skirt hides (the scan has only skirt there), so a stride shows a leg, not the void."""
    out = []
    for s, bone in ((1.0, "R"), (-1.0, "L")):
        zs = [0.46, 0.52, 0.58, 0.64, 0.72]
        rs = [0.06, 0.07, 0.08, 0.086, 0.08]
        path = [[s * (0.1191 + (z - 0.4) * -0.03), 0.0, z] for z in zs]
        sec = [(np.cos(a), np.sin(a)) for a in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
        p = sweep("thigh" + bone, "skin-kael", path, sec, rs, side_hint=np.array([0, 1.0, 0]))
        p.rigid("thigh." + bone)
        out.append(p)
    return out


# ------------------------------------------------------------------ hands
def hand(side, grip_dir, curl, spread=0.0, bone_prefix=True):
    """A big hand on the wrist. curl: finger joint angles (radians) from flat. Frame: k along the knuckles (thumb side
    first), a from wrist to knuckles, o out of the back of the hand."""
    s = ARM[side]
    wrist = np.array([s * SH, 0.0, HAND_Z + 0.012])
    k = norm(np.asarray(grip_dir, float))
    a = np.array([0, 0, -1.0])
    a = norm(a - k * np.dot(a, k))
    o = norm(np.cross(a, k)) * 1.0
    if o[0] * s < 0:
        o = -o
    pieces = []
    sec8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    # the palm: a wedge from the wrist out to the knuckles
    knuck = wrist + a * 0.082
    centre = [wrist - a * 0.018, wrist + a * 0.03, wrist + a * 0.062, knuck]
    width = np.array([0.036, 0.046, 0.052, 0.050])
    depth = np.array([0.031, 0.027, 0.026, 0.023])
    palm = sweep("palm" + side, "skin-kael", centre, sec8, width, side_hint=o, depth=depth)
    t_, s_, n_ = frames(np.asarray(centre), o)
    # rotate the sweep's section so its long axis lies along the knuckles
    for i in range(len(centre)):
        for j in range(8):
            d = palm.v[i * 8 + j] - centre[i]
            x = np.dot(d, s_[i]) / width[i]
            y = np.dot(d, n_[i]) / depth[i]
            palm.v[i * 8 + j] = centre[i] + k * x * width[i] + o * y * depth[i]
    pieces.append(palm.rigid("hand." + side))
    # the fingers, each three bones, curling from the knuckle toward the palm
    lens = [(0.036, 0.026, 0.024), (0.040, 0.029, 0.025), (0.037, 0.026, 0.024), (0.029, 0.021, 0.020)]
    rads = [0.0118, 0.0122, 0.0116, 0.0104]
    for f in range(4):
        base = knuck + k * (0.036 - f * 0.024) + o * 0.006
        p = [base - a * 0.012]
        d = a.copy()
        fan = rot_about(d, o, -spread * (f - 1.5))
        d = norm(fan)
        p.append(base.copy())
        cur = base.copy()
        ang = 0.0
        for jn in range(3):
            ang += curl[jn]
            dd = rot_about(d, k, ang * (1.0 if np.dot(np.cross(k, a), o) < 0 else -1.0))
            cur = cur + dd * lens[f][jn]
            p.append(cur.copy())
        p = np.array(p)
        wd = np.array([1.0, 1.02, 1.0, 0.93, 0.8]) * rads[f]
        sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
        fp = sweep("finger%d%s" % (f, side), "skin-kael", p, sec, wd, side_hint=k)
        bone = "hand." + side if side == "R" else "fingers." + side
        fp.w = {"hand." + side: 1 - smooth(0.015, 0.02, np.linalg.norm(fp.v - base, axis=1)), bone: 0 * fp.v[:, 0]}
        if bone != "hand." + side:
            fp.w[bone] = 1 - fp.w["hand." + side]
        else:
            fp.w = {bone: np.ones(len(fp.v))}
        pieces.append(fp)
    # the thumb
    base = wrist + a * 0.028 + k * 0.048 - o * 0.008
    t1 = base + norm(a * 0.72 + k * 0.42 - o * 0.5) * 0.04
    t2 = t1 + norm(a * 0.9 + k * 0.05 - o * 0.45) * 0.03
    t3 = t2 + norm(a * 0.9 - k * 0.35 - o * 0.2) * 0.026
    sec = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 6, endpoint=False)]
    tp = sweep("thumb" + side, "skin-kael", [base - a * 0.01, t1, t2, t3], sec, np.array([0.02, 0.0155, 0.0125, 0.0105]),
               side_hint=o)
    if side == "R":
        tp.rigid("hand.R")
    else:
        q = smooth(0.01, 0.03, np.linalg.norm(tp.v - base, axis=1))
        tp.w = {"hand.L": 1 - q, "thumb.L": q}
    pieces.append(tp)
    return pieces


# ------------------------------------------------------------------ chains
RING = [(np.cos(t), np.sin(t)) for t in (0.5, 2.6, 4.7)]


def link(centre, along, side, ln=0.040, wid=0.020, th=0.0058, uv=(0, 0, 1, 1)):
    """One chain link: a stadium ring, 8 segments of a triangular wire."""
    along, side = norm(along), norm(side)
    nrm = np.cross(along, side)
    pts = []
    for t in np.linspace(0, 2 * np.pi, 6, endpoint=False):
        cx, sx = np.cos(t), np.sin(t)
        pts.append(along * (cx * (ln * 0.5 - wid * 0.1) + np.sign(cx) * 0.0) + side * sx * wid * 0.5)
    v, f, uvs = [], [], []
    n = len(pts)
    for i in range(n):
        o = norm(pts[i] * [1, 1, 1])
        for a, b in RING:
            v.append(centre + pts[i] + o * a * th + nrm * b * th)
    for i in range(n):
        for j in range(3):
            aa = i * 3 + j
            bb = i * 3 + (j + 1) % 3
            cc = ((i + 1) % n) * 3 + (j + 1) % 3
            dd = ((i + 1) % n) * 3 + j
            f.append([aa, bb, cc, dd])
            u0, v0, u1, v1 = uv
            uu = u0 + (u1 - u0) * (j / 3.0)
            uw = u0 + (u1 - u0) * ((j + 1) / 3.0)
            vv = v0 + (v1 - v0) * (i / n)
            vw = v0 + (v1 - v0) * ((i + 1) / n)
            uvs.append([(uu, vv), (uw, vv), (uw, vw), (uu, vw)])
    return v, f, uvs


def chain_along(name, path, step=0.033, uv=(0, 0, 1, 1), ln=0.040, wid=0.021, th=0.0058, flip=0.0):
    """Links along a path, every other one turned 90 degrees about the path."""
    p = np.asarray(path, dtype=np.float64)
    seg = np.linalg.norm(np.diff(p, axis=0), axis=1)
    s = np.concatenate([[0], np.cumsum(seg)])
    cnt = max(1, int(s[-1] / step))
    v, f, uvs = [], [], []
    t, side, nrm = frames(p, (0.3, 0.4, 0.9))
    for i in range(cnt):
        d = (i + 0.5) * step
        k = np.searchsorted(s, d) - 1
        k = int(np.clip(k, 0, len(p) - 2))
        q = (d - s[k]) / max(seg[k], 1e-6)
        c = p[k] * (1 - q) + p[k + 1] * q
        a = t[k]
        tw = (i % 2) * (np.pi / 2) + flip + (i * 0.17)
        sd = side[k] * np.cos(tw) + nrm[k] * np.sin(tw)
        vv, ff, uu = link(c, a, sd, ln=ln, wid=wid, th=th, uv=uv)
        o = len(v)
        v += vv
        f += [[o + x for x in q2] for q2 in ff]
        uvs += uu
    return Piece(name, "metal-chain", v, f, uvs, room=0.15)


def wrist_chain(uv):
    """The rusted chain wound round the bandaged right wrist."""
    cx = SH
    pts = []
    turns = 2.4
    n = 70
    for i in range(n):
        k = i / (n - 1)
        a = k * turns * 2 * np.pi + 0.6
        z = HAND_Z + 0.075 - 0.075 * k + 0.008 * np.sin(a * 2.3)
        r = 0.05 - 0.008 * k
        pts.append([cx + np.cos(a) * r * 1.06, np.sin(a) * r, z])
    p = chain_along("chain_wrap", pts, step=0.0345, uv=uv, ln=0.042, wid=0.023, th=0.0064)
    return p.rigid("forearm.R")


def hanging_chain(uv):
    """From the wrist to the hook (spring_hangwarchain_*): the game hangs it from the fist."""
    top = np.array([SH + 0.044, 0.02, HAND_Z - 0.0])
    drop = 0.40
    path = [top + [0, 0, -k * drop] for k in np.linspace(0, 1, 12)]
    p = chain_along("chain_hang", path, step=0.0395, uv=uv, ln=0.046, wid=0.026, th=0.0068)
    ring_c = top + [0, 0, -drop - 0.022]
    pts = catmull([ring_c, ring_c + [0.0, 0.0, -0.05], ring_c + [0.0, 0.016, -0.115], ring_c + [0, 0.05, -0.15], ring_c + [0, 0.098, -0.13],
                   ring_c + [0, 0.112, -0.082], ring_c + [0, 0.098, -0.05]], 10)
    wd = np.array([0.018, 0.018, 0.019, 0.021, 0.021, 0.02, 0.018, 0.015, 0.01, 0.0015])
    sec = [(-1, 0), (0, 0.55), (1, 0), (0, -0.55)]
    hook = sweep("hook", "metal-hook", pts, sec, wd * 0.72, side_hint=np.array([1.0, 0, 0]), depth=wd * 1.05, uv_rect=uv)
    chain_pts = [top + [0, 0, -(drop + 0.06) * i / 6.0] for i in range(7)]
    return p, hook, chain_pts


def cuff_chain(uv):
    top = np.array([-SH - 0.05, 0.0, HAND_Z + 0.03])
    path = [top + [0, 0, -k * 0.21] for k in np.linspace(0, 1, 6)]
    p = chain_along("chain_cuff", path, step=0.038, uv=uv, ln=0.044, wid=0.024, th=0.0062)
    return p, [top + [0, 0, -0.24 * i / 3.0] for i in range(4)]


# ------------------------------------------------------------------ the mane
LENS = [(-1, 0), (-0.45, 0.38), (0.45, 0.38), (1, 0), (0.45, -0.3), (-0.45, -0.3)]
DIA = [(-1, 0), (0, 0.42), (1, 0), (0, -0.32)]


def _skull_r(d):
    """Head-local distance from the centre to the skull along a unit direction."""
    r = 0.14
    for _ in range(40):
        r = max(r - float(head_sdf((np.asarray(d) * r)[None, :])[0]) * 0.9, 0.01)
    return r


def lock(name, pts, w0, rings=7, wide=False, peak=0.32, tip=0.0, hint=None, tile=0.0, group=None, v0=0.0, root=0.55, soft=0.0):
    path = catmull(pts, rings)
    k = np.linspace(0, 1, rings)
    prof = np.minimum(1.0, root + k / peak * (1 - root)) * (1 - smooth(peak, 1.0, k)) ** 0.8
    wd = w0 * np.maximum(prof, 0.012 + soft * smooth(0.8, 1.0, k)) + tip
    if hint is None:
        c = np.array([0, -0.03, 1.40])
        hint = norm(path[0] - c)
    u0 = tile
    p = sweep(name, "hair-mane", path, LENS if wide else DIA, wd, side_hint=hint, uv_rect=(u0, v0, u0 + 0.25, 1),
              room=0.0, depth=wd * (0.62 if wide else 0.62))
    p.t = np.repeat(k, len(LENS if wide else DIA))
    p.group = group
    p.path = path
    return p


def mane():
    """Long white hair in a few big clumps, swept back and over to his left as the master sheet: broad soft-tipped masses, no spikes."""
    locks = []
    add = lambda *a, **k: locks.append(lock(*a, **k))
    tile = lambda i: (i * 0.25) % 1.0
    top = C[2] + 0.095
    # the sweep over the skull: six broad clumps from an uneven hairline, leaning toward his left as they go back
    for i, a_deg in enumerate((-70, -44, -18, 12, 40, 68)):
        a_ = np.radians(a_deg)
        line = 44 - 11 * np.cos(a_ * 2.6) + 5 * np.sin(i * 2.4)
        path = []
        for t_ in np.linspace(0, 1, 7):
            th = np.radians(line + (172 - line) * t_)
            al = a_ * (1 - 0.1 * t_) - 0.55 * t_
            d = np.array([np.sin(th) * np.sin(al), np.cos(th), np.sin(th) * np.cos(al)])
            lift = 0.004 + 0.026 * smooth(0.0, 0.3, t_)
            path.append(hl(d * _skull_r(d)) + d * lift)
        add("sweep%d" % i, path, .09, rings=7, wide=True, peak=.4, tile=tile(i), group=None, v0=0.2, root=0.3, soft=0.25)
    # one soft fall each side of the face
    for s in (1.0, -1.0):
        add("fore%d" % s, [(s * .05, .07, top - .03), (s * .082, .05, top - .09), (s * .094, .03, top - .17), (s * .1, .0, top - .25), (s * .11, -.03, top - .33)], .036, rings=6,
            wide=True, tile=tile(0), soft=0.3)
    # the fall: big clumps down the back, drifting to his left, ends lifting out
    z = top - .06
    for i, (x, low, w, drift, g) in enumerate(((.06, .96, .115, .0, "r"), (.0, .88, .13, -.03, "c"), (-.06, .9, .125, -.07, "l"), (-.1, .98, .1, -.11, "l"), (.1, 1.08, .085, .0, "r"))):
        add("back%d" % i, [(x * .6, -.09, z + .04), (x * 1.0, -.15, z - .08), (x * 1.15 + drift * .25, -.18, z - .24), (x * 1.2 + drift * .6, -.19, 1.2), (x * 1.2 + drift, -.19, 1.06),
                           (x * 1.15 + drift * 1.6, -.21, low)], w, rings=8, wide=True, peak=.45, tile=tile(i), group=g, hint=np.array([0, -1.0, 0.1]), soft=0.12)
    for i, (x, low, w, drift, g) in enumerate(((.03, .96, .085, -.02, "c"), (-.04, 1.0, .085, -.07, "l"), (.08, 1.06, .07, .0, "r"))):
        add("over%d" % i, [(x * .6, -.12, z + .02), (x * 1.0, -.19, z - .08), (x * 1.2, -.215, z - .24), (x * 1.25 + drift * .6, -.22, 1.2), (x * 1.3 + drift * 1.5, -.215, low)], w, rings=7, wide=True,
            peak=.4, tile=tile(i + 1), group=g, hint=np.array([0, -1.0, 0.1]), soft=0.12)
    cap = hair_cap()
    return [cap] + locks


def hair_cap():
    """The scalp under the crown: a coarse shell, so no bald gap shows between the locks."""
    rows, cols = 7, 14
    zs = np.linspace(0.122, -0.06, rows)
    A, Z = np.meshgrid(np.linspace(0, 2 * np.pi, cols, endpoint=False) + 0.2, zs)
    R = ray_out(A, Z, r0=0.15) + 0.009
    front = np.cos(A) > 0.25
    R = R * (1 - 0.0 * front)
    v = hl(np.stack([np.sin(A) * R, np.cos(A) * R, Z], -1).reshape(-1, 3))
    f = grid_faces(rows, cols, True)
    # the hairline: no cap over the forehead
    keep = []
    for q in f:
        c = (v[q].mean(0) - C) / HS
        if not (c[1] > 0.0 and np.degrees(np.arctan2(c[2], c[1])) < 66):
            keep.append(q)
    uv = [[(0.5 * ((j % 4) / 4), 0.35), (0.5 * ((j % 4) / 4) + .125, .35), (0.5 * ((j % 4) / 4) + .125, .55),
           (0.5 * ((j % 4) / 4), .55)] for j in range(len(keep))]
    p = Piece("cap", "hair-mane", v, keep, uv, room=0.0).rigid("head")
    p.group = None
    p.t = None
    return p


CHAIN_BONES = 6


def mane_chains(locks):
    """Mean paths of the groups that swing: spring_mane_<g>_<i>; the group's locks skinned along it by arc length."""
    out = {}
    for g in ("c", "l", "r"):
        ms = [p for p in locks if getattr(p, "group", None) == g]
        res = []
        for p in ms:
            s = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(p.path, axis=0), axis=1))])
            s /= s[-1]
            t = np.linspace(0.14, 1.0, CHAIN_BONES)
            res.append(np.stack([np.interp(t, s, p.path[:, i]) for i in range(3)], -1))
        out[g] = np.mean(res, axis=0)
        names = ["spring_mane_%s_%d" % (g, i) for i in range(CHAIN_BONES)]
        for p in ms:
            w = {"head": np.zeros(len(p.v))}
            for n in names[:-1]:
                w[n] = np.zeros(len(p.v))
            for vi in range(len(p.v)):
                t = p.t[vi]
                u = smooth(0.08, 0.3, t)
                x = np.clip((t - 0.14) / 0.86, 0, 0.9999) * (CHAIN_BONES - 2)
                b0 = int(x)
                q = x - b0
                w["head"][vi] = 1 - u
                w[names[b0]][vi] += u * (1 - q)
                w[names[min(b0 + 1, CHAIN_BONES - 2)]][vi] += u * q
            p.w = w
    for p in locks:
        if not p.w:
            p.rigid("head")
    return out


# ------------------------------------------------------------------ the greatsword
GRIP_DIR = norm(np.array([0.0, 0.76, -0.65]))    # the blade from the fist, rest pose (he faces +Y)
_a = norm(np.array([0, 0, -1.0]) - GRIP_DIR * np.dot(np.array([0, 0, -1.0]), GRIP_DIR))
GRIP_AT = np.array([SH, 0.0, HAND_Z + 0.012]) + _a * 0.094 + np.array([-0.03, 0.0, 0.0])    # inside the closed fist
L_MID = 0.5
GUARD_OFF = 0.085                                # fist to guard: a short grip, as the master sheet
BLADE_LEN, BLADE_W = 1.0, 0.128                  # guard to tip; half width: shoulder to ankle on him


def sword_frame():
    b = GRIP_DIR                                 # along the blade
    e = norm(np.cross(b, (1.0, 0, 0)))           # along the edge
    if e[2] < 0:
        e = -e
    n = np.cross(b, e)                           # out of the flat
    return b, e, n


def outline():
    """The blade's silhouette: (along, across): a broad slab, stepped chips out of both edges, a barbed arrow head."""
    L, W = BLADE_LEN, BLADE_W
    right = [(0.0, .9), (.05, .92), (.09, 1.0), (.14, 1.0), (.155, .86), (.2, .9), (.23, 1.03), (.3, 1.03), (.32, .9), (.37, .94), (.41, 1.06), (.47, 1.04), (.49, .86), (.55, .9), (.58, 1.02),
             (.64, 1.03), (.665, .88), (.71, .94), (.75, 1.1), (.79, 1.24)]
    tip = [(.83, .82), (.815, .68), (.875, .52), (.865, .4), (.94, .2), (1.0, 0.0)]
    left = [(.93, -.24), (.875, -.38), (.885, -.54), (.82, -.72), (.835, -.86), (.77, -1.26), (.73, -1.08), (.68, -.92), (.64, -1.04), (.57, -1.06), (.55, -.88), (.5, -.92), (.46, -1.05),
            (.39, -1.04), (.37, -.86), (.31, -.92), (.27, -1.05), (.2, -1.04), (.18, -.87), (.12, -.92), (.08, -1.02), (.04, -.92), (0.0, -.9)]
    return np.array([(a * L, c * W) for a, c in right + tip + left])


def core_outline():
    """The white-hot heart: wide at the guard, jagged, narrowing to the point, with forks."""
    L, W = BLADE_LEN, BLADE_W
    pts = [(0.0, .42), (.1, .34), (.15, .46), (.22, .3), (.32, .34), (.37, .5), (.4, .3), (.52, .24), (.57, .38), (.6, .22), (.72, .17), (.8, .2), (.84, .1), (.93, .03), (.96, 0.0), (.93, -.03),
           (.84, -.1), (.76, -.18), (.68, -.16), (.63, -.36), (.58, -.22), (.47, -.27), (.42, -.46), (.38, -.28), (.26, -.3), (.2, -.48), (.16, -.3), (.07, -.36), (0.0, -.42)]
    return np.array([(a * L, c * W * 0.68) for a, c in pts])


def crack_shapes():
    """The cracks forking from the core toward the chipped edges, each a thin (along, across) triangle fan."""
    L, W = BLADE_LEN, BLADE_W
    out = []
    for a0, c0, a1, c1, wd in ((.15, .4, .24, .88, .014), (.37, .44, .3, .9, .012), (.57, .32, .67, .84, .014), (.2, -.42, .13, -.86, .014), (.42, -.4, .5, -.86, .014), (.63, -.3, .72, -.82, .012),
                               (.78, .16, .84, .46, .01), (.76, -.16, .81, -.5, .01), (.06, .36, .02, .8, .012), (.28, -.26, .33, -.76, .011), (.5, .24, .46, .86, .011)):
        a, b = np.array([a0 * L, c0 * W]), np.array([a1 * L, c1 * W])
        mid = (a + b) / 2 + np.array([0.012, -0.012])
        d = np.array([-(b - a)[1], (b - a)[0]])
        d = d / np.linalg.norm(d) * wd
        out.append(np.array([a + d, mid + d * 0.6, b, mid - d * 0.6, a - d]))
    return out


def resample_like(core, ol):
    return np.array([core[np.argmin(np.linalg.norm(core - p * [1, .4], axis=1))] for p in ol])


def blade():
    b, e, n = sword_frame()
    guard_at = GRIP_AT + b * GUARD_OFF
    ol, co = outline(), core_outline()
    m = len(ol)
    TH = 0.036
    from mathutils.geometry import tessellate_polygon
    from mathutils import Vector
    v, faces = [], []

    def put(a, c, h):
        return guard_at + b * a + e * c + n * h
    rng = np.random.RandomState(9)
    jit = rng.uniform(-.0035, .0035, m)
    # the rings: edge (shared), both faces' rim tops, both faces' inner walls
    for i, (a, c) in enumerate(ol):
        v.append(put(a, c, 0.0))
    for sgn in (1.0, -1.0):
        for i, (a, c) in enumerate(ol):
            a2, c2 = a - 0.008 * np.sign(a - .5), c * 0.74
            v.append(put(a2, c2, sgn * (TH + jit[i])))
        for i, (a, c) in enumerate(ol):
            a3, c3 = a * 0.985, c * 0.5
            v.append(put(a3, c3, sgn * (TH * 0.78 + jit[i] * .5)))
    for k in range(2):
        r0 = m * (1 + 2 * k)
        r1 = r0 + m
        for i in range(m - 1):
            j = i + 1
            faces.append([i, j, r0 + j, r0 + i] if k == 0 else [j, i, r0 + i, r0 + j])
            faces.append([r0 + i, r0 + j, r1 + j, r1 + i] if k == 0 else [r0 + j, r0 + i, r1 + i, r1 + j])
    # the bottom end is hidden by the guard. Each face's middle stays solid metal under the core's glow plates.
    for k, sgn in enumerate((1.0, -1.0)):
        r1 = m * (2 + 2 * k)
        loop = [r1 + i for i in range(m)]
        tri = tessellate_polygon([[Vector(v[i]) for i in loop]])
        for t in tri:
            q = [loop[t[0]], loop[t[1]], loop[t[2]]]
            faces.append(q if sgn < 0 else q[::-1])
    # (each face out of the blade: its flat side or its edge)
    v_ = np.array(v)
    mid = guard_at + b * L_MID
    for i, q in enumerate(faces):
        pts = v_[q]
        nrm = np.cross(pts[1] - pts[0], pts[2] - pts[0])
        c_ = pts.mean(0) - mid
        h_ = np.dot(c_, n)
        out = n * np.sign(h_ if abs(h_) > 1e-4 else 1.0) + (e * np.dot(c_, e) + b * np.dot(c_, b)) * 2.0
        if np.dot(nrm, out) < 0:
            faces[i] = q[::-1]
    plate = Piece("blade", "metal-blade", v, faces).rigid("hand.R")
    plate.ol = ol
    plate.guard_at, plate.frame = guard_at, (b, e, n)
    cores = []
    for k, sgn in enumerate((1.0, -1.0)):
        vv = [guard_at + b * a + e * c + n * sgn * (TH * 0.78 + 0.0035) for a, c in co]
        tri = tessellate_polygon([[Vector(p) for p in vv]])
        ff = [list(t) if sgn > 0 else list(t)[::-1] for t in tri]
        # keep the fan's winding out of the flat
        q = np.array(vv)
        d = np.cross(q[ff[0][1]] - q[ff[0][0]], q[ff[0][2]] - q[ff[0][0]])
        if np.dot(d, n * sgn) < 0:
            ff = [f[::-1] for f in ff]
        cores.append(Piece("core%d" % k, "glow-sword", vv, ff, room=0.0).rigid("hand.R"))
    # the white-gold halo round the core and its forked cracks, a step below it
    halos = []
    for k, sgn in enumerate((1.0, -1.0)):
        ring = co.copy()
        cen = np.array([[a_, 0.0] for a_, _ in ring])
        ring = cen + (ring - cen) * 1.28
        polys = [ring] + crack_shapes()
        vv, ff = [], []
        for poly in polys:
            q = [guard_at + b * a_ + e * c_ + n * sgn * (TH * 0.78 + 0.002) for a_, c_ in poly]
            tri = tessellate_polygon([[Vector(x) for x in q]])
            o = len(vv)
            vv += q
            for t in tri:
                f = [o + t[0], o + t[1], o + t[2]]
                d = np.cross(np.array(vv[f[1]]) - vv[f[0]], np.array(vv[f[2]]) - vv[f[0]])
                ff.append(f if np.dot(d, n * sgn) > 0 else f[::-1])
        halos.append(Piece("coreh%d" % k, "glow-sword_edge", vv, ff, room=0.0).rigid("hand.R"))
    return [plate] + cores + halos


def hilt(uv_chain):
    b, e, n = sword_frame()
    g = GRIP_AT + b * GUARD_OFF
    out = []
    # the flat iron crossguard
    sec = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
    path = [g + e * d for d in (-0.165, -0.15, 0.15, 0.165)]
    bar = sweep("guard", "metal-guard", path, sec, np.array([0.022, 0.03, 0.03, 0.022]), side_hint=b, depth=np.array([0.018, 0.024, 0.024, 0.018]))
    out.append(bar.rigid("hand.R"))
    # the grip, its iron collar and the spiked pommel
    sec8 = [(np.cos(t), np.sin(t)) for t in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
    p = [g - b * 0.20, g - b * 0.19, g - b * 0.175, g - b * 0.16, g - b * 0.02, g]
    grip = sweep("grip", "leather-grip", p, sec8, np.array([0.03, 0.03, 0.026, 0.0195, 0.0195, 0.024]), side_hint=e)
    out.append(grip.rigid("hand.R"))
    spike = [g - b * 0.195, g - b * 0.225, g - b * 0.28, g - b * 0.335]
    sp = sweep("pommel", "metal-guard", spike, [(-1, 0), (0, 1), (1, 0), (0, -1)], np.array([0.022, 0.03, 0.016, 0.001]), side_hint=e)
    out.append(sp.rigid("hand.R"))
    return out
