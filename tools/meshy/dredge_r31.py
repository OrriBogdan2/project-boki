"""Grimble (dredge) native model, round 31 (plan: gens/hunter-round-1124/grimble/PLAN-1124o.md section 14).

  dredge_r31.py --pack-export OUT.glb IN.glb [--turn]     the pack primitives (material pack-meshy) as one untextured
                                                          mesh for a Meshy retexture (--original-uv); --turn spins it
                                                          180 deg about y so the pack's back (the side the game camera
                                                          sees) faces Meshy's front (+z)
  dredge_r31.py --pack-tex OUT.glb IN.glb MESHY.glb       the retextured pack's base colour (same UVs) in place of the
                                                          pack image (only pack-meshy uses it); nothing else changes
  dredge_r31.py --backing OUT.glb IN.glb [--ring N]       r32: a reversed-winding backing under every fold zone of the
                                                          skin/dome/goo (see backing()), ink off on the folds
  dredge_r31.py --strap-sink OUT.glb IN.glb [--sink M] [--sink-k N]   r37: strap band ends sink under the skin
  dredge_r31.py --relax OUT.glb IN.glb [--goo] [--knee] [--box B] [--target X] [--passes N]
                                                          skin weights blended toward their neighbours (r28's relax
                                                          loop) only where edges stretch past --target in any clip:
                                                          --goo = the skin-goo primitive (review D1: shards at the goo
                                                          root in Attack, goo stretch 3x live), with each horn rigid except
                                                          its collar (2 rings next to the goo); --knee = the
                                                          skin around both knees (D2: crack under the raised knee at
                                                          jump apex); --box x0,y0,z0,x1,y1,z1 (r34) = skin+dome
                                                          in that rest box (D3: Attack stretch on the back).
                                                          Everything outside the mask keeps its weights.

Why: the game camera looks down on Grimble from behind, so the pack is most of what the player sees, and its Meshy
texture reads near-black/grey with orange specks (review D3, outfit/open_chest 5.5-6.0) against the turnaround's warm
brown wood crates, iron bands and the open gold-filled chest. Visible texture work goes through Meshy (owner rule);
this file only exports the mesh and swaps the image. numpy + PIL.
"""

import argparse
import io
import os
import sys

import numpy as np
from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from dredge_r29 import acc, add_acc, add_view, compact, load, meshy_part, write  # noqa: E402
from dredge_r28 import _report, g, glb_add_clips, skin_relax, weld  # noqa: E402

PACK = "pack-meshy"


def pack_prims(js, mat=PACK):
    return [p for p in js["meshes"][0]["primitives"] if js["materials"][p["material"]]["name"] == mat]


def pack_export(o):
    js, b = load(o.inp)
    P, N, UV, F = [], [], [], []
    for pr in pack_prims(js, o.mat):
        F.append(acc(js, b, pr["indices"]).reshape(-1, 3).astype(np.uint32) + sum(len(q) for q in P))
        P.append(acc(js, b, pr["attributes"]["POSITION"]).astype(np.float32))
        N.append(acc(js, b, pr["attributes"]["NORMAL"]).astype(np.float32))
        UV.append(acc(js, b, pr["attributes"]["TEXCOORD_0"]).astype(np.float32))
    P, N, UV, F = (np.concatenate(x) for x in (P, N, UV, F))
    if o.turn:
        P[:, [0, 2]] *= -1
        N[:, [0, 2]] *= -1
    P -= np.r_[0.0, P[:, 1].min(), 0.0].astype(np.float32)
    out = {
        "asset": {"version": "2.0"},
        "scene": 0,
        "scenes": [{"nodes": [0]}],
        "nodes": [{"mesh": 0}],
        "buffers": [{}],
        "bufferViews": [],
        "accessors": [],
        "materials": [{"name": "pack"}],
        "meshes": [{"primitives": [{"attributes": {}, "indices": 0, "material": 0}]}],
    }
    ob = bytearray()

    def put(arr, ctype, typ, minmax=False):
        a = {"bufferView": add_view(out, ob, arr), "componentType": ctype, "count": len(arr), "type": typ}
        if minmax:
            a["min"], a["max"] = arr.min(0).tolist(), arr.max(0).tolist()
        out["accessors"].append(a)
        return len(out["accessors"]) - 1

    prim = out["meshes"][0]["primitives"][0]
    prim["indices"] = put(F.reshape(-1), 5125, "SCALAR")
    prim["attributes"] = {
        "POSITION": put(P, 5126, "VEC3", True),
        "NORMAL": put(N, 5126, "VEC3"),
        "TEXCOORD_0": put(UV, 5126, "VEC2"),
    }
    ob += b"\0" * (-len(ob) % 4)
    out["buffers"][0]["byteLength"] = len(ob)
    write(o.out, out, ob)
    print("wrote %s: pack %d verts %d tris, uv %s..%s" % (o.out, len(P), len(F), UV.min(0), UV.max(0)))


