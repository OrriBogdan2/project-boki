"""Boki 2D style audit: scores every Boki hero (the site's portrait art) against the two anchors, Vespyx and Mycroll.

Decision 2026-11-09: ONE Boki 2D style, anchored on Vespyx + Mycroll. This measures four traits per hero (subject cropped
and scaled to 640 px tall so size does not matter) and writes a ranked list plus lettered-free review sheets.

  line     outline band width (px) and its contrast with the fill, interior edge density (Sobel)
  shading  luminance steps (24-bin histogram, bins >= 1.5%) and colours covering 90% of the subject (3-bit/channel)
  palette  mean HSV saturation and the 90th percentile saturation
  eye      proxy only: contrast and saturation of the highest local-contrast spot (the eye on a flat-shaded Boki);
           eye STYLE (gloss, iris shape) is judged by looking at the sheets, not by this number

Score = how far a metric sits outside the band spanned by the two anchors (widened by 0.35 x the population IQR),
in IQRs; a trait is the mean over its metrics; total = mean of the four traits.

    python3 tools/boki/style_audit.py HERO_DIR OUT_DIR [--data dex_data.json] [--kin art/kin]

HERO_DIR holds <id>.webp (RGBA cutouts). Sheet borders: green on-style, red off, grey anchor. No verdict text on images.
"""
import argparse
import glob
import json
import os
from multiprocessing import Pool

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ANCHORS = ("vespyx", "mycroll")
H = 640
GROUPS = {"line": ["lw", "lc", "edge"], "shade": ["steps", "ncol"], "palette": ["sat", "vib"], "eye": ["eye_con", "eye_sat"]}
BAND = 0.35  # anchor band widening, in population IQRs
RED_TOTAL = 0.4  # total score above this is off-style
RED_TRAIT = 1.0  # or any single trait above this
GREEN, RED, GREY = (46, 170, 84), (206, 48, 48), (140, 140, 146)
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def _load(path):
    im = Image.open(path).convert("RGBA")
    ys, xs = np.where(np.array(im)[..., 3] > 128)
    if len(ys) == 0:
        return None
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))
    return im.resize((max(1, round(im.width * H / im.height)), H), Image.LANCZOS)


def _conv(x, k):
    p = np.pad(x, 1, mode="edge")
    h, w = x.shape
    return sum(k[i][j] * p[i : i + h, j : j + w] for i in range(3) for j in range(3))


def _mask_img(m):
    return Image.fromarray((m * 255).astype("uint8"))


def _outline(rgb, m):
    """Outline band width (px at 640 tall) and contrast: mean colour of 1 px rings eroded inward from the edge."""
    cur, prev, cols = _mask_img(m), m, []
    for _ in range(26):
        cur = cur.filter(ImageFilter.MinFilter(3))
        nm = np.array(cur) > 0
        ring = prev & ~nm
        if ring.sum() < 50:
            break
        cols.append(rgb[ring].mean(0))
        prev = nm
    if len(cols) < 8:
        return 0.0, 0.0
    dist = np.linalg.norm(np.array(cols) - cols[1], axis=1)[:18]
    top = dist.max()
    half = np.where(dist >= 0.5 * top)[0]
    d = int(half[0]) if len(half) else 18
    width = float(d) if d == 0 else d - 1 + (0.5 * top - dist[d - 1]) / max(dist[d] - dist[d - 1], 1e-6)
    return width, float(top)


def metrics(path):
    im = _load(path)
    if im is None:
        return None
    a = np.array(im).astype(float) / 255
    rgb = a[..., :3]
    m = a[..., 3] > 0.5
    mx, mn = rgb.max(-1), rgb.min(-1)
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    sat = np.where(mx > 0, (mx - mn) / np.maximum(mx, 1e-6), 0)
    grad = np.hypot(_conv(lum, [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]]), _conv(lum, [[-1, -2, -1], [0, 0, 0], [1, 2, 1]]))
    inner = np.array(_mask_img(m).filter(ImageFilter.MinFilter(13))) > 0
    hist = np.histogram(lum[inner], bins=24, range=(0, 1))[0] / max(inner.sum(), 1)
    q = (rgb[inner] * 7).round().astype(int)
    cnt = np.sort(np.bincount(q[:, 0] * 64 + q[:, 1] * 8 + q[:, 2]))[::-1]
    # eye proxy: the spot with the highest local luminance range
    li = Image.fromarray((lum * 255).astype("uint8"))
    rng = (np.array(li.filter(ImageFilter.MaxFilter(15)), float) - np.array(li.filter(ImageFilter.MinFilter(15)), float)) / 255
    deep = np.array(_mask_img(m).filter(ImageFilter.MinFilter(25))) > 0
    rng = np.where(deep, rng, 0)
    spot = (rng >= np.percentile(rng[deep], 99.7)) & deep
    width, contrast = _outline(rgb, m)
    return {
        "lw": round(width, 2),
        "lc": float(contrast),
        "edge": float((grad[inner] > 0.5).mean()),
        "steps": int((hist >= 0.015).sum()),
        "ncol": int(np.searchsorted(np.cumsum(cnt) / cnt.sum(), 0.9) + 1),
        "sat": float(sat[inner].mean()),
        "vib": float(np.percentile(sat[inner], 90)),
        "eye_con": float(rng[spot].mean()),
        "eye_sat": float(sat[spot].mean()),
    }


