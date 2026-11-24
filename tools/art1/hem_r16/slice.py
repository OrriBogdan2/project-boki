import sys

sys.path.insert(0, sys.path[0])
import numpy as np  # noqa: E402
from glbio import acc, json, load, put, save  # noqa: E402,F401
from PIL import Image, ImageDraw

j, b = load(sys.argv[1])
sk = j["meshes"][4]["primitives"][0]
bd = j["meshes"][1]["primitives"][2]


def sl(P, F, y):
    out = []
    for tri in F:
        p = P[tri]
        s = p[:, 1] - y
        pts = []
        for i in range(3):
            a, c = p[i], p[(i + 1) % 3]
            sa, sc = s[i], s[(i + 1) % 3]
            if sa * sc < 0:
                pts.append(a + (c - a) * sa / (sa - sc))
        if len(pts) == 2:
            out.append(pts)
    return np.array(out)


S = acc(j, b, sk["attributes"]["POSITION"])
SF = acc(j, b, sk["indices"]).reshape(-1, 3)
B = acc(j, b, bd["attributes"]["POSITION"])
BF = acc(j, b, bd["indices"]).reshape(-1, 3)
EX = [
    (
        acc(j, b, p["attributes"]["POSITION"]),
        acc(j, b, p["indices"]).reshape(-1, 3),
        (0, 160, 0) if k == 1 else (0, 0, 255),
    )
    for k, p in enumerate(j["meshes"][4]["primitives"][1:], 1)
]
ys = [float(x) for x in sys.argv[3].split(",")]
W = 300
im = Image.new("RGB", (W * len(ys), W + 20), "white")
dr = ImageDraw.Draw(im)
for i, y in enumerate(ys):
    dr.text((i * W + 5, W + 4), f"y {y}", fill="black")
    for P, F, c in [(B, BF, (0, 0, 0)), (S, SF, (220, 0, 0))] + EX:
        m = np.abs(P[F][:, :, 1].mean(1) - y) < 0.05
        seg = sl(P, F[m], y)
        for s_ in seg:
            q = [(i * W + W / 2 + x * W / 0.7, W / 2 - z * W / 0.7) for x, _, z in s_]
            dr.line(q, fill=c, width=1)
    dr.line([(i * W, 0), (i * W, W)], fill=(150, 150, 150))
im.save(sys.argv[2])
