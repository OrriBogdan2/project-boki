# ruff: noqa: F403, F405
import sys

sys.path.insert(0, "tools/art1/rig_test")
from rigkit import *

a = sys.argv[sys.argv.index("--") + 1 :]
arm, body, ms = load(a[0])
r = stretch_metrics(arm, body)
ws = sorted(r.items(), key=lambda kv: -kv[1][0])
print(
    "METRIC worst-edge p99.99 max %.2f ; mean %%edges>2x %.3f ; >3x %.3f ; area max %.1f"
    % (
        max(v[0] for v in r.values()),
        np.mean([v[1] for v in r.values()]),
        np.mean([v[2] for v in r.values()]),
        max(v[3] for v in r.values()),
    )
)
print(
    "LOWER worst-edge p99.9 max %.2f ; mean %%edges>2x %.3f ; area p99.9 max %.1f"
    % (max(v[4] for v in r.values()), np.mean([v[5] for v in r.values()]), max(v[6] for v in r.values()))
)
print("LTOP", [(k, round(v[4], 2), round(v[5], 2)) for k, v in sorted(r.items(), key=lambda kv: -kv[1][4])[:6]])
print("TOP", [(k, round(v[0], 2), round(v[1], 2)) for k, v in ws[:8]])
