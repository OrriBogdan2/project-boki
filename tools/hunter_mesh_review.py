#!/usr/bin/env python3
"""Hunter fix review: the visual checks a reviewer runs on a fixed Hunter GLB, as numbers against the live GLB.

hunter_mesh_check.py measures one GLB (stretch, open edges, islands). A tear fix can cut the stretch 99% and still fail
review, because the reviewer looks at renders: black blobs where skin was cut away, see-through holes, loose bits and
a body that no longer matches live. This renders the live and the fixed GLB the same way (CPU z-buffer, textured,
orthographic front and side, every clip at N frames, same camera) and compares them:

  silhouette   mask difference vs live at rest and in the idle clips (the body must still look like live)
  black        textured pixels darker than BLACK_MAX (black patches / unpainted skin)
  inside       pixels whose nearest surface faces away from the camera: a hole into the dark inside of the shell
  holes        background pixels fully enclosed by the body (see-through holes)
  loose        separate body blobs (a bit that came off) and thin shards (pixels an opening removes: spikes, needles)
  mesh         triangles and clips lost vs live, bind-pose vertices moved, new open boundary edges

A defect FAILs only if it is worse than live by more than a slack (live's own flaws never fail a fix). Used by
hunter_mesh_check.py (`--review --live`/`--base`), which carries the exit code.
"""

from __future__ import annotations

import re
from pathlib import Path

import numpy as np

import hunter_mesh_check as hmc

RES = 512  # image side in pixels; the window is VIEW_H x body height tall
VIEW_H = 1.5
BLACK_MAX = 40  # a texel whose brightest channel is below this is black
AREA_MIN = 12  # blobs/holes smaller than this many pixels are specks, counted apart
# FAIL when cand_worst > live_worst * (1 + REL) + SLACK[metric]; the worst is taken over every clip, frame and view.
REL = 0.25
SLACK = {"black_px": 40, "inside_px": 25, "hole_comps": 2, "blobs": 1, "specks": 6, "shard_px": 30}
SIL_REST = 0.015  # silhouette change at rest, share of live area
SIL_IDLE = 0.05  # in the idle clips
SIL_ANIM = 0.20  # other clips: WARN only (a fix is meant to change torn poses)
BIND_MOVED = 0.002  # a bind-pose vertex moved more than this x body height
LOST_TRIS = 0.002  # share of live triangles missing from the fix
NEW_OPEN = 0.002  # share of edges that are new open boundary edges vs live
IDLE_RE = re.compile(r"^idle", re.I)
VIEWS = ("front", "side")


# ------------------------------------------------------------------ materials
def body_uvs(g: hmc.Glb) -> np.ndarray:
    """TEXCOORD_0 per vertex in the order hmc.Body gathers them (zeros where a primitive has none)."""
    out = []
    for nd in g.j["nodes"]:
        if "mesh" not in nd:
            continue
        for p in g.j["meshes"][nd["mesh"]]["primitives"]:
            at = p["attributes"]
            if "POSITION" not in at or p.get("mode", 4) != 4:
                continue
            n = g.j["accessors"][at["POSITION"]]["count"]
            out.append(g.acc(at["TEXCOORD_0"]) if "TEXCOORD_0" in at else np.zeros((n, 2)))
    return np.concatenate(out)


def material_table(g: hmc.Glb) -> list[tuple[np.ndarray, np.ndarray | None]]:
    """Per material: (rgb factor 0-255, texture HxWx4 uint8 or None, cutout: texel alpha < 0.5 is not drawn, fx: see-through by design)."""
    out = []
    tj = g.j.get("textures", [])
    for m in g.j.get("materials", []):
        pbr = m.get("pbrMetallicRoughness", {})
        fac = np.array(pbr.get("baseColorFactor", [1, 1, 1, 1])[:3], dtype=np.float64) * 255.0
        tex = None
        ref = pbr.get("baseColorTexture")
        if ref is not None and ref["index"] < len(tj):
            src = tj[ref["index"]].get("source")
            if src is None:
                src = tj[ref["index"]].get("extensions", {}).get("EXT_texture_webp", {}).get("source")
            img = g.image(src) if src is not None else None
            if img is not None:
                img = img.convert("RGBA")
                if max(img.size) > 1024:
                    img = img.resize((1024, 1024))
                tex = np.asarray(img, dtype=np.uint8)
        cutout = m.get("alphaMode", "OPAQUE") != "OPAQUE"
        out.append((fac, tex, cutout, bool(hmc.BLEND_OK.search(m.get("name", "")))))
    out.append((np.array([200.0, 200.0, 200.0]), None, False, False))  # material -1
    return out


