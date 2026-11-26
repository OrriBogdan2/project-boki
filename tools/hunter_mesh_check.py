#!/usr/bin/env python3
"""Absolute mesh-quality gate for the shipped Hunter (warden) and Boki (kin) GLBs.

The merge gate only compares test results against main, and the older model checks only counted joints and
clips, so a shredded, spiky or see-through Hunter could ship. This reads every art/wardens/**/*.glb and art/kin/**/*.glb with plain
numpy (no pygltflib/trimesh needed; PIL is optional, only for the review PNG) and checks defects as absolute
numbers, not as a diff:

  bind pose   NaN/Inf, degenerate + sliver triangles, spike edges vs the median edge, floating islands far
              from the body, open boundary edges, non-manifold edges
  skinning    CPU-skins every clip at N frames; per edge, stretch vs bind (> STRETCH_MAX or < COLLAPSE_MIN);
              vertices whose weights do not sum to 1, or that bind to a joint far from them
  materials   alphaMode BLEND on body materials (sorting makes it see-through), alpha < 1, missing textures,
              textures that are mostly transparent or black

Each Hunter gets PASS / WARN / FAIL, counts, the worst clip + frame, and a PNG of the flagged triangles.
Thresholds were calibrated on the live GLBs: Tenzo (tarek), Neve (claire) and Grimble (dredge) must FAIL.

Usage:
  python3 tools/hunter_mesh_check.py                              # every art/wardens/*/*.glb
  python3 tools/hunter_mesh_check.py art/kin                      # every Boki glb
  python3 tools/hunter_mesh_check.py art/wardens/tarek/tarek.glb --out build/mesh --json build/mesh/r.json
  python3 tools/hunter_mesh_check.py --base origin/main --changed-vs origin/main   # PR gate: head vs main
  python3 tools/hunter_mesh_check.py --base origin/main --changed-vs origin/main --head-ref refs/pull/N/head  # no checkout
Exit code: 0 = no FAIL and no new WARN vs the base, 1 = FAIL or new WARN, 2 = usage/read error.
"""

from __future__ import annotations

import argparse
import json
import math
import re
import struct
import subprocess
import sys
from pathlib import Path

import numpy as np

# ---- thresholds (calibrated on the live GLBs) ----
STRETCH_MAX = 2.5  # an edge longer than this x its bind length is torn
COLLAPSE_MIN = 0.3  # an edge shorter than this x its bind length is crushed
VISIBLE_H = 0.04  # ...but only if the torn/crushed edge is at least this x body height (tiny edges jitter freely)
STATIC_MOVE = 0.003  # a clip whose every vertex stays within this x body height of the rest pose is not animating
SLIVER_Q = 0.02  # triangle quality 4*sqrt(3)*A / sum(l^2): 1 = equilateral, ~0 = needle
SPIKE_RATIO = 12.0  # a needle triangle: longest edge more than this x the median edge of the mesh (bind pose)...
SPIKE_Q = 0.15  # ...and quality below this (long flat panels are fine, long thin shards are not)
WEIGHT_TOL = 0.02  # |sum of weights - 1| allowed
FAR_BONE = 0.30  # a weight > 0.2 on a joint farther than this x body height from the vertex
ISLAND_GAP = 0.10  # an island this far (x body height) from the main body floats
ISLAND_MIN_TRIS = 20  # smaller floating islands are ignored (pins, buttons)
WELD = 1e-5  # position weld size (x body height) for topology
# A defect becomes WARN above WARN_*, FAIL above FAIL_* (share of triangles / vertices, or a plain count).
LIMITS = {
    # absolute defects: FAIL = the model is broken (shredded / torn / holes), WARN = ugly, worth a look
    "nan": (0, 0),
    "degenerate_tris": (0.0005, 0.005),
    "sliver_tris": (0.005, 0.03),
    "spike_edges": (0.0002, 0.01),
    "floating_islands": (0, 2),
    "open_boundary_edges": (0.02, 0.15),
    "nonmanifold_edges": (0.002, 0.005),
    "bad_weight_sum": (0.0005, 0.005),
    "far_bone_verts": (0.0005, 0.20),
    "rest_collapsed": (0.0002, 0.0012),
    "stretched_tris": (0.005, 0.08),
    "collapsed_tris": (0.003, 0.05),
    "no_skin": (0, 0),
    "no_clips": (0, 0),
    "all_clips_static": (0, 0),
    "static_clips": (0, 10**9),
    "blend_materials": (0, 0),
    "alpha_lt1_materials": (0, 0),
    "missing_texture": (0, 0),
    "transparent_texels": (0.05, 0.25),
    "black_texels": (0.15, 0.60),
}
# Counts (not shares) use these keys.
COUNT_KEYS = {
    "no_skin",
    "no_clips",
    "all_clips_static",
    "static_clips",
    "nan",
    "floating_islands",
    "blend_materials",
    "alpha_lt1_materials",
    "missing_texture",
}
# Materials whose job is to be see-through or emissive; BLEND there is a design choice, still reported as INFO.
BLEND_OK = re.compile(r"(eye|glow|flame|fx|cards|spark|aura)", re.I)

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16, 5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


