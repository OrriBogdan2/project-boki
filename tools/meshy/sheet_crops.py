"""Cuts a turnaround sheet into one 9:16 crop per view on the sheet's grey (Meshy image-to-image keeps the frame, so
the figure fills it), each figure centred, nothing mirrored (RECIPE_95.md step 2). Blender's Python (numpy):
  python3 -I tools/meshy/sheet_crops.py SHEET.png OUT_DIR VIEWS.json
VIEWS.json: {"views": [{"name": "front", "x0": 0, "x1": 528, "kill": [[x0, y0, x1, y1], ...]}, ...]} (sheet px;
"kill": a neighbour's pixels to paint out with the grey), or {"auto": ["front", "tq", "side", "back"]}: the
figures found as runs of non-grey columns, left to right (check the result: touching figures merge)."""
import json
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402


def runs(cols, min_w=8, gap=6):
    out, start, last = [], None, None
    for x, c in enumerate(cols):
        if c:
            if start is None or x - last > gap:
                if start is not None and last - start >= min_w:
                    out.append((start, last))
                start = x
            last = x
    if start is not None and last - start >= min_w:
        out.append((start, last))
    return out


def main(a):
    sheet = imgio.load(a[0])
    out = a[1]
    spec = json.load(open(a[2]))
    os.makedirs(out, exist_ok=True)
    h, w = sheet.shape[:2]
    bg = np.median(sheet[5:30, 5:30].reshape(-1, 3), axis=0)
    fg = np.abs(sheet - bg).sum(axis=2) > 0.10
    views = spec.get("views")
    if not views:
        found = runs(fg.sum(axis=0) > 2)
        names = spec["auto"]
        if len(found) != len(names):
            sys.exit("found %d figures for %d views: %s (give the views' x0/x1)" % (len(found), len(names), found))
        views = [{"name": n, "x0": max(0, r[0] - 12), "x1": min(w, r[1] + 12)} for n, r in zip(names, found)]
    cw = int(round(h * 9 / 16))
    boxes = {}
    for v in views:
        x0, x1 = int(v["x0"]), int(v["x1"])
        part = sheet[:, x0:x1].copy()
        m = fg[:, x0:x1].copy()
        for k in v.get("kill", []):
            part[k[1]:k[3], max(0, k[0] - x0):max(0, k[2] - x0)] = bg
            m[k[1]:k[3], max(0, k[0] - x0):max(0, k[2] - x0)] = False
        cols = np.nonzero(m.any(axis=0))[0]
        cx = x0 + (cols.min() + cols.max()) / 2.0
        canvas = np.empty((h, cw, 3), np.float32)
        canvas[:] = bg
        left = int(round(cx - cw / 2))
        for sx in range(x0, x1):
            if 0 <= sx - left < cw:
                canvas[:, sx - left] = part[:, sx - x0]
        imgio.save(canvas, os.path.join(out, v["name"] + ".png"))
        boxes[v["name"]] = {"sheet_left": left, "w": cw, "h": h}
        print("SHEETCROP", v["name"], boxes[v["name"]])
    json.dump(boxes, open(os.path.join(out, "crops.json"), "w"), indent=1)


main(sys.argv[1:])
