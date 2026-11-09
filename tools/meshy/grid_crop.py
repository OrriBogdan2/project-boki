"""A zoomed crop of an image with a pixel grid in the image's own coordinates (thin lines every 10 px, red every
50 px): for reading landmarks off a sheet or a render (Face rules: never read them on a downscaled whole image).
  python3 -I tools/meshy/grid_crop.py IMG x0 y0 w h zoom OUT.png      (runs in any Python with numpy, e.g. Blender's)"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402

im = imgio.load(sys.argv[1])
x0, y0, w, h, z = map(int, sys.argv[2:7])
c = im[y0:y0 + h, x0:x0 + w]
c = np.repeat(np.repeat(c, z, 0), z, 1)
for v in range(x0, x0 + w):
    if v % 10 == 0:
        k, col = (0.55, np.array([0.95, 0.1, 0.1])) if v % 50 == 0 else (0.25, np.array([1.0, 1.0, 1.0]))
        c[:, (v - x0) * z] = c[:, (v - x0) * z] * (1 - k) + col * k
for u in range(y0, y0 + h):
    if u % 10 == 0:
        k, col = (0.55, np.array([0.95, 0.1, 0.1])) if u % 50 == 0 else (0.25, np.array([1.0, 1.0, 1.0]))
        c[(u - y0) * z, :] = c[(u - y0) * z, :] * (1 - k) + col * k
imgio.save(c, sys.argv[7])
