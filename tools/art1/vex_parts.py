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
    """The belt: from the gear pack over her left shoulder, across the chest, down to her right hip where the cannon feeds."""
    SH = VC.J("upper_arm.R")
    top = SH[2]
    H = VC.J("hips")[2]
    key = [(-.20, .10 * -1, top + .03), (-.15, .06, top + .055), (-.085, .135, top - .08), (-.03, .165, top - .2), (.05, .165, top - .32), (.13, .13, top - .40), (.215, .07, top - .45)]
    path = catmull(np.array(key, float), 44)
    path = project(bvh, path, 0.012)
    # smooth what the projection jittered
    for _ in range(3):
        path[1:-1] = (path[:-2] + path[2:] + path[1:-1] * 2) / 4
    side_hint = np.array([0.5, -0.1, 0.85])
    p = VC.belt_path_tile("ammo", path, 0.028, hint=side_hint)
    return p


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
                    v.append(p + n * 0.003 + s_ * off * 0.0075)
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
    belt.w = {"hips": np.ones(len(belt.v))}
    hs = hoses(pack_c)
    pieces = stripes(bvh_low) + headp + bd + cannon + arm + hnd + [coin] + sp + pack + [belt] + hs
    for p in pieces:
        if p.name.startswith(("ammo", "lid", "face", "gfr", "gl", "eyeL", "stripe")):
            continue
        p.orient()
    return {"pieces": pieces, "hair": hair, "braid": bd, "bnames": bnames, "bpts": bpts, "fnames": fnames, "fpts": fpts, "coin": coin_c, "pack_c": pack_c, "lid_c": lid_c}
