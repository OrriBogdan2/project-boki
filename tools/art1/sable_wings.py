"""Sable's moth wings on any rigged Sable body, with no Blender: the two wing chains (spring_wingL/R_0..2 under
"hips"), the alpha-card wings skinned to them and their own small texture. Run it again after every body swap.
Docs: docs/SABLE_WINGS.md. The wings' motion is the game's (WardenGlb.Springs, WardenWings), not baked here.

Run:  python3 tools/art1/sable_wings.py IN.glb [OUT.glb]       (OUT defaults to IN: in place)
      python3 tools/art1/sable_wings.py --extract SRC.glb       (retake the donor wings from a model that has them)

The donor (art/wardens/src/sable_wings.json + sable_wings.jpg) holds the cards and the chain relative to the hips
bone's bind, so the wings land on a new body where the old ones sat. Any earlier card-wing primitive is replaced
(idempotent). It then measures the cards against the body, folded (hanging) and raised (WardenGlb.Springs RAISE,
SPREAD), and if the body pokes through the folded cards more than it does on the donor, it moves each chain's root
back and tips the hanging cards back about it, the least that clears (a fuller coat)."""
import json
import math
import os
import struct
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from glb_add_clips import read, write

DONOR = os.path.join(HERE, "..", "..", "art", "wardens", "src", "sable_wings.json")
TEX = DONOR[:-5] + ".jpg"
MAT = "card-wing"           # the "card" slot (WardenGlb._toon: the alpha-card shader, both sides, no ink)
IMG = "sable_wings"
TEX_W = 768                 # px: the donor texture's width at most (the wings are a hand's width on screen)
RAISE, SPREAD = 2.4, 0.45   # rad: WardenGlb.Springs' raised pose (keep in step with warden_glb.gd)
CELL = 0.03                 # m: the body's depth map cell
SKIN_M = 0.02               # m: how close behind the body's back a card may sit
ROOT_M = 0.08               # m round the chain's root that sits under the coat by design (not counted)
PUSHES = [0.01 * i for i in range(9)]       # m the root may move back (past 8 cm the body needs a look)
TILTS = [0.05 * i for i in range(11)]       # rad the hanging cards may tip back about the root (past ~30 degrees
                                            # they stop reading as folded)
TILT_COST = 0.1             # m of root push one radian of tip-back is worth (the root moves least)

CT = {5126: ("f", 4), 5123: ("H", 2), 5121: ("B", 1), 5125: ("I", 4)}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def acc(j, b, i):
    a = j["accessors"][i]
    bv = j["bufferViews"][a["bufferView"]]
    f, sz = CT[a["componentType"]]
    n = NC[a["type"]]
    st = bv.get("byteStride", sz * n)
    o = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
    out = [struct.unpack_from("<" + f * n, b, o + k * st) for k in range(a["count"])]
    if a.get("normalized") and f != "f":
        out = [tuple(x / (255.0 if f == "B" else 65535.0) for x in v) for v in out]
    return out


def put(j, b, rows, ctype, typ, target=None, minmax=False):
    """Appends rows as a new accessor (tightly packed) and returns its index."""
    f, sz = CT[ctype]
    b += b"\0" * (-len(b) % 4)
    off = len(b)
    for r in rows:
        b += struct.pack("<" + f * NC[typ], *r)
    bv = {"buffer": 0, "byteOffset": off, "byteLength": len(b) - off}
    if target:
        bv["target"] = target
    j["bufferViews"].append(bv)
    a = {"bufferView": len(j["bufferViews"]) - 1, "componentType": ctype, "count": len(rows), "type": typ}
    if minmax:
        a["min"] = [min(r[k] for r in rows) for k in range(NC[typ])]
        a["max"] = [max(r[k] for r in rows) for k in range(NC[typ])]
    j["accessors"].append(a)
    return len(j["accessors"]) - 1


# 4x4 row-major matrices
def mm(a, c):
    return [[sum(a[i][k] * c[k][jj] for k in range(4)) for jj in range(4)] for i in range(4)]


def inv(m):
    r = [row[:3] for row in m[:3]]
    t = [m[i][3] for i in range(3)]
    det = (r[0][0] * (r[1][1] * r[2][2] - r[1][2] * r[2][1]) - r[0][1] * (r[1][0] * r[2][2] - r[1][2] * r[2][0])
           + r[0][2] * (r[1][0] * r[2][1] - r[1][1] * r[2][0]))
    ri = [[(r[(jj + 1) % 3][(i + 1) % 3] * r[(jj + 2) % 3][(i + 2) % 3]
            - r[(jj + 1) % 3][(i + 2) % 3] * r[(jj + 2) % 3][(i + 1) % 3]) / det for jj in range(3)] for i in range(3)]
    ti = [-sum(ri[i][k] * t[k] for k in range(3)) for i in range(3)]
    return [ri[i] + [ti[i]] for i in range(3)] + [[0.0, 0.0, 0.0, 1.0]]


