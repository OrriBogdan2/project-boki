"""ART-1 Vex: every rebuilt piece in one place (shared by the shape pass and the finish): build(bvh of the fitted scan, bvh of the shipped body) -> dict."""
import numpy as np
from mathutils import Vector
from meshkit import Piece, catmull, norm, smooth, sweep
import vex_cannon as VC, vex_arm as VA, vex_head as VH


def surf_y_back(bvh, z):
    hit = bvh.ray_cast(Vector((0, -0.6, z)), Vector((0, 1, 0)), 1.0)
    return hit[0][1] if hit[0] is not None else -0.12


def project(bvh, pts, off):
    """Each point pushed from the body's axis onto the surface, `off` outside it."""
    out = []
    for p in pts:
        p = np.asarray(p, float)
        d = norm(p - np.array([0, 0, p[2]]))
        hit = bvh.ray_cast(Vector(p + d * 0.3), Vector(-d), 0.6)
        out.append(np.array(hit[0]) + d * off if hit[0] is not None else p)
    return np.array(out)


def ammo(bvh):
    """The belt: from the gear pack over her left shoulder, across the chest, to her right hip. Real cartridges side by side on a dark link strip, each brass with a copper nose, tiled."""
    SH = VC.J("upper_arm.R")
    top = SH[2]
    key = [(-.20, -.10, top + .03), (-.15, .06, top + .055), (-.085, .135, top - .08), (-.03, .165, top - .2), (.05, .165, top - .32), (.13, .13, top - .40), (.215, .07, top - .45)]
    path = catmull(np.array(key, float), 60)
    path = project(bvh, path, 0.011)
    for _ in range(4):
        path[1:-1] = (path[:-2] + path[2:] + path[1:-1] * 2) / 4
    # even steps along the path
    d = np.concatenate([[0], np.cumsum(np.linalg.norm(np.diff(path, axis=0), axis=1))])
    STEP, LEN, R = 0.0285, 0.03, 0.0112
    at = np.arange(STEP * 0.5, d[-1], STEP)
    pts = np.stack([np.interp(at, d, path[:, i]) for i in range(3)], 1)
    tan = M_norm(np.gradient(pts, axis=0))
    nor = M_norm(pts * [1, 1, 0] - [0, -0.02, 0])
    acr = M_norm(np.cross(tan, nor))
    nor = M_norm(np.cross(acr, tan)) * np.sign(np.sum(np.cross(acr, tan) * nor, axis=1, keepdims=True))
    v, f, uv = [], [], []
    SEC = 5
    prof = [(-1.0, 0.92, 0.0), (0.4, 1.0, 0.72), (0.72, 0.8, 0.8), (1.0, 0.22, 1.0)]       # (along, radius, tile v)
    for i in range(len(pts)):
        base = len(v)
        for al, rr, tv in prof:
            for j in range(SEC):
                t_ = j / SEC * 2 * np.pi
                v.append(pts[i] + acr[i] * al * LEN + (nor[i] * np.cos(t_) + tan[i] * np.sin(t_)) * rr * R + nor[i] * 0.004)
        for k in range(len(prof) - 1):
            for j in range(SEC):
                a0, b0 = base + k * SEC + j, base + k * SEC + (j + 1) % SEC
                f.append([a0, a0 + SEC, b0 + SEC, b0])
                s0, s1 = abs(np.cos(j / SEC * 2 * np.pi)), abs(np.cos((j + 1) / SEC * 2 * np.pi))
                uv.append([(s0, prof[k][2]), (s0, prof[k + 1][2]), (s1, prof[k + 1][2]), (s1, prof[k][2])])
    c = Piece("ammoc", "metal-belt", np.array(v), f, uv, room=0.3)
    # the link strip under them
    sv, sf, su = [], [], []
    for i in range(len(pts)):
        for off in (-1, 1):
            sv.append(pts[i] + acr[i] * off * 0.02 - nor[i] * 0.004)
    for i in range(len(pts) - 1):
        q = i * 2
        sf.append([q, q + 2, q + 3, q + 1])
        su.append([(0.1, 0.02), (0.9, 0.02), (0.9, 0.2), (0.1, 0.2)])
    st = Piece("ammostrip", "metal-belt", np.array(sv), sf, su, room=0.3)
    return [c, st]


def M_norm(a):
    return norm(a)


def stripes(bvh):
    """The thigh-highs' glowing lines as geometry: a slim strip down the shin's front and up the thigh's, on the surface (the scan's paint breaks up under the budget)."""
    out = []
    for sd, sx in (("R", 1.0), ("L", -1.0)):
        K = VC.J("shin." + sd)
        for nm, z0, z1, bone in (("stripeS", K[2] - 0.075, 0.22, "shin." + sd), ("stripeT", K[2] + 0.08, K[2] + 0.28, "thigh." + sd)):
            pts = []
            for z in np.linspace(z0, z1, 7):
                x = K[0] + (0.0 if z > K[2] else (z - K[2]) * 0.0)
                hit = bvh.ray_cast(Vector((x, 0.5, z)), Vector((0, -1, 0)), 1.0)
                if hit[0] is not None:
                    pts.append((np.array(hit[0]), np.array(hit[1])))
            if len(pts) < 3:
                continue
            v, f = [], []
            for p, n in pts:
                s_ = norm(np.cross(n, (0, 0, 1.0)))
                for off in (-1, 1):
                    v.append(p + n * 0.007 + s_ * off * 0.0085)
            for i in range(len(pts) - 1):
                f.append([i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2])
            q = Piece(nm + sd, "glow-vex", np.array(v), f).rigid(bone)
            c = np.array([pts[0][0][0], pts[0][0][1] - 0.2, (z0 + z1) / 2])
            q.orient(tuple(c))
            out.append(q)
    return out


