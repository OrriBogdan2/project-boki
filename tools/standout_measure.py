"""How well each Hunter stands off the ground in tools/standout_shots.gd's stills.

python3 tools/standout_measure.py <shots dir>  ->  <dir>/measure.json, one row per ground and Hunter:
  px        body pixels (the key frame shows the Hunter's own key colour there, within KEY_TOL)
  lum       mean relative luminance of the body, ring = of the ground band RING_PX round it (rings, shadow in)
  contrast  (lighter + 0.05) / (darker + 0.05) of those two means (WCAG ratio)
  dl        mean |L*| step across the silhouette edge: body pixels on the edge vs ground pixels just outside
  sat_d     mean HSV saturation of the body minus the ring's
  edge      mean luminance gradient (Sobel, 0..1 scale) on the silhouette's edge pixels
"""

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

KEY_TOL = 0.3  # max channel step (0..1) from a Hunter's key colour that still counts as its body
RING_PX = 10  # width of the ground band round the body


def _lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _lum(rgb):
    lin = _lin(rgb)
    return lin[..., 0] * 0.2126 + lin[..., 1] * 0.7152 + lin[..., 2] * 0.0722


def _lstar(y):
    return np.where(y > 0.008856, 116.0 * np.cbrt(y) - 16.0, 903.3 * y)


def _sat(rgb):
    mx = rgb.max(-1)
    mn = rgb.min(-1)
    return np.where(mx > 1e-4, (mx - mn) / np.maximum(mx, 1e-4), 0.0)


def measure_one(shot, keyed, key, box):
    h, w, _ = shot.shape
    x0, y0, x1, y1 = (int(v) for v in box)
    pad = 24
    x0, y0 = max(0, x0 - pad), max(0, y0 - pad)
    x1, y1 = min(w, x1 + pad), min(h, y1 + pad)
    a = shot[y0:y1, x0:x1]
    b = keyed[y0:y1, x0:x1]
    body = np.abs(b - key).max(-1) < KEY_TOL
    lab, n = ndimage.label(body)
    if n == 0:
        return None
    sizes = ndimage.sum(body, lab, range(1, n + 1))
    body = lab == (int(np.argmax(sizes)) + 1)
    body = ndimage.binary_fill_holes(body)
    grown = ndimage.binary_dilation(body, iterations=RING_PX)
    ring = grown & ~body
    inner = body & ~ndimage.binary_erosion(body, iterations=2)
    outer = ndimage.binary_dilation(body, iterations=2) & ~body
    y = _lum(a)
    ls = _lstar(y)
    s = _sat(a)
    gx = ndimage.sobel(y, 1)
    gy = ndimage.sobel(y, 0)
    grad = np.hypot(gx, gy) / 8.0
    edge = ndimage.binary_dilation(body, iterations=1) & ~ndimage.binary_erosion(body, iterations=1)
    lb, lr = float(y[body].mean()), float(y[ring].mean())
    hi, lo = max(lb, lr), min(lb, lr)
    return {
        "px": int(body.sum()),
        "lum": round(lb, 4),
        "ring_lum": round(lr, 4),
        "contrast": round((hi + 0.05) / (lo + 0.05), 3),
        "dl": round(float(abs(ls[inner].mean() - ls[outer].mean())), 2),
        "sat_d": round(float(s[body].mean() - s[ring].mean()), 3),
        "edge": round(float(grad[edge].mean()), 4),
    }


def main(d):
    d = Path(d)
    meta = json.loads((d / "standout.json").read_text())
    rows = []
    for g, info in meta.items():
        shot = np.asarray(Image.open(d / f"{g}.png").convert("RGB"), dtype=np.float64) / 255.0
        keyed = np.asarray(Image.open(d / f"{g}_key.png").convert("RGB"), dtype=np.float64) / 255.0
        for arch, hv in info["hunters"].items():
            key = np.array([int(hv["key"][i : i + 2], 16) / 255.0 for i in (0, 2, 4)])
            r = measure_one(shot, keyed, key, hv["box"])
            if r:
                rows.append({"ground": g, "arch": arch, "team": hv["team"], "box": hv["box"], **r})
    (d / "measure.json").write_text(json.dumps(rows, indent=1))
    for r in rows:
        print(
            f"{r['ground']:7s} {r['arch']:11s} px={r['px']:5d} C={r['contrast']:.2f} dL={r['dl']:5.1f} "
            f"dS={r['sat_d']:+.2f} edge={r['edge']:.3f}"
        )


if __name__ == "__main__":
    main(sys.argv[1])
