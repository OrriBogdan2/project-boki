"""Nearest point on a polyline, for texel arrays (no scipy on Blender's python)."""
import numpy as np


def nearest_on_path(p, n, path):
    """-> (u 0..1 along the path, the texel normal's share along the path's 'up' side)."""
    path = np.asarray(path)
    d = np.linalg.norm(p[..., None, :] - path, axis=-1)
    i = d.argmin(-1)
    u = i / (len(path) - 1)
    tg = np.gradient(path, axis=0)
    tg /= np.linalg.norm(tg, axis=-1, keepdims=True)
    t = tg[i]
    # the outer side of the curve is its back: "down" is toward the ground and in
    up = np.array([0, 0, 1.0]) - t * t[..., 2:3]
    up /= np.maximum(np.linalg.norm(up, axis=-1, keepdims=True), 1e-5)
    return u, np.sum(n * up, -1)
