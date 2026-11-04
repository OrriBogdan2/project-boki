"""Touches up a flat-lit face sheet before it is projected (fit spec project_late "image"), credit-free:
  BPY -I tools/meshy/face_touch.py SPEC.json
SPEC: {"in": png, "out": png, and any of
  "blush": {"rows": [r0, r1], "k": 0.5, "hue": [h0, h1], "sat_min": 0.08, "skin": "hex"}
      pink texels in those rows move k of the way to the skin colour at their own value (a hot blotch -> a glow);
  "freckles": {"box": [c0, r0, c1, r1], "k": 1.6, "grow": 1, "dot": 0.04, "colour": "hex"}
      small dots darker than their neighbourhood by more than `dot` are deepened k times, grown `grow` px and
      tinted toward `colour` (fine freckles vanish on a 4096 atlas otherwise);
  "eyes": [{"c": [col, row], "r": px, "scale": 1.15, "glow": 0.25, "glow_hue": [h0, h1]}]
      each eye magnified about its centre with a soft falloff to r (no seam), and its pale-blue iris lifted toward
      white-blue by `glow` (a glowing eye at the match camera), or tinted toward `iris` (hex, `iris_k`, `iris_r`)}.
Image coordinates are the sheet's own pixels (row 0 at the top)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402


def hsv(rgb):
    mx = rgb.max(axis=-1)
    mn = rgb.min(axis=-1)
    d = np.maximum(mx - mn, 1e-6)
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    h = np.where(mx == r, ((g - b) / d) % 6.0, np.where(mx == g, (b - r) / d + 2.0, (r - g) / d + 4.0)) / 6.0
    return h, (mx - mn) / np.maximum(mx, 1e-6), mx


def hexcol(s):
    return np.array([int(s[i:i + 2], 16) / 255.0 for i in (0, 2, 4)], np.float32)


def box_blur(a, r):
    out = a.copy()
    for ax in (0, 1):
        c = np.cumsum(np.pad(out, [(r + 1, r) if i == ax else (0, 0) for i in range(out.ndim)], mode="edge"), axis=ax)
        n = out.shape[ax]
        out = (np.take(c, np.arange(2 * r + 1, 2 * r + 1 + n), axis=ax) - np.take(c, np.arange(0, n), axis=ax)) / (2 * r + 1)
    return out


def blush(im, b):
    h, s, v = hsv(im)
    r0, r1 = b["rows"]
    h0, h1 = b.get("hue", [0.9, 0.06])
    hue_ok = (h >= h0) | (h <= h1) if h0 > h1 else (h >= h0) & (h <= h1)
    m = hue_ok & (s >= float(b.get("sat_min", 0.08)))
    m[:r0] = False
    m[r1:] = False
    if "cols" in b:
        m[:, :b["cols"][0]] = False
        m[:, b["cols"][1]:] = False
    skin = hexcol(b["skin"])
    tgt = skin[None, None, :] * (v / max(float(skin.max()), 1e-3))[..., None]
    w = box_blur(m.astype(np.float32), 3)[..., None] * float(b["k"])
    out = im * (1 - w) + np.clip(tgt, 0, 1) * w
    print("FACETOUCH blush: %d px" % int(m.sum()))
    return out


def freckles(im, f):
    c0, r0, c1, r1 = f["box"]
    sub = im[r0:r1, c0:c1]
    lum = sub.mean(axis=-1)
    loc = box_blur(lum, 4)
    dot = (loc - lum) > float(f.get("dot", 0.04))
    # (no lashes, brows or nostrils: only small isolated dots, under a blob size)
    small = box_blur(dot.astype(np.float32), 3) < 0.35
    dot &= small
    g = int(f.get("grow", 1))
    if g:
        dot = box_blur(dot.astype(np.float32), g) > 0.15
    col = hexcol(f.get("colour", "b4707a"))
    depth = np.clip((loc - lum) * float(f["k"]), 0.05, 0.25)[..., None]
    tint = sub * (1 - depth * 1.6) * 0.5 + col[None, None, :] * 0.5
    w = box_blur(dot.astype(np.float32), 1)[..., None]
    sub[:] = sub * (1 - w) + np.clip(tint, 0, 1) * w
    print("FACETOUCH freckles: %d px" % int(dot.sum()))
    return im


def eye(im, e):
    H, W, _ = im.shape
    cx, cy = e["c"]
    R = float(e["r"])
    sc = float(e.get("scale", 1.15))
    x0, x1 = int(max(0, cx - R)), int(min(W, cx + R + 1))
    y0, y1 = int(max(0, cy - R)), int(min(H, cy + R + 1))
    ys, xs = np.mgrid[y0:y1, x0:x1].astype(np.float32)
    dx, dy = xs - cx, ys - cy
    rr = np.sqrt(dx * dx + dy * dy) / R
    # (a lens: scale inside, easing to none at the edge)
    t = np.clip(rr, 0, 1)
    k = 1.0 / sc + (1.0 - 1.0 / sc) * (t * t * (3 - 2 * t))
    sx = np.clip(cx + dx * k, 0, W - 1)
    sy = np.clip(cy + dy * k, 0, H - 1)
    xi, yi = np.floor(sx).astype(int), np.floor(sy).astype(int)
    fx, fy = (sx - xi)[..., None], (sy - yi)[..., None]
    xj, yj = np.minimum(xi + 1, W - 1), np.minimum(yi + 1, H - 1)
    src = im.copy()
    samp = (src[yi, xi] * (1 - fx) * (1 - fy) + src[yi, xj] * fx * (1 - fy) + src[yj, xi] * (1 - fx) * fy +
            src[yj, xj] * fx * fy)
    im[y0:y1, x0:x1] = samp
    g = float(e.get("glow", 0.0))
    if g:
        sub = im[y0:y1, x0:x1]
        h, s, v = hsv(sub)
        g0, g1 = e.get("glow_hue", [0.5, 0.7])
        m = (h >= g0) & (h <= g1) & (s >= float(e.get("glow_sat", 0.3))) & (v >= 0.45) & (rr <= float(e.get("glow_r", 0.45)))
        w = box_blur(m.astype(np.float32), 1)[..., None] * g
        lift = np.clip(sub * 0.55 + np.array([0.62, 0.86, 1.0], np.float32) * 0.6, 0, 1)
        sub[:] = sub * (1 - w) + lift * w
        print("FACETOUCH eye %s: glow %d px" % (str(e["c"]), int(m.sum())))
    if e.get("iris"):
        # (a blue iris, not a white glow: the iris texels toward the colour at their own value, the catchlight kept)
        sub = im[y0:y1, x0:x1]
        h, s, v = hsv(sub)
        g0, g1 = e.get("glow_hue", [0.5, 0.7])
        m = (h >= g0) & (h <= g1) & (s >= float(e.get("iris_sat", 0.18))) & (v >= 0.35) & (v <= 0.97) & (rr <= float(e.get("iris_r", 0.5)))
        col = hexcol(e["iris"])
        w = box_blur(m.astype(np.float32), 1)[..., None] * float(e.get("iris_k", 0.6))
        tgt = np.clip(col[None, None, :] * (v / max(float(col.max()), 1e-3))[..., None] * 0.95, 0, 1)
        sub[:] = sub * (1 - w) + tgt * w
        print("FACETOUCH eye %s: iris %d px" % (str(e["c"]), int(m.sum())))
    return im


def main():
    spec = json.load(open(sys.argv[1]))
    im = imgio.load(os.path.expanduser(spec["in"]))
    for e in spec.get("eyes", []):
        im = eye(im, e)
    if "blush" in spec:
        im = blush(im, spec["blush"])
    if "freckles" in spec:
        im = freckles(im, spec["freckles"])
    imgio.save(im, os.path.expanduser(spec["out"]))
    print("FACETOUCH wrote", spec["out"])


if __name__ == "__main__":
    main()
