"""(Hem) Cuts the r3 turnaround (2000x1116: front, 3/4, side (her right), back) into 9:16 crops on the sheet's grey,
each figure centred, its neighbours' pixels painted out. Nothing is mirrored."""
import sys, os, json
sys.path.insert(0, sys.argv[1])
import numpy as np
import imgio
sheet = imgio.load(sys.argv[2])
out = sys.argv[3]
os.makedirs(out, exist_ok=True)
H, W = sheet.shape[:2]
bg = np.median(sheet[5:30, 5:30].reshape(-1, 3), axis=0)
fg = np.abs(sheet - bg).sum(axis=2) > 0.10
# (name, keep x0, x1, and a mask of the neighbour's pixels to paint out within that span)
FLOOR = 903   # Hem: the clawed VFX shadow under the ground line is painted out (not in the mesh)
VIEWS = [("front", 0, 580, lambda y, x: y > FLOOR),
         ("tq", 585, 1075, lambda y, x: (y > FLOOR) | ((x > 1020) & (y > 550))),
         ("side", 1025, 1400, lambda y, x: (y > FLOOR) | ((x < 1110) & (y < 450))),
         ("back", 1440, 2000, lambda y, x: y > FLOOR)]
CW = int(round(H * 9 / 16))
boxes = {}
for name, x0, x1, nb in VIEWS:
    part = sheet[:, x0:x1].copy()
    yy, xx = np.mgrid[0:H, x0:x1]
    kill = nb(yy, xx)
    part[kill] = bg
    m = fg[:, x0:x1] & ~kill
    cols = np.nonzero(m.any(axis=0))[0]
    cx = x0 + (cols.min() + cols.max()) / 2.0
    canvas = np.empty((H, CW, 3), np.float32)
    canvas[:] = bg
    left = int(round(cx - CW / 2))        # sheet column at the canvas's x = 0
    for sx in range(x0, x1):
        dx = sx - left
        if 0 <= dx < CW:
            canvas[:, dx] = part[:, sx - x0]
    imgio.save(canvas, os.path.join(out, name + ".png"))
    boxes[name] = {"sheet_left": left, "w": CW, "h": H, "fig_cols": [int(x0 + cols.min()), int(x0 + cols.max())]}
    print(name, boxes[name])
json.dump(boxes, open(os.path.join(out, "crops.json"), "w"), indent=1)
