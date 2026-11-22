"""mk_sheet.py OUT.jpg VERDICTS : 1600px owner sheet, hybrid Sable (in-game Godot + Blender eye) vs live contract Sable.
VERDICTS = clip=green|red,... ; border colour is the only verdict (grey = live). Letters: A = hybrid, B = live."""

import sys, os
from PIL import Image, ImageDraw, ImageFont

J = "/home/boki/jobq/done"
NAT, LV1, LV2 = (
    f"{J}/20261121-224510-19240/out/states",
    f"{J}/20261121-224510-13709/out",
    f"{J}/20261121-225237-28716/out",
)
EYE = f"{J}/20261121-221535-27493/out/A_eye"
ROWS = [
    ("Idle", range(0, 16), LV1 + "/idle", "Idle"),
    ("Walk", range(16, 28), LV2 + "/walk_f", "walk"),
    ("Run", range(28, 40), LV2 + "/run_f", "run"),
    ("Jump", range(40, 50), LV1 + "/jump", "Jump_Run"),
    ("Attack", range(50, 63), LV2 + "/lmb_l", "Attack"),
    ("Crouch", range(63, 73), LV1 + "/crouch_f", "Crouch_Walk_with_Torch"),
]
C = {"grey": (150, 150, 150), "green": (40, 200, 70), "red": (220, 50, 50)}
F = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 24)
V = dict(x.split("=") for x in sys.argv[2].split(","))


def tile(im, col, lab, w=512):
    im = im.convert("RGB")
    im = im.resize((w, round(im.height * w / im.width)))
    b = Image.new("RGB", (w + 14, im.height + 14), col)
    b.paste(im, (7, 7))
    d = ImageDraw.Draw(b)
    d.rectangle((7, 7, 7 + d.textlength(lab, font=F) + 12, 40), fill=(25, 25, 30))
    d.text((13, 9), lab, font=F, fill=(255, 255, 255))
    return b


def mid(d, k):
    fs = sorted(os.listdir(d))
    return Image.open(f"{d}/{fs[min(len(fs) - 1, int(len(fs) * k))]}")


rows = []
for lab, rng, lv, eyec in ROWS:
    n = sorted(os.listdir(NAT))
    r = list(rng)
    fr = n[r[len(r) // 2]]
    ts = [
        tile(Image.open(f"{NAT}/{fr}"), C[V[lab.lower()]], f"A  {lab}  in game"),
        tile(Image.open(f"{EYE}/{eyec}/eye_3.jpg"), C[V[lab.lower()]], f"A  {lab}  eye level"),
        tile(mid(lv, 0.8), C["grey"], f"B  {lab}  live"),
    ]
    row = Image.new("RGB", (1600, max(t.height for t in ts)), (20, 20, 20))
    x = 0
    for t in ts:
        row.paste(t, (x, 0))
        x += t.width + 8
    rows.append(row)
S = Image.new("RGB", (1600, sum(r.height for r in rows)), (20, 20, 20))
y = 0
for r in rows:
    S.paste(r, (0, y))
    y += r.height
S.save(sys.argv[1], quality=88)
print(S.size)