# ------------------------------------------------------------------ GLB reading
class Glb:
    def __init__(self, data: bytes):
        magic, _ver, _length = struct.unpack("<4sII", data[:12])
        if magic != b"glTF":
            raise ValueError("not a GLB")
        off, self.bin = 12, b""
        while off < len(data):
            n, kind = struct.unpack("<I4s", data[off : off + 8])
            chunk = data[off + 8 : off + 8 + n]
            if kind == b"JSON":
                self.j = json.loads(chunk)
            elif kind == b"BIN\x00":
                self.bin = chunk
            off += 8 + n

    def acc(self, i: int) -> np.ndarray:
        a = self.j["accessors"][i]
        ncomp = NC[a["type"]]
        dt = np.dtype(CT[a["componentType"]])
        count = a["count"]
        if "bufferView" not in a:
            return np.zeros((count, ncomp), dtype=np.float64)
        bv = self.j["bufferViews"][a["bufferView"]]
        start = bv.get("byteOffset", 0) + a.get("byteOffset", 0)
        stride = bv.get("byteStride") or dt.itemsize * ncomp
        arr = np.ndarray((count, ncomp), dtype=dt, buffer=self.bin, offset=start, strides=(stride, dt.itemsize)).astype(
            np.float64
        )
        if a.get("normalized") and dt.kind in "iu":
            arr = arr / float(np.iinfo(dt).max)
            if dt.kind == "i":
                arr = np.maximum(arr, -1.0)
        return arr

    def image(self, i: int):
        try:
            from PIL import Image
        except ImportError:
            return None
        import io

        img = self.j["images"][i]
        if "bufferView" not in img:
            return None
        bv = self.j["bufferViews"][img["bufferView"]]
        off = bv.get("byteOffset", 0)
        return Image.open(io.BytesIO(self.bin[off : off + bv["byteLength"]]))


def quat_to_mat(q: np.ndarray) -> np.ndarray:
    x, y, z, w = q
    return np.array(
        [
            [1 - 2 * (y * y + z * z), 2 * (x * y - z * w), 2 * (x * z + y * w)],
            [2 * (x * y + z * w), 1 - 2 * (x * x + z * z), 2 * (y * z - x * w)],
            [2 * (x * z - y * w), 2 * (y * z + x * w), 1 - 2 * (x * x + y * y)],
        ]
    )


def trs_matrix(t, r, s) -> np.ndarray:
    m = np.eye(4)
    m[:3, :3] = quat_to_mat(np.asarray(r) / (np.linalg.norm(r) or 1.0)) * np.asarray(s)[None, :]
    m[:3, 3] = t
    return m


def slerp(a: np.ndarray, b: np.ndarray, u: float) -> np.ndarray:
    d = float(np.dot(a, b))
    if d < 0:
        b, d = -b, -d
    if d > 0.9995:
        r = a + u * (b - a)
    else:
        th = math.acos(d)
        r = (math.sin((1 - u) * th) * a + math.sin(u * th) * b) / math.sin(th)
    return r / (np.linalg.norm(r) or 1.0)


class Rig:
    """Skeleton + clips of one GLB; world matrices per node for a clip time."""

    def __init__(self, g: Glb):
        j = g.j
        self.g = g
        self.nodes = j["nodes"]
        n = len(self.nodes)
        self.parent = [-1] * n
        for i, nd in enumerate(self.nodes):
            for c in nd.get("children", []):
                self.parent[c] = i
        self.order = self._topo()
        self.rest = [self._local(nd) for nd in self.nodes]
        self.clips = []
        for an in j.get("animations", []):
            chans = []
            for ch in an["channels"]:
                tgt = ch["target"]
                if "node" not in tgt or tgt["path"] not in ("translation", "rotation", "scale"):
                    continue
                s = an["samplers"][ch["sampler"]]
                chans.append(
                    (
                        tgt["node"],
                        tgt["path"],
                        g.acc(s["input"])[:, 0],
                        g.acc(s["output"]),
                        s.get("interpolation", "LINEAR"),
                    )
                )
            dur = max((c[2][-1] for c in chans if len(c[2])), default=0.0)
            self.clips.append((an.get("name", "anim"), dur, chans))

    @staticmethod
    def _local(nd):
        return (
            np.array(nd.get("translation", [0, 0, 0]), dtype=np.float64),
            np.array(nd.get("rotation", [0, 0, 0, 1]), dtype=np.float64),
            np.array(nd.get("scale", [1, 1, 1]), dtype=np.float64),
        )

    def _topo(self):
        out, seen = [], set()

        def visit(i):
            if i in seen:
                return
            seen.add(i)
            out.append(i)
            for c in self.nodes[i].get("children", []):
                visit(c)

        for i in range(len(self.nodes)):
            if self.parent[i] == -1:
                visit(i)
        return out

    @staticmethod
    def _sample(times, vals, interp, t, is_rot):
        if len(times) == 1 or t <= times[0]:
            v = vals[0] if interp != "CUBICSPLINE" else vals[1]
            return v
        if t >= times[-1]:
            return vals[-1] if interp != "CUBICSPLINE" else vals[-2]
        k = int(np.searchsorted(times, t, side="right")) - 1
        u = (t - times[k]) / max(times[k + 1] - times[k], 1e-12)
        if interp == "STEP":
            return vals[k]
        if interp == "CUBICSPLINE":
            a, b = vals[3 * k + 1], vals[3 * (k + 1) + 1]
        else:
            a, b = vals[k], vals[k + 1]
        return slerp(a, b, u) if is_rot else a + u * (b - a)

    def world(self, clip: int | None, t: float) -> list[np.ndarray]:
        local = {i: list(self.rest[i]) for i in range(len(self.nodes))}
        if clip is not None:
            for node, path, times, vals, interp in self.clips[clip][2]:
                idx = {"translation": 0, "rotation": 1, "scale": 2}[path]
                local[node][idx] = self._sample(times, vals, interp, t, path == "rotation")
        w: list = [None] * len(self.nodes)
        for i in self.order:
            m = trs_matrix(*local[i])
            w[i] = m if self.parent[i] == -1 else w[self.parent[i]] @ m
        return w


