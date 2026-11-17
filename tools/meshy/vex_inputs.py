"""Vex's Meshy inputs (r2 art, docs/art/gen/wardens_r2/vex_turnaround.png), in Blender's Python (numpy; no PIL):
  blender -b --factory-startup --python tools/meshy/vex_inputs.py -- TURNAROUND.png OUT_DIR

The sheet has four views side by side: front, 3/4, a near profile (her right side), back. Each is cut out,
padded to a square on the sheet's grey (the 666 px sheet enlarged 2x for Meshy; the 2000 px one, used for the
texture projection, as is). Nothing is mirrored:
her minigun arm is her RIGHT, the monocle her LEFT eye, as drawn. The views are written in Meshy's order
(front first) as view0..3.png, and their crop boxes to views.json for the texture projection.
"""
import json
import os
import sys

import bpy
import numpy as np

# column ranges and rows on the 1568 px sheet; the 2000 px sheet (vex_turnaround_2k) is scaled to match
VIEWS = [("front", 36, 357), ("three_quarter", 447, 720), ("profile", 863, 1065), ("back", 1224, 1539)]
TOP, BOTTOM = 30, 650          # sheet rows kept (above the bolt, below the boots)
MARGIN = 24                    # px of grey around a view
BASE_W = 1568


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1].copy()      # row 0 = top


def save(px, path):
    h, w = px.shape[:2]
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True)
    img.pixels = px[::-1].ravel()
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()


def drop_ground_line(sq, bg):
    """The sheet's ground line (a thin dark rule under the boots) painted out with the sheet's grey: Meshy reads it
    as a floor slab. Rows where a third of the pixels are line-dark; only pixels with grey 4 rows above and below."""
    dark = np.abs(sq[..., :3] - bg[:3]).sum(axis=2) > 0.45
    grey = np.abs(sq[..., :3] - bg[:3]).sum(axis=2) < 0.06
    n = len(sq)
    for r in np.nonzero(dark.mean(axis=1) > 0.33)[0]:
        if r < 4 or r + 4 >= n:
            continue
        line = dark[r] & grey[max(r - 4, 0)] & grey[min(r + 4, n - 1)]
        sq[r, line] = bg
        for d in (-2, -1, 1, 2):         # (its anti-aliased edge)
            rr = r + d
            edge = ~grey[rr] & grey[max(rr - 4, 0)] & grey[min(rr + 4, n - 1)] & line
            sq[rr, edge] = bg


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    sheet, out = load(a[0]), a[1]
    os.makedirs(out, exist_ok=True)
    f = sheet.shape[1] / BASE_W
    scale = 2 if f < 1.1 else 1          # (the small sheet is enlarged for Meshy)
    top, bottom = int(TOP * f), int(BOTTOM * f)
    bg = np.median(sheet[5:20, 5:20].reshape(-1, 4), axis=0)
    bg[3] = 1.0
    boxes = {}
    for i, (name, x0, x1) in enumerate(VIEWS):
        x0, x1 = int((x0 - MARGIN) * f), int((x1 + MARGIN) * f)
        crop = sheet[top:bottom, x0:x1].copy()
        crop[..., 3] = 1.0
        h, w = crop.shape[:2]
        n = max(h, w)
        sq = np.empty((n, n, 4), np.float32)
        sq[:] = bg
        ox, oy = (n - w) // 2, (n - h) // 2
        sq[oy:oy + h, ox:ox + w] = crop
        drop_ground_line(sq, bg)
        sq = np.repeat(np.repeat(sq, scale, 0), scale, 1)
        save(sq, os.path.join(out, "view%d.png" % i))
        boxes[name] = {"file": "view%d.png" % i, "sheet_x0": x0 - ox, "sheet_y0": top - oy, "scale": scale, "sheet_k": f}
    json.dump(boxes, open(os.path.join(out, "views.json"), "w"), indent=1)
    print("VEXINPUTS wrote", out)


main()
