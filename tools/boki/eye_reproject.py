"""Put Meshy-edited head renders back onto a Boki coat's atlas: the eyes Meshy painted, nothing else.

    python3 tools/boki/eye_reproject.py <id>.glb <dir> <out.png> <view>:<edit.png>[:x0,y0,x1,y1] [...] [--thr 28]
`[--check]`; the optional box (render px) keeps the edit to the eyes when Meshy also touched the mouth or a prop.
`<dir>` holds eye_headcam.py's renders, cams.json and geo.npz. For each view, the texels whose render pixel the
Meshy edit changed (|edit - render| > thr, cleaned and feathered), that face the camera and pass a z-buffer test,
take the edit's pixel; every other texel keeps the live atlas. Mesh, UVs and rig are untouched: feed `out.png` to
swap_atlas.py. `--check` prints how far the render is from the atlas it samples (a camera/UV sanity check, ~9/255)."""

import io
import json
import sys

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from swap_atlas import read_glb

FACING_MIN = 0.15  # below this the camera sees the texel too edge-on to trust
FACING_FULL = 0.35  # full weight from here


def live_atlas(glb):
    js, blob = read_glb(glb)
    sid = glb.rsplit("/", 1)[1][:-4]
    im = next(i for i in js["images"] if i.get("name") == sid + "_atlas")
    bv = js["bufferViews"][im["bufferView"]]
    off = bv.get("byteOffset", 0)
    raw = blob[off : off + bv["byteLength"]]
    return np.asarray(Image.open(io.BytesIO(raw)).convert("RGB")).astype(np.float32)


def bary(tri, xs, ys):
    """Barycentric weights of pixel centres against a 2D triangle, or None when it is degenerate."""
    (ax, ay), (bx, by), (cx, cy) = tri
    den = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
    if abs(den) < 1e-9:
        return None
    w0 = ((by - cy) * (xs - cx) + (cx - bx) * (ys - cy)) / den
    w1 = ((cy - ay) * (xs - cx) + (ax - cx) * (ys - cy)) / den
    return w0, w1, 1 - w0 - w1, den


def box(pts, w, h, pad=0):
    x0, y0 = np.floor(pts.min(0)).astype(int) - pad
    x1, y1 = np.ceil(pts.max(0)).astype(int) + pad
    return max(x0, 0), max(y0, 0), min(x1, w - 1), min(y1, h - 1)


def zbuffer(q, res):
    z = np.full((res, res), np.inf, np.float32)
    for t in q:
        x0, y0, x1, y1 = box(t[:, :2], res, res)
        if x1 < x0 or y1 < y0:
            continue
        ys, xs = np.mgrid[y0 : y1 + 1, x0 : x1 + 1] + 0.5
        b = bary(t[:, :2], xs, ys)
        if b is None:
            continue
        w0, w1, w2, _ = b
        ins = (w0 >= -1e-3) & (w1 >= -1e-3) & (w2 >= -1e-3)
        sub = z[y0 : y1 + 1, x0 : x1 + 1]
        np.minimum(sub, np.where(ins, w0 * t[0, 2] + w1 * t[1, 2] + w2 * t[2, 2], np.inf), out=sub)
    return z


def edit_mask(edit, render, thr, path, keep=None):
    d = np.abs(edit - render).mean(2)
    if keep:
        x0, y0, x1, y1 = keep
        inside = np.zeros_like(d, bool)
        inside[y0:y1, x0:x1] = True
        d[~inside] = 0
    m = Image.fromarray((d > thr).astype(np.uint8) * 255)
    m = m.filter(ImageFilter.MedianFilter(3)).filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.GaussianBlur(4))
    m.save(path)
    return np.asarray(m).astype(np.float32) / 255


