"""Review composites for a Warden (PIPELINE.md step 4), in Blender's Python (numpy):
  blender -b --factory-startup --python tools/meshy/compose.py -- OUT.png rows|cols IMG [IMG ...]
rows: the images stacked, each scaled to 1280 wide; cols: side by side, each scaled to the same height, the
whole at most 1280 wide."""
import sys

import bpy
import numpy as np

W = 1280


def load(path):
    img = bpy.data.images.load(path)
    w, h = img.size
    return np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)


def resize(px, w, h):
    sh, sw = px.shape[:2]
    ys = (np.arange(h) * sh / h).astype(int)
    xs = (np.arange(w) * sw / w).astype(int)
    return px[ys][:, xs]


def main():
    a = sys.argv[sys.argv.index("--") + 1:]
    out, mode, paths = a[0], a[1], a[2:]
    ims = [load(p) for p in paths]
    gap = 6
    if mode == "rows":
        ims = [resize(p, W, int(p.shape[0] * W / p.shape[1])) for p in ims]
        h = sum(p.shape[0] for p in ims) + gap * (len(ims) - 1)
        canvas = np.zeros((h, W, 4), np.float32)
        canvas[..., 3] = 1.0
        y = h
        for p in ims:              # (Blender rows run bottom up: the first image goes on top)
            canvas[y - p.shape[0]:y] = p
            y -= p.shape[0] + gap
    else:
        hh = min(p.shape[0] for p in ims)
        ims = [resize(p, int(p.shape[1] * hh / p.shape[0]), hh) for p in ims]
        w = sum(p.shape[1] for p in ims) + gap * (len(ims) - 1)
        canvas = np.zeros((hh, w, 4), np.float32)
        canvas[..., 3] = 1.0
        x = 0
        for p in ims:
            canvas[:, x:x + p.shape[1]] = p
            x += p.shape[1] + gap
        if w > W:
            canvas = resize(canvas, W, int(hh * W / w))
    img = bpy.data.images.new("out", canvas.shape[1], canvas.shape[0], alpha=True)
    img.pixels = canvas.ravel()
    img.filepath_raw = out
    img.file_format = "PNG"
    img.save()
    print("COMPOSE wrote", out, canvas.shape[1], canvas.shape[0])


main()