# ------------------------------------------------------------------ rasteriser
def raster(sx, sy, depth, tris, w, h):
    """Z-buffer: returns (tri id per pixel or -1, barycentrics (h,w,3), facing (h,w) True = front, CCW)."""
    ids = np.full((h, w), -1, dtype=np.int64)
    bary = np.zeros((h, w, 3))
    front = np.zeros((h, w), dtype=bool)
    ax, ay = sx[tris[:, 0]], sy[tris[:, 0]]
    bx, by = sx[tris[:, 1]], sy[tris[:, 1]]
    cx, cy = sx[tris[:, 2]], sy[tris[:, 2]]
    area = (bx - ax) * (cy - ay) - (cx - ax) * (by - ay)
    ok = np.isfinite(area) & (np.abs(area) > 1e-9)
    x0 = np.clip(np.floor(np.minimum(np.minimum(ax, bx), cx)), 0, w - 1)
    x1 = np.clip(np.ceil(np.maximum(np.maximum(ax, bx), cx)), 0, w - 1)
    y0 = np.clip(np.floor(np.minimum(np.minimum(ay, by), cy)), 0, h - 1)
    y1 = np.clip(np.ceil(np.maximum(np.maximum(ay, by), cy)), 0, h - 1)
    ok &= np.isfinite(x0) & (np.maximum(ax, np.maximum(bx, cx)) >= 0) & (np.minimum(ax, np.minimum(bx, cx)) <= w)
    size = np.maximum(x1 - x0, y1 - y0).astype(np.int64) + 1
    cand_t, cand_p, cand_z, cand_b = [], [], [], []
    k = 1
    todo = np.flatnonzero(ok)
    while len(todo):
        sel = todo[size[todo] <= k]
        todo = todo[size[todo] > k]
        if len(sel):
            step = max(1, 400000 // (k * k))
            oy, ox = np.divmod(np.arange(k * k), k)
            for s in range(0, len(sel), step):
                t = sel[s : s + step]
                px = x0[t][:, None] + ox[None, :]
                py = y0[t][:, None] + oy[None, :]
                qx, qy = px + 0.5, py + 0.5
                a_ = area[t][:, None]
                w0 = ((bx[t][:, None] - qx) * (cy[t][:, None] - qy) - (cx[t][:, None] - qx) * (by[t][:, None] - qy)) / a_
                w1 = ((cx[t][:, None] - qx) * (ay[t][:, None] - qy) - (ax[t][:, None] - qx) * (cy[t][:, None] - qy)) / a_
                w2 = 1.0 - w0 - w1
                inside = (w0 >= -1e-6) & (w1 >= -1e-6) & (w2 >= -1e-6) & (px < w) & (py < h)
                ti, pi = np.nonzero(inside)
                if not len(ti):
                    continue
                tt = t[ti]
                bb = np.stack([w0[ti, pi], w1[ti, pi], w2[ti, pi]], axis=1)
                z = bb[:, 0] * depth[tris[tt, 0]] + bb[:, 1] * depth[tris[tt, 1]] + bb[:, 2] * depth[tris[tt, 2]]
                cand_t.append(tt)
                cand_p.append((py[ti, pi] * w + px[ti, pi]).astype(np.int64))
                cand_z.append(z)
                cand_b.append(bb)
        k *= 2
    if not cand_t:
        return ids, bary, front
    ct, cp, cz, cb = (np.concatenate(x) for x in (cand_t, cand_p, cand_z, cand_b))
    order = np.lexsort((-cz, cp))  # per pixel: nearest (largest depth) first
    cp_s = cp[order]
    first = np.concatenate([[True], cp_s[1:] != cp_s[:-1]])
    win = order[first]
    flat = cp[win]
    ids.ravel()[flat] = ct[win]
    bary.reshape(-1, 3)[flat] = cb[win]
    front.ravel()[flat] = area[ct[win]] > 0
    return ids, bary, front


def project(pos: np.ndarray, view: str, cx: float, cy: float, cz: float, scale: float):
    """Orthographic camera: the Hunters face -Z in the GLB, so 'front' looks down +Z from -Z, 'side' down -X from +X. y is up."""
    if view == "front":
        sx, depth = -(pos[:, 0] - cx), -pos[:, 2]
    else:
        sx, depth = -(pos[:, 2] - cz), pos[:, 0]
    px = RES / 2 + sx * scale
    py = RES / 2 - (pos[:, 1] - cy) * scale
    return px, py, depth


# ------------------------------------------------------------------ one model, posed
class Posed:
    """One GLB ready to pose and render. Cameras come from the live model so both render identically."""

    def __init__(self, data: bytes):
        self.g = hmc.Glb(data)
        self.body = hmc.Body(self.g)
        self.uv = body_uvs(self.g)
        self.mats = material_table(self.g)
        fin = np.isfinite(self.body.pos).all(axis=1)
        p = self.body.pos[fin]
        self.height = float(p[:, 1].max() - p[:, 1].min()) or 1.0
        self.center = (float((p[:, 0].max() + p[:, 0].min()) / 2), float((p[:, 1].max() + p[:, 1].min()) / 2),
                       float((p[:, 2].max() + p[:, 2].min()) / 2))
        self.rig = hmc.Rig(self.g)
        self.double = np.array([bool(m.get("doubleSided")) for m in self.g.j.get("materials", [])] + [False])
        self.skinned = self.body.skin is not None and bool(self.g.j.get("skins"))
        if self.skinned:
            sk = self.g.j["skins"][self.body.skin]
            self.jnodes = sk["joints"]
            self.ibm = (
                self.g.acc(sk["inverseBindMatrices"]).reshape(-1, 4, 4).transpose(0, 2, 1)
                if "inverseBindMatrices" in sk
                else np.stack([np.eye(4)] * len(self.jnodes))
            )
        self.clip_ids = {name: i for i, (name, _d, _c) in enumerate(self.rig.clips)}

    def pose(self, clip: str | None, f: int, frames: int) -> np.ndarray:
        if not self.skinned or clip is None:
            return self.body.pos
        ci = self.clip_ids[clip]
        dur = self.rig.clips[ci][1]
        sp = hmc.skin_positions(self.body, self.ibm, self.jnodes, self.rig.world(ci, dur * f / max(frames - 1, 1)))
        return np.nan_to_num(sp, nan=0.0, posinf=0.0, neginf=0.0)

    def render(self, pos: np.ndarray, cam: tuple, view: str) -> dict:
        cx, cy, cz, scale = cam
        sx, sy, depth = project(pos, view, cx, cy, cz, scale)
        ids, bary, front = raster(sx, sy, depth, self.body.tris, RES, RES)
        mask = ids >= 0
        rgb = np.zeros((RES, RES, 3), dtype=np.uint8)
        ys, xs = np.nonzero(mask)
        t = ids[ys, xs]
        mat = self.body.mat_of_tri[t]
        b = bary[ys, xs]
        tv = self.body.tris[t]
        uv = b[:, 0:1] * self.uv[tv[:, 0]] + b[:, 1:2] * self.uv[tv[:, 1]] + b[:, 2:3] * self.uv[tv[:, 2]]
        col = np.zeros((len(t), 3))
        keep = np.ones(len(t), dtype=bool)  # False: a cut-out texel (alpha card) or an eye/glow layer
        for m in np.unique(mat):
            fac, tex, cutout, fx = self.mats[m] if m >= 0 else self.mats[-1]
            s = mat == m
            if tex is None:
                col[s] = fac
            else:
                u = (uv[s, 0] % 1.0) * (tex.shape[1] - 1)
                v = (uv[s, 1] % 1.0) * (tex.shape[0] - 1)
                texel = tex[v.astype(int), u.astype(int)]
                col[s] = texel[:, :3] * (fac / 255.0)
                if cutout:
                    keep[s] = texel[:, 3] >= 128
            if fx:
                keep[s] = False
        ys, xs, t, mat = ys[keep], xs[keep], t[keep], mat[keep]
        col = col[keep]
        mask = np.zeros_like(mask)
        mask[ys, xs] = True
        rgb[ys, xs] = np.clip(col, 0, 255).astype(np.uint8)
        dbl = self.double[np.where(mat >= 0, mat, -1)]
        inside = np.zeros_like(mask)
        inside[ys, xs] = ~front[ys, xs] & ~dbl  # nearest surface faces away: looking into the shell
        dark = np.zeros_like(mask)
        dark[ys, xs] = (rgb[ys, xs].max(axis=1) < BLACK_MAX) & ~inside[ys, xs]
        return {"mask": mask, "rgb": rgb, "inside": inside, "dark": dark}


# ------------------------------------------------------------------ image measures
def _shift_and(m: np.ndarray, grow: bool) -> np.ndarray:
    p = np.pad(m, 1, constant_values=False)
    ops = [p[dy : dy + m.shape[0], dx : dx + m.shape[1]] for dy in range(3) for dx in range(3)]
    return np.logical_or.reduce(ops) if grow else np.logical_and.reduce(ops)


def label(m: np.ndarray) -> tuple[np.ndarray, int]:
    from scipy import ndimage

    return ndimage.label(m, structure=np.ones((3, 3)))


def measures(r: dict) -> dict:
    mask = r["mask"]
    lab, n = label(mask)
    areas = np.bincount(lab.ravel())[1:] if n else np.array([], dtype=int)
    blobs = int((areas >= AREA_MIN).sum())
    specks = int((areas < AREA_MIN).sum())
    bg, nb = label(~mask)
    border = set(np.unique(np.concatenate([bg[0], bg[-1], bg[:, 0], bg[:, -1]])).tolist())
    bareas = np.bincount(bg.ravel())
    holes = sum(1 for i in range(1, nb + 1) if i not in border and bareas[i] >= 4)
    opened = _shift_and(_shift_and(_shift_and(_shift_and(mask, False), False), True), True)  # 2 px opening
    return {
        "area": int(mask.sum()),
        "black_px": int(r["dark"].sum() + r["inside"].sum()),
        "inside_px": int(r["inside"].sum()),
        "hole_comps": holes,
        "blobs": blobs,
        "specks": specks,
        "shard_px": int((mask & ~opened).sum()),
    }


def frame_list(live: Posed, cand: Posed, frames: int, clip_re: str | None):
    shared = [c for c in live.clip_ids if c in cand.clip_ids and (not clip_re or re.search(clip_re, c))]
    return [("rest", None, 0)] + [(c, c, f) for c in shared for f in range(frames)]


# ------------------------------------------------------------------ the comparison
def mesh_diff(live: Posed, cand: Posed) -> dict:
    lb, cb = live.body, cand.body
    out = {"tris_live": len(lb.tris), "tris_fix": len(cb.tris)}
    out["lost_tris"] = max(0, len(lb.tris) - len(cb.tris))
    out["lost_clips"] = sorted(set(live.clip_ids) - set(cand.clip_ids))
    out["new_clips"] = sorted(set(cand.clip_ids) - set(live.clip_ids))
    if len(lb.pos) == len(cb.pos):
        d = np.linalg.norm(lb.pos - cb.pos, axis=1) / live.height
        out["bind_moved"] = int((d > BIND_MOVED).sum())
    else:
        out["bind_moved"] = int(len(cb.pos))
    lo = hmc.bind_checks(lb, live.height)[0].get("open_boundary_edges", 0)
    co = hmc.bind_checks(cb, cand.height)[0].get("open_boundary_edges", 0)
    out["open_edges_live"], out["open_edges_fix"] = int(lo), int(co)
    out["new_open_edges"] = int(max(0, co - lo))
    return out


_JOB: dict = {}


def _frame(item):
    """Measures of one (clip, frame) pair, both views: [(view, live measures, fix measures, silhouette diff)]."""
    live, cand, cam, frames = _JOB["live"], _JOB["cand"], _JOB["cam"], _JOB["frames"]
    clip, f = item
    lp, cp = live.pose(clip, f, frames), cand.pose(clip, f, frames)
    out = []
    for view in VIEWS:
        rl, rc = live.render(lp, cam, view), cand.render(cp, cam, view)
        ml = measures(rl)
        out.append((view, ml, measures(rc), int((rl["mask"] ^ rc["mask"]).sum()) / max(ml["area"], 1)))
    return out


def _images(live, cand, cam, frames, clip, f, view):
    return live.render(live.pose(clip, f, frames), cam, view), cand.render(cand.pose(clip, f, frames), cam, view)


def compare(live_data: bytes, cand_data: bytes, frames: int = 6, clip_re: str | None = None, png_dir=None, name="hunter",
            jobs: int = 8):
    """Returns {"verdict", "codes", "worst": {metric: [live, fix, where]}, "mesh": ..., "sil": ..., "frames": n}."""
    import multiprocessing as mp

    live, cand = Posed(live_data), Posed(cand_data)
    cam = (live.center[0], live.center[1], live.center[2], RES / (VIEW_H * live.height))
    _JOB.update(live=live, cand=cand, cam=cam, frames=frames)
    items = [(c, f) for _l, c, f in frame_list(live, cand, frames, clip_re)]
    if jobs > 1 and len(items) > 8:
        with mp.get_context("fork").Pool(jobs) as pool:
            results = pool.map(_frame, items, chunksize=2)
    else:
        results = [_frame(i) for i in items]
    worst = {k: [0, 0, ""] for k in SLACK}
    worst_at: dict[str, tuple] = {}
    sil = {"rest": 0.0, "idle": 0.0, "anim": 0.0}
    sil_at = {"rest": "", "idle": "", "anim": ""}
    for (clip, f), per_view in zip(items, results):
        for view, ml, mc, diff in per_view:
            where = f"{clip or 'rest'} f{f} {view}"
            for k in SLACK:
                if mc[k] - ml[k] > worst[k][1] - worst[k][0]:
                    worst[k] = [ml[k], mc[k], where]
                    worst_at[k] = (clip, f, view)
            kind = "rest" if clip is None else "idle" if IDLE_RE.match(clip) else "anim"
            if diff > sil[kind]:
                sil[kind], sil_at[kind] = diff, where
                worst_at["sil_" + kind] = (clip, f, view)
    mesh = mesh_diff(live, cand)
    codes: dict[str, str] = {}
    for k, (lv, cv, _w) in worst.items():
        if cv > lv * (1 + REL) + SLACK[k]:
            codes[k] = "FAIL"
    for kind, lim, lvl in (("rest", SIL_REST, "FAIL"), ("idle", SIL_IDLE, "FAIL"), ("anim", SIL_ANIM, "WARN")):
        if sil[kind] > lim:
            codes["sil_" + kind] = lvl
    if mesh["lost_tris"] > LOST_TRIS * mesh["tris_live"]:
        codes["lost_tris"] = "FAIL"
    if mesh["lost_clips"]:
        codes["lost_clips"] = "FAIL"
    if mesh["bind_moved"] > 0.001 * len(cand.body.pos):
        codes["bind_moved"] = "WARN"  # a body edit, not a weights-only fix: the silhouette numbers above decide
    if mesh["new_open_edges"] > NEW_OPEN * max(mesh["tris_live"] * 1.5, 1):
        codes["new_open_edges"] = "FAIL"
    level = "FAIL" if "FAIL" in codes.values() else "WARN" if codes else "PASS"
    res = {"verdict": level, "codes": codes, "worst": worst, "mesh": mesh,
           "sil": {k: [round(sil[k], 4), sil_at[k]] for k in sil}, "frames": frames}
    if png_dir is not None:
        shown = {k: worst_at[k] for k in worst_at if k in codes} or dict(list(worst_at.items())[:3])
        imgs = {k: (*_images(live, cand, cam, frames, *w), f"{w[0] or 'rest'} f{w[1]} {w[2]}") for k, w in shown.items()}
        res["png"] = write_sheet(Path(png_dir) / f"{name}_review.png", imgs, codes, name)
    return res


def write_sheet(path: Path, imgs: dict, codes: dict, name: str):
    """One row per failed metric: live | fix | overlay (red = only in fix, blue = only in live, magenta = inside, yellow = black)."""
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        return None
    keys = [k for k in imgs if k in codes] or list(imgs)[:3]
    rows = []
    for k in keys[:6]:
        rl, rc, where = imgs[k]
        ov = np.zeros((RES, RES, 3), dtype=np.uint8)
        ov[rl["mask"] & rc["mask"]] = 70
        ov[rc["mask"] & ~rl["mask"]] = (230, 40, 40)
        ov[rl["mask"] & ~rc["mask"]] = (40, 90, 230)
        ov[rc["dark"]] = (230, 220, 40)
        ov[rc["inside"]] = (230, 40, 230)
        row = np.concatenate([rl["rgb"], rc["rgb"], ov], axis=1)
        im = Image.fromarray(row)
        ImageDraw.Draw(im).text((4, 4), f"{name} {k} {codes.get(k, '')}: {where}", fill=(255, 255, 255))
        rows.append(np.asarray(im))
    if not rows:
        return None
    path.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(np.concatenate(rows, axis=0)).save(path)
    return str(path)
