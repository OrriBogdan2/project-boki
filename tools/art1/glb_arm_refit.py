"""Turns a scan's bent arm onto its straight rest bones in a shipped Hero .glb, and moves the clips' wrist roll into the
forearm, in place (numpy, no Blender; every other byte of the file stays as it was).

Why (Neve, claire.glb, docs/DEBT.md): the 11-17 body (board1117/B) was modelled holding its spear, the right arm bent
about 90 degrees with the forearm and open glove raised to the chest, but it was bound to the rig's straight-down arm
bones, and the glove was weighted to upper_arm/forearm. Every clip bent the mesh about the wrong points: the glove rode
the forearm out at the side while hand.R (and the spear on it) sat on the shoulder. tools/art1/warden_fix_1112.py fixed
the same thing on the 11-10 body in Blender; this is the in-place pass for a body that is already shipped.

1. Refit: the arm (grown over the mesh from its chain, only arm-weighted vertices) turns about the mesh's own shoulder
   onto a straight line down to the prop's grip, each joint by a blended rotation about the joint (no collapse at the
   bend); the glove last, turned so its palm faces the grip. The bones stay on the rig nodes (warden_skeleton REST_TOL).
2. Weights: the arm's own (shoulder blend kept), the glove on hand.*, the elbow blended between the mesh's elbow and the
   bone's (the scan's upper arm is longer than the rig's); stray arm weight far from the arm goes.
3. Re-key: in every clip the hand's roll about its bone is split evenly between the elbow and the wrist (the forearm
   turns about its own axis, the hand back by as much), so hand.* and the prop on it keep their world pose exactly.

Run: python3 tools/art1/glb_arm_refit.py <claire> IN.glb OUT.glb [--i-checked-renders]
It refuses to write a shipped Hunter (art/wardens/<id>/<id>.glb) without --i-checked-renders (as glb_relax.py)."""

import os
import re
import struct
import sys

import numpy as np

import glb_add_clips
import glb_relax

# glTF model metres (Y up, the hunter faces -Z). Measured on gridded front and side renders of the rest mesh.
SPECS = {
    "claire": {
        "side": "R",
        "mesh": "Body.002",
        "shoulder": (0.18, 1.32, 0.02),  # the arm's turning point in the sleeve top
        "elbow": (0.25, 1.09, 0.03),  # the bend: the upper arm hangs, the forearm points forward at the waist
        "wrist": (0.30, 1.12, -0.12),  # cuff to glove
        "tip": (0.34, 1.15, -0.19),  # the glove's middle (open, thumb up, palm in)
        "grip": (0.12, 0.835, 0.0),  # on the spear shaft (rest, along Z) by hand.R
        "palm_off": 0.03,  # m from the shaft's line to the glove's middle, outward (+X)
        "palm_turn": 0.0,  # degrees about the arm's line: unbending the elbow already turns the palm in, thumb along the shaft
    },
}
SEED_R, GROW_R = 0.045, 0.13  # m from the chain: the arm's seed, and how far it grows over arm-weighted vertices
ARM_W = 0.2  # an arm vertex carries at least this much of the side's arm weight
STRAY_KEEP = 0.20  # m from the shoulder: arm weight off the arm is kept this near it (the shoulder blend)
STRAY_FAR = 0.12  # m from the arm's line: arm weight further off fades out over STRAY_FADE
STRAY_FADE = 0.15
SCRAP = 200  # points: a loose piece this small keeps its weights (the scan's floating slivers)
SHOULDER_BLEND = 0.08  # m along the arm over which the refit turns in from nothing (and the skin from hips)
ELBOW_BLEND, WRIST_BLEND = 0.05, 0.025  # m either side of the skin's elbow and wrist
REFIT_ELBOW, REFIT_WRIST = 0.04, 0.02  # m either side of the mesh's joints over which the refit's turn blends
TWIST_SPLIT = 0.5  # the forearm takes this share of the wrist's roll over the elbow's
TWIST_CAP = 60.0  # degrees: the most roll the forearm takes (a full twirl of the spear stays in the wrist)


def smooth(x):
    x = np.clip(x, 0.0, 1.0)
    return x * x * (3 - 2 * x)


def qmul(a, b):
    ax, ay, az, aw = np.moveaxis(a, -1, 0)
    bx, by, bz, bw = np.moveaxis(b, -1, 0)
    return np.stack(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ],
        -1,
    )


def qconj(q):
    return q * np.array([-1, -1, -1, 1.0])