def col(m16):           # glTF column-major -> row-major
    return [[m16[c * 4 + r] for c in range(4)] for r in range(4)]


def flat(m):
    return [m[r][c] for c in range(4) for r in range(4)]


def xp(m, p, w=1.0):
    return tuple(m[i][0] * p[0] + m[i][1] * p[1] + m[i][2] * p[2] + m[i][3] * w for i in range(3))


def fit(root, push, tilt):
    """The move that sets a chain back: tipped back tilt rad about its root (the tip goes +Z), then push m back."""
    c, s = math.cos(-tilt), math.sin(-tilt)
    r = [[1, 0, 0, 0], [0, c, -s, 0], [0, s, c, 0], [0, 0, 0, 1]]
    t0 = [[1, 0, 0, -root[0]], [0, 1, 0, -root[1]], [0, 0, 1, -root[2]], [0, 0, 0, 1]]
    t1 = [[1, 0, 0, root[0]], [0, 1, 0, root[1]], [0, 0, 1, root[2] + push], [0, 0, 0, 1]]
    return mm(t1, mm(r, t0))


def quat(m):
    """A rotation matrix's quaternion (x, y, z, w)."""
    tr = m[0][0] + m[1][1] + m[2][2]
    if tr > 0:
        k = 0.5 / math.sqrt(tr + 1.0)
        q = ((m[2][1] - m[1][2]) * k, (m[0][2] - m[2][0]) * k, (m[1][0] - m[0][1]) * k, 0.25 / k)
    else:
        i = max(range(3), key=lambda a: m[a][a])
        jj, kk = (i + 1) % 3, (i + 2) % 3
        k = 2.0 * math.sqrt(1.0 + m[i][i] - m[jj][jj] - m[kk][kk])
        q = [0.0, 0.0, 0.0, (m[kk][jj] - m[jj][kk]) / k]
        q[i] = 0.25 * k
        q[jj] = (m[jj][i] + m[i][jj]) / k
        q[kk] = (m[kk][i] + m[i][kk]) / k
    return [round(v, 7) for v in q]