def hoses(pack_c):
    S = VC.J("upper_arm.R")
    E = VC.E
    out = []
    # the feed: from the gear pack, over her back behind the neck, into the socket
    out.append(VC.hose("hose0", [pack_c + [0.02, -0.05, 0.07], pack_c + [0.1, -0.03, 0.15], (0.04, pack_c[1] + 0.06, S[2] + 0.2), (S[0] - 0.02, -0.07, S[2] + 0.16), (S[0] + 0.01, -0.05, S[2] + 0.06)], r=0.015, n=11, bones=["hips", "upper_arm.R"], sec=6))
    # socket to the cannon: the sheet's pair of looped hoses
    a0, b0 = S + [0.09, -0.06, -0.17], VC.C(0.02, 0.05, -0.07)
    out.append(VC.hose("hose1", [a0, a0 + [0.05, -0.05, -0.08], b0 + [0.03, -0.1, 0.05], b0 + [0.0, -0.02, 0.0]], r=0.0125, n=8, bones=["upper_arm.R", "forearm.R"]))
    a1, b1 = S + [0.1, -0.03, -0.2], VC.C(-0.06, 0.045, -0.075)
    out.append(VC.hose("hose2", [a1, a1 + [0.05, -0.08, -0.04], b1 + [0.03, -0.09, 0.03], b1], r=0.0125, n=8, bones=["upper_arm.R", "forearm.R"]))
    # launcher feed, up from the drum
    a2 = VC.C(-0.09, VC.SLEEVE_R + 0.05, VC.SLEEVE_F - 0.016)
    b2 = VC.C(-0.02, 0.03, VC.TUBE_F - 0.03)
    out.append(VC.hose("hose3", [a2, a2 + [0.02, 0.03, 0.05], b2 + [0.03, 0.03, 0.03], b2], r=0.009, n=7, bones=["forearm.R"], sec=5))
    return out


def build(bvh_src, bvh_low, bvh_head=None):
    """bvh_head: the placed head scan (fine-detail pass): it carries the face, hair, goggles and ears."""
    VH.set_eye_y(bvh_head or bvh_src)
    bd, bpath = VH.braid()
    bnames, bpts = VH.braid_chain(bd, bpath)
    if bvh_head is not None:
        lid, lid_c = VH.blink_lid(bvh_head)
        headp = VH.scan_brows(bvh_head) + VH.scan_lens(bvh_head) + [lid]
        hair, fnames, fpts = [], [], []
    else:
        lid_c = None
        face = VH.head(bvh_src)
        hair = VH.hair(bvh_src)
        fnames, fpts = VH.fore_chain(hair)
        for p in hair:
            if not p.w:
                p.rigid("head")
        headp = [face, VH.eyeball()] + VH.lids() + VH.brows() + VH.cyber_eye() + hair + VH.goggles(bvh_src) + VH.ear(bvh_src)
    cannon = VC.all_pieces()
    arm = VA.forearm()
    hnd, knuck, a, k, o = VA.hand()
    coin, coin_c = VA.coin(knuck, a, k, o)
    S = VC.J("upper_arm.R")
    sh_z = S[2]
    VH.Z_WAIST = VC.J("hips")[2] + 0.05
    sp = VH.spine(VC.J("hips")[2] + 0.02, sh_z - 0.06, lambda z: surf_y_back(bvh_low, z))
    pack, pack_c, pa, pb = VC.gear_pack(sh_z + 0.0, surf_y_back(bvh_low, sh_z - 0.0))
    belt = ammo(bvh_low)
    for q in belt:
        q.w = {"hips": np.ones(len(q.v))}
    plate_back = VH.spine_plate(sh_z - 0.03, lambda z: surf_y_back(bvh_low, z), lambda x, z: bvh_low.ray_cast(Vector((x, -0.6, z)), Vector((0, 1, 0)), 1.0)[0])
    poster = VC.poster()
    hs = hoses(pack_c)
    pieces = stripes(bvh_low) + headp + bd + cannon + arm + hnd + [coin] + sp + plate_back + pack + belt + poster + hs + VA.panel()
    for p in pieces:
        if p.name.startswith(("ammo", "lid", "face", "gfr", "gl", "eyeL", "stripe", "splate", "poster")):
            continue
        p.orient()
    return {"pieces": pieces, "hair": hair, "braid": bd, "bnames": bnames, "bpts": bpts, "fnames": fnames, "fpts": fpts, "coin": coin_c, "pack_c": pack_c, "lid_c": lid_c}
