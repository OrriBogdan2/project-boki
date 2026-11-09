"""(Hem) Meshy inputs from the edited views, each padded to a square on its own grey."""
import sys, os
sys.path.insert(0, sys.argv[1])
import numpy as np
import imgio
M = sys.argv[2]
out = os.path.join(M, "in")
os.makedirs(out, exist_ok=True)
for v, src in (("front", "edit_front"), ("tq", "edit_tq"), ("side", "edit_side"), ("back", "edit_back")):
    im = imgio.load(os.path.join(M, src, "image0.png"))
    h, w = im.shape[:2]
    bg = np.median(np.concatenate([im[:20, :20].reshape(-1, 3), im[:20, -20:].reshape(-1, 3)]), axis=0)
    n = max(h, w)
    sq = np.empty((n, n, 3), np.float32)
    sq[:] = bg
    sq[(n - h) // 2:(n - h) // 2 + h, (n - w) // 2:(n - w) // 2 + w] = im
    imgio.save(sq, os.path.join(out, v + ".png"))
    print(v, sq.shape, "bg", bg)