def pack_tex(o):
    js, b = load(o.inp)
    prims = pack_prims(js, o.mat)
    tex = {js["materials"][p["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"] for p in prims}
    assert len(tex) == 1, "pack prims use more than one texture"
    t = tex.pop()
    users = [
        m for m in js["materials"] if m.get("pbrMetallicRoughness", {}).get("baseColorTexture", {}).get("index") == t
    ]
    assert all(m["name"] == o.mat for m in users), "pack texture shared with another material"
    _, _, _, img = meshy_part(o.meshy)
    old = js["images"][js["textures"][t]["source"]]
    v = js["bufferViews"][old["bufferView"]]
    w = Image.open(io.BytesIO(bytes(b[v.get("byteOffset", 0) : v.get("byteOffset", 0) + v["byteLength"]]))).size[0]
    size = max(w, min(o.size, img.size[0]))
    im = img.resize((size, size), Image.LANCZOS) if img.size[0] != size else img
    jb = io.BytesIO()
    im.save(jb, "JPEG", quality=90)
    js["images"][js["textures"][t]["source"]] = {
        "bufferView": add_view(js, b, np.frombuffer(jb.getvalue(), np.uint8)),
        "mimeType": "image/jpeg",
    }
    b = compact(js, b)
    write(o.out, js, b)
    print("wrote %s: pack image %d px -> %d px from %s" % (o.out, w, size, o.meshy))


COLLAR = 2  # rings of horn vertices next to the plain goo that relax with it (the rest of each horn stays rigid)
KNEE = ((-0.40, 0.38, -0.30), (0.40, 0.78, 0.30))  # rest pose box round both knees (knee joints ~y 0.58), m
RAMP = 0.06  # m: inside the knee box's top and bottom faces the new weights fade in over this


def relax(o):
    j, bin_ = glb_add_clips.read(o.inp)
    skin = j["skins"][0]
    pz, _ = g.poses(j, bin_, skin)
    mats = [j["materials"][p["material"]]["name"] for p in j["meshes"][0]["primitives"]]
    for name, prims in g.skinned(j, bin_).items():
        rest, w, maps = weld(prims, len(skin["joints"]))
        tris = g.triangles(prims, maps)
        s = skin_relax.Skin.of(rest, w, g.edges_of(tris))
        mask = np.zeros(len(rest), bool)
        fade = np.ones(len(rest))
        if o.goo:
            gi = mats.index("skin-goo")
            mask[maps[gi]] = True
            # The horn prim indexes the goo's own vertex buffer, so its vertices are goo vertices with rigid weights
            # (r30). The worst goo stretch (26x, the review's cream shards at the root) is on horn-to-goo edges: the
            # horn's collar (horn vertices within COLLAR rings of a plain goo vertex) relaxes with the goo; the rest of
            # each horn keeps its weights (rigid).
            hv = np.zeros(len(rest), bool)
            hv[np.unique(tris[mats.index("leather-horn")])] = True
            free = mask & ~hv
            for _ in range(COLLAR):
                hit = free[s.edges[:, 0]] | free[s.edges[:, 1]]
                free[s.edges[hit].ravel()] = True
            near = mask & hv & ~free
            mask &= ~near
            print("goo: %d verts relaxable, %d horn verts kept rigid" % (mask.sum(), near.sum()))
        if o.knee:
            lo, hi = map(np.array, KNEE)
            k = ((rest >= lo) & (rest <= hi)).all(1)
            for m, mt in enumerate(mats):  # skin only (not goo, gauntlet, pack)
                if mt not in ("skin-native",):
                    k[maps[m]] = False
            fade = np.where(k, np.clip(np.minimum(rest[:, 1] - lo[1], hi[1] - rest[:, 1]) / RAMP, 0, 1), fade)
            mask |= k
            print("knee: %d verts in box" % k.sum())
        for bx in o.box:  # r34: any rest box (review D3 torso: Attack stretch on the back, which the game camera sees)
            lo, hi = np.array(bx[:3]), np.array(bx[3:])
            k = ((rest >= lo) & (rest <= hi)).all(1)
            for m, mt in enumerate(mats):  # skin + dome only (not goo, horns, gauntlet, pack)
                if mt not in ("skin-native", "skin-native-dome"):
                    k[maps[m]] = False
            edge = np.minimum(rest - lo, hi - rest).min(1)
            fade = np.where(k, np.clip(edge / RAMP, 0, 1), fade)
            mask |= k
            print("box %s: %d verts" % (bx, k.sum()))
        orig = s.w.copy()
        f = (fade * mask)[:, None]
        worst = _report("before " + name, s, pz, mask)
        for it in range(o.passes):
            bad = (worst > o.target) & mask[s.edges].all(1)
            if not bad.any():
                break
            s.relax_once(bad)
            s.w = orig * (1.0 - f) + s.w * f
            s.w /= np.maximum(s.w.sum(1, keepdims=True), 1e-9)
            worst, _ = s.stretch(pz)
        _report("after  %s (%d passes)" % (name, it + 1), s, pz, mask)
        g.store(bin_, prims, s.w, maps, tris)
    glb_add_clips.write(o.out, j, bin_)


# --open only here: the goo-side shoulder, neck and ear (review D1 notches, Attack f80-84); the Meshy skin has ~11.8k open
# edges all over (cuts), and backing/un-inking them everywhere would thin the outline on the whole body. Rest pose, m.
OPEN_BOX = ((-0.60, 1.15, -0.50), (0.05, 1.95, 0.50))
FOLD_MATS = ("skin-native", "skin-native-dome", "skin-goo")  # the skinned body surfaces that fold in clips


def _folds(js, b, pr, pz):
    """Which triangles of primitive pr fold over (face away from where their rest normal goes) in any clip pose."""
    P = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
    J = acc(js, b, pr["attributes"]["JOINTS_0"]).astype(int)
    W = acc(js, b, pr["attributes"]["WEIGHTS_0"]).astype(float)
    W /= np.maximum(W.sum(1, keepdims=True), 1e-9)  # the game sums the 4 slots
    F = acc(js, b, pr["indices"]).reshape(-1, 3).astype(np.int64)
    n0 = np.cross(P[F[:, 1]] - P[F[:, 0]], P[F[:, 2]] - P[F[:, 0]])
    ok = np.linalg.norm(n0, axis=1) > 1e-10
    vh = np.c_[P, np.ones(len(P))]
    flip = np.zeros(len(F), bool)
    for _, M in pz:
        m = np.einsum("nk,nkij->nij", W, M[J])
        p = np.einsum("nij,nj->ni", m[:, :3], vh)
        n1 = np.cross(p[F[:, 1]] - p[F[:, 0]], p[F[:, 2]] - p[F[:, 0]])
        ne = np.einsum("nij,nj->ni", m[:, :3, :3][F].mean(1), n0)
        flip |= ok & ((n1 * ne).sum(1) < 0)
    return F, flip


def _open_verts(js, b, prs, box=True):
    """Per primitive, its vertices on an open edge of the body surface they make together (welded by position, so a
    seam between two primitives or a UV split is not open)."""
    Ps = [acc(js, b, pr["attributes"]["POSITION"]) for pr in prs]
    _, inv = np.unique(np.round(np.concatenate(Ps) / 1e-4).astype(np.int64), axis=0, return_inverse=True)
    inv = inv.ravel()
    off = np.cumsum([0] + [len(P) for P in Ps])
    G = np.concatenate(
        [inv[off[k] + acc(js, b, pr["indices"]).reshape(-1, 3).astype(np.int64)] for k, pr in enumerate(prs)]
    )
    E = np.sort(np.concatenate([G[:, [0, 1]], G[:, [1, 2]], G[:, [2, 0]]]), 1)
    u, c = np.unique(E, axis=0, return_counts=True)
    hot = np.zeros(inv.max() + 1, bool)
    hot[u[c == 1].ravel()] = True
    lo, hi = map(np.array, OPEN_BOX) if box else (np.full(3, -np.inf), np.full(3, np.inf))
    return [hot[inv[off[k] : off[k + 1]]] & ((Ps[k] >= lo) & (Ps[k] <= hi)).all(1) for k in range(len(prs))]


def backing(o):
    """Review D1 (black see-through notches at the goo root, Attack) and D2 (black crescent on the raised knee, jump):
    where the skin folds over in a pose, its triangles turn away from the camera, the toon pass culls them (the game's
    hero shader is cull_back whatever the glb says) and the ink shell (cull_front, grown along the normal) draws its
    dark inside through the hole. Each fold zone (folded triangles + RING rings) gets a backing: the same triangles
    with the winding reversed, in the same material and on the same vertices (weights, UVs, normals), so a folded
    face shows the skin's texture instead of the ink; the backing and the folded originals carry no ink room
    (COLOR.a 0: outline.gdshader discards there; --ink-off: the folded originals too). Unfolded, a backing triangle faces inward and is culled: no change."""
    js, b = glb_add_clips.read(o.inp)
    pz, _ = g.poses(js, b, js["skins"][0])
    prims = js["meshes"][0]["primitives"]
    whole = set(o.whole.split(",")) if o.whole else set()
    todo = [
        (pi, pr)
        for pi, pr in enumerate(prims)
        if "COLOR_0" in pr["attributes"] and js["materials"][pr["material"]]["name"] in set(FOLD_MATS) | whole
    ]
    opn = _open_verts(js, b, [pr for _, pr in todo]) if o.open else [None] * len(todo)
    for (pi, pr), ov in zip(todo, opn):
        mat = js["materials"][pr["material"]]["name"]
        F, flip = _folds(js, b, pr, pz)
        zone = flip.copy() if mat not in whole else np.ones(len(F), bool)
        if ov is not None:
            zone |= ov[F].any(1)  # (--open: a triangle on an open edge: seen from inside through the gap)
        for _ in range(o.ring):
            hot = np.zeros(F.max() + 1, bool)
            hot[F[zone].ravel()] = True
            zone |= hot[F].any(1)
        C = acc(js, b, pr["attributes"]["COLOR_0"]).astype(np.float32)
        Cb = C.copy()
        Cb[:, 3] = 0.0
        Co = C.copy()
        if o.ink_off:
            Co[np.unique(F[flip].ravel()), 3] = 0.0  # the folded originals: no ink shell over the fold
        if ov is not None:
            Co[ov, 3] = 0.0  # (the shell's flap past an open edge)
        pr["attributes"] = dict(pr["attributes"], COLOR_0=add_acc(js, b, Co, 5126, "VEC4"))
        bk = dict(
            pr,
            attributes=dict(pr["attributes"], COLOR_0=add_acc(js, b, Cb, 5126, "VEC4")),
            indices=add_acc(js, b, F[zone][:, [0, 2, 1]].astype(np.uint32).ravel(), 5125, "SCALAR", 34963),
        )
        prims.append(bk)
        print(
            "prim %d %s: %d tris, %d fold in a clip, %s open verts, backing %d"
            % (pi, mat, len(F), flip.sum(), "-" if ov is None else ov.sum(), zone.sum())
        )
    js["buffers"][0]["byteLength"] = len(b)
    glb_add_clips.write(o.out, js, b)


def _qmul(a, b):
    """Quaternion product a*b, glTF order (x, y, z, w), rows broadcast."""
    ax, ay, az, aw = np.moveaxis(np.asarray(a, float), -1, 0)
    bx, by, bz, bw = np.moveaxis(np.asarray(b, float), -1, 0)
    return np.stack(
        [
            aw * bx + ax * bw + ay * bz - az * by,
            aw * by - ax * bz + ay * bw + az * bx,
            aw * bz + ax * by - ay * bx + az * bw,
            aw * bw - ax * bx - ay * by - az * bz,
        ],
        -1,
    )


def abduct(o):
    """r33, review D1 (the thick goo arm's inner edge held 2.4 cm inside the right thigh through the run loop, f0/f20):
    the goo shoulder (Meshy RightArm) turned DEG further out from the body, about the rest pose's forward axis (+z), in
    the named clips only. Key k: q' = Qp^-1 * R * Qp * q, Qp = the parent chain's rest rotation. No mesh or weight
    changes (r29's mesh push made the clips worse)."""
    js, b = glb_add_clips.read(o.inp)
    nodes = js["nodes"]
    bone = next(i for i, n in enumerate(nodes) if n.get("name") == o.bone)
    parent = {c: i for i, n in enumerate(nodes) for c in n.get("children", [])}
    qp, i = np.r_[0.0, 0.0, 0.0, 1.0], bone
    while i in parent:
        i = parent[i]
        qp = _qmul(nodes[i].get("rotation", [0, 0, 0, 1]), qp)
    h = np.radians(-o.abduct) / 2  # (the goo arm hangs on the -x side: out = negative turn about +z)
    q = _qmul(_qmul(qp * np.r_[-1, -1, -1, 1], np.r_[0.0, 0.0, np.sin(h), np.cos(h)]), qp)
    for an in js["animations"]:
        if an["name"] not in o.clips.split(","):
            continue
        for ch in an["channels"]:
            if ch["target"].get("node") == bone and ch["target"]["path"] == "rotation":
                sm = an["samplers"][ch["sampler"]]
                k = _qmul(q, acc(js, b, sm["output"]).astype(float)).astype(np.float32)
                sm["output"] = add_acc(js, b, k, 5126, "VEC4")
                print("%s: %s %d rotation keys turned %.1f deg out" % (an["name"], o.bone, len(k), o.abduct))
    b = compact(js, b)
    js["buffers"][0]["byteLength"] = len(b)
    glb_add_clips.write(o.out, js, b)


PACK_LOW, PACK_BACK = 1.42, -0.34  # m, rest: the pack's base band and its face against Grimble's back


def pack_ink(o):
    """r33, review D2/D4 (black wedge under the pack base in crouch, black square in the pack bottom in Attack): the
    pack prims carry no COLOR_0, so the ink shell runs at full room on the base and the face against the back; seen
    from below or behind its dark back face shows past the edge, and through the open rim the culled inside shows
    the shell. Ink room 0 on the base band (y < PACK_LOW) and the back-facing side (z > PACK_BACK), and a
    reversed-winding backing (same vertices) there and on the open rim, so a gap shows pack wood instead of ink."""
    js, b = glb_add_clips.read(o.inp)
    prims = js["meshes"][0]["primitives"]
    for pi, pr in enumerate(list(prims)):
        if js["materials"][pr["material"]]["name"] != PACK:
            continue
        P = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
        F = acc(js, b, pr["indices"]).reshape(-1, 3).astype(np.int64)
        low = (P[:, 1] < PACK_LOW) | (P[:, 2] > PACK_BACK)
        ov = _open_verts(js, b, [pr], box=False)[0]
        C = np.ones((len(P), 4), np.float32)
        C[low | ov, 3] = 0.0
        pr["attributes"] = dict(pr["attributes"], COLOR_0=add_acc(js, b, C, 5126, "VEC4"))
        zone = (low | ov)[F].any(1)
        Cb = C.copy()
        Cb[:, 3] = 0.0  # (the backing's own shell, coincident with the pack face, would z-fight black)
        prims.append(
            dict(
                pr,
                attributes=dict(pr["attributes"], COLOR_0=add_acc(js, b, Cb, 5126, "VEC4")),
                indices=add_acc(js, b, F[zone][:, [0, 2, 1]].astype(np.uint32).ravel(), 5125, "SCALAR", 34963),
            )
        )
        print(
            "prim %d %s: %d tris, ink off on %d verts (%d open), backing %d"
            % (pi, PACK, len(F), (low | ov).sum(), ov.sum(), zone.sum())
        )
    js["buffers"][0]["byteLength"] = len(b)
    glb_add_clips.write(o.out, js, b)


def seam_weld(o):
    """r36, review D1 (black slit + ragged dark edges on the goo-side shoulder cap, held in Idle/Crouch y270) and D2
    (torn blotches at the goo root, Attack f81-83): the socket dome (skin-native-dome) meets the skin on shared
    positions, but its seam vertices carry other weights (dome: RightShoulder; skin: headfront/Head/RightShoulder), so
    the seam opens in every clip (rest 0; Idle 8 cm, run 10 cm, Attack 27 cm) and the ink shell shows through. The
    r28 weld keys on position AND weights, so the stretch metric never saw it. Fix: each dome seam vertex takes the
    weights of the skin vertex it sits on; dome vertices within --ramp m of the seam fade from those to their own
    (smoothstep). Skin weights are untouched (--skin-too: coincident skin vertices take their group mean). Every prim sharing the dome's weight accessor (its backing) follows."""
    from scipy.spatial import cKDTree

    js, b = glb_add_clips.read(o.inp)
    prims = js["meshes"][0]["primitives"]
    nb = len(js["skins"][0]["joints"])
    names = [js["materials"][p["material"]]["name"] for p in prims]

    def dense(pr):
        J = acc(js, b, pr["attributes"]["JOINTS_0"]).astype(int)
        W = acc(js, b, pr["attributes"]["WEIGHTS_0"]).astype(float)
        D = np.zeros((len(J), nb))
        np.add.at(D, (np.repeat(np.arange(len(J)), J.shape[1]), J.ravel()), W.ravel())
        return D

    from scipy.sparse import coo_matrix
    from scipy.sparse.csgraph import connected_components

    def put(pr, D, done):
        J4 = np.argsort(-D, 1)[:, :4]
        W4 = np.take_along_axis(D, J4, 1)
        W4 /= W4.sum(1, keepdims=True)
        J4[W4 == 0] = 0
        ja = add_acc(js, b, J4.astype(np.uint16), 5123, "VEC4")
        wa = add_acc(js, b, W4.astype(np.float32), 5126, "VEC4")
        done[pr["attributes"]["WEIGHTS_0"]] = (ja, wa)

    to, seen, done = [p for p, n in zip(prims, names) if n == "skin-native"], set(), {}
    SP, SD = [], []
    for pr in to:
        if pr["attributes"]["WEIGHTS_0"] in seen:
            continue  # (a backing: same vertices)
        seen.add(pr["attributes"]["WEIGHTS_0"])
        P = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
        D = dense(pr)
        if o.skin_too:  # coincident skin vertices (UV splits) with other weights tear too: each takes the group mean
            pq = cKDTree(P).query_pairs(2e-4, output_type="ndarray")
            pq = pq[np.abs(D[pq[:, 0]] - D[pq[:, 1]]).sum(1) > 1e-3]
            if len(pq):
                _, lab = connected_components(coo_matrix((np.ones(len(pq)), (pq[:, 0], pq[:, 1])), (len(P), len(P))))
                hit = np.zeros(len(P), bool)
                hit[pq.ravel()] = True
                M = np.zeros((lab.max() + 1, nb))
                np.add.at(M, lab[hit], D[hit])
                M /= np.bincount(lab[hit], minlength=len(M))[:, None].clip(1)
                D[hit] = M[lab[hit]]
                put(pr, D, done)
                print("skin-native: %d coincident verts with split weights -> group mean" % hit.sum())
        SP.append(P)
        SD.append(D)
    SP, SD = np.concatenate(SP), np.concatenate(SD)
    tree = cKDTree(SP)
    for pr, n in zip(prims, names):
        if n != o.seam_mat or pr["attributes"]["WEIGHTS_0"] in done:
            continue
        P = acc(js, b, pr["attributes"]["POSITION"]).astype(float)
        D = dense(pr)
        d, i = tree.query(P)
        seam = d < 2e-4
        Ds = D.copy()
        Ds[seam] = SD[i[seam]]
        dd, k = cKDTree(P[seam]).query(P)
        t = np.clip(dd / o.ramp, 0.0, 1.0)[:, None] if o.ramp > 0 else (dd > 0)[:, None].astype(float)
        t = t * t * (3 - 2 * t)
        N = (1 - t) * Ds[np.where(seam)[0][k]] + t * D
        N[seam] = SD[i[seam]]
        put(pr, N, done)
        print(
            "%s: %d verts, %d on the skin seam, %d in the %.2f m fade"
            % (n, len(P), seam.sum(), (t[:, 0] < 1).sum() - seam.sum(), o.ramp)
        )
    for pr in prims:
        w = pr["attributes"].get("WEIGHTS_0")
        if w in done:
            pr["attributes"] = dict(pr["attributes"], JOINTS_0=done[w][0], WEIGHTS_0=done[w][1])
    b = compact(js, b)
    js["buffers"][0]["byteLength"] = len(b)
    glb_add_clips.write(o.out, js, b)


def strap_sink(o):
    """r37, review (r36 close 4.5): the y270 shoulder shows a pale triangle with a black centre and a black sliver at the
    strap end = the r22 band's square end cap (UVs on the texture's last row, seen edge-on with its ink). Fix: over the
    last --sink-k stations of each band end the band narrows and sinks under the skin along its own normal (smoothstep,
    --sink m at the end), so it ends inside the body and no cap faces the camera. Band layout (dredge_r22.strap_r22):
    per side 8 rings x ns stations (ring 0 = top face, its NORMAL = the skin normal) + 8 cap verts. Weights unchanged."""
    js, b = glb_add_clips.read(o.inp)
    prims = js["meshes"][0]["primitives"]
    pr = next(p for p in prims if js["materials"][p["material"]]["name"] == "strap-leather")
    P = acc(js, b, pr["attributes"]["POSITION"]).astype(float).copy()
    NR = acc(js, b, pr["attributes"]["NORMAL"]).astype(float)
    cut = int(np.nonzero(np.diff(np.sign(P[:, 0])))[0][0]) + 1
    k = o.sink_k
    for base, n in ((0, cut), (cut, len(P) - cut)):
        ns = (n - 8) // 8
        assert 8 * ns + 8 == n, "strap layout changed"
        R = P[base:base + 8 * ns].reshape(8, ns, 3)
        nr = NR[base:base + ns]
        mid = R.mean(0)
        t = np.zeros(ns)
        e = np.clip(1.0 - np.arange(k) / float(k), 0.0, 1.0)
        e = e * e * (3 - 2 * e)
        t[:k] = np.maximum(t[:k], e)
        t[ns - k:] = np.maximum(t[ns - k:], e[::-1])
        R[:] = R - (R - mid) * (0.6 * t)[None, :, None] - (o.sink * t)[None, :, None] * nr[None]
        P[base:base + 8 * ns] = R.reshape(-1, 3)
        caps = P[base + 8 * ns:base + n]
        caps[:4] = R[[0, 1, 4, 5], 0].mean(0)  # caps collapse onto the sunk end point
        caps[4:] = R[[0, 1, 4, 5], -1].mean(0)
        P[base + 8 * ns:base + n] = caps
        print("strap side %d: %d stations, ends sunk %.3f m over %d" % (base > 0, ns, o.sink, k))
    pr["attributes"] = dict(pr["attributes"], POSITION=add_acc(js, b, P.astype(np.float32), 5126, "VEC3", minmax=True))
    b = compact(js, b)
    js["buffers"][0]["byteLength"] = len(b)
    glb_add_clips.write(o.out, js, b)


def main():
    ap = argparse.ArgumentParser()
    grp = ap.add_mutually_exclusive_group(required=True)
    grp.add_argument("--pack-export", action="store_true")
    grp.add_argument("--pack-tex", action="store_true")
    grp.add_argument("--relax", action="store_true")
    grp.add_argument("--backing", action="store_true")
    grp.add_argument("--abduct", type=float, help="r33: deg the goo shoulder turns out in --clips")
    grp.add_argument("--pack-ink", action="store_true", help="r33: no ink + backing on the pack base and open rim")
    grp.add_argument("--seam-weld", action="store_true", help="r36: dome seam takes the skin's weights (D1/D2)")
    grp.add_argument("--strap-sink", action="store_true", help="r37: strap ends sink under the skin (no end cap)")
    ap.add_argument("out")
    ap.add_argument("inp")
    ap.add_argument("meshy", nargs="?")
    ap.add_argument("--turn", action="store_true")
    ap.add_argument("--size", type=int, default=2048, help="pack image size cap (px)")
    ap.add_argument("--goo", action="store_true")
    ap.add_argument("--knee", action="store_true")
    ap.add_argument(
        "--box",
        action="append",
        default=[],
        type=lambda v: [float(x) for x in v.split(",")],
        help="--relax r34: x0,y0,z0,x1,y1,z1 rest box of skin+dome, fade from every face (repeatable)",
    )
    ap.add_argument("--target", type=float, default=3.0, help="x rest length: masked edges over this relax")
    ap.add_argument("--passes", type=int, default=60)
    ap.add_argument("--ink-off", action="store_true", help="--backing: no ink room on the folded originals either")
    ap.add_argument("--whole", default="", help="--backing: materials backed all over (comma list)")
    ap.add_argument("--open", action="store_true", help="--backing: also back triangles on open edges, no ink there")
    ap.add_argument("--ring", type=int, default=1, help="--backing: rings of triangles round each fold")
    ap.add_argument("--mat", default=PACK, help="--pack-export/--pack-tex: the material (r33: metal-fist)")
    ap.add_argument("--clips", default="run", help="--abduct: comma list of clips")
    ap.add_argument("--bone", default="RightArm", help="--abduct: the goo shoulder (Meshy Right = goo side)")
    ap.add_argument("--seam-mat", default="skin-native-dome", help="--seam-weld: the material welded onto skin-native")
    ap.add_argument("--skin-too", action="store_true", help="--seam-weld: coincident skin verts share their weights")
    ap.add_argument("--ramp", type=float, default=0.05, help="--seam-weld: m the new weights fade over into the dome")
    ap.add_argument("--sink", type=float, default=0.02, help="--strap-sink: m the band end goes under the skin")
    ap.add_argument("--sink-k", type=int, default=6, help="--strap-sink: stations the sink fades over")
    o = ap.parse_args()
    stages = (
        ("pack_export", pack_export),
        ("pack_tex", pack_tex),
        ("backing", backing),
        ("pack_ink", pack_ink),
        ("seam_weld", seam_weld),
        ("strap_sink", strap_sink),
    )
    run = next((f for k, f in stages if getattr(o, k)), abduct if o.abduct is not None else relax)
    run(o)


if __name__ == "__main__":
    main()
