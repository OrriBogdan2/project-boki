# Check timing (headless, one at a time, 16-core box, 2026-11-09)

Every non-`-shots` entry in tools/check_registry.gd, 115 flags, total 4534 s before. Two (--hero-vfx-gallery, --lineup-shot) and --cliff-mantle-check hit the 300 s timeout. --boki-dash-check had 13 FAIL lines at baseline.

| # | flag | seconds | PASS lines |
|---|---|---|---|
| 1 | --cliff-mantle-check | 300 | 0 |
| 2 | --hero-vfx-gallery | 300 | 0 |
| 3 | --lineup-shot | 300 | 0 |
| 4 | --dash-flow-check | 155 | 0 |
| 5 | --boki-dash-check | 123 | 13 |
| 6 | --perkorb-check | 103 | 0 |
| 7 | --perf-bench | 85 | 0 |
| 8 | --juggernaut-combo-check | 82 | 0 |
| 9 | --music-leave-check | 79 | 0 |
| 10 | --support-check | 78 | 0 |
| 11 | --hero-combo-check | 75 | 0 |
| 12 | --shake-check | 74 | 0 |
| 13 | --keys-check | 72 | 0 |
| 14 | --displace-net-check | 70 | 0 |
| 15 | --kin-loss-check | 65 | 0 |
| 16 | --boki-lines-check | 63 | 0 |
| 17 | --bulwark-combo-check | 59 | 0 |
| 18 | --prologue-check | 58 | 0 |
| 19 | --rimewright-combo-check | 58 | 0 |
| 20 | --equal-check | 57 | 0 |

## Speed-ups
- --music-leave-check: crossfade settles run at Engine.time_scale 4 (the fades are game-time tweens): 79 s to 40 s, 18 PASS, 0 failures, same asserts.
- The rest of the top 10 are real simulation (a full Match.start per hero and slot, thousands of m.step calls) with no warm-up to cut; shared setup would risk cross-test state. Each run also pays about 10 s of boot.

## Advisory timing checks (2026-11-11)

`--hitch-check` and `--load-check` judge wall-clock frame times. On a shared CPU box (llvmpipe, other
suites on the same cores) those swing with load, not with the code: the 0.24.4 gate saw hitch at 2
then 6 fails on the same base tree (docs/GATE_0244.md). So the rule:

- In `tools/check_registry.gd` both entries carry `"advisory"`. They still run in the suite and print
  every frame line; a fail prints its verdict as `ADVISORY` instead of `FAIL` and exits 0, so it never
  turns a suite row red. A script error still does.
- The numbers are judged on a GPU host. `CheckRegistry.GPU_HOST` holds the strict runs; the gate sends
  each through jobq and treats a non-zero exit or a `FAIL` line as red:
  `jobq submit --needs gpu --tree <tree> --out hitch-gpu -- --hitch-check --timing-strict`
  `jobq submit --needs gpu --tree <tree> --out load-gpu -- --load-check --timing-strict`
- `--timing-strict` on any machine makes a fail a fail again (use it when you profile on a quiet box).
- A new timing check (wall-clock frame or load budgets) gets `"advisory"` and a `GPU_HOST` line too.
  Checks that only count things (build steps, nodes, draw calls) stay strict everywhere; hitch-check's
  late-shader-compile fails go advisory with the rest of it on the CPU box and stay strict on the GPU host.
