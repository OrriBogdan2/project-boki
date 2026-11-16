"""python compose.py OUTDIR  (reads ba_out/<h>/ + HUNT table) -> OUTDIR/<h>.jpg"""
import sys, json, os
from PIL import Image, ImageDraw, ImageFont
BA, OUT = sys.argv[1], sys.argv[2]
SPL = "/home/boki/site-repo/assets/img/hunters/%s-1600.webp"
HUNT = json.load(open(os.path.join(os.path.dirname(__file__), "hunters.json")))
GREY, GREEN, RED = (128, 128, 128), (40, 170, 60), (200, 40, 40)
F = lambda s: ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", s)
PH = 760; B = 10; G = 14; MH = 700   # panel height, border, gap, model px height for the tallest model
def tile(h, tag, ppm_t, meta):
    m = meta[tag]; ims = []
    for v in ("front", "tq"):
        im = Image.open(f"{BA}/{h['id']}/{h['id']}_{tag}_{v}.png").convert("RGBA")
        k = ppm_t / (m["res_h"] / m["H_view"])
        im = im.resize((max(1, int(im.width * k)), max(1, int(im.height * k))), Image.LANCZOS)
        bb = im.getchannel('A').point(lambda v: 255 if v > 8 else 0).getbbox()
        if bb: im = im.crop((max(0, bb[0] - 24), 0, min(im.width, bb[2] + 24), im.height))
        ims.append(im)
    foot = (m["H_view"] - m["dims"][2]) / 2 * ppm_t        # px under the feet inside the image
    w = sum(i.width for i in ims)
    t = Image.new("RGB", (w, PH), (214, 214, 218)); x = 0
    for i in ims:
        t.paste(i, (x, int(PH - 20 - foot - (i.height - foot))), i); x += i.width
    return t
def label(t, txt, sub=None):
    d = ImageDraw.Draw(t); d.text((10, 8), txt, fill=(20, 20, 20), font=F(24))
    if sub: d.text((10, 38), sub, fill=(60, 60, 60), font=F(17))
for h in HUNT:
    if not os.path.exists(f"{BA}/{h['id']}/{h['id']}_meta.json"): continue
    meta = json.load(open(f"{BA}/{h['id']}/{h['id']}_meta.json"))
    ppm = lambda m: m["res_h"] / m["H_view"]
    hmax = max(m["dims"][2] for m in meta.values())
    ppm_t = MH / hmax                       # one px/metre for all four views of this hunter
    to, tn = tile(h, "old", ppm_t, meta), tile(h, "new", ppm_t, meta)
    label(to, f"OLD ({h['old_lbl']})", h["name"]); label(tn, f"NEW ({h['new_lbl']})", h["name"])
    sp = Image.open(SPL % h["splash"]).convert("RGB"); sp = sp.resize((640, int(sp.height * 640 / sp.width)), Image.LANCZOS); pn = Image.new("RGB", (640, PH), (214, 214, 218)); pn.paste(sp, (0, 70)); sp = pn
    label(sp, f"{h['name']} live splash")
    col = GREEN if h["better"] else RED
    tiles = [(sp, GREY), (to, GREY), (tn, col)]
    W = sum(t.width + 2 * B + G for t, _ in tiles)
    im = Image.new("RGB", (W, PH + 2 * B), (255, 255, 255)); x = 0
    for t, c in tiles:
        ImageDraw.Draw(im).rectangle([x, 0, x + t.width + 2 * B, PH + 2 * B], fill=c); im.paste(t, (x + B, B)); x += t.width + 2 * B + G
    s = min(1.0, 2400 / im.width); im = im.resize((int(im.width * s), int(im.height * s)), Image.LANCZOS)
    im.save(f"{OUT}/{h['id']}.jpg", quality=88); print(h["id"], im.size)