# ------------------------------------------------------------------ mesh gathering
class Body:
    """All skinned primitives of a GLB merged into one vertex/triangle soup in skin (bind) space."""

    def __init__(self, g: Glb):
        j = g.j
        self.pos, self.joints, self.weights, self.mat_of_tri = [], [], [], []
        self.tris, self.skin = [], None
        base = 0
        for nd in j["nodes"]:
            if "mesh" not in nd:
                continue
            if "skin" in nd and self.skin is None:
                self.skin = nd["skin"]
            for p in j["meshes"][nd["mesh"]]["primitives"]:
                at = p["attributes"]
                if "POSITION" not in at or p.get("mode", 4) != 4:
                    continue
                pos = g.acc(at["POSITION"])
                n = len(pos)
                idx = g.acc(p["indices"])[:, 0].astype(np.int64) if "indices" in p else np.arange(n)
                tri = idx.reshape(-1, 3) + base
                self.pos.append(pos)
                self.tris.append(tri)
                self.mat_of_tri.append(np.full(len(tri), p.get("material", -1)))
                if "JOINTS_0" in at and "WEIGHTS_0" in at:
                    self.joints.append(g.acc(at["JOINTS_0"]).astype(np.int64))
                    self.weights.append(g.acc(at["WEIGHTS_0"]))
                else:
                    self.joints.append(np.zeros((n, 4), dtype=np.int64))
                    self.weights.append(np.zeros((n, 4)))
                base += n
        self.pos = np.concatenate(self.pos)
        self.tris = np.concatenate(self.tris)
        self.joints = np.concatenate(self.joints)
        self.weights = np.concatenate(self.weights)
        self.mat_of_tri = np.concatenate(self.mat_of_tri)


def skin_positions(body: Body, ibm: np.ndarray, jnodes: list[int], world: list[np.ndarray]) -> np.ndarray:
    jm = np.stack([world[n] @ ibm[k] for k, n in enumerate(jnodes)])  # (J,4,4)
    # Godot ignores the mesh node's own transform for skinned meshes, so skin space is the result space.
    sel = jm[body.joints]  # (V,4,4,4)
    ph = np.concatenate([body.pos, np.ones((len(body.pos), 1))], axis=1)
    per = np.einsum("vkij,vj->vki", sel, ph)[..., :3]  # (V,4,3)
    return np.einsum("vk,vki->vi", body.weights, per)


# ------------------------------------------------------------------ analyses
def tri_edges(tris: np.ndarray) -> np.ndarray:
    return np.stack([tris[:, [0, 1]], tris[:, [1, 2]], tris[:, [2, 0]]], axis=1)  # (T,3,2)


def edge_lengths(pos: np.ndarray, tris: np.ndarray) -> np.ndarray:
    e = tri_edges(tris)
    return np.linalg.norm(pos[e[..., 0]] - pos[e[..., 1]], axis=-1)  # (T,3)


def tri_quality(pos: np.ndarray, tris: np.ndarray):
    a, b, c = pos[tris[:, 0]], pos[tris[:, 1]], pos[tris[:, 2]]
    area = 0.5 * np.linalg.norm(np.cross(b - a, c - a), axis=1)
    l2 = ((b - a) ** 2).sum(1) + ((c - b) ** 2).sum(1) + ((a - c) ** 2).sum(1)
    return area, 4.0 * math.sqrt(3.0) * area / np.maximum(l2, 1e-30)


def weld(pos: np.ndarray, size: float) -> np.ndarray:
    key = np.round(pos / size).astype(np.int64)
    _, inv = np.unique(key, axis=0, return_inverse=True)
    return inv.reshape(-1)


def components(wtris: np.ndarray, nv: int) -> np.ndarray:
    parent = np.arange(nv)

    def find(x):
        while parent[x] != x:
            parent[x] = parent[parent[x]]
            x = parent[x]
        return x

    for a, b, c in wtris:
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra
        if find(c) != find(a):
            parent[find(c)] = find(a)
    return np.array([find(i) for i in range(nv)])


