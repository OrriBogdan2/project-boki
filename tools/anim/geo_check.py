#!/usr/bin/env python3
"""Geometry check of a hunter .glb: part-vs-part clipping and flat hands, in every clip.

Run: python3 tools/anim/geo_check.py GLB [--compare LIVE_GLB] [--key KEY] [--out DIR] [--dump-frames N]
  python3 tools/anim/geo_check.py --hunter sable          (the in-game glb from content/rules/warden_native.json)
  python3 tools/anim/geo_check.py --all --out DIR          (all 13 hunters: TSV + JSON per hunter, summary lines)
numpy + scipy only (no Blender, no Godot); reads the .glb and never writes to it.

How it measures
- PARTS: every skinned vertex goes to one body region by its dominant bone (bone name, else its nearest named
  ancestor): head, hair, torso, upper_arm/forearm/hand/thigh/shin/foot (_L/_R), outfit shells (skirt, scarf, cloth,
  pauldron, tail...), props (weapon, shield, hammer...). Materials named skirt/cape/scarf/hair/sword... override.
  The hand = one hand length (HAND_LEN of body height) past the wrist joint; what the hand bone carries further out is
  prop:held_L/R (Sable's pistols). A body region keeps its main connected patch; stray patches (skin-weight bleed) join
  the region around them. Large disconnected mesh islands become their own part (region.2).
- CLIPPING: every pair of parts that is not anatomically joined (JOINED) is tested both ways every 2nd frame of every
  clip (30 fps). A point of part A is inside part B when its exact closest point on B's triangles is behind B's surface,
  is not on B's open cut rim (beside a sleeve opening is not inside), and going on inward reaches B's far wall (a
  one-sided coat tail has none: behind it is not inside). Depth = that distance, the 3rd deepest point, up to
  MAX_DEPTH. Cloth shells are only tested as the sinking part. Held clips (loops and holds) are reported apart (HELD).
  Checked against Blender's own skinning (Sable Attack and run: 0.0 mm) and by eye in Blender renders (11-23).
- FLAT HANDS: per hand, PCA of the hand's skinned vertices: thickness ratio = palm thickness / palm width (2-98
  percentile extents), at rest (bind pose) and at the clip frame with the lowest ratio; plus the thumb lobe (thumb
  vertices outside the hull of the rest of the hand in the palm plane) and finger separation (1 - area / hull area of
  the hand's silhouette). FLAT = finger separation below FLAT_SEP or thickness ratio below FLAT_RATIO; 'fingers-unrigged' (finger bones
  that carry no mesh) is a warning (calibrated on 11-23, docs/art/HUNTER_GEO_AUDIT.md).
Output per hunter: <key>.tsv (clip, frame, pair, depth_cm, flags), <key>.json (per part, for the hunter panel),
one summary line. Exit code 0 = PASS, 1 = FAIL (held clip over 1 cm, FLAT hand, or worse than --compare)."""

import argparse
import json
import os
import re
import struct
import subprocess
import sys

import numpy as np
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.ndimage import binary_closing
from scipy.spatial import ConvexHull, Delaunay, cKDTree

FPS = 30
STEP = 2  # every 2nd frame
HELD_CM = 1.0  # held-pose clip deeper than this = FAIL
SEEN_CM = 0.3  # shallower than this is not listed
FLAT_SEP = 0.2  # finger separation below this = FLAT: fused mitten (calibrated: Lace 0.11/0.15, Sparkle 0.51/0.54, Sable fist 0.24)
FLAT_RATIO = 0.3  # hand thickness / width below this = FLAT: paper thin (Sparkle's slim open hand is 0.45)
WORSE_CM = 0.3  # --compare: held depth this much deeper than live = worse
WORSE_SEP = 0.05  # --compare: finger separation this much lower than live = worse
WORSE_RATIO = 0.04  # --compare: thickness ratio this much lower than live = worse
MAX_PTS = 3000  # sampled vertices per part (the clip test)
HAND_LEN = 0.11  # hand length / body height: the hand = this far past the wrist joint
ISLAND_MIN = 300  # vertices: a disconnected island this big is its own part
PIVOT_R = 0.12  # m: points this near the hinge two parts share are not tested (a thigh at the hip)
MAX_DEPTH = 0.25  # m: deepest point searched (a hand fully through a thigh is ~15 cm)
WALL_REACH = 0.40  # m: how far inward a point looks for the part's far wall
WALL_R = 0.015  # m: radius of that ray's search tube
KT = 16  # nearest triangles (by centre) searched for a point's exact closest point
DEEP_RANK = 3  # the 3rd deepest inside point is the pair's depth
HELD = re.compile(
    r"^(idle|stance|crouch_(idle|f|b|l|r)|walk(_\w+)?|run(_\w+)?|glide|lmb_hold|rmb(_guard)?|guard_armed|downed|stun|"
    r"crouch_walk_with_torch|cheer|emote|fall)$",
    re.I,
)
SKIP_CLIPS = re.compile(r"baselayer", re.I)

MAT_WORDS = {"skirt": "skirt", "cape": "cape", "scarf": "scarf", "hair": "hair", "sword": "weapon", "hammer": "hammer"}
# anatomically joined pairs (base names, same side unless noted): not tested
JOINED = {
    ("head", "torso"),
    ("head", "hair"),
    ("head", "upper_arm"),
    ("torso", "upper_arm"),
    ("upper_arm", "forearm"),
    ("forearm", "hand"),
    ("torso", "thigh"),
    ("thigh", "shin"),
    ("shin", "foot"),
}
COMPONENT = ("torso", "head")  # outfit shells hang off these: joined to them and to the limb roots
LIMB_ROOTS = ("upper_arm", "thigh", "hair", "pauldron")


def read_glb(path):
    """(json, bin) of a .glb."""
    d = open(path, "rb").read()
    n = struct.unpack("<I", d[12:16])[0]
    j = json.loads(d[20 : 20 + n])
    off = 20 + n
    m = struct.unpack("<I", d[off : off + 4])[0]
    return j, d[off + 8 : off + 8 + m]


COMP = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


