# ruff: noqa: F403, F405
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *

a = sys.argv[sys.argv.index("--") + 1 :]
arm, body, ms = load(a[0])
r = tail_gap(arm, body, a[1].split(","))
print("TAIL", {k: v for k, v in r.items() if k != "clips"})
print("TAILCLIPS", {k: (round(v[0], 3), round(v[1], 3)) for k, v in r["clips"].items()})
