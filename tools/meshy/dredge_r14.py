"""Grimble (dredge) native r14 stages, run on the r13 glb (docs/art/wardens/MESHY_NATIVE.md).

  python3 tools/meshy/dredge_r14.py OUT.obj IN_R13.glb --shell MATERIAL SEAL INSET VOXEL [FLOOR_Y|- [YMAX]]   # a watertight voxel shell inside that part (skin-native, skin-goo, pack-meshy; m)
  then native_hunters/body_underlay.py smooths and decimates it
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --coins 1   # r14: the head coins as separate discs in stacks
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --feet Y,K   # ink room x K below Y (m)
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --straps 1   # r14 straps: thin ribbons on the skin's own surface
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --ball X,Y,Z,SCALE,YAW   # r16: the contract's junk ball rigid on Spine02 at that centre (m)
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --trim-pack Y   # drop the pack below Y (m, rest pose) and its shards
  python3 tools/meshy/dredge_r14.py OUT.glb IN_R13.glb --skin-native S.obj --skin-native+foot F.obj --skin-goo G.obj --pack-meshy P.obj   # the stages (shells from native_hunters/body_underlay.py)

- underlay shells: a closed shell just inside the skin, the goo and the pack, weighted like the nearest vertex: where Meshy's
  surface has a crack (thigh, goo shoulder, pack bottom) the game now sees the part's colour, not the black ink hull behind it.
Needs numpy and scipy (the venv).
"""

import io
import sys

import dredge_post as dp
import dredge_reskin as rs
import native_pack as n
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree


def read_obj(path):
    v, f = [], []
    for line in open(path):
        t = line.split()
        if t and t[0] == "v":
            v.append([float(x) for x in t[1:4]])
        elif t and t[0] == "f":
            f.append([int(x.split("/")[0]) - 1 for x in t[1:4]])
    return np.array(v, np.float32), np.array(f, np.int64)


def surface_points(pos, faces, step):
    """Points on the triangles, at most about `step` apart (barycentric lattice per triangle)."""
    tri = pos[faces]
    edge = np.max([np.linalg.norm(tri[:, i] - tri[:, (i + 1) % 3], axis=1) for i in range(3)], axis=0)
    div = np.minimum(np.ceil(edge / step).astype(int), 40)
    pts = []
    for k in np.unique(div):
        t = tri[div == k]
        ij = np.array([(i, j) for i in range(k + 1) for j in range(k + 1 - i)], np.float32) / max(k, 1)
        w = np.stack([1 - ij.sum(1), ij[:, 0], ij[:, 1]], 1)
        pts.append(np.einsum("tvc,wv->twc", t, w).reshape(-1, 3))
    return np.concatenate(pts)


def joints_weights(js, b, attrs):
    """(joints (N, 4), weights (N, 4)) of a primitive's attributes."""
    ja = js["accessors"][attrs["JOINTS_0"]]
    joints = np.frombuffer(
        n.view_bytes(js, b, ja["bufferView"]),
        np.uint8 if ja["componentType"] == 5121 else np.uint16,
        ja["count"] * 4,
        ja.get("byteOffset", 0),
    ).reshape(-1, 4)
    return joints, n.floats(js, b, attrs["WEIGHTS_0"])


def part_prim(js, name):
    """The first primitive whose material is called `name` (the shells' own are marked extras.under and skipped)."""
    for p in js["meshes"][0]["primitives"]:
        m = js["materials"][p["material"]]
        if m["name"] == name and not m.get("extras", {}).get("under"):
            return p
    raise KeyError(name)