def accessor(j, bin_, i):
    """Accessor i as a float/int array [count, n] (normalized ints become floats)."""
    ac = j["accessors"][i]
    bv = j["bufferViews"][ac["bufferView"]]
    dt, n = np.dtype(COMP[ac["componentType"]]), NCOMP[ac["type"]]
    start = bv.get("byteOffset", 0) + ac.get("byteOffset", 0)
    stride = bv.get("byteStride", n * dt.itemsize)
    raw = np.frombuffer(bin_, np.uint8, ac["count"] * stride, start).reshape(ac["count"], stride)
    out = np.ascontiguousarray(raw[:, : n * dt.itemsize]).view(dt).reshape(ac["count"], n)
    if ac.get("normalized") and dt.kind in "iu":
        out = out / float(np.iinfo(dt).max)
    return out


def quat_to_mat(q):
    """Quaternions [..., 4] (x y z w) to rotation matrices [..., 3, 3]."""
    x, y, z, w = q[..., 0], q[..., 1], q[..., 2], q[..., 3]
    m = np.empty(q.shape[:-1] + (3, 3))
    m[..., 0, 0], m[..., 0, 1], m[..., 0, 2] = 1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)
    m[..., 1, 0], m[..., 1, 1], m[..., 1, 2] = 2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)
    m[..., 2, 0], m[..., 2, 1], m[..., 2, 2] = 2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)
    return m


def channel_at(times, vals, mode, path, T):
    """A channel's values at times T [F, n] (LINEAR lerp, rotations nlerp; STEP; CUBICSPLINE keys only)."""
    if mode == "CUBICSPLINE":
        vals = vals[1::3]
    k = np.clip(np.searchsorted(times, T, side="right") - 1, 0, len(times) - 1)
    k2 = np.minimum(k + 1, len(times) - 1)
    if mode == "STEP":
        return vals[k]
    f = np.clip((T - times[k]) / np.maximum(times[k2] - times[k], 1e-9), 0, 1)[:, None]
    a, b = vals[k], vals[k2]
    if path == "rotation":
        b = np.where((a * b).sum(1, keepdims=True) < 0, -b, b)
        q = a * (1 - f) + b * f
        return q / np.linalg.norm(q, axis=1, keepdims=True)
    return a * (1 - f) + b * f