def bind_checks(body: Body, height: float) -> tuple[dict, dict]:
    pos, tris = body.pos, body.tris
    res, flags = {}, {}
    res["nan"] = int((~np.isfinite(pos)).any(axis=1).sum())
    ok = np.isfinite(pos).all(axis=1)
    good = ok[tris].all(axis=1)
    area, q = tri_quality(np.where(ok[:, None], pos, 0.0), tris)
    degenerate = good & (area < (1e-6 * height) ** 2)
    sliver = good & ~degenerate & (q < SLIVER_Q)
    el = edge_lengths(np.where(ok[:, None], pos, 0.0), tris)
    med = float(np.median(el[good])) if good.any() else 0.0
    spike = good & (el.max(axis=1) > SPIKE_RATIO * max(med, 1e-9)) & (q < SPIKE_Q)
    res["degenerate_tris"] = int(degenerate.sum())
    res["sliver_tris"] = int(sliver.sum())
    res["spike_edges"] = int(spike.sum())
    res["median_edge"] = med
    flags["degenerate_tris"], flags["sliver_tris"], flags["spike_edges"] = degenerate, sliver, spike
    # topology on welded positions
    w = weld(np.where(ok[:, None], pos, 0.0), max(WELD * height, 1e-9))
    wt = w[tris]
    nondeg = good & (wt[:, 0] != wt[:, 1]) & (wt[:, 1] != wt[:, 2]) & (wt[:, 0] != wt[:, 2])
    e = tri_edges(wt[nondeg]).reshape(-1, 2)
    e = np.sort(e, axis=1)
    uniq, cnt = np.unique(e, axis=0, return_counts=True)
    res["open_boundary_edges"] = int((cnt == 1).sum())
    res["nonmanifold_edges"] = int((cnt > 2).sum())
    res["edges_total"] = int(len(uniq))
    # boundary / non-manifold triangle flags
    boundary = set(map(tuple, uniq[cnt != 2].tolist()))
    tf = np.zeros(len(tris), dtype=bool)
    if boundary:
        ew = np.sort(tri_edges(wt), axis=2)
        keys = ew[..., 0].astype(np.int64) * (int(w.max()) + 1) + ew[..., 1]
        bset = np.array([a * (int(w.max()) + 1) + b for a, b in boundary], dtype=np.int64)
        tf = np.isin(keys, bset).any(axis=1) & nondeg
    flags["boundary_tris"] = tf
    # islands: connected components of welded vertices
    comp = components(wt[nondeg], int(w.max()) + 1)
    ctri = comp[wt[:, 0]]
    ids, counts = np.unique(ctri[nondeg], return_counts=True)
    main = ids[np.argmax(counts)]
    mmask = ctri == main
    mv = pos[tris[mmask & good]].reshape(-1, 3)
    lo, hi = mv.min(0), mv.max(0)
    floating, fl_tri = [], np.zeros(len(tris), dtype=bool)
    for cid, ct in zip(ids, counts):
        if cid == main or ct < ISLAND_MIN_TRIS:
            continue
        m = (ctri == cid) & good
        iv = pos[tris[m]].reshape(-1, 3)
        gap = np.maximum(0.0, np.maximum(lo - iv.max(0), iv.min(0) - hi))
        dist = float(np.linalg.norm(gap))
        if dist > ISLAND_GAP * height:
            floating.append({"tris": int(ct), "gap_h": round(dist / height, 3)})
            fl_tri |= m
    res["islands_total"] = int(len(ids))
    res["floating_islands"] = len(floating)
    res["floating_detail"] = floating[:6]
    flags["floating_tris"] = fl_tri
    return res, flags


def weight_checks(body: Body, ibm: np.ndarray, jnodes: list[int], rig: Rig, height: float) -> tuple[dict, dict]:
    pos = body.pos
    s = body.weights.sum(axis=1)
    bad_sum = np.abs(s - 1.0) > WEIGHT_TOL
    # joint bind heads from the inverse bind matrices, bone = head to children heads
    heads = np.stack([np.linalg.inv(ibm[k])[:3, 3] for k in range(len(jnodes))])
    jindex = {n: k for k, n in enumerate(jnodes)}
    segs = [[heads[k]] for k in range(len(jnodes))]
    for k, n in enumerate(jnodes):
        for c in rig.nodes[n].get("children", []):
            if c in jindex:
                segs[k].append(heads[jindex[c]])
    far = np.zeros(len(pos), dtype=bool)
    worst = np.zeros(len(pos))
    for k in range(len(jnodes)):
        use = ((body.joints == k) & (body.weights > 0.2)).any(axis=1)
        if not use.any():
            continue
        d = np.full(use.sum(), np.inf)
        for tail in segs[k]:
            a = heads[k]
            ab = tail - a
            den = float(ab @ ab)
            p = pos[use] - a
            t = np.clip((p @ ab) / den, 0, 1) if den > 1e-18 else np.zeros(len(p))
            d = np.minimum(d, np.linalg.norm(p - t[:, None] * ab[None, :], axis=1))
        worst[use] = np.maximum(worst[use], d)
    far = worst > FAR_BONE * height
    res = {
        "bad_weight_sum": int(bad_sum.sum()),
        "far_bone_verts": int(far.sum()),
        "far_bone_max_h": round(float(worst.max()) / height, 3),
    }
    vflag = bad_sum | far
    return res, {"bad_vertex": vflag}