def qaxis(axis, ang):
    axis = np.asarray(axis, float)
    axis = axis / np.linalg.norm(axis, axis=-1, keepdims=True)
    h = np.asarray(ang)[..., None] / 2
    return np.concatenate([axis * np.sin(h), np.cos(h)], -1)


def qfrom_to(a, b):
    """The shortest-arc rotation taking direction a onto b."""
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    c = np.cross(a, b)
    q = np.array([*c, 1.0 + a @ b])
    if q[3] < 1e-8:
        perp = np.cross(a, [1, 0, 0]) if abs(a[0]) < 0.9 else np.cross(a, [0, 1, 0])
        q = np.array([*perp, 0.0])
    return q / np.linalg.norm(q)


def qslerp(a, b, t):
    """Per-row slerp of a [4] toward b [4] by t [n]."""
    d = float(a @ b)
    if d < 0:
        b, d = -b, -d
    t = np.asarray(t, float)[:, None]
    if d > 0.9995:
        q = a * (1 - t) + b * t
    else:
        th = np.arccos(d)
        q = (np.sin((1 - t) * th) * a + np.sin(t * th) * b) / np.sin(th)
    return q / np.linalg.norm(q, axis=1, keepdims=True)


def qrot_rows(q, v):
    """Rotates each row of v by the matching row of q."""
    u, w = q[:, :3], q[:, 3:4]
    return v + 2 * np.cross(u, np.cross(u, v) + w * v)


def twist_first(q, axis):
    """q = twist * swing with twist about axis (unit): the twist's angle (radians, -pi..pi)."""
    qi = qconj(q)  # qi = swing^-1 * twist^-1: its twist (swing-twist form) is twist^-1
    proj = qi[..., :3] @ axis
    ang = -2 * np.arctan2(proj, qi[..., 3])
    return (ang + np.pi) % (2 * np.pi) - np.pi


def raw(j, bin_, i):
    """(array [count, n] float/int, byte offset, stride, dtype) of accessor i."""
    rows, at, stride = glb_relax.accessor(j, bin_, i)
    return rows, at, stride, rows.dtype


def put(bin_, at, stride, rows, dt):
    rows = np.asarray(rows).astype(dt)
    w = rows.shape[1] * rows.dtype.itemsize
    for k, r in enumerate(rows):
        o = at + k * stride
        bin_[o : o + w] = r.tobytes()


def polyline_param(P, pts):
    """Arc length along the polyline pts of each point's nearest point, and the distance to it."""
    best_d = np.full(len(P), np.inf)
    best_s = np.zeros(len(P))
    acc = 0.0
    for a, b in zip(pts[:-1], pts[1:]):
        ab = b - a
        L = np.linalg.norm(ab)
        t = np.clip(((P - a) @ ab) / (L * L), 0.0, 1.0)
        d = np.linalg.norm(P - (a + t[:, None] * ab), axis=1)
        m = d < best_d
        best_d[m], best_s[m] = d[m], acc + t[m] * L
        acc += L
    return best_s, best_d


def adjacency(prims, maps, pid):
    tris = np.concatenate([pid[t] for t in glb_relax.triangles(prims, maps)])
    e = np.sort(np.concatenate([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]]), axis=1)
    e = np.unique(e[e[:, 0] != e[:, 1]], axis=0)
    nb = [[] for _ in range(pid.max() + 1)]
    for a, b in e:
        nb[a].append(b)
        nb[b].append(a)
    return nb


def piece_sizes(nb):
    """Each point's connected piece's point count."""
    lab = np.full(len(nb), -1)
    sizes = []
    for i in range(len(nb)):
        if lab[i] >= 0:
            continue
        lab[i] = len(sizes)
        todo, n = [i], 0
        while todo:
            u = todo.pop()
            n += 1
            for k in nb[u]:
                if lab[k] < 0:
                    lab[k] = len(sizes)
                    todo.append(k)
        sizes.append(n)
    return np.array(sizes)[lab]


def grow(nb, seed, allowed):
    out = seed.copy()
    todo = list(np.nonzero(seed)[0])
    while todo:
        i = todo.pop()
        for k in nb[i]:
            if not out[k] and allowed[k]:
                out[k] = True
                todo.append(k)
    return out