class Rig:
    """The skin of a .glb: joints, parents, inverse binds, and the skinning matrices of any clip frame."""

    def __init__(self, j, bin_):
        self.j, self.bin = j, bin_
        nodes = j["nodes"]
        self.parent = [-1] * len(nodes)
        for i, nd in enumerate(nodes):
            for c in nd.get("children", []):
                self.parent[c] = i
        self.order = []  # parents before children
        seen = set()
        for i in range(len(nodes)):
            chain = []
            while i >= 0 and i not in seen:
                chain.append(i)
                i = self.parent[i]
            for c in reversed(chain):
                seen.add(c)
                self.order.append(c)
        sk = j["skins"][0]
        self.joints = sk["joints"]
        self.names = [nodes[i]["name"] for i in self.joints]
        self.ibm = accessor(j, bin_, sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
        self.rest = [
            (
                np.array(nd.get("translation", [0, 0, 0]), float),
                np.array(nd.get("rotation", [0, 0, 0, 1]), float),
                np.array(nd.get("scale", [1, 1, 1]), float),
            )
            for nd in nodes
        ]

    def skin_mats(self, anim, T):
        """Skinning matrices [F, joints, 4, 4] at times T [F] for animation `anim` (None = the rest pose)."""
        F, nodes = len(T), self.j["nodes"]
        loc_t = np.tile(np.stack([r[0] for r in self.rest]), (F, 1, 1))
        loc_q = np.tile(np.stack([r[1] for r in self.rest]), (F, 1, 1))
        loc_s = np.tile(np.stack([r[2] for r in self.rest]), (F, 1, 1))
        if anim is not None:
            for ch in anim["channels"]:
                path = ch["target"]["path"]
                if path not in ("translation", "rotation", "scale"):
                    continue
                sm = anim["samplers"][ch["sampler"]]
                times = accessor(self.j, self.bin, sm["input"])[:, 0].astype(float)
                vals = accessor(self.j, self.bin, sm["output"]).astype(float)
                v = channel_at(times, vals, sm.get("interpolation", "LINEAR"), path, T)
                {"translation": loc_t, "rotation": loc_q, "scale": loc_s}[path][:, ch["target"]["node"]] = v
        loc = np.zeros((F, len(nodes), 4, 4))
        loc[..., :3, :3] = quat_to_mat(loc_q) * loc_s[:, :, None, :]
        loc[..., :3, 3] = loc_t
        loc[..., 3, 3] = 1
        glob = np.zeros_like(loc)
        for i in self.order:
            glob[:, i] = loc[:, i] if self.parent[i] < 0 else glob[:, self.parent[i]] @ loc[:, i]
        return glob[:, self.joints] @ self.ibm[None]


def region_of(name):
    """(region, side) a bone name says by itself, or None."""
    n = name.lower().replace("mixamorig:", "")
    side = (
        "L"
        if (n.startswith("left") or re.search(r"[._]l$", n))
        else "R"
        if (n.startswith("right") or re.search(r"[._]r$", n))
        else ""
    )
    n = re.sub(r"^(left|right)", "", n)
    n = re.sub(r"[._][lr]$", "", n)
    if n.startswith("x_") and any(k in n for k in ("shield", "weapon", "fish")):
        return "prop:" + n[2:], ""
    if n.startswith("spring_hang") or "fish" in n:
        return "prop:fish", ""
    if any(k in n for k in ("braid", "hair", "ponytail")):
        return "hair", ""
    for k in ("skirt", "scarf", "cape", "cloak", "tail", "ribbon", "cloth"):
        if k in n:
            return "outfit:" + k, ""
    if n.startswith("bow") or n.startswith("stringmid") or n == "bow":
        return "prop:bow", ""
    for k in ("launcher", "gatling", "hammer", "gun", "coin", "sword", "weapon", "shield"):
        if k in n:
            return "prop:" + k, ""
    if "pauldron" in n:
        return "outfit:pauldron", side
    if any(k in n for k in ("thumb", "fing", "pinky", "ring", "middle", "index")) or "hand" in n:
        return "hand", side
    if "forearm" in n or "lowerarm" in n:
        return "forearm", side
    if "upleg" in n or "thigh" in n:
        return "thigh", side
    if "shin" in n or n in ("leg", "calf"):
        return "shin", side
    if "foot" in n or "toe" in n or "heel" in n:
        return "foot", side
    if n.startswith("arm") or "upper_arm" in n or "upperarm" in n:
        return "upper_arm", side
    if any(k in n for k in ("head", "neck", "lid", "brow", "jaw", "eye")):
        return "head", ""
    if any(k in n for k in ("hips", "spine", "chest", "pelvis", "shoulder", "root")):
        return "torso", ""
    return None


def bone_regions(rig):
    """['region' or 'region_L'] per joint: its own name, else its nearest named ancestor's (a loose Bone_NN under the
    head is hair, under the hips cloth)."""
    out = []
    for k, node in enumerate(rig.joints):
        cur, found = node, None
        while cur >= 0 and found is None:
            found = region_of(rig.j["nodes"][cur]["name"])
            if found is None:
                cur = rig.parent[cur]
        if found is None:
            found = ("torso", "")
        reg, side = found
        if cur != node and reg == "head" and re.match(r"(bone|joint)", rig.names[k].lower()):
            reg = "hair"
        elif cur != node and reg == "torso" and re.match(r"(bone|joint)", rig.names[k].lower()):
            reg, side = "outfit:cloth", ""
        out.append(reg + ("_" + side if side else ""))
    return out


def load_mesh(j, bin_):
    """Skinned primitives merged: pos, normal, joints [V,4], weights [V,4], tris [T,3], material name per vertex."""
    P, N, J, W, TR, M = [], [], [], [], [], []
    base = 0
    for m in j["meshes"]:
        for pr in m["primitives"]:
            at = pr["attributes"]
            if "JOINTS_0" not in at:
                continue
            pos = accessor(j, bin_, at["POSITION"]).astype(float)
            nrm = accessor(j, bin_, at["NORMAL"]).astype(float) if "NORMAL" in at else np.zeros_like(pos)
            jo = accessor(j, bin_, at["JOINTS_0"]).astype(int)
            wt = accessor(j, bin_, at["WEIGHTS_0"]).astype(float)
            idx = accessor(j, bin_, pr["indices"])[:, 0].astype(np.int64).reshape(-1, 3) + base
            mat = j["materials"][pr["material"]]["name"] if "material" in pr else ""
            P.append(pos), N.append(nrm), J.append(jo), W.append(wt), TR.append(idx)
            M.append([m["name"] + "|" + mat] * len(pos))
            base += len(pos)
    return {
        "pos": np.vstack(P),
        "nrm": np.vstack(N),
        "joints": np.vstack(J),
        "weights": np.vstack(W),
        "tris": np.vstack(TR),
        "mat": np.concatenate(M).astype(object),
    }


def split_parts(rig, mesh):
    """{part name: vertex indices}: dominant-bone regions, material overrides, hands cut by geometry, and pieces
    detached from the whole body (weapons, hair cards) as their own parts."""
    breg = bone_regions(rig)
    dom = mesh["joints"][np.arange(len(mesh["pos"])), mesh["weights"].argmax(1)]
    reg = np.array([breg[d] for d in dom], dtype=object)
    for k, mt in enumerate(mesh["mat"]):
        low = mt.lower()
        for word, name in MAT_WORDS.items():
            if word in low:
                reg[k] = (
                    ("outfit:" + name)
                    if name in ("skirt", "cape", "scarf")
                    else ("hair" if name == "hair" else "prop:" + name)
                )
    H = np.ptp(mesh["pos"][:, 1])
    jpos = np.linalg.inv(rig.ibm)[:, :3, 3]  # joint positions in the bind pose
    for side in "LR":
        # the hand = from the wrist joint one hand length (HAND_LEN of body height) along the forearm; what the hand
        # bone carries further out (a pistol barrel, a blade) is a held prop, so the hand test measures the hand
        arm = np.isin(reg, ["%s_%s" % (r, side) for r in ("upper_arm", "forearm", "hand")])
        wrist = [
            k
            for k, n in enumerate(rig.names)
            if region_of(rig.j["nodes"][rig.joints[k]]["name"]) == ("hand", side)
            and re.search(r"hand$", re.sub(r"[._ ]?[lr]$", "", n.lower().replace("mixamorig:", "")))
        ]
        elbow = [
            k for k, n in enumerate(rig.names) if region_of(rig.j["nodes"][rig.joints[k]]["name"]) == ("forearm", side)
        ]
        if not wrist or not elbow or arm.sum() < 60:
            continue
        w, e = jpos[wrist[0]], jpos[elbow[0]]
        axis = (w - e) / max(np.linalg.norm(w - e), 1e-9)
        proj = (mesh["pos"] - w) @ axis
        was = reg == "hand_" + side
        hand = arm & (proj >= -0.01 * H) & (proj <= HAND_LEN * H)
        held = (was | arm) & (proj > HAND_LEN * H)
        reg[was & (proj < -0.01 * H)] = "forearm_" + side
        reg[hand] = "hand_" + side
        if held.sum() >= 50:
            reg[held] = "prop:held_" + side
        else:
            reg[held] = "hand_" + side
    # welded vertex ids (seams) so islands follow the surface, not the UV cuts
    key = np.round(mesh["pos"] * 1e4).astype(np.int64)
    _, weld = np.unique(key, axis=0, return_inverse=True)
    weld = weld.reshape(-1)
    tr = weld[mesh["tris"]]
    g = coo_matrix(
        (np.ones(len(tr) * 3), (np.r_[tr[:, 0], tr[:, 1], tr[:, 2]], np.r_[tr[:, 1], tr[:, 2], tr[:, 0]])),
        shape=(weld.max() + 1,) * 2,
    )
    _, comp = connected_components(g, directed=False)
    comp = comp[weld]  # whole-mesh island of each vertex: only a piece detached from the body is its own part
    reg = absorb_strays(reg, weld, tr)
    size = np.bincount(comp)
    main = size.argmax()
    parts = {}
    for r in sorted(set(reg)):
        ids = np.where(reg == r)[0]
        loose = [c for c in np.unique(comp[ids]) if c != main and size[c] >= ISLAND_MIN]
        rest = ids
        for k, c in enumerate(loose):
            parts["%s.%d" % (r, k + 2)] = ids[comp[ids] == c]
            rest = rest[comp[rest] != c]
        parts[r] = rest
    return {k: v for k, v in parts.items() if len(v) >= 20}


BODY = ("head", "torso", "upper_arm", "forearm", "hand", "thigh", "shin", "foot")


def absorb_strays(reg, weld, tr):
    """Body regions keep only their main connected patch on the welded surface; a stray patch (Meshy's skin weights
    bleed: belt bits at the hip skinned to the hand) joins the region that surrounds it most. Outfit, hair and prop
    regions are left as they are (they are often many strips)."""
    nv = weld.max() + 1
    wreg = np.empty(nv, dtype=object)
    wreg[weld] = reg  # welded duplicates share their weights in practice
    e = np.r_[tr[:, [0, 1]], tr[:, [1, 2]], tr[:, [2, 0]]]
    for _ in range(3):
        same = wreg[e[:, 0]] == wreg[e[:, 1]]
        g = coo_matrix((np.ones(same.sum()), (e[same, 0], e[same, 1])), shape=(nv, nv))
        _, cc = connected_components(g, directed=False)
        size = np.bincount(cc)
        moved = 0
        for r in sorted(set(wreg)):
            if base_of(r)[0] not in BODY:
                continue
            ids = np.where(wreg == r)[0]
            if not len(ids):
                continue
            keep = cc[ids][size[cc[ids]].argmax()]
            stray = ids[cc[ids] != keep]
            if not len(stray):
                continue
            mask = np.zeros(nv, bool)
            mask[stray] = True
            for c in np.unique(cc[stray]):
                m = mask & (cc == c)
                border = e[m[e[:, 0]] & ~m[e[:, 1]], 1]
                votes = [x for x in wreg[border] if x != r]
                if votes:
                    vals, cnt = np.unique(np.array(votes, dtype=object), return_counts=True)
                    wreg[m] = vals[cnt.argmax()]
                    moved += 1
        if not moved:
            break
    return wreg[weld]


def base_of(part):
    """('upper_arm', 'L') for 'upper_arm_L.2'; shells report as 'outfit'."""
    p = part.split(".")[0]
    m = re.match(r"(.*)_([LR])$", p)
    name, side = (m.group(1), m.group(2)) if m else (p, "")
    return name, side


def is_shell(part):
    n = base_of(part)[0]
    return n.startswith("outfit:") and "pauldron" not in n or n == "hair"


def joined(a, b):
    """True when two parts are anatomically joined (not tested against each other)."""
    (na, sa), (nb, sb) = base_of(a), base_of(b)
    if a.split(".")[0] == b.split(".")[0]:
        return True
    for x, y, sx, sy in ((na, nb, sa, sb), (nb, na, sb, sa)):
        if (x, y) in JOINED and (sx == sy or "" in (sx, sy)):
            return True
        if x.startswith("outfit:") and (y in COMPONENT or y in LIMB_ROOTS):
            return True
        if x.startswith("prop:held"):
            if y in ("hand", "forearm") and sx == sy:
                return True
            continue
        if x.startswith("prop:") and y in ("hand", "torso"):
            return True
    return False


def pick(ids, n):
    """At most n of ids, evenly spread (a fixed pick: the same points every frame)."""
    return ids if len(ids) <= n else ids[np.linspace(0, len(ids) - 1, n).astype(int)]


def skin_points(S, mesh, ids):
    """World positions and normals [len(ids), 3] of vertices ids for skinning matrices S [joints, 4, 4]."""
    p = np.c_[mesh["pos"][ids], np.ones(len(ids))]
    n = mesh["nrm"][ids]
    jo, wt = mesh["joints"][ids], mesh["weights"][ids]
    op, on = np.zeros((len(ids), 3)), np.zeros((len(ids), 3))
    for k in range(4):
        m = S[jo[:, k]]
        op += wt[:, k, None] * np.einsum("vij,vj->vi", m[:, :3, :], p)
        on += wt[:, k, None] * np.einsum("vij,vj->vi", m[:, :3, :3], n)
    ln = np.linalg.norm(on, axis=1, keepdims=True)
    return op, on / np.maximum(ln, 1e-9)


def closest_on_tris(p, a, b, c):
    """Exact closest points on triangles (a, b, c) [n, 3] to points p [n, 3] (Ericson 5.1.5): (point [n, 3],
    barycentric [n, 3]). A zero barycentric weight means the closest point is on that corner's opposite edge."""
    ab, ac, ap = b - a, c - a, p - a
    d1, d2 = (ab * ap).sum(1), (ac * ap).sum(1)
    bp = p - b
    d3, d4 = (ab * bp).sum(1), (ac * bp).sum(1)
    cp = p - c
    d5, d6 = (ab * cp).sum(1), (ac * cp).sum(1)
    va, vb, vc = d3 * d6 - d5 * d4, d5 * d2 - d1 * d6, d1 * d4 - d3 * d2
    den = np.maximum(va + vb + vc, 1e-30)
    bc = np.stack([va / den, vb / den, vc / den], 1)  # inside the face

    def put(mask, w):
        bc[mask] = w[mask]

    z = np.zeros_like(d1)
    with np.errstate(divide="ignore", invalid="ignore"):
        t = np.clip(np.nan_to_num((d4 - d3) / ((d4 - d3) + (d5 - d6))), 0, 1)
        put((va <= 0) & (d4 - d3 >= 0) & (d5 - d6 >= 0), np.stack([z, 1 - t, t], 1))  # edge bc
        t = np.clip(np.nan_to_num(d2 / (d2 - d6)), 0, 1)
        put((vb <= 0) & (d2 >= 0) & (d6 <= 0), np.stack([1 - t, z, t], 1))  # edge ac
        t = np.clip(np.nan_to_num(d1 / (d1 - d3)), 0, 1)
        put((vc <= 0) & (d1 >= 0) & (d3 <= 0), np.stack([1 - t, t, z], 1))  # edge ab
    one = np.ones_like(d1)
    put((d6 >= 0) & (d5 <= d6), np.stack([z, z, one], 1))  # corner c
    put((d3 >= 0) & (d4 <= d3), np.stack([z, one, z], 1))  # corner b
    put((d1 <= 0) & (d2 <= 0), np.stack([one, z, z], 1))  # corner a
    return bc[:, :1] * a + bc[:, 1:2] * b + bc[:, 2:] * c, bc


def part_faces(mesh, ids, weld):
    """(triangles [T, 3] of global vertex ids wholly inside part `ids`, rim mask [T, 3] per corner and per opposite
    edge): rim = on the part's open cut (an edge only one of the part's triangles uses, after welding UV seams)."""
    inp = np.zeros(len(mesh["pos"]), bool)
    inp[ids] = True
    tri = mesh["tris"][inp[mesh["tris"]].all(1)]
    if not len(tri):
        return tri, np.zeros((0, 3), bool), np.zeros((0, 3), bool)
    w = weld[tri]
    e = np.sort(np.stack([w[:, [1, 2]], w[:, [2, 0]], w[:, [0, 1]]], 1), axis=2)  # edge opposite corner k
    flat = e.reshape(-1, 2)
    _, inv, cnt = np.unique(flat, axis=0, return_inverse=True, return_counts=True)
    edge_rim = (cnt[inv.reshape(-1)] == 1).reshape(-1, 3)
    rim_v = np.zeros(weld.max() + 1, bool)
    rim_v[flat[(cnt[inv.reshape(-1)] == 1)].reshape(-1)] = True
    return tri, rim_v[w], edge_rim


def penetration(pa, P, N, face):
    """(depth m, centre) of points pa inside part surface `face` = (triangles, corner rim, edge rim) posed at P, N.
    A point is inside when its exact closest point on the part is behind the surface (against the interpolated
    normal there, and mostly along it) and is not on the part's open cut rim (a point beside the opening of a
    sleeve or a cut limb is not inside it). Depth = the DEEP_RANK-th deepest inside point. (0, None) when none."""
    tri, vrim, erim = face
    if len(tri) == 0 or len(pa) < DEEP_RANK:
        return 0.0, None
    cen = P[tri].mean(1)
    tree = cKDTree(cen)
    k = min(KT, len(tri))
    d, q = tree.query(pa, k=k, distance_upper_bound=MAX_DEPTH + 0.05)
    d, q = d.reshape(len(pa), -1), q.reshape(len(pa), -1)
    near = np.isfinite(d[:, 0])
    if near.sum() < DEEP_RANK:
        return 0.0, None
    pa, q, d = pa[near], q[near], d[near]
    ok = np.isfinite(d)
    q = np.where(ok, q, q[:, :1])
    n, kk = q.shape
    t = tri[q.reshape(-1)]
    pp = np.repeat(pa, kk, axis=0)
    cp, bc = closest_on_tris(pp, P[t[:, 0]], P[t[:, 1]], P[t[:, 2]])
    dist = np.linalg.norm(pp - cp, axis=1).reshape(n, kk)
    best = dist.argmin(1)
    sel = np.arange(n) * kk + best
    cp, bc, t, dist = cp[sel], bc[sel], t[sel], dist[np.arange(n), best]
    tq = q[np.arange(n), best]
    zero = bc <= 1e-6
    corner = zero.sum(1) == 2  # closest = a corner
    edge = zero.sum(1) == 1  # closest = an edge (opposite the zero corner)
    on_rim = (corner & vrim[tq, bc.argmax(1)]) | (edge & erim[tq, zero.argmax(1)])
    nrm = (bc[:, :, None] * N[t]).sum(1)
    fn = np.cross(P[t[:, 1]] - P[t[:, 0]], P[t[:, 2]] - P[t[:, 0]])
    fn /= np.maximum(np.linalg.norm(fn, axis=1, keepdims=True), 1e-12)
    nrm = np.where(corner[:, None] | edge[:, None], nrm, np.where((fn * nrm).sum(1, keepdims=True) < 0, -fn, fn))
    nrm /= np.maximum(np.linalg.norm(nrm, axis=1, keepdims=True), 1e-12)
    sd = ((pa - cp) * nrm).sum(1)
    inside = (~on_rim) & (sd < 0) & (-sd >= 0.7 * dist) & (dist <= MAX_DEPTH) & (dist > 1e-5)
    if inside.sum() < DEEP_RANK:
        return 0.0, None
    # enclosed: going on inward from the point must reach the part's far wall (a surface facing the same way the
    # ray runs). A single cloth sheet (a coat tail skinned to the thigh) has no far wall: behind it is not inside.
    vids = np.unique(tri)
    Pv, Nv = P[vids], N[vids]
    tv = cKDTree(Pv)
    deep = np.where(inside)[0]
    deep = deep[np.argsort(-dist[deep])]
    good = []
    for i in deep:
        ray = -nrm[i]
        cand = tv.query_ball_point(pa[i] + ray * WALL_REACH / 2, WALL_REACH / 2 + WALL_R)
        if cand:
            v = Pv[cand] - pa[i]
            along = v @ ray
            off = np.linalg.norm(v - along[:, None] * ray, axis=1)
            if ((along > 0.002) & (off < WALL_R) & (Nv[cand] @ ray > 0.3)).any():
                good.append(i)
                if len(good) == DEEP_RANK:
                    break
    if len(good) < DEEP_RANK:
        return 0.0, None
    return float(dist[good[-1]]), pa[good].mean(0)


def hand_shape(pts, is_thumb):
    """(thickness ratio, thumb lobe 0..1 or None, finger separation 0..1) of a hand's vertices; is_thumb marks the
    thumb's vertices (all False: no thumb bone)."""
    c = pts.mean(0)
    vt = np.linalg.svd(pts - c, full_matrices=False)[2]
    q = (pts - c) @ vt.T
    ext = np.percentile(q, 98, axis=0) - np.percentile(q, 2, axis=0)
    xy = q[:, :2]
    res = 48
    lo, hi = xy.min(0), xy.max(0)
    cell = np.minimum(((xy - lo) / np.maximum(hi - lo, 1e-9) * (res - 1)).astype(int), res - 1)
    occ = np.zeros((res, res), bool)
    occ[cell[:, 0], cell[:, 1]] = True
    occ = binary_closing(occ, iterations=2)
    area = ConvexHull(cell).volume if len(cell) > 3 else 0.0
    sep = float(np.clip(1 - occ.sum() / max(area, 1.0), 0, 1))
    lobe = None
    if is_thumb.sum() >= 6 and (~is_thumb).sum() >= 6:
        palm = ConvexHull(xy[~is_thumb])
        inside = Delaunay(xy[~is_thumb][palm.vertices]).find_simplex(xy[is_thumb]) >= 0
        lobe = float(1 - inside.mean())
    return float(ext[2] / max(ext[1], 1e-9)), lobe, sep


class Check:
    """One glb: parts, then clipping and hand shape over its clips."""

    def __init__(self, path, key=None):
        self.path, self.key = path, key or os.path.basename(path).split(".")[0]
        j, b = read_glb(path)
        self.rig = Rig(j, b)
        self.mesh = load_mesh(j, b)
        self.parts = split_parts(self.rig, self.mesh)
        self.anims = [a for a in j.get("animations", []) if not SKIP_CLIPS.search(a["name"])]
        self.sample = {k: pick(v, MAX_PTS) for k, v in self.parts.items()}
        names = list(self.parts)
        self.pairs = [(a, c) for a in names for c in names if a != c and not joined(a, c) and not is_shell(c)]
        self.dom = self.mesh["joints"][np.arange(len(self.mesh["pos"])), self.mesh["weights"].argmax(1)]
        self.pivot = {pair: self.pivot_joint(*pair) for pair in self.pairs}
        self.bind_pos = np.linalg.inv(self.rig.ibm)[:, :, 3]  # joint positions in the bind pose
        key = np.round(self.mesh["pos"] * 1e4).astype(np.int64)
        weld = np.unique(key, axis=0, return_inverse=True)[1].reshape(-1)
        self.faces = {
            k: part_faces(self.mesh, v, weld) for k, v in self.parts.items() if k in {c for _, c in self.pairs}
        }
        self.every = np.arange(len(self.mesh["pos"]))
        thumb = [k for k, n in enumerate(self.rig.names) if "thumb" in n.lower()]
        self.thumb_joint = set(thumb)

    def hand_ids(self):
        """{'hand_L': (vertex ids, thumb mask)}: a hand's pieces together (a glove can be a detached island)."""
        out = {}
        for side in "LR":
            ids = np.concatenate(
                [v for k, v in self.parts.items() if base_of(k) == ("hand", side)] or [np.zeros(0, int)]
            )
            if len(ids) >= 30:
                out["hand_" + side] = (ids, np.isin(self.dom[ids], list(self.thumb_joint)))
        return out

    def finger_bones_unused(self, side):
        """True when the rig has finger/thumb bones on this side and no vertex is mainly on any of them."""
        fing = [
            k
            for k, n in enumerate(self.rig.names)
            if region_of(self.rig.j["nodes"][self.rig.joints[k]]["name"]) == ("hand", side)
            and re.search(r"fing|thumb|index|middle|ring|pinky", n.lower())
        ]
        return bool(fing) and int(np.isin(self.dom, fing).sum()) < 20

    def pivot_joint(self, a, c):
        """Joint index of the nearest common ancestor of the two parts' main bones (the hinge they share), or None."""

        def chain(part):
            ids = self.parts[part]
            node = self.rig.joints[np.bincount(self.dom[ids], minlength=len(self.rig.joints)).argmax()]
            out = []
            while node >= 0:
                out.append(node)
                node = self.rig.parent[node]
            return out

        ca, cc = chain(a), chain(c)
        common = next((n for n in ca if n in cc), None)
        return self.rig.joints.index(common) if common in self.rig.joints else None

    def frame_clip(self, pts, jw, P, N):
        """{(a, c): (depth m, centre)} of the pairs that clip at one posed frame (pts: sampled points per part,
        jw: joint world positions, P/N: every vertex posed)."""
        res = {}
        lo = {k: p.min(0) for k, p in pts.items()}
        hi = {k: p.max(0) for k, p in pts.items()}
        for a, c in self.pairs:
            if (lo[a] > hi[c] + 0.02).any() or (lo[c] > hi[a] + 0.02).any():
                continue
            pa = pts[a]
            if self.pivot[(a, c)] is not None:  # not within the hinge they share (two thighs at the hip)
                pa = pa[np.linalg.norm(pa - jw[self.pivot[(a, c)]], axis=1) > PIVOT_R]
            pa = pa[((pa >= lo[c] - 0.01) & (pa <= hi[c] + 0.01)).all(1)]
            if len(pa) < DEEP_RANK:
                continue
            d, where = penetration(pa, P, N, self.faces[c])
            if d * 100 >= SEEN_CM:
                res[(a, c)] = (d, where)
        return res

    def run(self, log=print):
        """The report: rows (clip, frame, pair, depth_cm, flags), worst frames, per-part data, hand data."""
        hands = self.hand_ids()
        rows, worst, hand = [], {}, {k: {"rest": None, "worst": None} for k in hands}
        clips = [("rest", None, np.array([0.0]))] + [
            (
                a["name"],
                a,
                np.arange(
                    0,
                    max(accessor(self.rig.j, self.rig.bin, s["input"]).max() for s in a["samplers"]) + 1e-6,
                    STEP / FPS,
                ),
            )
            for a in self.anims
        ]
        for cname, anim, T in clips:
            mats = self.rig.skin_mats(anim, T)
            held = cname == "rest" or bool(HELD.match(cname))
            for f in range(len(T)):
                P, N = skin_points(mats[f], self.mesh, self.every)
                pts = {k: P[ids] for k, ids in self.sample.items()}
                hit = self.frame_clip(pts, np.einsum("jik,jk->ji", mats[f], self.bind_pos)[:, :3], P, N)
                for (a, c), (d, w) in hit.items():
                    flags = ("HELD" if held else "move") + (",OVER1CM" if d * 100 > HELD_CM else "")
                    rows.append((cname, f * STEP, a + ">" + c, round(d * 100, 2), flags))
                    cur = worst.get((a, c))
                    if cur is None or d > cur[0]:
                        worst[(a, c)] = (d, cname, f * STEP, w)
                for k, (ids, thumb) in hands.items():
                    hp, _ = skin_points(mats[f], self.mesh, ids)
                    ratio, lobe, sep = hand_shape(hp, thumb)
                    rec = {
                        "ratio": round(ratio, 3),
                        "thumb_lobe": None if lobe is None else round(lobe, 2),
                        "finger_sep": round(sep, 2),
                        "clip": cname,
                        "frame": f * STEP,
                    }
                    if cname == "rest":
                        hand[k]["rest"] = rec
                    if hand[k]["worst"] is None or ratio < hand[k]["worst"]["ratio"]:
                        hand[k]["worst"] = rec
            log("  %s %d frames" % (cname, len(T)))
        return rows, worst, hand


def summarize(chk, rows, worst, hand):
    """(summary line, per-part JSON dict, stats) of one run."""
    over = {(r[0], r[1]) for r in rows if r[3] > HELD_CM}
    over_held = {k for k in over if k[0] == "rest" or HELD.match(k[0])}
    top = max((r[3] for r in rows), default=0.0)
    top_held = max((r[3] for r in rows if "HELD" in r[4]), default=0.0)
    parts = {k: {"clips_into": [], "flat": None, "thickness_ratio": None} for k in chk.parts}
    agg = {}
    for cname, frame, pair, depth, flags in rows:
        a, c = pair.split(">")
        e = agg.setdefault((a, c), {"other": c, "max_cm": 0.0, "frames": 0, "held": 0, "held_max_cm": 0.0})
        e["max_cm"] = max(e["max_cm"], depth)
        if depth > HELD_CM:
            e["frames"] += 1
            e["held"] += "HELD" in flags
        if "HELD" in flags:
            e["held_max_cm"] = max(e["held_max_cm"], depth)
    for (a, c), e in sorted(agg.items(), key=lambda kv: -kv[1]["max_cm"]):
        parts[a]["clips_into"].append(e)
    flat = {}
    for k, h in hand.items():
        rest, w = h["rest"], h["worst"]
        # the rest pose (a clip frame only re-blends the wrist): fused fingers or paper thin. Finger bones that carry no
        # mesh (Vex: belt beads ride hand.L) are a warning only: then the hand test measures what the hand bone carries
        rig_bad = chk.finger_bones_unused(k[-1])
        flat[k] = rest["finger_sep"] < FLAT_SEP or rest["ratio"] < FLAT_RATIO
        parts.setdefault(k, {"clips_into": []}).update(
            {
                "flat": bool(flat[k]),
                "thickness_ratio": rest["ratio"],
                "worst_ratio": w["ratio"],
                "worst_at": "%s:%d" % (w["clip"], w["frame"]),
                "thumb_lobe": rest["thumb_lobe"],
                "finger_sep": rest["finger_sep"],
                "finger_bones_unused": rig_bad,
            }
        )
    hl = (
        " | ".join(
            "HAND %s %s sep %.2f ratio %.2f%s"
            % (
                k.split("_")[-1],
                "FLAT" if flat[k] else "ok",
                hand[k]["rest"]["finger_sep"],
                hand[k]["rest"]["ratio"],
                " fingers-unrigged" if parts[k]["finger_bones_unused"] else "",
            )
            for k in sorted(hand)
        )
        or "HAND none"
    )
    line = "%s: CLIP worst %.1f cm in %d frames (held %d, held worst %.1f cm) | %s" % (
        chk.key,
        top,
        len(over),
        len(over_held),
        top_held,
        hl,
    )
    stats = {
        "worst_cm": top,
        "held_worst_cm": top_held,
        "frames": len(over),
        "held_frames": len(over_held),
        "flat": flat,
        "ratios": {k: [hand[k]["rest"]["ratio"], hand[k]["worst"]["ratio"]] for k in hand},
        "seps": {k: hand[k]["rest"]["finger_sep"] for k in hand},
        "pairs": {"%s>%s" % k: [round(e["held_max_cm"], 2), round(e["max_cm"], 2)] for k, e in agg.items()},
    }
    return line, parts, stats


def glb_blob(path):
    """git blob hash of the file (so a reader can tell the audit is stale)."""
    r = subprocess.run(["git", "hash-object", path], capture_output=True, text=True)
    return r.stdout.strip() or None


def native_glb(key, root="."):
    """The in-game glb of a hunter (content/rules/warden_native.json: meshy_native -> <key>_meshy.glb)."""
    cfg = json.load(open(os.path.join(root, "content/rules/warden_native.json"))).get(key, {})
    name = key + ("_meshy" if cfg.get("meshy_native") else "")
    return os.path.join(root, "art/wardens", key, name + ".glb")


KEYS = "claire ostra breaker hem ryzz dredge gil tarek pip kael vex cinder sable".split()


def verdict(stats, live=None):
    """['reason', ...] why a glb FAILs: a held clip over 1 cm, a FLAT hand, worse than the live glb."""
    why = []
    if stats["held_worst_cm"] > HELD_CM:
        why.append("held clip clips %.1f cm" % stats["held_worst_cm"])
    why += [
        "hand %s FLAT (sep %.2f, ratio %.2f)" % (k, stats["seps"][k], stats["ratios"][k][0])
        for k, v in stats["flat"].items()
        if v
    ]
    if live:
        for pair, (held, _all) in stats["pairs"].items():
            if held > live["pairs"].get(pair, [0, 0])[0] + WORSE_CM and held > HELD_CM:
                why.append("worse than live: %s %.1f cm (live %.1f)" % (pair, held, live["pairs"].get(pair, [0])[0]))
        for k, (rest, worst) in stats["ratios"].items():
            if k in live["ratios"] and rest < live["ratios"][k][0] - WORSE_RATIO:
                why.append("worse than live: hand %s ratio %.2f (live %.2f)" % (k, rest, live["ratios"][k][0]))
        for k, sep in stats["seps"].items():
            if k in live.get("seps", {}) and sep < live["seps"][k] - WORSE_SEP:
                why.append("worse than live: hand %s finger separation %.2f (live %.2f)" % (k, sep, live["seps"][k]))
    return why


def dump_shots(chk, key, worst, out, count=3):
    """Writes the `count` worst frames (distinct clip frames) as posed meshes for tools/geo_shots.gd (--geo-shots)."""
    os.makedirs(out, exist_ok=True)
    seen, names = set(), []
    for pair, (depth, clip, frame, at) in sorted(worst.items(), key=lambda kv: -kv[1][0]):
        if (clip, frame) in seen or len(names) == count:
            continue
        seen.add((clip, frame))
        a, c = pair
        anim = next((x for x in chk.anims if x["name"] == clip), None)
        S = chk.rig.skin_mats(anim, np.array([frame / FPS]))[0]
        every = np.arange(len(chk.mesh["pos"]))
        pos, nrm = skin_points(S, chk.mesh, every)
        grp = np.zeros(len(pos), np.uint8)
        grp[chk.parts[c]] = 2
        grp[chk.parts[a]] = 1
        tri = chk.mesh["tris"]
        centre = pos.mean(0)
        v = np.array([at[0] - centre[0], 0.2, at[2] - centre[2]])
        if np.hypot(v[0], v[2]) < 0.05:
            v = np.array([0.0, 0.2, 1.0])
        name = "%s_%d" % (key, len(names) + 1)
        with open(os.path.join(out, name + ".bin"), "wb") as f:
            f.write(
                pos.astype("<f4").tobytes()
                + nrm.astype("<f4").tobytes()
                + tri.astype("<i4").tobytes()
                + grp[tri[:, 0]].tobytes()
            )
        json.dump(
            {
                "key": key,
                "clip": clip,
                "frame": frame,
                "pair": "%s>%s" % pair,
                "cm": round(depth * 100, 2),
                "held": clip == "rest" or bool(HELD.match(clip)),
                "nv": len(pos),
                "nt": len(tri),
                "at": [float(x) for x in at],
                "view": [float(x) for x in v],
                "height": float(pos[:, 1].max()),
            },
            open(os.path.join(out, name + ".json"), "w"),
        )
        names.append(name)
    return names


def make_sheets(meta_dir, png_dir, out, per_page=5, width=1600):
    """Contact sheets (width px wide, one hunter a row, its 3 worst frames close up with the whole body inset) from
    the --dump-shots metas and the PNGs tools/geo_shots.gd rendered. Border: red = a held clip over 1 cm, grey = not."""
    from PIL import Image, ImageDraw

    tile = (width - 4 * 10) // 3
    keys = [k for k in KEYS if os.path.exists(os.path.join(meta_dir, k + "_1.json"))]
    pages = []
    for p0 in range(0, len(keys), per_page):
        rows = []
        for k in keys[p0 : p0 + per_page]:
            row = Image.new("RGB", (width, tile + 28), (30, 30, 34))
            d = ImageDraw.Draw(row)
            for i in range(3):
                n = "%s_%d" % (k, i + 1)
                if not os.path.exists(os.path.join(meta_dir, n + ".json")):
                    continue
                m = json.load(open(os.path.join(meta_dir, n + ".json")))
                im = Image.open(os.path.join(png_dir, n + "_close.png")).convert("RGB").resize((tile, tile))
                inset = Image.open(os.path.join(png_dir, n + "_full.png")).convert("RGB").resize((tile // 3, tile // 3))
                im.paste(inset, (tile - tile // 3, tile - tile // 3))
                col = (210, 40, 40) if m["held"] and m["cm"] > HELD_CM else (120, 120, 124)
                x = 10 + i * (tile + 10)
                ImageDraw.Draw(im).rectangle([0, 0, tile - 1, tile - 1], outline=col, width=6)
                row.paste(im, (x, 28))
                d.text(
                    (x, 8),
                    "%s  %s f%d  %s  %.1f cm" % (k, m["clip"], m["frame"], m["pair"], m["cm"]),
                    fill=(235, 235, 235),
                )
            rows.append(row)
        page = Image.new("RGB", (width, sum(r.height for r in rows)))
        y = 0
        for r in rows:
            page.paste(r, (0, y))
            y += r.height
        pages.append(page)
    for i, pg in enumerate(pages):
        pg.save(os.path.join(out, "sheet_%d.jpg" % (i + 1)), quality=88)
    return len(pages)


def run_one(path, key, out, quiet=False, shots=None):
    """Check one glb; write <out>/<key>.tsv and .json; (summary line, stats)."""
    chk = Check(path, key)
    t0 = len(chk.parts)
    if not quiet:
        print("%s: %d parts, %d pairs tested" % (key, t0, len(chk.pairs)), flush=True)
    rows, worst, hand = chk.run(log=lambda m: None)
    line, parts, stats = summarize(chk, rows, worst, hand)
    if shots:
        dump_shots(chk, key, worst, shots)
    if out:
        os.makedirs(out, exist_ok=True)
        with open(os.path.join(out, key + ".tsv"), "w") as f:
            f.write("clip\tframe\tpair\tdepth_cm\tflags\n")
            for r in sorted(rows, key=lambda r: -r[3]):
                f.write("\t".join(str(x) for x in r) + "\n")
        json.dump(
            {
                "glb_blob": glb_blob(path),
                "glb": path,
                "parts": parts,
                "stats": stats,
                "worst": [
                    {
                        "pair": "%s>%s" % k,
                        "cm": round(v[0] * 100, 2),
                        "clip": v[1],
                        "frame": v[2],
                        "at": [round(x, 4) for x in v[3]],
                    }
                    for k, v in sorted(worst.items(), key=lambda kv: -kv[1][0])[:12]
                ],
            },
            open(os.path.join(out, key + ".json"), "w"),
            indent=1,
        )
    return line, stats


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("glb", nargs="?")
    ap.add_argument("--compare", help="the live glb: the candidate must not be worse")
    ap.add_argument("--hunter", help="check the in-game glb of this hunter key")
    ap.add_argument("--all", action="store_true", help="all 13 hunters")
    ap.add_argument("--key")
    ap.add_argument("--out", default="geo_out")
    ap.add_argument("--sheets", nargs=3, metavar=("META_DIR", "PNG_DIR", "OUT_DIR"), help="build the contact sheets")
    ap.add_argument("--dump-shots", help="also write each hunter's 3 worst frames here for tools/geo_shots.gd")
    a = ap.parse_args()
    if a.sheets:
        print("%d sheets" % make_sheets(*a.sheets))
        return
    root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
    jobs = (
        [(k, native_glb(k, root)) for k in KEYS]
        if a.all
        else [(a.hunter, native_glb(a.hunter, root))]
        if a.hunter
        else [(a.key or os.path.basename(a.glb).split(".")[0], a.glb)]
    )
    fail = False
    for key, path in jobs:
        line, stats = run_one(path, key, a.out, shots=a.dump_shots)
        print(line, flush=True)
        live = run_one(a.compare, key + "_live", a.out, True)[1] if a.compare else None
        why = verdict(stats, live)
        print("%s %s%s" % (key, "FAIL" if why else "PASS", ": " + "; ".join(why) if why else ""), flush=True)
        fail |= bool(why)
    sys.exit(1 if fail else 0)


if __name__ == "__main__":
    main()
