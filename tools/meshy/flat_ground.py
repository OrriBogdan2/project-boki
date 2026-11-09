"""Flattens an edited view's background to one grey: every near-grey pixel connected to the image's border (a
flood fill, so a pale translucent fin inside the figure is kept) becomes the border's median grey. A padded crop
leaves the art's own lighter rectangle and floor band behind it, which Meshy can model as a slab.
Blender's Python (numpy):
  python3 -I tools/meshy/flat_ground.py IN.png OUT.png [tol 0.07] [sat_max 0.09] [dark 0.25: how far below the backdrop a grey still counts, e.g. a floor shadow]"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np  # noqa: E402
import imgio  # noqa: E402


def main(a):
    im = imgio.load(a[0])
    tol = float(a[2]) if len(a) > 2 else 0.07
    sat_max = float(a[3]) if len(a) > 3 else 0.09
    dark = float(a[4]) if len(a) > 4 else 0.25
    h, w = im.shape[:2]
    border = np.concatenate([im[:4].reshape(-1, 3), im[-4:].reshape(-1, 3), im[:, :4].reshape(-1, 3), im[:, -4:].reshape(-1, 3)])
    bg = np.median(border, axis=0)
    mx, mn = im.max(axis=2), im.min(axis=2)
    sat = (mx - mn) / np.maximum(mx, 1e-4)
    # grey and light: the backdrop, the floor band, the art's lighter rectangle, a soft floor shadow
    grey = (sat < sat_max) & (mx > bg.max() - dark) & (np.abs(im - im.mean(axis=2, keepdims=True)).max(axis=2) < tol)
    reach = np.zeros_like(grey)
    reach[0, :] = grey[0, :]
    reach[-1, :] = grey[-1, :]
    reach[:, 0] = grey[:, 0]
    reach[:, -1] = grey[:, -1]
    for _ in range(4 * max(h, w)):
        grow = reach.copy()
        grow[1:] |= reach[:-1]
        grow[:-1] |= reach[1:]
        grow[:, 1:] |= reach[:, :-1]
        grow[:, :-1] |= reach[:, 1:]
        grow &= grey
        if (grow == reach).all():
            break
        reach = grow
    out = im.copy()
    out[reach] = bg
    imgio.save(out, a[1])
    print("FLATGROUND %s: %.1f%% flattened to %s" % (os.path.basename(a[1]), 100.0 * reach.mean(), np.round(bg * 255).astype(int)))


if __name__ == "__main__":
    main(sys.argv[1:])