def skin_checks(body, ibm, jnodes, rig, frames, clip_re, height):
    """Returns summary + per-triangle worst flags and the worst (clip, frame, positions)."""
    bind_len = edge_lengths(body.pos, body.tris)
    valid = bind_len > 1e-4 * height
    res = {"stretched_tris": 0, "collapsed_tris": 0}
    per_clip = {}
    st_any = np.zeros(len(body.tris), dtype=bool)
    co_any = np.zeros(len(body.tris), dtype=bool)
    worst = (-1, None, None, None, None)  # score, clip, frame, stretched mask, collapsed mask
    rest_pos = None
    moved: dict[str, float] = {}  # clip -> largest vertex displacement from the rest pose, x body height
    pose_sets = [("rest", 0, 0.0, None)]
    for ci, (name, dur, _) in enumerate(rig.clips):
        if clip_re and not re.search(clip_re, name):
            continue
        for f in range(frames):
            pose_sets.append((name, f, dur * f / max(frames - 1, 1), ci))
    for name, f, t, ci in pose_sets:
        world = rig.world(ci, t)
        sp = skin_positions(body, ibm, jnodes, world)
        if ci is None:
            rest_pos = sp
        elif rest_pos is not None:
            dv = np.linalg.norm(np.nan_to_num(sp - rest_pos, nan=0.0, posinf=0.0, neginf=0.0), axis=1)
            moved[name] = max(moved.get(name, 0.0), float(dv.max()) / height)
        ln = edge_lengths(sp, body.tris)
        ratio = np.where(valid, ln / np.maximum(bind_len, 1e-12), 1.0)
        # an edge touching a non-finite position counts as stretched
        bad = ~np.isfinite(ratio)
        st = (((ratio > STRETCH_MAX) & (ln > VISIBLE_H * height)) | bad).any(axis=1)
        co = ((ratio < COLLAPSE_MIN) & (bind_len > VISIBLE_H * height)).any(axis=1)
        if ci is None:
            res["rest_stretched"], res["rest_collapsed"] = int(st.sum()), int(co.sum())
        pc = per_clip.setdefault(name, {"stretched": 0, "collapsed": 0, "worst_frame": 0, "max_ratio": 1.0})
        n_st, n_co = int(st.sum()), int(co.sum())
        score = n_st + 0.2 * n_co
        if n_st > pc["stretched"] or (n_st == pc["stretched"] and n_co > pc["collapsed"]):
            pc.update(stretched=n_st, collapsed=n_co, worst_frame=f)
        pc["max_ratio"] = max(pc["max_ratio"], float(np.nan_to_num(ratio, nan=1e9, posinf=1e9).max()))
        st_any |= st
        co_any |= co
        if score > worst[0]:
            worst = (score, name, f, st, co)
    static = sorted(k for k, v in moved.items() if v < STATIC_MOVE)
    res["clips_total"], res["static_clips"] = len(moved), len(static)
    res["all_clips_static"] = int(bool(moved) and len(static) == len(moved))
    res["static_clip_names"] = static
    # headline counts = the worst single pose (what the player sees at its ugliest), not the union over clips
    res["stretched_tris"] = int(worst[3].sum()) if worst[3] is not None else 0
    res["collapsed_tris"] = int(worst[4].sum()) if worst[4] is not None else 0
    clip_st = [v["stretched"] for k, v in per_clip.items() if k != "rest"]
    res["stretched_median_clip"] = int(np.median(clip_st)) if clip_st else 0
    res["stretched_union"] = int(st_any.sum())
    res["collapsed_union"] = int(co_any.sum())
    res["worst_clip"] = worst[1]
    res["worst_frame"] = worst[2]
    top = sorted(per_clip.items(), key=lambda kv: -(kv[1]["stretched"] + 0.2 * kv[1]["collapsed"]))[:5]
    res["worst_clips"] = [{"clip": k, **v} for k, v in top]
    res["poses_checked"] = len(pose_sets)
    wpos = None
    if worst[1] is not None:
        ci = next((i for i, c in enumerate(rig.clips) if c[0] == worst[1]), None)
        dur = rig.clips[ci][1] if ci is not None else 0.0
        wpos = skin_positions(body, ibm, jnodes, rig.world(ci, dur * worst[2] / max(frames - 1, 1)))
    return res, {"stretched": worst[3], "collapsed": worst[4], "worst_pos": wpos}


def material_checks(g: Glb, body: Body) -> tuple[dict, list[str]]:
    j = g.j
    mats = j.get("materials", [])
    notes, blend, alpha, missing = [], [], [], []
    used = set(int(m) for m in np.unique(body.mat_of_tri) if m >= 0)
    ntri = np.bincount(body.mat_of_tri[body.mat_of_tri >= 0], minlength=len(mats)) if mats else []
    transparent, black = {}, {}
    for mi in sorted(used):
        m = mats[mi]
        name = m.get("name", f"mat{mi}")
        pbr = m.get("pbrMetallicRoughness", {})
        mode = m.get("alphaMode", "OPAQUE")
        if mode == "BLEND":
            (notes if BLEND_OK.search(name) else blend).append(
                f"{name} BLEND ({int(ntri[mi])} tris)" if not BLEND_OK.search(name) else f"{name} BLEND ok"
            )
        if pbr.get("baseColorFactor", [1, 1, 1, 1])[3] < 0.999:
            alpha.append(name)
        tex = pbr.get("baseColorTexture")
        if tex is None:
            if "baseColorFactor" not in pbr:
                missing.append(f"{name}: no baseColor")
            continue
        tj = j.get("textures", [])
        src = tj[tex["index"]].get("source") if tex["index"] < len(tj) else None
        if src is None and tex["index"] < len(tj):  # Boki glbs carry the image through EXT_texture_webp
            src = tj[tex["index"]].get("extensions", {}).get("EXT_texture_webp", {}).get("source")
        if src is None:
            missing.append(f"{name}: texture {tex['index']} has no image")
            continue
        img = g.image(src)
        if img is None:
            continue
        a = np.asarray(img.convert("RGBA").resize((128, 128)), dtype=np.uint8)
        if mode in ("BLEND", "MASK") and not BLEND_OK.search(name):
            transparent[name] = round(float((a[..., 3] < 128).mean()), 3)
        black[name] = round(float(((a[..., :3].max(axis=2) < 12) & (a[..., 3] > 128)).mean()), 3)
    res = {
        "blend_materials": len(blend),
        "alpha_lt1_materials": len(alpha),
        "missing_texture": len(missing),
        "transparent_texels": max(transparent.values(), default=0.0),
        "black_texels": max(black.values(), default=0.0),
        "material_notes": blend + alpha + missing + notes,
        "double_sided_materials": sum(1 for mi in used if mats[mi].get("doubleSided")),
        "materials_used": len(used),
    }
    return res, notes


