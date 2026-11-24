"""sheets13.py R LIVE A B VERDICT_A VERDICT_B LEGS_A LEGS_B (3 letters run jump crouch): r13 owner sheets from live-audit dirs (each with match/ close/ grip/).
Rows per clip: L (grey border) then A, B in rank order; verdict = border colour only (g = green, r = red per clip,
6 letters in order idle run dash jump attack hit, e.g. ggrggg). Writes R/sheet_game.jpg, sheet_close.jpg, hands.jpg."""

import sys
from PIL import Image, ImageDraw

R, LIVE, A, B, VA, VB = sys.argv[1:7]
GREY, GREEN, RED = (150, 150, 150), (40, 190, 70), (215, 50, 50)
COL = {"g": GREEN, "r": RED}
CL = ["idle", "run", "dash", "jump", "attack", "hit"]
ROWS = [(LIVE, "L", [GREY] * 6), (A, "A", [COL[c] for c in VA]), (B, "B", [COL[c] for c in VB])]


def bordered(im, col, tag, bw=7):
    im = im.convert("RGB")
    W = Image.new("RGB", (im.width + 2 * bw, im.height + 2 * bw), col)
    W.paste(im, (bw, bw))
    d = ImageDraw.Draw(W)
    d.rectangle((bw, bw, bw + 34, bw + 34), fill=(0, 0, 0))
    d.text((bw + 11, bw + 10), tag, fill=(255, 255, 255))
    return W


def crop(p):
    return Image.open(p).crop((200, 200, 500, 500))


n = len(ROWS)
cell = 314
W = Image.new("RGB", (3 * cell, 6 * n * cell), (30, 30, 30))
for r, c in enumerate(CL):
    for s, (d, tag, cols) in enumerate(ROWS):
        for k in range(3):
            W.paste(bordered(crop(f"{d}/match/{c}_{k}.jpg"), cols[r], tag), (k * cell, (n * r + s) * cell))
W.save(R + "/sheet_game.jpg", quality=88)
cw = 300
W = Image.new("RGB", (6 * (cw + 14), 3 * n * (cw + 14)), (30, 30, 30))
for i, c in enumerate(CL):
    views = [
        lambda d: crop(f"{d}/match/{c}_1.jpg"),
        lambda d: Image.open(f"{d}/close/{c}_1_eye.jpg"),
        lambda d: Image.open(f"{d}/close/{c}_1_knee.jpg"),
    ]
    for j, fn in enumerate(views):
        for s, (d, tag, cols) in enumerate(ROWS):
            W.paste(bordered(fn(d).resize((cw, cw)), cols[i], tag), (i * (cw + 14), (n * j + s) * (cw + 14)))
W.save(R + "/sheet_close.jpg", quality=88)
names = ["grip_idle_0", "grip_idle_1", "grip_attack_0", "grip_attack_1"]
hw = 400
W = Image.new("RGB", (4 * (hw + 14), n * (hw + 14)), (30, 30, 30))
for i, nm in enumerate(names):
    for s, (d, tag, cols) in enumerate(ROWS):
        col = GREY if tag == "L" else RED  # hands unchanged in every candidate: no gain
        W.paste(bordered(Image.open(f"{d}/grip/{nm}.jpg").resize((hw, hw)), col, tag), (i * (hw + 14), s * (hw + 14)))
W.save(R + "/hands.jpg", quality=88)
print("sheets written", R)
# legs_back: front/side/back at run f2, jump f1, crouch f0 (CPU qr renders R/qr2/{L,N,A}_*), rows L, A (= N, new), B (= A, old)
QR = [("L", "L", [GREY] * 3), ("N", "A", [COL[c] for c in sys.argv[7]]), ("A", "B", [COL[c] for c in sys.argv[8]])]
blocks = [("run", 2), ("Jump", 1), ("Crou", 0)]
cw, ch = 280, 430
W = Image.new("RGB", (9 * (cw + 14), len(QR) * (ch + 14)), (30, 30, 30))
x = 0
for bi, (key, fr) in enumerate(blocks):
    for v in ("f", "s", "b"):
        for s, (p, tag, cols) in enumerate(QR):
            im = Image.open(f"{R}/qr2/{p}_{key}_{fr}_{v}.png").resize((cw, ch))
            W.paste(bordered(im, cols[bi], tag), (x * (cw + 14), s * (ch + 14)))
        x += 1
W.save(R + "/legs_back.jpg", quality=88)
print("legs_back written")