def trs(n):
    if "matrix" in n:
        return col(n["matrix"])
    x, y, z, w = n.get("rotation", (0, 0, 0, 1))
    t = n.get("translation", (0, 0, 0))
    s = n.get("scale", (1, 1, 1))
    r = [[1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
         [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
         [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)]]
    return [[r[i][0] * s[0], r[i][1] * s[1], r[i][2] * s[2], t[i]] for i in range(3)] + [[0, 0, 0, 1]]


def find(j, name):
    for i, n in enumerate(j["nodes"]):
        if n.get("name") == name:
            return i
    return -1


def body(j):
    """The skinned mesh node with the most vertices (the game body) and its skin."""
    best, nv = None, -1
    for n in j["nodes"]:
        if "mesh" in n and "skin" in n:
            v = sum(j["accessors"][p["attributes"]["POSITION"]]["count"] for p in j["meshes"][n["mesh"]]["primitives"])
            if v > nv:
                best, nv = n, v
    return best


def bind(j, b, sk, ni):
    """A joint's bind matrix (mesh space): the inverse of its inverse bind matrix."""
    ibm = acc(j, b, sk["inverseBindMatrices"])
    return inv(col(ibm[sk["joints"].index(ni)]))


def chain_names():
    return ["spring_wing%s_%d" % (s, i) for s in "RL" for i in range(3)]


def extract(src):
    j, b = read(src)
    node = body(j)
    sk = j["skins"][node["skin"]]
    mesh = j["meshes"][node["mesh"]]
    prim = next(p for p in mesh["primitives"] if j["materials"][p["material"]]["name"].startswith(MAT))
    hips = bind(j, b, sk, find(j, "hips"))
    names = [j["nodes"][jn]["name"] for jn in sk["joints"]]
    at = prim["attributes"]
    uv = acc(j, b, at["TEXCOORD_0"])
    u0, u1 = min(u for u, _ in uv), max(u for u, _ in uv)
    v0, v1 = min(v for _, v in uv), max(v for _, v in uv)
    # the card's texture: its UV box cut from the model's atlas (ffmpeg: no image library needed)
    tex = j["textures"][j["materials"][prim["material"]]["pbrMetallicRoughness"]["baseColorTexture"]["index"]]
    im = j["images"][tex["source"]]
    bv = j["bufferViews"][im["bufferView"]]
    with tempfile.NamedTemporaryFile(suffix=".jpg", delete=False) as f:
        f.write(b[bv.get("byteOffset", 0):bv.get("byteOffset", 0) + bv["byteLength"]])
    wh = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "stream=width,height", "-of", "csv=p=0", f.name],
                        capture_output=True, text=True).stdout.strip().split(",")
    W, H = int(wh[0]), int(wh[1])
    x0, y0 = max(int(u0 * W) - 4, 0), max(int(v0 * H) - 4, 0)
    x1, y1 = min(int(math.ceil(u1 * W)) + 4, W), min(int(math.ceil(v1 * H)) + 4, H)
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", f.name, "-vf",
                    "crop=%d:%d:%d:%d,scale='min(%d,iw)':-2" % (x1 - x0, y1 - y0, x0, y0, TEX_W), "-q:v", "3", TEX],
                   check=True)
    os.unlink(f.name)
    bones = []
    for nm in chain_names():
        ni = find(j, nm)
        par = next(i for i, n in enumerate(j["nodes"]) if ni in n.get("children", []))
        bones.append({"name": nm, "parent": j["nodes"][par]["name"],
                      "bind": flat(mm(inv(hips), bind(j, b, sk, ni)))})
    # vertices relative to the hips' bind (a new body's hips may sit elsewhere)
    ih = inv(hips)
    out = {"doc": "Sable's moth wings, taken from %s by tools/art1/sable_wings.py --extract: the alpha cards and their "
                  "chain relative to the hips bone's bind; sable_wings.jpg is their texture. docs/SABLE_WINGS.md."
                  % os.path.basename(src),
           "bones": bones,
           "pos": [[round(c, 6) for c in xp(ih, p)] for p in acc(j, b, at["POSITION"])],
           "nrm": [[round(c, 6) for c in xp(ih, p, 0.0)] for p in acc(j, b, at["NORMAL"])],
           "uv": [[round((u * W - x0) / (x1 - x0), 6), round((v * H - y0) / (y1 - y0), 6)] for u, v in uv],
           "joints": [[names[k] for k in q] for q in acc(j, b, at["JOINTS_0"])],
           "weights": [[round(w, 5) for w in q] for q in acc(j, b, at["WEIGHTS_0"])],
           "indices": [q[0] for q in acc(j, b, prim["indices"])]}
    # how far the donor's own body already overlaps its folded cards (the owner-approved look): the bar for a new body
    g = depth_map(j, b, mesh, prim["material"])
    out["folded_inside"] = clearance(g, [xp(hips, p) for p in out["pos"]], roots_of(hips, bones), 0.0)[0]
    with open(DONOR, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print("donor: %d vertices, %d triangles, texture %dx%d px of the atlas -> %s" % (
        len(out["pos"]), len(out["indices"]) // 3, x1 - x0, y1 - y0, os.path.relpath(DONOR)))


def compact(j, b):
    """Drops buffer data nothing points at any more (the replaced cards), keeping images."""
    used = set()
    for me in j["meshes"]:
        for p in me["primitives"]:
            used.update(p["attributes"].values())
            if "indices" in p:
                used.add(p["indices"])
            for t in p.get("targets", []):
                used.update(t.values())
    for s in j.get("skins", []):
        used.add(s["inverseBindMatrices"])
    for a in j.get("animations", []):
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))
    amap = {i: k for k, i in enumerate(sorted(used))}
    j["accessors"] = [j["accessors"][i] for i in sorted(used)]
    views = sorted({a["bufferView"] for a in j["accessors"]} | {im["bufferView"] for im in j.get("images", [])})
    vmap, nb, nv = {}, bytearray(), []
    for vi in views:
        v = dict(j["bufferViews"][vi])
        nb += b"\0" * (-len(nb) % 4)
        o = v.get("byteOffset", 0)
        blob = b[o:o + v["byteLength"]]
        v["byteOffset"] = len(nb)
        nb += blob
        vmap[vi] = len(nv)
        nv.append(v)
    for a in j["accessors"]:
        a["bufferView"] = vmap[a["bufferView"]]
    for im in j.get("images", []):
        im["bufferView"] = vmap[im["bufferView"]]
    j["bufferViews"] = nv
    for me in j["meshes"]:
        for p in me["primitives"]:
            p["attributes"] = {k: amap[v] for k, v in p["attributes"].items()}
            if "indices" in p:
                p["indices"] = amap[p["indices"]]
            if "targets" in p:
                p["targets"] = [{k: amap[v] for k, v in t.items()} for t in p["targets"]]
    for s in j.get("skins", []):
        s["inverseBindMatrices"] = amap[s["inverseBindMatrices"]]
    for a in j.get("animations", []):
        for s in a["samplers"]:
            s["input"], s["output"] = amap[s["input"]], amap[s["output"]]
    nb += b"\0" * (-len(nb) % 4)
    j["buffers"] = [{"byteLength": len(nb)}]
    return nb


def depth_map(j, b, mesh, mat_idx):
    """(x, y) cell -> (front z, back z) of the body's vertices, the cards left out (+Z is behind)."""
    g = {}
    for p in mesh["primitives"]:
        if p.get("material") == mat_idx:
            continue
        for x, y, z in acc(j, b, p["attributes"]["POSITION"]):
            k = (round(x / CELL), round(y / CELL))
            lo, hi = g.get(k, (9.0, -9.0))
            g[k] = (min(lo, z), max(hi, z))
    return g


def rot(ax, a, v):
    c, s = math.cos(a), math.sin(a)
    x, y, z = v
    return (x, c * y - s * z, s * y + c * z) if ax == "x" else (c * x - s * y, s * x + c * y, z)


def roots_of(hips, bones):
    """The two chains' roots in mesh space (right, left)."""
    return [xp(hips, xp(col(bo["bind"]), (0, 0, 0))) for bo in bones if bo["name"].endswith("_0")]


def clearance(g, pos, roots, raise_k):
    """(cards inside the body, worst depth m) with the wings raised raise_k of the way (0 folded)."""
    n, worst = 0, 0.0
    for p in pos:
        r0 = roots[0] if p[0] >= 0 else roots[1]
        out = 1.0 if p[0] >= 0 else -1.0
        d = tuple(p[i] - r0[i] for i in range(3))
        if math.dist(p, r0) < ROOT_M:
            continue
        d = rot("z", out * SPREAD * -raise_k, rot("x", RAISE * -raise_k, d))
        q = tuple(r0[i] + d[i] for i in range(3))
        lohi = g.get((round(q[0] / CELL), round(q[1] / CELL)))
        if lohi and lohi[0] - 0.01 < q[2] < lohi[1] + SKIN_M:
            n += 1
            worst = max(worst, lohi[1] + SKIN_M - q[2])
    return n, worst


def apply(src, dst):
    d = json.load(open(DONOR))
    j, b = read(src)
    node = body(j)
    sk = j["skins"][node["skin"]]
    mesh = j["meshes"][node["mesh"]]
    hips_i = find(j, "hips")
    assert hips_i in sk["joints"], "%s has no hips joint: not a Sable rig" % src
    hips = bind(j, b, sk, hips_i)
    # the cards on this body, measured against it folded; if the body pokes through more than on the donor, each
    # chain's root moves back and its cards tip back about it, the least that clears
    g = depth_map(j, b, mesh, next((i for i, m in enumerate(j.get("materials", [])) if m["name"].startswith(MAT)), -1))
    pos0 = [xp(hips, p) for p in d["pos"]]
    roots = roots_of(hips, d["bones"])
    bar = int(d.get("folded_inside", 0))
    best = None
    for push in PUSHES:
        for tilt in TILTS:
            mv = [fit(r, push, tilt) for r in roots]
            pos = [xp(mv[0] if p[0] >= 0 else mv[1], p) for p in pos0]
            n, w = clearance(g, pos, [xp(m, r) for m, r in zip(mv, roots)], 0.0)
            cost = (n > bar, push + TILT_COST * tilt)
            if best is None or cost < best[0]:
                best = (cost, push, tilt, n)
    _, push, tilt, n = best
    mv = [fit(r, push, tilt) for r in roots]
    pos = [xp(mv[0] if p[0] >= 0 else mv[1], p) for p in pos0]
    roots = [xp(m, r) for m, r in zip(mv, roots)]
    # the chain: placed (rest = bind) under the hips, added where the body hasn't one, reset where it has
    ibm = [col(m) for m in acc(j, b, sk["inverseBindMatrices"])]
    added = []
    world = {}
    for bo in d["bones"]:
        want = mm(mv[0 if "wingR" in bo["name"] else 1], mm(hips, col(bo["bind"])))
        world[bo["name"]] = want
        ni = find(j, bo["name"])
        if ni < 0:
            j["nodes"].append({"name": bo["name"]})
            ni = len(j["nodes"]) - 1
            j["nodes"][find(j, bo["parent"])].setdefault("children", []).append(ni)
            added.append(bo["name"])
        loc = mm(inv(world.get(bo["parent"], hips)), want)
        n_ = j["nodes"][ni]
        for k in ("matrix", "scale"):
            n_.pop(k, None)
        n_["translation"] = [round(loc[i][3], 7) for i in range(3)]
        n_["rotation"] = quat(loc)
        if ni not in sk["joints"]:
            sk["joints"].append(ni)
            ibm.append(inv(want))
        else:
            ibm[sk["joints"].index(ni)] = inv(want)
    # the card material and its texture (reused on a re-run)
    mi = next((i for i, m in enumerate(j.get("materials", [])) if m["name"].startswith(MAT)), -1)
    img = open(TEX, "rb").read()
    b += b"\0" * (-len(b) % 4)
    j["bufferViews"].append({"buffer": 0, "byteOffset": len(b), "byteLength": len(img)})
    b += img
    ii = next((i for i, im in enumerate(j.get("images", [])) if im.get("name") == IMG), -1)
    if ii < 0:
        j.setdefault("images", []).append({"name": IMG, "mimeType": "image/jpeg"})
        ii = len(j["images"]) - 1
        if not j.get("samplers"):
            j["samplers"] = [{"magFilter": 9729, "minFilter": 9987}]
        j.setdefault("textures", []).append({"sampler": 0, "source": ii})
    j["images"][ii]["bufferView"] = len(j["bufferViews"]) - 1
    ti = next(i for i, t in enumerate(j["textures"]) if t["source"] == ii)
    m = {"name": MAT, "doubleSided": True, "pbrMetallicRoughness": {"baseColorTexture": {"index": ti},
         "metallicFactor": 0.0, "roughnessFactor": 0.7}}
    if mi < 0:
        j.setdefault("materials", []).append(m)
        mi = len(j["materials"]) - 1
    else:
        j["materials"][mi] = m
    mesh["primitives"] = [p for p in mesh["primitives"] if p.get("material") != mi]
    raised = clearance(g, pos, roots, 1.0)
    nrm = [xp(mv[0] if p[0] >= 0 else mv[1], xp(hips, q, 0.0), 0.0) for p, q in zip(pos0, d["nrm"])]
    nrm = [tuple(c / (math.sqrt(sum(x * x for x in q)) or 1.0) for c in q) for q in nrm]
    jix = [[sk["joints"].index(find(j, nm)) for nm in q] for q in d["joints"]]
    sk["inverseBindMatrices"] = put(j, b, [flat(m) for m in ibm], 5126, "MAT4")
    prim = {"attributes": {"POSITION": put(j, b, pos, 5126, "VEC3", 34962, True),
                           "NORMAL": put(j, b, nrm, 5126, "VEC3", 34962),
                           "TEXCOORD_0": put(j, b, d["uv"], 5126, "VEC2", 34962),
                           "JOINTS_0": put(j, b, jix, 5123 if len(sk["joints"]) > 255 else 5121, "VEC4", 34962),
                           "WEIGHTS_0": put(j, b, d["weights"], 5126, "VEC4", 34962)},
            "indices": put(j, b, [(i,) for i in d["indices"]], 5123, "SCALAR", 34963), "material": mi}
    mesh["primitives"].append(prim)
    b = compact(j, b)
    write(dst, j, b)
    print("wings on %s -> %s: chain %s; root %.0f cm back, cards tipped back %.0f deg; card vertices within %.0f cm of "
          "the body's back: folded %d (donor %d), raised %d (worst %.1f cm)" % (
              os.path.basename(src), dst, ("added " + ",".join(added)) if added else "reset to the donor's place",
              push * 100, math.degrees(tilt), SKIN_M * 100, n, bar, raised[0], raised[1] * 100))
    bad = n > bar or raised[1] > SKIN_M          # (raised: only a card under the body's surface counts)
    if bad:
        print("  WARN: the body still pokes through the cards: look at it (docs/SABLE_WINGS.md)")
    return 1 if bad else 0


if __name__ == "__main__":
    a = sys.argv[1:]
    if a and a[0] == "--extract":
        extract(a[1])
    elif a:
        sys.exit(apply(a[0], a[1] if len(a) > 1 else a[0]))
    else:
        print(__doc__)
