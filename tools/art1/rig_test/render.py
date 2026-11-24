# ruff: noqa: F403, F405
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *

a = sys.argv[sys.argv.index("--") + 1 :]
glb, out, px = a[0], a[1], int(a[2])
jobs = [j.split(":") for j in a[3].split(",")]  # clip:frame
arm, body, ms = load(glb)
co = setup_render(px)
P = evalverts(body)
H = float(os.environ.get("HH", 0)) or float(P[:, 2].max() - P[:, 2].min()) - 0.0
if H > 1.9 and "tarek" in glb:
    H = 1.95
VIEWS = views(H)
os.makedirs(out, exist_ok=True)
for clip, fr in jobs:
    if clip not in bpy.data.actions:
        print("missing", clip)
        continue
    pose(arm, clip, int(fr))
    for v, (p, t, k) in VIEWS.items():
        shot(co, f"{out}/{clip}_{fr}_{v}.png", p, t, **k)
