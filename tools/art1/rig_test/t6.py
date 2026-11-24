# ruff: noqa: F403, F405
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *

a = sys.argv[sys.argv.index("--") + 1 :]
arm, body, ms = load(a[0])
clips = a[1].split(",")
r, n = web_metric(arm, body, clips)
print("WEBTRIS", n)
for c, v in r.items():
    print("WEB", c, "total area ratio %.2f p99 tri ratio %.1f worst frame %d" % v)