def _run(path):
    return os.path.basename(path)[:-5], metrics(path)


def score(met):
    """Per-hero {trait: z} and total; z = distance outside the anchor band in population IQRs."""
    band = {}
    for ks in GROUPS.values():
        for k in ks:
            iqr = float(np.subtract(*np.percentile([x[k] for x in met.values()], [75, 25])))
            a = [met[n][k] for n in ANCHORS]
            band[k] = (min(a) - BAND * iqr, max(a) + BAND * iqr, max(iqr, 1e-6))
    out = {}
    for n, x in met.items():
        z = {g: float(np.mean([max(band[k][0] - x[k], x[k] - band[k][1], 0) / band[k][2] for k in ks])) for g, ks in GROUPS.items()}
        z["total"] = float(np.mean(list(z.values())))
        z["red"] = n not in ANCHORS and (z["total"] > RED_TOTAL or max(z[g] for g in GROUPS) > RED_TRAIT)
        out[n] = z
    return out


def _tile(path, size, color, label, sub=""):
    im = Image.open(path).convert("RGBA")
    bg = Image.new("RGBA", im.size, (240, 240, 244, 255))
    bg.alpha_composite(im)
    pad = max(3, size // 40)
    tile = Image.new("RGB", (size, size + (34 if label else 0)), color)
    tile.paste(bg.convert("RGB").resize((size - 2 * pad,) * 2, Image.LANCZOS), (pad, pad))
    if label:
        d = ImageDraw.Draw(tile)
        d.rectangle((0, size, size, size + 34), fill=(30, 30, 34))
        d.text((6, size + 2), label, font=ImageFont.truetype(FONT, 13), fill=(240, 240, 240))
        d.text((6, size + 18), sub, font=ImageFont.truetype(FONT, 11), fill=(170, 170, 176))
    return tile


def sheets(names, heroes, met, sc, out_dir, prefix, rows=4, size=300):
    """Pages of rows: [Vespyx][Mycroll] then 3 Bokis (border colour = verdict, grey = anchor)."""
    per = rows * 3
    paths = []
    for p in range(0, len(names), per):
        page = Image.new("RGB", (size * 5 + 24, rows * (size + 40) + 8), (24, 24, 28))
        for i, n in enumerate(names[p : p + per]):
            r, c = divmod(i, 3)
            y = r * (size + 40) + 4
            for j, a in enumerate(ANCHORS):
                page.paste(_tile(f"{heroes}/{a}.webp", size, GREY, a, _sub(met[a])), (j * (size + 4) + 4, y))
            col = RED if sc[n]["red"] else GREEN
            page.paste(_tile(f"{heroes}/{n}.webp", size, col, n, _sub(met[n])), ((2 + c) * (size + 4) + 4, y))
        path = f"{out_dir}/{prefix}_p{p // per + 1:02d}.png"
        page.save(path)
        paths.append(path)
    return paths


def _sub(x):
    return f"line {x['lw']:.1f}px  steps {x['steps']}  sat {x['sat']:.2f}  eye {x['eye_con']:.2f}"


def overview(names, heroes, sc, out_path, cols=20, size=120):
    rows = -(-len(names) // cols)
    page = Image.new("RGB", (cols * (size + 3) + 3, rows * (size + 3) + 3), (24, 24, 28))
    for i, n in enumerate(names):
        r, c = divmod(i, cols)
        color = GREY if n in ANCHORS else (RED if sc[n]["red"] else GREEN)
        page.paste(_tile(f"{heroes}/{n}.webp", size, color, ""), (c * (size + 3) + 3, r * (size + 3) + 3))
    page.save(out_path)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("heroes")
    ap.add_argument("out")
    ap.add_argument("--data", help="bokidex data.json (alias map, to tell which heroes have an art/kin model)")
    ap.add_argument("--kin", default="art/kin")
    a = ap.parse_args()
    os.makedirs(a.out, exist_ok=True)
    with Pool(8) as pool:
        met = {k: v for k, v in pool.map(_run, sorted(glob.glob(a.heroes + "/*.webp"))) if v}
    sc = score(met)
    in_kin = set()
    if a.data and os.path.isdir(a.kin):
        alias = json.load(open(a.data))["dex"]["aliases"]
        in_kin = {alias.get(k, k) for k in os.listdir(a.kin)}
    ranked = sorted((n for n in met if n not in ANCHORS), key=lambda n: -sc[n]["total"])
    reds = [n for n in ranked if sc[n]["red"]]
    greens = [n for n in reversed(ranked) if not sc[n]["red"]]
    json.dump({"metrics": met, "score": sc, "in_kin": sorted(in_kin & set(met)), "ranked": ranked}, open(f"{a.out}/style_audit.json", "w"), indent=1)
    overview(list(ANCHORS) + ranked[::-1], a.heroes, sc, f"{a.out}/overview_all_worst_last.png")
    pages = sheets(reds, a.heroes, met, sc, a.out, "red_ranked") + sheets(greens, a.heroes, met, sc, a.out, "green_closest_first")
    print(f"{len(met)} heroes, {len(reds)} off-style, {len(greens)} on-style, {len(pages)} pages")


if __name__ == "__main__":
    main()