def shell_obj(path, glb, part, seal, inset, vox, floor_y=None, y_max=None):
    """A watertight voxel shell `inset` m inside the part's surface (rest pose), written as an OBJ of voxel faces. Cracks up to
    2 x `seal` wide are closed first (dilate by seal, fill, erode by seal + inset): a soup that is not watertight has no
    usable inside for Blender's remesh."""
    rig = rs.Rig(glb)
    prim = part_prim(rig.js, part)
    pos = n.floats(rig.js, rig.b, prim["attributes"]["POSITION"])
    faces = dp.prim_faces(rig.js, rig.b, prim)
    if y_max is not None:  # only the part below y_max (the feet get a finer shell than the body)
        faces = faces[pos[faces].mean(1)[:, 1] < y_max]
    pts = surface_points(pos, faces, vox / 2)
    if (
        floor_y is not None
    ):  # a trimmed part is open there: a plate over the section just above the cut closes it before the fill
        sec = pts[(pts[:, 1] >= floor_y) & (pts[:, 1] < floor_y + 0.12)][:, [0, 2]]
        lo2, st = sec.min(0), vox / 2
        grid = np.zeros(tuple(np.ceil((sec.max(0) - lo2) / st).astype(int) + 1), bool)
        grid[tuple(((sec - lo2) / st).astype(int).T)] = True
        grid = ndimage.binary_fill_holes(ndimage.binary_closing(grid, iterations=int(0.03 / st)))
        xz = np.argwhere(grid) * st + lo2
        pts = np.concatenate([pts, np.stack([xz[:, 0], np.full(len(xz), floor_y), xz[:, 1]], 1).astype(np.float32)])
    lo = pts.min(0) - (seal + inset + 4 * vox)
    shape = tuple((np.ceil((pts.max(0) + (seal + inset + 4 * vox) - lo) / vox)).astype(int))
    occ = np.zeros(shape, bool)
    occ[tuple(((pts - lo) / vox).astype(int).T)] = True
    solid = ndimage.binary_fill_holes(ndimage.distance_transform_edt(~occ) <= seal / vox)
    core = ndimage.distance_transform_edt(solid) > (seal + inset) / vox
    verts, quads, idx = [], [], {}
    for axis in range(3):
        for sgn in (1, -1):
            nb = np.roll(core, -sgn, axis=axis)
            edge = np.argwhere(core & ~nb)
            for c in edge:
                corners = []
                for da, db in ((0, 0), (1, 0), (1, 1), (0, 1)):
                    q = c.copy()
                    q[axis] += 1 if sgn > 0 else 0
                    q[(axis + 1) % 3] += da
                    q[(axis + 2) % 3] += db
                    k = tuple(q)
                    if k not in idx:
                        idx[k] = len(verts)
                        verts.append(lo + np.array(k) * vox)
                    corners.append(idx[k])
                quads.append(corners if sgn > 0 else corners[::-1])
    with open(path, "w") as fh:
        fh.writelines("v %f %f %f\n" % tuple(v) for v in verts)
        fh.writelines("f %d %d %d %d\n" % tuple(np.array(q) + 1) for q in quads)
    return "%s shell: %d voxel faces, core %d voxels, sealed %d, surface %d" % (
        part,
        len(quads),
        int(core.sum()),
        int(solid.sum()),
        int(occ.sum()),
    )


