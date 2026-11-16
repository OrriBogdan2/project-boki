#!/usr/bin/env python3
"""Void & Masks menu mockup variations (owner 11-10): stronger borders, and panels without the purple/blue accent.

  python3 briefs/boki-art/batch/ui_mockups.py --queue    # append the jobs to jobs.json (coordinator, on ext/agent-briefs; the Mac Vertex runner picks them up)
  python3 briefs/boki-art/batch/ui_mockups.py --preview  # quick local PIL approximation of each variant (no API), into out/
  python3 briefs/boki-art/batch/ui_mockups.py --sheet    # side-by-side contact sheet from out/ (AI runs, else the preview) -> briefs/shots/ui-void-masks-1110/mockups_sheet.jpg
"""
import argparse, json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
SHOTS = ROOT / "briefs/shots/ui-void-masks-1110"
OUT = HERE / "out"
SCREENS = ["01_title", "03_settings", "10_boki_page", "11_market"]
BASE = ("Image 1 is a screenshot of a game's menu UI. Reproduce it exactly: same layout, same text, same icons, same portraits, "
        "same blurred background, same torn-paper neon frame shape with its cracks and tally marks. Change ONLY what is listed, nothing else. ")
STRONG = ("Make the neon frame around every panel stronger: the glowing rim line about twice as thick, with a brighter, crisper core line and a "
          "slightly tighter bloom, and the cracks and tally marks a little bolder. Keep every colour exactly as it is. ")
NO_ACCENT = ("Remove the purple and blue accent from every panel: the panel body becomes a neutral near-black charcoal with no purple tint, and the "
             "cyan/blue half of the frame glow becomes the same warm magenta-pink as the other half, so each panel has one pink neon frame on a neutral "
             "dark body. Keep the pink tabs and buttons. ")
NEUTRAL = ("Remove the purple, blue and cyan accents from every panel: the panel body becomes a neutral near-black charcoal with no purple tint, and the "
           "whole frame glow becomes a soft warm cream-white neon. Pink stays only on the selected tab and the main button. ")
VARIANTS = {  # id suffix -> (label, prompt)
    "strong": ("Stronger borders", BASE + STRONG),
    "noaccent": ("No purple/blue (pink frame)", BASE + NO_ACCENT),
    "neutral": ("No accent (cream frame)", BASE + NEUTRAL),
    "strong_noaccent": ("Stronger + no purple/blue", BASE + STRONG + NO_ACCENT),
}

def jobs():
    return [{"id": f"ui_{s}_{v}", "name": f"UI mockup {s} ({label})", "refs": [f"briefs/shots/ui-void-masks-1110/{s}.jpg"],
             "runs": 1, "aspect": "16:9", "size": "2K", "prompt": prompt}
            for s in SCREENS for v, (label, prompt) in VARIANTS.items()]

def queue():
    path = HERE / "jobs.json"
    have = json.loads(path.read_text())
    ids = {j["id"] for j in have}
    new = [j for j in jobs() if j["id"] not in ids]
    path.write_text(json.dumps(have + new, indent=2))
    print(f"{len(new)} jobs appended to {path.relative_to(ROOT)}")

def _hsv(img):
    return np.asarray(img.convert("HSV"), dtype=np.float32)

def _cool_mask(hsv):  # cyan, blue and purple: hue 150-290 deg (PIL hue is 0-255), with real saturation
    h, s = hsv[..., 0] * 360 / 255, hsv[..., 1] / 255
    return (h > 150) & (h < 290) & (s > 0.12)

def recolour(img, hue_deg):  # cool pixels take the given hue (None = grey), luminance untouched
    hsv = _hsv(img)
    m = _cool_mask(hsv)
    if hue_deg is None:
        hsv[..., 1][m] *= 0.12
    else:
        hsv[..., 0][m] = hue_deg * 255 / 360
    return Image.fromarray(hsv.clip(0, 255).astype(np.uint8), "HSV").convert("RGB")

def thicken(img):  # bright saturated neon lines grow ~2 px each side and get a crisper, more saturated core
    hsv = _hsv(img)
    core = (hsv[..., 1] > 110) & (hsv[..., 2] > 200)
    mask = Image.fromarray((core * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(5))
    grown = img.filter(ImageFilter.MaxFilter(5))
    out = Image.composite(grown, img, mask)
    hsv2 = _hsv(out)
    hsv2[..., 1] = np.where(np.asarray(mask) > 0, hsv2[..., 1] * 1.25, hsv2[..., 1])
    return Image.fromarray(hsv2.clip(0, 255).astype(np.uint8), "HSV").convert("RGB")

PREVIEW = {"strong": lambda im: thicken(im), "noaccent": lambda im: recolour(im, 318),
           "neutral": lambda im: recolour(im, None), "strong_noaccent": lambda im: thicken(recolour(im, 318))}

def preview():
    OUT.mkdir(exist_ok=True)
    for s in SCREENS:
        im = Image.open(SHOTS / f"{s}.jpg").convert("RGB")
        for v, fn in PREVIEW.items():
            fn(im).save(OUT / f"ui_{s}_{v}_preview.jpg", quality=90)
    print("previews in", OUT.relative_to(ROOT))

def sheet():
    cell, pad, head = (640, 360), 12, 44
    cols = 1 + len(VARIANTS)
    font = ImageFont.load_default()
    page = Image.new("RGB", (pad + cols * (cell[0] + pad), head + pad + len(SCREENS) * (cell[1] + pad + 22)), (24, 22, 30))
    d = ImageDraw.Draw(page)
    d.text((pad, 14), "Void & Masks menu mockups (owner 11-10): base | stronger borders | no purple/blue | cream frame | stronger + no purple/blue."
           "  '[preview]' = local approximation, not the AI render yet.", fill=(230, 230, 230), font=font)
    for r, s in enumerate(SCREENS):
        y = head + r * (cell[1] + pad + 22)
        for c, v in enumerate([None, *VARIANTS]):
            x = pad + c * (cell[0] + pad)
            ai = OUT / f"ui_{s}_{v}_1.jpg"
            pv = OUT / f"ui_{s}_{v}_preview.jpg"
            src = SHOTS / f"{s}.jpg" if v is None else (ai if ai.exists() else pv)
            tag = s if v is None else VARIANTS[v][0] + ("" if ai.exists() else " [preview]")
            if src.exists():
                page.paste(Image.open(src).convert("RGB").resize(cell), (x, y + 20))
            else:
                tag += " (missing)"
            d.text((x, y + 4), tag, fill=(255, 210, 240) if v else (255, 255, 255), font=font)
    dest = SHOTS / "mockups_sheet.jpg"
    page.save(dest, quality=88)
    print("wrote", dest.relative_to(ROOT))

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--queue", action="store_true"); ap.add_argument("--preview", action="store_true"); ap.add_argument("--sheet", action="store_true")
    a = ap.parse_args()
    if a.queue: queue()
    if a.preview: preview()
    if a.sheet: sheet()
    if not (a.queue or a.preview or a.sheet): print(json.dumps(jobs(), indent=2))
