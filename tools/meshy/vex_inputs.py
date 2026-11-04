"""Vex's Meshy inputs from the turnaround crops (~/meshy/vex/{front,side,back}.png), in Blender's Python
(numpy; there is no PIL on the box):
  ~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python tools/meshy/vex_inputs.py -- IN_DIR OUT_DIR

- The rifle (and the scripture strips hanging off it) is painted out of the front and back views, so Meshy
  builds her with free hands; the rifle alone goes to rifle_front/back.png for its own model, the separate
  `weapon` mesh (RIG_CONTRACT).
- The views are mirrored so the mechanical arm and the sigil plate land on her LEFT, as her Warden block and
  splash have them (the sheet draws them on her right). Her head is put back unmirrored in the front view, so
  the mechanical eye stays her right; in the profile (now her left side) the lens is painted over.
"""
import os
import sys

import bpy
import numpy as np

# polygons in crop pixels (x right, y down), drawn against the 1344 crops
RIFLE = {
    "front": [[(735, 684), (775, 698), (905, 752), (978, 788), (1265, 1060), (1248, 1104), (905, 1102), (850, 1102),
               (778, 1018), (768, 880), (712, 800), (700, 762), (712, 746), (735, 740)],
              [(548, 553), (572, 546), (638, 616), (638, 650), (652, 674), (668, 690), (668, 722), (616, 722), (553, 652),
               (548, 612)]],
    "back": [[(650, 700), (612, 712), (470, 760), (146, 1052), (136, 1084), (190, 1118), (402, 962), (478, 1110),
              (616, 1110), (618, 872), (640, 826), (678, 792), (690, 762), (660, 742), (652, 736)],
             [(712, 676), (748, 620), (800, 560), (830, 552), (830, 648), (786, 662), (766, 722), (722, 712)]],
}
HEAD = {"front": (450, 244, 95)}      # axis x, bottom row, half-width of the head put back unmirrored
LENS = (764, 178, 24)                                        # the profile's lens (centre x, y, radius), before mirroring


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()     # row 0 = top
    return px


def save(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels = px[::-1].ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def inside(poly, h, w):
    yy, xx = np.mgrid[0:h, 0:w]
    m = np.zeros((h, w), bool)
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i]
        x1, y1 = poly[(i + 1) % n]
        if y0 == y1:
            continue
        cond = ((yy >= min(y0, y1)) & (yy < max(y0, y1)))
        xc = x0 + (yy - y0) * (x1 - x0) / (y1 - y0)
        m ^= cond & (xx < xc)
    return m


def _ground(px, holes):
    """The sheet's grey behind the figure, per pixel: a smooth vignette, so each row's ground is the median of
    its grey (unsaturated, mid-light) pixels, blended toward the nearest such pixel along the row."""
    h, w = px.shape[:2]
    rgb = px[..., :3]
    grey = (rgb.max(axis=2) - rgb.min(axis=2) < 0.03) & (rgb.mean(axis=2) > 0.68) & (rgb.mean(axis=2) < 0.86) & ~holes
    out = np.empty_like(px)
    cols = np.arange(w)
    for y in range(h):
        g = np.nonzero(grey[y])[0]
        if g.size == 0:
            out[y] = out[y - 1] if y else px[y]
            continue
        for c in range(4):
            out[y, :, c] = np.interp(cols, g, px[y, g, c])
    return out


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    src, out = a[0], a[1]
    os.makedirs(out, exist_ok=True)
    for view in ("front", "side", "back"):
        px = load(os.path.join(src, view + ".png"))
        h, w = px.shape[:2]
        holes = np.zeros((h, w), bool)
        for poly in RIFLE.get(view, []):
            holes |= inside(poly, h, w)
        bg = _ground(px, holes)
        if holes.any():
            # the rifle on its own, for its own model (the `weapon` mesh)
            rifle = np.empty_like(px)
            rifle[:] = np.median(bg.reshape(-1, 4), axis=0)
            rifle[holes] = px[holes]
            save(rifle, os.path.join(out, "rifle_" + view + ".png"))
        px[holes] = bg[holes]
        if view == "side":
            cx, cy, r = LENS
            yy, xx = np.mgrid[0:h, 0:w]
            lens = ((xx - cx) ** 2 + (yy - cy) ** 2 < r * r) & (np.abs(px - bg).sum(axis=2) > 0.08)
            skin = np.median(px[205:225, 745:765].reshape(-1, 4), axis=0)
            px[lens] = skin
            eye = (xx - (cx + 8)) ** 2 + (yy - cy) ** 2 < 20
            px[eye] = np.array([0.12, 0.08, 0.07, 1.0])
            px = px[:, ::-1].copy()
        elif view == "back":
            px = px[:, ::-1].copy()          # the back of her head mirrors without harm
        else:
            ax, bottom, half = HEAD[view]
            orig = px.copy()
            # mirror about the head's axis (the figure shifts a little, it stays on the grey)
            idx = 2 * ax - np.arange(w)
            off = (idx < 0) | (idx >= w)
            px = px[:, np.clip(idx, 0, w - 1)]
            px[:, off] = bg[:, off]
            x0, x1 = ax - half, ax + half
            px[:bottom, x0:x1] = orig[:bottom, x0:x1]
        save(px, os.path.join(out, view + ".png"))
    print("VEXINPUTS wrote", out)


main()
