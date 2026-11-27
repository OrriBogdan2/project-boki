"""sheet33.py OUT VIEW LIVE_DIR A_DIR VERDICT [B_DIR VERDICT_B]: owner sheet, one row per clip (idle run dash jump attack hit),
frames 0-2 of LIVE (grey border, tag L) then A (and B) in rank order. Verdict = border colour only, 6 letters g/r per clip.
VIEW = match (game camera, clip_i.jpg) | eye | knee (close, clip_i_VIEW.jpg). Dirs are live-audit shot dirs (archer/)."""
import sys
from PIL import Image, ImageDraw

out, view, live = sys.argv[1:4]
cols = [(live, "L", "x" * 6)] + [(sys.argv[k], "AB"[(k - 4) // 2], sys.argv[k + 1]) for k in range(4, len(sys.argv), 2)]
COL = {"g": (40, 190, 70), "r": (215, 50, 50), "x": (150, 150, 150)}
CL = ["idle", "run", "dash", "jump", "attack", "hit"]
cell, bw = 240, 6
W = len(cols) * 3 * (cell + 2 * bw) + (len(cols) - 1) * 16
sheet = Image.new("RGB", (W, 6 * (cell + 2 * bw)), (20, 20, 20))
for r, c in enumerate(CL):
    x = 0
    for d, tag, v in cols:
        for f in range(3):
            im = Image.open(f"{d}/{c}_{f}.jpg" if view == "match" else f"{d}/{c}_{f}_{view}.jpg").convert("RGB").resize((cell, cell))
            b = Image.new("RGB", (cell + 2 * bw, cell + 2 * bw), COL[v[r]]); b.paste(im, (bw, bw))
            dr = ImageDraw.Draw(b); dr.rectangle((bw, bw, bw + 22, bw + 22), fill=(0, 0, 0)); dr.text((bw + 8, bw + 6), tag, fill=(255, 255, 255))
            sheet.paste(b, (x, r * (cell + 2 * bw))); x += cell + 2 * bw
        x += 16
sheet.save(out, quality=90)
print(out, sheet.size)
