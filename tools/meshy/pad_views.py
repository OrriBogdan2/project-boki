"""The chosen (edited) views padded to squares on their own grey: Meshy's multi-image inputs (RECIPE_95.md step 2).
  python3 -I tools/meshy/pad_views.py OUT_DIR name=IMG [name=IMG ...]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
for arg in sys.argv[2:]:
    name, path = arg.split("=", 1)
    im = imgio.load(os.path.expanduser(path))
    h, w = im.shape[:2]
    bg = np.median(np.concatenate([im[:20, :20].reshape(-1, 3), im[:20, -20:].reshape(-1, 3)]), axis=0)
    n = max(h, w)
    sq = np.empty((n, n, 3), np.float32)
    sq[:] = bg
    sq[(n - h) // 2:(n - h) // 2 + h, (n - w) // 2:(n - w) // 2 + w] = im
    imgio.save(sq, os.path.join(out, name + ".png"))
    print("PADVIEW", name, sq.shape[:2])
