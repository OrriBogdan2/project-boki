"""(Sparkle) Meshy inputs from the edited views (pigtails, ties and rods out; side eye closed), each padded to a
square on its own grey; the small green bolt the back edit invented on the corset painted pink by hand.
  <blender python> -I tools/meshy/ryzz_prep.py tools/meshy ~/meshy/ryzz"""
import sys, os
sys.path.insert(0, sys.argv[1])
import numpy as np
import imgio
M = os.path.expanduser(sys.argv[2])
out = os.path.join(M, "in")
os.makedirs(out, exist_ok=True)
for v, src in (("front", "edit_front"), ("side", "edit_side2"), ("back", "edit_back")):
    im = imgio.load(os.path.join(M, src, "image0.png"))
    if v == "back":
        y0, y1, x0, x1 = 520, 610, 360, 450
        box = im[y0:y1, x0:x1]
        green = (box[..., 1] > box[..., 0] + 0.03) | (box[..., 1] > box[..., 2] + 0.02)
        green &= box.mean(axis=2) > 0.3        # (not the jacket's dark hem above it)
        green[:28] = False
        g2 = green.copy()
        for d in range(1, 6):            # (its anti-aliased rim too)
            g2[d:] |= green[:-d]; g2[:-d] |= green[d:]; g2[:, d:] |= green[:, :-d]; g2[:, :-d] |= green[:, d:]
        for r in range(len(box)):              # (each row's run filled between its two edge texels: the hem stays)
            xs = np.nonzero(g2[r])[0]
            if len(xs):
                a, b = max(xs[0] - 1, 0), min(xs[-1] + 1, box.shape[1] - 1)
                t = np.linspace(0.0, 1.0, b - a + 1)[:, None]
                box[r, a:b + 1] = box[r, a] * (1 - t) + box[r, b] * t
        print("back: %d green texels painted pink" % int(g2.sum()))
    h, w = im.shape[:2]
    bg = np.median(np.concatenate([im[:20, :20].reshape(-1, 3), im[:20, -20:].reshape(-1, 3)]), axis=0)
    n = max(h, w)
    sq = np.empty((n, n, 3), np.float32)
    sq[:] = bg
    sq[(n - h) // 2:(n - h) // 2 + h, (n - w) // 2:(n - w) // 2 + w] = im
    imgio.save(sq, os.path.join(out, v + ".png"))
    print(v, sq.shape, "bg", bg)