# ------------------------------------------------------------------ verdict
def share_of(key: str, res: dict, ntri: int, nvert: int) -> float:
    v = res.get(key, 0)
    if key in COUNT_KEYS:
        return float(v)
    if key in ("bad_weight_sum", "far_bone_verts"):
        return v / max(nvert, 1)
    if key in ("spike_edges",):
        return v / max(ntri, 1)
    if key in ("open_boundary_edges", "nonmanifold_edges"):
        return v / max(res.get("edges_total", 1), 1)
    if key in ("transparent_texels", "black_texels"):
        return float(v)
    return v / max(ntri, 1)


def verdict(res: dict, ntri: int, nvert: int) -> tuple[str, dict[str, str]]:
    codes: dict[str, str] = {}
    for key, (warn, fail) in LIMITS.items():
        s = share_of(key, res, ntri, nvert)
        if s > fail:
            codes[key] = "FAIL"
        elif s > warn:
            codes[key] = "WARN"
    level = "FAIL" if "FAIL" in codes.values() else "WARN" if codes else "PASS"
    return level, codes


# ------------------------------------------------------------------ PNG
def render_png(path: Path, body: Body, flags: dict, worst_pos, title: str, lines: list[str]):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return False
    S = 560
    panels = []
    sets = [("bind pose", body.pos, "front")]
    if worst_pos is not None:
        sets.append((lines[0] if lines else "worst frame", worst_pos, "front"))
    colors = {
        "stretched": (255, 40, 40),
        "collapsed": (255, 160, 0),
        "boundary_tris": (60, 120, 255),
        "spike_edges": (255, 0, 255),
        "sliver_tris": (255, 255, 0),
        "degenerate_tris": (255, 255, 0),
        "floating_tris": (0, 220, 220),
    }
    for label, pos, _ in sets:
        fin = np.isfinite(pos).all(axis=1)
        lo = pos[fin].min(0)
        hi = pos[fin].max(0)
        # clip view to the body bind extent so a few exploded vertices do not shrink the model to a dot
        blo, bhi = np.percentile(body.pos[np.isfinite(body.pos).all(1)], [0.5, 99.5], axis=0)
        lo, hi = np.maximum(lo, blo - (bhi - blo) * 0.25), np.minimum(hi, bhi + (bhi - blo) * 0.25)
        scale = 0.92 * S / max(hi[1] - lo[1], (hi[0] - lo[0]) * 1.0, 1e-9)
        im = Image.new("RGB", (S, S + 40), (24, 24, 28))
        d = ImageDraw.Draw(im)
        tri = body.tris
        pts = np.stack(
            [(pos[:, 0] - (lo[0] + hi[0]) / 2) * scale + S / 2, S - 0.04 * S - (pos[:, 1] - lo[1]) * scale], axis=1
        )
        depth = pos[tri][..., 2].mean(axis=1)
        order = np.argsort(depth)  # +z is toward the viewer in glTF, draw far first
        light = np.clip(
            np.abs(
                np.cross(pos[tri[:, 1]] - pos[tri[:, 0]], pos[tri[:, 2]] - pos[tri[:, 0]])[:, 2]
                / np.maximum(
                    np.linalg.norm(np.cross(pos[tri[:, 1]] - pos[tri[:, 0]], pos[tri[:, 2]] - pos[tri[:, 0]]), axis=1),
                    1e-12,
                )
            ),
            0.0,
            1.0,
        )
        flagged = {}
        for k, col in colors.items():
            m = flags.get(k)
            if k in ("stretched", "collapsed") and label == "bind pose":
                continue
            if m is not None and m.any():
                flagged[k] = col
        for t in order:
            if not np.isfinite(pts[tri[t]]).all():
                continue
            g = int(70 + 110 * light[t])
            d.polygon([tuple(p) for p in pts[tri[t]]], fill=(g, g, g + 6))
        for k, col in flagged.items():
            for t in np.nonzero(flags[k])[0]:
                if np.isfinite(pts[tri[t]]).all():
                    d.polygon([tuple(p) for p in pts[tri[t]]], fill=col)
        d.text((8, S + 6), label, fill=(230, 230, 230))
        d.text((8, S + 22), "  ".join(f"{k}" for k in flagged) or "nothing flagged", fill=(230, 200, 120))
        panels.append(im)
    out = Image.new("RGB", (S * len(panels), S + 70), (24, 24, 28))
    for i, p in enumerate(panels):
        out.paste(p, (i * S, 0))
    ImageDraw.Draw(out).text((8, S + 48), title, fill=(255, 255, 255))
    path.parent.mkdir(parents=True, exist_ok=True)
    out.save(path)
    return True