def paint_view(state, cam, edit, render, mask, check):
    atlas, out, wsum, P, uvs, near, hs = state
    ah, aw = atlas.shape[:2]
    r, loc, sc, res = np.array(cam["R"]), np.array(cam["loc"]), cam["scale"], cam["res"]
    q = (P[near] - loc) @ r
    q = np.stack([(q[..., 0] / sc + 0.5) * res, (0.5 - q[..., 1] / sc) * res, -q[..., 2]], -1)
    tri = P[near]
    nrm = np.cross(tri[:, 1] - tri[:, 0], tri[:, 2] - tri[:, 0])
    # abs: some coats are mirrored (flipped winding); the z-buffer drops the far side
    facing = np.abs(nrm @ -np.array(cam["d"])) / (np.linalg.norm(nrm, axis=1) + 1e-12)
    z = zbuffer(q, res)
    errs = []
    for k, i in enumerate(np.nonzero(near)[0]):
        if facing[k] < FACING_MIN:
            continue
        uv = uvs[i] * [aw, ah]
        uv[:, 1] = ah - uv[:, 1]
        x0, y0, x1, y1 = box(uv, aw, ah, 1)
        ys, xs = np.mgrid[y0 : y1 + 1, x0 : x1 + 1] + 0.5
        b = bary(uv, xs, ys)
        if b is None:
            continue
        w0, w1, w2, den = b
        tol = -1.5 / max(abs(den) ** 0.5, 1)  # a texel of bleed past the UV edge (no seams)
        ins = (w0 >= tol) & (w1 >= tol) & (w2 >= tol)
        if not ins.any():
            continue
        t = q[k]
        px, py, pz = (w0 * t[0, j] + w1 * t[1, j] + w2 * t[2, j] for j in range(3))
        pxi, pyi = np.clip(px.astype(int), 0, res - 1), np.clip(py.astype(int), 0, res - 1)
        vis = ins & (pz <= z[pyi, pxi] + hs * 0.02) & (px >= 0) & (px < res) & (py >= 0) & (py < res)
        live = atlas[y0 : y1 + 1, x0 : x1 + 1]
        if check and vis.any():
            errs.append(np.abs(render[pyi[vis], pxi[vis]] - live[vis]).mean())
        wv = mask[pyi, pxi] * vis * min(1.0, facing[k] / FACING_FULL)
        sub, ws = out[y0 : y1 + 1, x0 : x1 + 1], wsum[y0 : y1 + 1, x0 : x1 + 1]
        up = wv > ws
        sub[up] = live[up] * (1 - wv[up, None]) + edit[pyi[up], pxi[up]] * wv[up, None]
        ws[up] = wv[up]
    return float(np.mean(errs)) if errs else None


def main():
    args = [x for x in sys.argv[1:] if not x.startswith("--")]
    thr = float(sys.argv[sys.argv.index("--thr") + 1]) if "--thr" in sys.argv else 28.0
    if "--thr" in sys.argv:
        args.remove(sys.argv[sys.argv.index("--thr") + 1])
    glb, d, out_path = args[:3]
    atlas = live_atlas(glb)
    g = np.load(d + "/geo.npz")
    cams = json.load(open(d + "/cams.json"))
    head, hs = np.array(cams["H"]), cams["hs"]
    near = np.linalg.norm(g["P"].mean(1) - head, axis=1) < hs * 1.2
    out, wsum = atlas.copy(), np.zeros(atlas.shape[:2], np.float32)
    state = (atlas, out, wsum, g["P"], g["UV"], near, hs)
    for spec in args[3:]:
        view, edit_path, *keep = spec.split(":")
        keep = [int(x) for x in keep[0].split(",")] if keep else None
        cam = cams["cams"][view]
        res = cam["res"]
        edit = np.asarray(Image.open(edit_path).convert("RGB").resize((res, res), Image.LANCZOS)).astype(np.float32)
        render = np.asarray(Image.open(f"{d}/{view}.png").convert("RGB")).astype(np.float32)
        mask = edit_mask(edit, render, thr, f"{d}/mask_{view}.png", keep)
        err = paint_view(state, cam, edit, render, mask, "--check" in sys.argv)
        if err is not None:
            print(view, "render vs atlas", round(err, 2))
    print("changed texels", int((wsum > 0.02).sum()))
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(out_path)


main()