def refit(j, bin_, sp, names):
    """Steps 1 and 2 on the spec's mesh. Returns a report dict."""
    sd = sp["side"]
    mesh = next(m for m in j["meshes"] if m["name"] == sp["mesh"])
    prims = glb_relax.skinned(j, bin_)[sp["mesh"]]
    rest, w, maps = glb_relax.weld(prims, len(names))  # one row per position+weights
    key = np.round(rest / glb_relax.WELD).astype(np.int64)
    _, first, pid = np.unique(key, axis=0, return_index=True, return_inverse=True)
    pid = pid.ravel()  # weld row -> position point
    P = rest[first]
    up, fo, ha = (names.index(b + "." + sd) for b in ("upper_arm", "forearm", "hand"))
    hips = names.index("hips")
    aw_row = w[:, [up, fo, ha]].sum(1)
    aw = np.zeros(len(P))
    np.maximum.at(aw, pid, aw_row)

    S, E, W, T = (np.array(sp[k], float) for k in ("shoulder", "elbow", "wrist", "tip"))
    l1, l2, l3 = np.linalg.norm(E - S), np.linalg.norm(W - E), np.linalg.norm(T - W)
    T2 = T + (T - W) / l3 * 0.06  # past the glove's middle: the fingers and claws
    s_par, dist = polyline_param(P, [S, E, W, T2])
    nb = adjacency(prims, maps, pid)
    seed = (dist < SEED_R) & (aw > 0.3)
    arm = grow(nb, seed, (aw > ARM_W) & (dist < GROW_R) & (P[:, 1] < S[1] + 0.06))

    # the target line: from the shoulder down to the grip, the glove's middle line palm_off outside the shaft
    G = np.array(sp["grip"], float) + np.array([sp["palm_off"], 0, 0])
    d_t = G - S
    d_t /= np.linalg.norm(d_t)  # the glove's middle lands about on G (l1 + l2 + l3 down)
    E_t, W_t = S + l1 * d_t, S + (l1 + l2) * d_t
    R_u = qfrom_to(E - S, d_t)
    R_f = qmul(qfrom_to(qrot_rows(R_u[None], (W - E)[None])[0], d_t), R_u)
    R_h0 = qmul(qfrom_to(qrot_rows(R_f[None], (T - W)[None])[0], d_t), R_f)
    gl = arm & (s_par > l1 + l2 + 0.01)
    ang = np.radians(sp["palm_turn"])
    R_h = qmul(qaxis(d_t, ang), R_h0)

    # per point: the blended rotation and its pivot
    s = s_par
    a_s = smooth(s / SHOULDER_BLEND)
    a_e = smooth((s - (l1 - REFIT_ELBOW)) / (2 * REFIT_ELBOW))
    a_w = smooth((s - (l1 + l2 - REFIT_WRIST)) / (2 * REFIT_WRIST))
    ident = np.array([0, 0, 0, 1.0])
    q_up = qslerp(ident, R_u, a_s)
    q_e = qslerp(R_u, R_f, a_e)
    q = np.where((a_e > 0)[:, None], q_e, q_up)
    newP = S + qrot_rows(q_up, P - S)
    m = a_e > 0
    newP[m] = E_t + qrot_rows(q_e[m], P[m] - E)
    mw = a_w > 0
    q_w = np.array([qslerp(R_f, R_h, a_w[[i]])[0] for i in np.nonzero(mw)[0]]).reshape(-1, 4)
    newP[mw] = W_t + qrot_rows(q_w, P[mw] - W)
    q[mw] = q_w
    newP[~arm] = P[~arm]
    q[~arm] = ident

    # the bones' joints on the target line (arc length from the shoulder)
    nodes = j["nodes"]
    glob = node_rest_globals(j)
    jb = {
        b: glob[next(i for i, n in enumerate(nodes) if n.get("name") == b + "." + sd)][:3, 3]
        for b in ("forearm", "hand")
    }
    s_eb, s_wb = (float((jb[b] - S) @ d_t) for b in ("forearm", "hand"))
    s_e, s_w = (l1 + s_eb) / 2, (l1 + l2 + s_wb) / 2

    # step 2: weights, per weld row
    wn = w.copy()
    sr, armr = s[pid], arm[pid]
    a_up = smooth((sr + 0.01) / (SHOULDER_BLEND - 0.02))
    w_fo = smooth((sr - (s_e - ELBOW_BLEND)) / (2 * ELBOW_BLEND))
    w_ha = smooth((sr - (s_w - WRIST_BLEND)) / (2 * WRIST_BLEND))
    other = w.copy()
    other[:, [up, fo, ha]] = 0
    tot = other.sum(1, keepdims=True)
    other = np.where(tot > 0.05, other / np.maximum(tot, 1e-9), 0)
    other[tot[:, 0] <= 0.05, hips] = 1.0
    arm_rows = np.nonzero(armr)[0]
    share = aw_row + (1 - aw_row) * a_up  # from the old arm share at the shoulder (its neighbours
    wn[arm_rows] = other[arm_rows] * (1 - share[arm_rows, None])  # off the arm keep theirs) to all arm
    wn[arm_rows, up] += share[arm_rows] * (1 - w_fo[arm_rows])
    wn[arm_rows, fo] += share[arm_rows] * w_fo[arm_rows] * (1 - w_ha[arm_rows])
    wn[arm_rows, ha] += share[arm_rows] * w_fo[arm_rows] * w_ha[arm_rows]
    # the skirt, sash and cape off the arm lose their arm weight, fading out with the distance (no seam where it stops)
    keep = 1 - smooth((dist[pid] - STRAY_FAR) / STRAY_FADE) * smooth(
        (np.linalg.norm(rest - S, axis=1) - STRAY_KEEP) / STRAY_FADE
    )
    big = piece_sizes(nb) >= SCRAP  # loose scraps (a floating sliver) keep their weights
    far = (~armr) & (aw_row > 0) & (keep < 1) & big[pid]
    k = keep[far, None]
    wn[far] = w[far] * np.where(np.isin(np.arange(w.shape[1]), [up, fo, ha]), k, 1.0)
    wn[far] += other[far] * (aw_row[far, None] * (1 - k))

    # write: positions and normals per primitive (each vertex by its point), weights through glb_relax.store's packing
    for pr_j, p, mp in zip(mesh["primitives"], prims, maps):
        at = pr_j["attributes"]
        pts = pid[mp]
        pos, pat, pst, pdt = raw(j, bin_, at["POSITION"])
        nor, nat, nst, ndt = raw(j, bin_, at["NORMAL"])
        moved = arm[pts]
        pos = pos.astype(float)
        pos[moved] = newP[pts[moved]]
        nor = nor.astype(float)
        nor[moved] = qrot_rows(q[pts[moved]], nor[moved])
        nor[moved] /= np.linalg.norm(nor[moved], axis=1, keepdims=True)
        put(bin_, pat, pst, pos, pdt)
        put(bin_, nat, nst, nor, ndt)
        acc = j["accessors"][at["POSITION"]]
        acc["min"], acc["max"] = pos.min(0).tolist(), pos.max(0).tolist()
    store_weights(bin_, prims, wn, maps)
    return {
        "arm points": int(arm.sum()),
        "seed": int(seed.sum()),
        "glove points": int(gl.sum()),
        "stray rows cleared": int(far.sum()),
        "upper/fore/hand m": (round(l1, 3), round(l2, 3), round(l3, 3)),
        "skin elbow/wrist s": (round(s_e, 3), round(s_w, 3)),
        "bone elbow/wrist s": (round(s_eb, 3), round(s_wb, 3)),
        "turns deg (upper, fore, hand)": tuple(
            round(np.degrees(2 * np.arccos(min(1, abs(x[3])))), 1) for x in (R_u, R_f, R_h)
        ),
        "palm turn deg": round(float(np.degrees(ang)), 1),
    }


