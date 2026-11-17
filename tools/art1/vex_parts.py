"""ART-1 Vex (v2): every rebuilt piece in one place (shared by the shape pass and the finish): build(bvh of the fitted scan, bvh of the shipped body) -> dict."""
import numpy as np
from mathutils import Vector
from meshkit import Piece, catmull, norm
import vex_cannon as VC, vex_arm as VA, vex_head as VH


def project(bvh, pts, off):
    """Each point pushed from the body's axis onto the surface, `off` outside it."""
    out = []
    for p in pts:
        p = np.asarray(p, float)
        d = norm(p - np.array([0, 0, p[2]]))
        hit = bvh.ray_cast(Vector(p + d * 0.3), Vector(-d), 0.6)
        out.append(np.array(hit[0]) + d * off if hit[0] is not None else p)
    return np.array(out)


def coin_chain(bvh):
    """The gold coin hip chain: from the belt's front on her left hip, draped round the hip to the back pocket. Flat coins on the surface, rigid on hips."""
    z = VC.J("hips")[2]
    key = [(-.10, .14, z + .02), (-.15, .10, z - .07), (-.19, .02, z - .11), (-.18, -.07, z - .07), (-.12, -.13, z + .0)]
    path = project(bvh, catmull(np.array(key, float), 13), 0.008)
    out = []
    for i, c in enumerate(path):
        nrm = norm(c - np.array([0, 0, c[2]]))
        t = norm(path[min(i + 1, len(path) - 1)] - path[max(i - 1, 0)])
        b = norm(np.cross(nrm, t))
        v = [c + nrm * h + (np.cos(a) * t + np.sin(a) * b) * 0.0115 for h in (0.0025, -0.0025) for a in np.linspace(0, 2 * np.pi, 8, endpoint=False)]
        f = [[0, j + 1, j] for j in range(1, 7)] + [[8, 8 + j, 9 + j] for j in range(1, 7)] + [[j, (j + 1) % 8, 8 + (j + 1) % 8, 8 + j][::-1] for j in range(8)]
        out.append(Piece("hipcoin%d" % i, "brass-vex", np.array(v), f).rigid("hips"))
    return out


def build(bvh_src, bvh_low, bvh_head):
    """bvh_head: the placed head scan (fine-detail pass): it carries the face, hair, goggles and ears."""
    VH.set_eye_y(bvh_head)
    bd, bpath = VH.braid()
    bnames, bpts = VH.braid_chain(bd, bpath)
    lid, lid_c = VH.blink_lid(bvh_head)
    headp = VH.scan_brows(bvh_head) + [lid]
    arm = VA.forearm()
    hnd, knuck, a, k, o = VA.hand()
    coin, coin_c = VA.coin(knuck, a, k, o)
    pieces = headp + bd + VC.all_pieces() + arm + hnd + [coin] + VA.panel() + coin_chain(bvh_low)
    for p in pieces:
        if p.name.startswith(("ammo", "lid", "gl", "hipcoin")):
            continue
        p.orient()
    return {"pieces": pieces, "braid": bd, "bnames": bnames, "bpts": bpts, "coin": coin_c, "lid_c": lid_c}