# ------------------------------------------------------------------ driver
def check_glb(data: bytes, name: str, frames: int, clip_re: str | None, png: Path | None, hunter: bool = False) -> dict:
    g = Glb(data)
    if not g.j.get("meshes"):  # a clip library (e.g. vex_cast_clips.glb): nothing to render, nothing to tear
        return {
            "name": name,
            "tris": 0,
            "verts": 0,
            "verdict": "PASS",
            "codes": {},
            "notes": ["no mesh: clip-only file"],
        }
    body = Body(g)
    ntri, nvert = len(body.tris), len(body.pos)
    fin = np.isfinite(body.pos).all(axis=1)
    height = float(body.pos[fin][:, 1].max() - body.pos[fin][:, 1].min()) or 1.0
    res: dict = {"name": name, "tris": ntri, "verts": nvert, "height": round(height, 3)}
    r, flags = bind_checks(body, height)
    res.update(r)
    if body.skin is None or not g.j.get("skins"):
        res["notes"] = ["no skin: skinning checks skipped"]
        res["no_skin"], res["joints"] = 1, 0
        wflags = {}
        worst_pos = None
    else:
        skin = g.j["skins"][body.skin]
        jnodes = skin["joints"]
        ibm = (
            g.acc(skin["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
            if "inverseBindMatrices" in skin
            else np.stack([np.eye(4)] * len(jnodes))
        )
        rig = Rig(g)
        r, wflags = weight_checks(body, ibm, jnodes, rig, height)
        res.update(r)
        r, sflags = skin_checks(body, ibm, jnodes, rig, frames, clip_re, height)
        worst_pos = sflags.pop("worst_pos")
        res.update(r)
        flags.update({k: v for k, v in sflags.items() if v is not None})
        res["clips"] = len(rig.clips)
        res["joints"] = len(jnodes)
        res["no_clips"] = int(not rig.clips)
    r, _ = material_checks(g, body)
    res.update(r)
    level, codes = verdict(res, ntri, nvert)
    if (
        hunter and codes.get("no_clips") == "FAIL"
    ):  # a hunter's poses can come from HunterAnim (gil.json): a clip-less glb is a WARN there
        codes["no_clips"] = "WARN"
        level = "FAIL" if "FAIL" in codes.values() else "WARN"
    res["verdict"], res["codes"] = level, codes
    if png is not None:
        title = f"{name}: {level}  " + " ".join(f"{k}={res.get(k)}" for k in codes)
        label = (
            f"worst pose: {res.get('worst_clip')} f{res.get('worst_frame')}" if res.get("worst_clip") else "worst frame"
        )
        wf = {**flags}
        res["png"] = str(png) if render_png(png, body, wf, worst_pos, title, [label]) else None
    return res


def hunter_name(path: str) -> str:
    p = Path(path)
    return p.parent.name if p.stem == p.parent.name else p.stem


def git_bytes(ref: str, path: str) -> bytes | None:
    r = subprocess.run(["git", "show", f"{ref}:{path}"], capture_output=True)
    return r.stdout if r.returncode == 0 and r.stdout else None


MODEL_DIRS = ("art/wardens", "art/kin")  # Hunters and Boki (kin): <dir>/<name>/<name>.glb


def changed_hunters(base: str, head: str | None = None) -> list[str]:
    """Model GLBs a branch touches vs `base`: the .glb itself, or any file next to it (.import, textures), or the warden clips json."""
    r = subprocess.run(
        ["git", "diff", "--name-only", f"{base}...{head or 'HEAD'}", "--", *MODEL_DIRS, "content/rules"],
        capture_output=True,
        text=True,
    )
    out: list[str] = []

    def add(glb: str):
        if glb not in out and (git_bytes(head, glb) is not None if head else Path(glb).exists()):
            out.append(glb)

    for p in r.stdout.split():
        m = re.match(r"(art/wardens|art/kin)/([^/]+)/", p)
        if m and m.group(2) != "src":
            if p.endswith(".glb"):
                add(p)
            add(f"{m.group(1)}/{m.group(2)}/{m.group(2)}.glb")
        m = re.match(r"content/rules/warden_anim/([^/.]+)\.json", p)
        if m:
            add(f"art/wardens/{m.group(1)}/{m.group(1)}.glb")
    return out


def new_warnings(head: dict, base: dict | None) -> list[str]:
    """WARN codes that are new or grew (>10% and >= 5 more) vs the base GLB; a model new to main has base None."""
    out = []
    rank = {"PASS": 0, "WARN": 1, "FAIL": 2}
    if base is not None and rank[head["verdict"]] < rank[base["verdict"]]:
        return out  # the new GLB is better overall than main's: not a regression
    for code, lvl in head["codes"].items():
        if lvl != "WARN":
            continue
        if base is None or code not in base["codes"]:
            out.append(code)
        elif head.get(code, 0) > base.get(code, 0) * 1.1 and head.get(code, 0) - base.get(code, 0) >= 5:
            out.append(f"{code} {base.get(code, 0)}->{head.get(code, 0)}")
    return out


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(
        description=__doc__.split("\n\n")[0], formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("paths", nargs="*", help="GLB files or directories (default art/wardens)")  # kin: pass art/kin
    ap.add_argument("--out", type=Path, help="directory for the review PNGs")
    ap.add_argument("--json", type=Path, help="write the full results here")
    ap.add_argument("--frames", type=int, default=8, help="frames sampled per clip (default 8)")
    ap.add_argument("--clips", default=None, help="regex on clip names (default: every clip)")
    ap.add_argument(
        "--base", help="git ref to compare against: each GLB is also checked at that ref, no new WARN allowed"
    )
    ap.add_argument(
        "--changed-vs", help="only check hunters whose art/wardens or warden_anim files differ from this ref"
    )
    ap.add_argument(
        "--head-ref",
        help="read the GLBs from this git ref instead of the working tree (scan a PR head without a checkout)",
    )
    ap.add_argument(
        "--review",
        action="store_true",
        help="fix-review mode: also render each GLB against live (--live GLB, or the --base ref) and FAIL on black patches, "
        "holes, loose bits, a changed silhouette, lost clips (tools/hunter_mesh_review.py)",
    )
    ap.add_argument("--live", type=Path, help="with --review: the live GLB to compare one file against")
    ap.add_argument("--quiet", action="store_true", help="only print the verdict table")
    a = ap.parse_args(argv)

    files: list[str] = []
    if a.changed_vs:
        files = changed_hunters(a.changed_vs, a.head_ref)
        if not files:
            print("no hunter files changed vs", a.changed_vs)
    else:
        for p in a.paths or ["art/wardens"]:
            pp = Path(p)
            if a.head_ref and pp.is_dir():
                ls = subprocess.run(
                    ["git", "ls-tree", "-r", "--name-only", a.head_ref, p], capture_output=True, text=True
                ).stdout.split()
                files += sorted(x for x in ls if x.endswith(".glb"))
            else:
                files += sorted(str(x) for x in pp.rglob("*.glb")) if pp.is_dir() else [p]
    results, rc = [], 0
    for f in files:
        try:
            nm = hunter_name(f)
            png = a.out / f"{nm}.png" if a.out else None
            data = git_bytes(a.head_ref, f) if a.head_ref else Path(f).read_bytes()
            if data is None:
                raise FileNotFoundError(f"{f} not in {a.head_ref}")
            res = check_glb(data, nm, a.frames, a.clips, png, f.startswith("art/wardens"))
            base = None
            if a.base:
                bd = git_bytes(a.base, f)
                base = check_glb(bd, nm + "@base", a.frames, a.clips, None, f.startswith("art/wardens")) if bd else None
                res["base_verdict"] = base["verdict"] if base else "(new)"
                res["base_codes"] = base["codes"] if base else {}
            res["new_warnings"] = new_warnings(res, base) if a.base else []
            if a.review:
                live_bytes = a.live.read_bytes() if a.live else git_bytes(a.base, f) if a.base else None
                if live_bytes is None:
                    raise FileNotFoundError("--review needs --live GLB or --base REF with the GLB in it")
                import hunter_mesh_review as hmr

                rv = hmr.compare(live_bytes, data, a.frames, a.clips, a.out, nm)
                res["review"] = rv
                res["codes"].update({"review_" + k: v for k, v in rv["codes"].items()})
                if rv["verdict"] == "FAIL":
                    res["verdict"] = "FAIL"
            results.append(res)
        except Exception as ex:  # noqa: BLE001 - report which file broke, keep checking the rest
            print(f"ERROR {f}: {ex!r}", file=sys.stderr)
            rc = 2
    fails = [r for r in results if r["verdict"] == "FAIL"]
    for r in results:
        codes = " ".join(f"{k}={r.get(k, '')}[{v}]" for k, v in r["codes"].items()) or "-"
        worst = f"worst {r.get('worst_clip')} f{r.get('worst_frame')}" if r.get("worst_clip") else ""
        extra = f"  base={r['base_verdict']} new_warn={r['new_warnings']}" if a.base else ""
        print(f"{r['verdict']:4} {r['name']:8} tris={r['tris']} {worst} {codes}{extra}")
        for k, (lv, fv, where) in (r.get("review") or {}).get("worst", {}).items():
            if r["codes"].get("review_" + k) and not a.quiet:
                print(f"       review {k}: live {lv} -> fix {fv} at {where}")
        for k, (v, where) in (r.get("review") or {}).get("sil", {}).items():
            if r["codes"].get("review_sil_" + k) and not a.quiet:
                print(f"       review silhouette {k}: {v * 100:.1f}% of live changed at {where}")
        if not a.quiet and r["codes"]:
            for c in r.get("worst_clips", [])[:3]:
                print(
                    f"       clip {c['clip']}: stretched={c['stretched']} collapsed={c['collapsed']} f{c['worst_frame']}"
                )
    if a.json:
        a.json.parent.mkdir(parents=True, exist_ok=True)
        a.json.write_text(json.dumps(results, indent=1, default=lambda o: o.item() if hasattr(o, "item") else str(o)))
    if rc == 2:
        return 2
    if fails or any(r["new_warnings"] for r in results):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