def store_weights(bin_, prims, w, maps):
    """Each vertex's top 4 bones and weights over its JOINTS_0 and WEIGHTS_0 (glb_relax.store without the rip)."""
    for p, mp in zip(prims, maps):
        top = np.argsort(-w[mp], axis=1)[:, :4]
        wt = np.take_along_axis(w[mp], top, 1)
        wt = wt / np.maximum(wt.sum(1, keepdims=True), 1e-9)
        top[wt == 0.0] = 0
        jo_at, jo_st, jo_dt = p["jo"]
        wt_at, wt_st = p["wt"]
        for v in range(len(mp)):
            o = jo_at + v * jo_st
            bin_[o : o + 4 * jo_dt.itemsize] = top[v].astype(jo_dt).tobytes()
            o = wt_at + v * wt_st
            bin_[o : o + 16] = struct.pack("<4f", *wt[v])


def node_rest_globals(j):
    nodes = j["nodes"]
    parent = [-1] * len(nodes)
    for i, nd in enumerate(nodes):
        for c in nd.get("children", []):
            parent[c] = i
    out = [None] * len(nodes)

    def world(i):
        if out[i] is None:
            nd = nodes[i]
            loc = glb_relax.local_matrix(
                {
                    "translation": nd.get("translation", [0, 0, 0]),
                    "rotation": nd.get("rotation", [0, 0, 0, 1]),
                    "scale": nd.get("scale", [1, 1, 1]),
                }
            )
            out[i] = loc if parent[i] < 0 else world(parent[i]) @ loc
        return out[i]

    for i in range(len(nodes)):
        world(i)
    return out


