"""How blotchy each Boki's coat is, read off its coat atlas (every Boki, no renderer needed).

The coat = the coat material's texels (its uv triangles, rasterized) whose chromaticity is within KEY of their median
(eyes, horns, mane painted in the same atlas are left out). Per species: lum_std (sRGB luminance std-dev over the
coat), hf_std (the same after taking out a 16 px blur at 1024 px: flecks and blotches, not the big colour regions),
mean lum and HSV saturation. --look=<species> also emulates that species' FRAME "coat" albedo_flat override
(hero_toon.gdshader: mip-mean colour * gain, key-weighted mix, contrast about it) and desat on the texels;
dark_lift acts on the lit colour, so it is not in these numbers.

  python tools/boki/coat_blotch.py art/kin/*/*.glb [--before=heatherhorn:<old atlas>] [--look=heatherhorn]
"""

import argparse
import io
import sys

import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

sys.path.insert(0, __file__.rsplit("/", 1)[0])
from boki_delight import coat, image_bytes, load, to_lin, to_srgb  # noqa: E402

RES = 1024
KEY = 0.1
LUMA = np.array([0.3, 0.59, 0.11])  # the shader's luma weights
# heatherhorn's FRAME "coat" (scripts/match/boki_rig.gd)
LOOKS = {
    "heatherhorn": {
        "albedo_flat": 0.7,
        "contrast": 0.5,
        "gain": 1.7,
        "key": np.array([0.72, 0.165, 0.116]),
        "key_width": 0.1,
        "desat": 0.2,
    }
}


def coat_mask(uv, tri):
    m = Image.new("L", (RES, RES), 0)
    d = ImageDraw.Draw(m)
    px = np.stack([uv[:, 0] % 1 * RES, uv[:, 1] % 1 * RES], 1)
    for t in tri:
        d.polygon([tuple(px[i]) for i in t], fill=255)
    return np.asarray(m) > 0


def apply_look(lin, lk):
    tf = lin.reshape(-1, 3).mean(0) * lk["gain"]  # lod 11 of a 2048 atlas: one texel, the mean
    s = lin.sum(2, keepdims=True)
    kc = lk["key"] / lk["key"].sum()
    d = np.linalg.norm(lin / np.maximum(s, 1e-4) - kc, axis=2)
    w = lk["key_width"]
    t = np.clip((d - w) / (w * 0.6), 0, 1)
    kw = (1 - t * t * (3 - 2 * t))[..., None]
    tx = lin + (tf - lin) * lk["albedo_flat"] * kw
    tl = tx @ LUMA
    fl = tf @ LUMA
    tx = np.maximum(tx + ((tl - fl) * (lk["contrast"] - 1))[..., None] * kw, 0)
    g = (tx @ LUMA)[..., None]
    return tx + (g - tx) * lk["desat"]


def stats(lin, mask):
    srgb = to_srgb(lin)
    s = lin.sum(2)
    ch = lin / np.maximum(s, 1e-4)[..., None]
    med = np.median(ch[mask], 0)
    m = mask & (np.linalg.norm(ch - med, axis=2) < KEY)
    lum = srgb @ np.array([0.2126, 0.7152, 0.0722])
    mf = m.astype(float)
    blur = ndimage.gaussian_filter(lum * mf, 16) / np.maximum(ndimage.gaussian_filter(mf, 16), 1e-4)
    mx, mn = srgb.max(2), srgb.min(2)
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-4), 0)
    return lum[m].std(), (lum - blur)[m].std(), lum[m].mean(), sat[m].mean(), m.mean() / max(mask.mean(), 1e-6)


def atlas(path, j, b, img):
    raw = image_bytes(j, b, img) if path is None else open(path, "rb").read()
    im = Image.open(io.BytesIO(raw)).convert("RGB").resize((RES, RES), Image.LANCZOS)
    return to_lin(np.asarray(im).astype(float) / 255)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("glbs", nargs="+")
    ap.add_argument("--before", action="append", default=[])
    ap.add_argument("--look", action="append", default=[])
    a = ap.parse_args()
    before = dict(x.split(":", 1) for x in a.before)
    print("species\tstate\tlum_std\thf_std\tlum\tsat\tcoat_frac")
    for p in a.glbs:
        sp = p.rsplit("/", 2)[1]
        j, b = load(p)
        _n, uv, tri, img = coat(j, b)
        mask = coat_mask(uv, tri)
        rows = []
        if sp in before:
            rows.append(("before", atlas(before[sp], j, b, img)))
        lin = atlas(None, j, b, img)
        rows.append(("atlas", lin))
        if sp in a.look:
            rows.append(("after", apply_look(lin, LOOKS[sp])))
        for state, x in rows:
            print("%s\t%s\t%.3f\t%.3f\t%.3f\t%.3f\t%.2f" % ((sp, state) + stats(x, mask)))


if __name__ == "__main__":
    main()