def trim_pack(js, b, out, rig, y_cut):
    """Drops the pack's ragged bottom: triangles with a vertex below y_cut (rest pose) and the loose shards that leaves
    (islands under 100 triangles). What Meshy's decimation left down there was a torn, sparse corner you could see through."""
    prim = part_prim(js, "pack-meshy")
    pos = n.floats(js, b, prim["attributes"]["POSITION"])
    f = dp.prim_faces(js, b, prim)
    f = f[pos[f][:, :, 1].min(1) >= y_cut]
    size = np.bincount(dp.island_labels(pos, f))
    f = f[size[dp.island_labels(pos, f)] >= 100].astype(np.uint32)
    js["accessors"].append(
        {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
    )
    prim["indices"] = len(js["accessors"]) - 1
    return "%d pack triangles left" % len(f)


STRAP_X, STRAP_W, STRAP_LIFT, STRAP_K = 0.17, 0.06, 0.006, 40  # K: skin vertices whose weights a row averages
STRAP_CORE = np.array(
    [1.5, -0.1]
)  # y, z: a point inside the torso the over-the-shoulder rays leave from (sagittal plane)
STRAP_ARC = range(
    130, -1, -10
)  # degrees from +z towards +y: from the back of the shoulder, over the crest, to the chest
STRAP_DOWN = np.arange(1.46, 1.3, -0.04)  # y of the rays straight at the chest below the arc


def leather_image(w=96, h=384):
    """A strap's leather: brown with noise, dark edges, a row of pale stitches along each side. u across, v along."""
    rng = np.random.default_rng(14)
    px = np.zeros((h, w, 3), np.float32)
    px[:] = np.array([0.17, 0.085, 0.04]) * 255
    px *= (1 + 0.12 * ndimage.gaussian_filter(rng.standard_normal((h, w)), 1.2))[..., None]
    x = np.arange(w)[None, :] / (w - 1)
    px *= (0.55 + 0.45 * np.clip(np.minimum(x, 1 - x) / 0.12, 0, 1))[..., None]
    stitch = (np.abs(np.minimum(x, 1 - x) - 0.2) < 0.025) & ((np.arange(h)[:, None] // 10) % 2 == 0)
    px[stitch] = np.array([0.85, 0.7, 0.45]) * 255
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))


CONTRACT = "art/wardens/dredge/dredge.glb"  # the contract model (repo root): the junk ball comes from it
COIN_R, COIN_T, COIN_SIDES = 0.03, 0.009, 14  # m: coin radius, thickness, polygon sides of a disc
COIN_CAP = (np.array([0.0, 0.135]), np.array([0.15, 0.15]))  # x, z centre and semi-axes of the head's coin region


def coin_image(size=256):
    """Left half: a coin's face (gold, raised rim, embossed ring and centre); right half: its edge (darker gold, ridges)."""
    yy, xx = np.mgrid[0:size, 0:size].astype(np.float32)
    px = np.zeros((size, size, 3), np.float32)
    r = np.hypot(xx - size / 4, yy - size / 2) / (size / 2.1)
    face = np.array([200, 138, 30], np.float32)
    px[:] = face
    px[:, : size // 2] *= np.clip(1.15 - 0.45 * r, 0.5, 1.1)[:, : size // 2, None]
    ring = (np.abs(r - 0.78) < 0.05) | (np.abs(r - 0.28) < 0.12)
    px[:, : size // 2][ring[:, : size // 2]] = np.array([112, 70, 14], np.float32)
    px[:, : size // 2][(r > 0.93)[:, : size // 2]] = np.array([236, 178, 60], np.float32)
    px[:, size // 2 :] = (
        np.array([140, 92, 20], np.float32) * (0.85 + 0.15 * np.sin(xx[:, size // 2 :] * 1.1))[..., None]
    )
    return Image.fromarray(np.clip(px, 0, 255).astype(np.uint8))


def coin_mesh(c, axis, rot, rad):
    """One disc: centre c, unit axis, rot turn about it, radius rad: (positions, normals, uvs, triangles)."""
    u = np.cross(axis, [1.0, 0.0, 0.0] if abs(axis[0]) < 0.9 else [0.0, 0.0, 1.0])
    u /= np.linalg.norm(u)
    v = np.cross(axis, u)
    ang = np.linspace(0, 2 * np.pi, COIN_SIDES, endpoint=False) + rot
    ring = np.cos(ang)[:, None] * u + np.sin(ang)[:, None] * v
    top, bot = c + axis * COIN_T / 2, c - axis * COIN_T / 2
    P, N, UV, F = [], [], [], []
    for centre, nrm in ((top, axis), (bot, -axis)):  # faces: a fan round a centre vertex
        base = len(P)
        P += [centre] + [centre + rad * r_ for r_ in ring]
        N += [nrm] * (COIN_SIDES + 1)
        UV += [[0.25, 0.5]] + [[0.25 + 0.23 * np.cos(a), 0.5 + 0.46 * np.sin(a)] for a in ang]
        for i in range(COIN_SIDES):
            a, b_ = base + 1 + i, base + 1 + (i + 1) % COIN_SIDES
            F.append((base, a, b_) if nrm is axis else (base, b_, a))
    base = len(P)  # the edge: two rings, normals out
    for i, r_ in enumerate(ring):
        for centre in (top, bot):
            P.append(centre + rad * r_)
            N.append(r_)
            UV.append([0.52 + 0.46 * i / COIN_SIDES, 0.1 if centre is top else 0.9])
    for i in range(COIN_SIDES):
        a0, a1 = base + 2 * i, base + 2 * ((i + 1) % COIN_SIDES)
        F += [(a0, a0 + 1, a1), (a1, a0 + 1, a1 + 1)]
    return np.array(P), np.array(N), np.array(UV), np.array(F)


def add_coin_stacks(js, b, out, rig, seed=14):
    """r14: the head's coins as real, separate coin discs in short leaning stacks sitting on the skull (the Meshy pile came
    out as one fuzzy gold patch): stacks of 2-5 coins on a jittered grid inside COIN_CAP, axes along the skull's normal."""
    rng = np.random.default_rng(seed)
    old = part_prim(js, "brass-coin")
    oat = old["attributes"]
    opos = n.floats(js, b, oat["POSITION"])
    oj, ow = joints_weights(js, b, oat)
    skin = part_prim(js, "skin-native")
    sp = n.floats(js, b, skin["attributes"]["POSITION"])
    tri = sp[dp.prim_faces(js, b, skin)]
    tri = tri[(tri.mean(1)[:, 1] > 1.6) & (np.abs(tri.mean(1)[:, 0]) < 0.3)]

    def height(x, z):
        t = first_hit(tri, np.array([x, 2.4, z]), np.array([0.0, -1.0, 0.0]))
        return None if t is None else 2.4 - t

    P, N, UV, F = [], [], [], []
    cen, semi = COIN_CAP
    step = 0.052
    for gx in np.arange(-semi[0], semi[0] + 1e-6, step):
        for gz in np.arange(-semi[1], semi[1] + 1e-6, step):
            x, z = cen[0] + gx + rng.uniform(-0.012, 0.012), cen[1] + gz + rng.uniform(-0.012, 0.012)
            if ((x - cen[0]) / semi[0]) ** 2 + ((z - cen[1]) / semi[1]) ** 2 > 1:
                continue
            h = [height(x, z), height(x + 0.01, z), height(x, z + 0.01)]
            if None in h:
                continue
            nrm = np.array([-(h[1] - h[0]) / 0.01, 1.0, -(h[2] - h[0]) / 0.01])
            nrm /= np.linalg.norm(nrm)
            for k in range(rng.integers(2, 6)):
                tilt = rng.normal(0, 0.12, 3)
                axis = nrm + tilt
                axis /= np.linalg.norm(axis)
                c = np.array([x, h[0], z]) + nrm * (COIN_T * (k + 0.5) - 0.002) + rng.normal(0, 0.003, 3)
                p, nm, uv, f = coin_mesh(c, axis, rng.uniform(0, 6.28), COIN_R * rng.uniform(0.9, 1.1))
                F += (f + len(P)).tolist()
                P += p.tolist()
                N += nm.tolist()
                UV += uv.tolist()
    P, N, UV, F = (np.array(a, np.float32) for a in (P, N, UV, F))
    near = cKDTree(opos).query(P)[1]
    buf = io.BytesIO()
    coin_image().save(buf, "JPEG", quality=92)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append({"source": len(js["images"]) - 1})
    mat = js["materials"][old["material"]]
    mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": len(js["textures"]) - 1}
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "TEXCOORD_0": out.add_floats(UV, "VEC2"),
        "WEIGHTS_0": out.add_floats(ow[near], "VEC4"),
    }
    if "COLOR_0" in oat:
        attrs["COLOR_0"] = out.add_floats(np.ones((len(P), 4), np.float32), "VEC4")
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(oj[near].astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(P),
            "type": "VEC4",
        }
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    f = F.astype(np.uint32)
    js["accessors"].append(
        {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
    )
    old["attributes"], old["indices"] = attrs, len(js["accessors"]) - 1
    return "%d coin triangles" % len(F)


def add_ball(js, b, out, rig, spec):
    """r16: Grimble's junk ball, the contract dredge.glb's own (the triangles its `ball` bone carries, same textures), rigid
    on Spine02 so it rides the pack. spec = "x,y,z,scale,yaw": the ball's centre in this glb (m), the contract's size x scale, a turn about up (deg)."""
    x, y, z, k, yaw = (float(v) for v in spec.split(","))
    c_, s_ = np.cos(np.radians(yaw)), np.sin(np.radians(yaw))
    turn = np.array([[c_, 0, s_], [0, 1, 0], [-s_, 0, c_]], np.float32)
    cj, cb = n.load(CONTRACT)
    names = [cj["nodes"][i]["name"] for i in cj["skins"][0]["joints"]]
    ball = names.index("ball")
    spine = [js["nodes"][i]["name"] for i in js["skins"][0]["joints"]].index("Spine02")
    centre = None
    info = []
    for p in cj["meshes"][0]["primitives"]:
        at = p["attributes"]
        pos = n.floats(cj, cb, at["POSITION"])
        jt, wt = joints_weights(cj, cb, at)
        mine = jt[np.arange(len(jt)), wt.argmax(1)] == ball
        f = dp.prim_faces(cj, cb, p)
        f = f[mine[f].all(1)]
        if not len(f):
            continue
        used, inv = np.unique(f, return_inverse=True)
        P, N, UV = pos[used], n.floats(cj, cb, at["NORMAL"])[used], n.floats(cj, cb, at["TEXCOORD_0"])[used]
        if centre is None:
            centre = (P.min(0) + P.max(0)) / 2
        P = (P - centre) @ turn.T * k + np.array([x, y, z], np.float32)
        N = N @ turn.T
        mat = dict(cj["materials"][p["material"]])
        tex = cj["textures"][mat["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
        img = cj["images"][tex["source"]]
        js["images"].append(
            {"bufferView": out.add_view(bytes(n.view_bytes(cj, cb, img["bufferView"]))), "mimeType": img["mimeType"]}
        )
        js["textures"].append({"source": len(js["images"]) - 1})
        mat["name"] = "metal-ball" if "metal" in mat["name"] else mat["name"].replace("atlas", "ball")
        mat["pbrMetallicRoughness"] = dict(
            mat["pbrMetallicRoughness"], baseColorTexture={"index": len(js["textures"]) - 1}
        )
        js["materials"].append(mat)
        w = np.zeros((len(P), 4), np.float32)
        w[:, 0] = 1.0
        attrs = {
            "POSITION": out.add_floats(P.astype(np.float32), "VEC3"),
            "NORMAL": out.add_floats(N, "VEC3"),
            "TEXCOORD_0": out.add_floats(UV, "VEC2"),
            "WEIGHTS_0": out.add_floats(w, "VEC4"),
            "COLOR_0": out.add_floats(np.ones((len(P), 4), np.float32), "VEC4"),
        }
        js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
        j = np.zeros((len(P), 4), np.uint16)
        j[:, 0] = spine
        js["accessors"].append(
            {"bufferView": out.add_view(j.tobytes()), "componentType": 5123, "count": len(P), "type": "VEC4"}
        )
        attrs["JOINTS_0"] = len(js["accessors"]) - 1
        idx = inv.reshape(-1).astype(np.uint32)
        js["accessors"].append(
            {"bufferView": out.add_view(idx.tobytes()), "componentType": 5125, "count": int(idx.size), "type": "SCALAR"}
        )
        js["meshes"][0]["primitives"].append(
            {"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1}
        )
        info.append("%s %d tris" % (mat["name"], len(f)))
    return "; ".join(info)


def first_hit(tri, o, d):
    """Distance from o along d to the nearest triangle of tri (a (T, 3, 3) array) past 2 cm; None for no hit."""
    e1, e2 = tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0]
    h = np.cross(d, e2)
    a = (e1 * h).sum(1)
    ok = np.abs(a) > 1e-9
    ia = np.where(ok, 1 / np.where(ok, a, 1), 0)
    s = o - tri[:, 0]
    q = np.cross(s, e1)
    u, v, t = ia * (s * h).sum(1), ia * (q * d).sum(1), ia * (e2 * q).sum(1)
    t = t[ok & (u >= 0) & (v >= 0) & (u + v <= 1) & (t > 0.02)]
    return t.min() if len(t) else None


def strap_rays():
    """(origin y, z; direction y, z) of the rays the ribbon sits on, in order from the back to the belt."""
    rays = [(STRAP_CORE, np.array([np.sin(np.radians(a)), np.cos(np.radians(a))])) for a in STRAP_ARC]
    return rays + [(np.array([y, STRAP_CORE[1] - 0.05]), np.array([0.0, 1.0])) for y in STRAP_DOWN]


def add_straps(js, b, out, rig):
    """r14: the two shoulder straps follow the skin: every point of the ribbon (three across) is the first hit of a ray from
    inside the torso, STRAP_LIFT off the surface, so the ribbon takes the chest's curve. Thin, weighted like the nearest skin vertex."""
    skin = part_prim(js, "skin-native")
    sp = n.floats(js, b, skin["attributes"]["POSITION"])
    tri = sp[dp.prim_faces(js, b, skin)]
    tri = tri[(np.abs(tri.mean(1)[:, 0]) < 0.45) & (tri.mean(1)[:, 1] > 1.0)]
    P, N, F, UV = [], [], [], []
    for side in (-1, 1):
        base, run = len(P), 0.0
        for o, d in strap_rays():
            for dx in (-STRAP_W / 2, 0.0, STRAP_W / 2):
                x = side * STRAP_X + dx
                t = first_hit(tri, np.array([x, o[0], o[1]]), np.array([0.0, d[0], d[1]]))
                if t is None:
                    t = 0.2
                P.append([x, o[0] + d[0] * (t + STRAP_LIFT), o[1] + d[1] * (t + STRAP_LIFT)])
                N.append([0.0, d[0], d[1]])
                UV.append([(dx / STRAP_W) + 0.5, run / STRAP_W / 4])
            run += np.linalg.norm(np.array(P[-1][1:]) - np.array(P[-4][1:])) if len(P) - base > 3 else 0.0
        rows = (len(P) - base) // 3
        for i in range(rows - 1):
            for j in range(2):
                a0, a1, b0, b1 = (
                    base + 3 * i + j,
                    base + 3 * i + j + 1,
                    base + 3 * (i + 1) + j,
                    base + 3 * (i + 1) + j + 1,
                )
                F += [(a0, b1, a1), (a0, b0, b1)]
    P, N, F = np.array(P, np.float32), np.array(N, np.float32), np.array(F, np.uint32)
    sj, sw = joints_weights(js, b, skin["attributes"])  # the strap moves with the skin under it, not with the spine
    ids = np.unique(dp.prim_faces(js, b, skin))
    mid = P[
        1::3
    ]  # a row of three shares the weights round its middle point: the ribbon cannot tear across or kink along
    near = ids[cKDTree(sp[ids]).query(mid, k=STRAP_K)[1]]
    dn = rs.dense(sj[ids], sw[ids], len(rig.names))
    pos_in = {v: i for i, v in enumerate(ids)}
    rows = np.array([[pos_in[v] for v in r_] for r_ in near])
    jn, wt = rs.top4(dn[rows].mean(1))
    jn, wt = jn.repeat(3, axis=0), wt.repeat(3, axis=0)
    prims = js["meshes"][0]["primitives"]
    prims[:] = [p for p in prims if js["materials"][p["material"]]["name"] != "strap-leather"]
    buf = io.BytesIO()
    leather_image().save(buf, "JPEG", quality=92)
    js["images"].append({"bufferView": out.add_view(buf.getvalue()), "mimeType": "image/jpeg"})
    js["textures"].append({"source": len(js["images"]) - 1})
    js["materials"].append(
        {
            "name": "strap-leather",
            "doubleSided": True,
            "pbrMetallicRoughness": {
                "baseColorTexture": {"index": len(js["textures"]) - 1},
                "metallicFactor": 0.0,
                "roughnessFactor": 0.8,
            },
        }
    )
    attrs = {
        "POSITION": out.add_floats(P, "VEC3"),
        "NORMAL": out.add_floats(N, "VEC3"),
        "WEIGHTS_0": out.add_floats(wt, "VEC4"),
        "TEXCOORD_0": out.add_floats(np.array(UV, np.float32), "VEC2"),
    }
    js["accessors"][attrs["POSITION"]].update(min=P.min(0).tolist(), max=P.max(0).tolist())
    js["accessors"].append(
        {
            "bufferView": out.add_view(jn.astype(np.uint16).tobytes()),
            "componentType": 5123,
            "count": len(P),
            "type": "VEC4",
        }
    )
    attrs["JOINTS_0"] = len(js["accessors"]) - 1
    js["accessors"].append(
        {"bufferView": out.add_view(F.tobytes()), "componentType": 5125, "count": int(F.size), "type": "SCALAR"}
    )
    prims.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
    return "%d strap triangles" % len(F)


def soften_feet(js, b, out, rig, y_max, k):
    """The ink hull's room (COLOR_0 alpha, shared by skin and goo) times k for vertices below y_max: between the toes the
    hulls of neighbouring toes showed through as black flecks; the sole and toe edges keep a thinner line."""
    at = part_prim(js, "skin-native")["attributes"]
    pos, col = n.floats(js, b, at["POSITION"]), n.floats(js, b, at["COLOR_0"])
    low = pos[:, 1] < y_max
    col[low, 3] *= k
    acc = out.add_floats(col, "VEC4")
    for p in js["meshes"][0]["primitives"]:
        if p["attributes"].get("COLOR_0") == at["COLOR_0"]:
            p["attributes"]["COLOR_0"] = acc
    return "%d vertices softened" % int(low.sum())


def vertex_normals(p, f):
    fn = np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]])
    nm = np.zeros_like(p)
    for k in range(3):
        np.add.at(nm, f[:, k], fn)
    return (nm / np.maximum(np.linalg.norm(nm, axis=1, keepdims=True), 1e-9)).astype(np.float32)


def add_body_underlay(js, b, out, rig, under_paths):
    """under_paths: [(material name, shell obj)]. Each shell is drawn with its part's own material (same slot, same atlas,
    no normal map) and takes joints, weights and ink mask from the nearest vertex of its part; every triangle takes one UV
    (the nearest vertex's at its centre), so a seam cannot smear. A shell triangle that shows through a crack reads as the
    part, not as the ink hull."""
    prims = js["meshes"][0]["primitives"]
    prims[:] = [p for p in prims if not js["materials"][p["material"]].get("extras", {}).get("under")]
    info = []
    for key, path in under_paths:
        name = key.split("+")[0]  # "skin-native+foot": a second shell for the same part
        src_prim = part_prim(js, name)
        at0 = src_prim["attributes"]
        pos, uv = n.floats(js, b, at0["POSITION"]), n.floats(js, b, at0["TEXCOORD_0"])
        joints, weights = joints_weights(js, b, at0)
        ids = np.unique(dp.prim_faces(js, b, src_prim))
        up, uf = read_obj(path)
        near = cKDTree(pos[ids])
        tri_src = ids[near.query(up[uf].mean(1))[1]]  # the vertex each triangle copies its UV from
        flat = up[uf].reshape(-1, 3)
        src = ids[near.query(flat)[1]]
        mat = {k: v for k, v in js["materials"][src_prim["material"]].items() if k != "normalTexture"}
        mat["pbrMetallicRoughness"] = {**mat["pbrMetallicRoughness"], "metallicFactor": 0.0, "roughnessFactor": 0.9}
        mat["pbrMetallicRoughness"].pop("metallicRoughnessTexture", None)
        mat["extras"] = {"under": True}
        js["materials"].append(mat)
        attrs = {
            "POSITION": out.add_floats(flat, "VEC3"),
            "NORMAL": out.add_floats(vertex_normals(up, uf)[uf].reshape(-1, 3), "VEC3"),
            "TEXCOORD_0": out.add_floats(np.repeat(uv[tri_src], 3, axis=0), "VEC2"),
            "WEIGHTS_0": out.add_floats(weights[src], "VEC4"),
        }
        if "COLOR_0" in at0:
            attrs["COLOR_0"] = out.add_floats(n.floats(js, b, at0["COLOR_0"])[src], "VEC4")
        js["accessors"][attrs["POSITION"]].update(min=flat.min(0).tolist(), max=flat.max(0).tolist())
        js["accessors"].append(
            {
                "bufferView": out.add_view(joints[src].astype(np.uint16).tobytes()),
                "componentType": 5123,
                "count": len(flat),
                "type": "VEC4",
            }
        )
        attrs["JOINTS_0"] = len(js["accessors"]) - 1
        f = np.arange(len(flat), dtype=np.uint32)
        js["accessors"].append(
            {"bufferView": out.add_view(f.tobytes()), "componentType": 5125, "count": int(f.size), "type": "SCALAR"}
        )
        prims.append({"attributes": attrs, "indices": len(js["accessors"]) - 1, "material": len(js["materials"]) - 1})
        info.append("%s shell %d tris" % (name, len(uf)))
    return "; ".join(info)


if __name__ == "__main__":
    out_path, in_path = sys.argv[1], sys.argv[2]
    if sys.argv[3] == "--shell":  # OUT.obj IN.glb --shell PART SEAL INSET VOX
        print(shell_obj(out_path, in_path, sys.argv[4], *(None if x == "-" else float(x) for x in sys.argv[5:10])))
        sys.exit()
    opts = dict(zip(sys.argv[3::2], sys.argv[4::2]))
    stages = []
    if "--coins" in opts:
        stages.append(("coin stacks", add_coin_stacks))
    if "--feet" in opts:  # Y,K
        y, k = map(float, opts["--feet"].split(","))
        stages.append(("feet ink", lambda js, b, out, rig: soften_feet(js, b, out, rig, y, k)))
    if "--straps" in opts:
        stages.append(("straps", add_straps))
    if "--ball" in opts:  # X,Y,Z,SCALE,YAW
        stages.append(("junk ball", lambda js, b, out, rig: add_ball(js, b, out, rig, opts["--ball"])))
    if "--trim-pack" in opts:
        stages.append(("pack trim", lambda js, b, out, rig: trim_pack(js, b, out, rig, float(opts["--trim-pack"]))))
    shells = [(k[2:], v) for k, v in opts.items() if k.startswith("--") and v.endswith(".obj")]
    if shells:  # --skin-native S.obj --skin-goo G.obj --pack-meshy P.obj
        stages.append(("underlay shells", lambda js, b, out, rig: add_body_underlay(js, b, out, rig, shells)))
    dp.rebuild_stages(out_path, in_path, stages)