def rekey(j, bin_, sd):
    """Step 3: each clip's hand roll split with the forearm (hand world pose kept). Returns {clip: (worst wrist roll
    before, after, worst elbow roll after)} in degrees."""
    nodes = j["nodes"]
    fo = next(i for i, n in enumerate(nodes) if n.get("name") == "forearm." + sd)
    ha = next(i for i, n in enumerate(nodes) if n.get("name") == "hand." + sd)
    rest_t = np.array(nodes[ha].get("translation", [0, 0, 0]), float)
    out = {}
    done = set()
    for anim in j["animations"]:
        ch = {(c["target"]["node"], c["target"]["path"]): anim["samplers"][c["sampler"]] for c in anim["channels"]}
        if (ha, "rotation") not in ch or (fo, "rotation") not in ch:
            continue
        sf, sh = ch[(fo, "rotation")], ch[(ha, "rotation")]
        assert sf.get("interpolation", "LINEAR") == "LINEAR" and sh.get("interpolation", "LINEAR") == "LINEAR"
        tf = raw(j, bin_, sf["input"])[0][:, 0]
        th = raw(j, bin_, sh["input"])[0][:, 0]
        assert len(tf) == len(th) and np.allclose(tf, th), anim["name"] + ": forearm and hand keys differ"
        assert (sf["output"], sh["output"]) not in done, "shared key data"
        done.add((sf["output"], sh["output"]))
        qf, fat, fst, fdt = raw(j, bin_, sf["output"])
        qh, hat, hst, hdt = raw(j, bin_, sh["output"])
        qf, qh = qf.astype(float), qh.astype(float)
        if (ha, "translation") in ch:
            tr = raw(j, bin_, ch[(ha, "translation")]["output"])[0].astype(float)
            axis = tr / np.linalg.norm(tr, axis=1, keepdims=True)
            assert np.abs(axis - rest_t / np.linalg.norm(rest_t)).max() < 1e-3, "hand moves off its bone line"
        axis = rest_t / np.linalg.norm(rest_t)
        tw_h = np.unwrap(twist_first(qh, axis))
        tw_h -= 2 * np.pi * np.round((tw_h.max() + tw_h.min()) / (4 * np.pi))  # the turn nearest rest
        tw_f = np.unwrap(twist_first(qf, axis))
        tw_f -= 2 * np.pi * np.round((tw_f.max() + tw_f.min()) / (4 * np.pi))
        # elbow and wrist end with the same roll, the forearm's share capped (a spear twirl stays in the wrist)
        beta = np.clip(TWIST_SPLIT * (tw_h - tw_f), -np.radians(TWIST_CAP), np.radians(TWIST_CAP))
        rf = qaxis(np.broadcast_to(axis, (len(beta), 3)), beta)
        qf2 = qmul(qf, rf)
        qh2 = qmul(qconj(rf), qh)
        for q in (qf2, qh2):  # keep the keys' sign continuous for the lerp
            for k in range(1, len(q)):
                if q[k] @ q[k - 1] < 0:
                    q[k] = -q[k]
        put(bin_, fat, fst, qf2, fdt)
        put(bin_, hat, hst, qh2, hdt)
        out[anim["name"]] = (
            float(np.degrees(np.abs(twist_first(qh, axis)).max())),
            float(np.degrees(np.abs(twist_first(qh2, axis)).max())),
            float(np.degrees(np.abs(twist_first(qf2, axis)).max())),
            float(np.degrees(np.abs(twist_first(qf, axis)).max())),
        )
    return out


def main(args):
    checked = "--i-checked-renders" in args
    args = [a for a in args if a != "--i-checked-renders"]
    who, src, dst = args[:3]
    if re.search(r"(^|/)art/wardens/([^/]+)/\2\.glb$", os.path.abspath(dst)) and not checked:
        sys.exit("glb_arm_refit: refusing to write a shipped Hunter glb (%s) without --i-checked-renders" % dst)
    sp = SPECS[who]
    j, bin_ = glb_add_clips.read(src)
    names = [j["nodes"][k]["name"] for k in j["skins"][0]["joints"]]
    rep = refit(j, bin_, sp, names)
    for k, v in rep.items():
        print("glb_arm_refit %s: %s" % (k, v))
    rk = rekey(j, bin_, sp["side"])
    for clip, (b, a, e, e0) in sorted(rk.items()):
        print("glb_arm_refit roll %-12s wrist %5.1f -> %5.1f  elbow %5.1f -> %5.1f" % (clip, b, a, e0, e))
    glb_add_clips.write(dst, j, bin_)
    print("glb_arm_refit wrote", dst)


if __name__ == "__main__":
    main(sys.argv[1:])
