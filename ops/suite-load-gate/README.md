# suite load gate (11-15)

Problem: gate-0249 and the anim-lane suite were ENV-BROKEN. The aimkit canary hit rc124 on both trees while hetzner had load 26-34 on 16
cores and 3-4 GB free (23 Godot runs at once). The canary lives in `suite-fast.sh` (master `coord/boki-tools/suite-fast.sh`, `boki-install`).

Fix (`suite-fast.patch` applies to the 11-15 08:11Z master; the master is already patched):
- `load_wait`: wait until loadavg1 <= `SUITE_MAX_LOAD` (default 1.5 x nproc = 24), max `SUITE_LOAD_WAIT` (900 s), before the canary.
- every `run()` also waits (max `SUITE_RUN_LOAD_WAIT`, 300 s), so concurrent suites back off by load. `SUITE_MAX_LOAD=0` disables.
- a canary with rc124 timeouts is a loaded box, not a broken tree: wait again, rerun the timeouts once, only then ENV-BROKEN
  (the message now carries loadavg1).
- `SUITE_RUN_TIMEOUT` (default 1200) and `SUITE_CANARY_ONLY=1` (stop after the canary) are test hooks.
- `load-wait [secs]` (install to ~/bin): same wait for scripts; called by merge-candidate.sh `import_tree` and 1114 `start-lanes.sh` per lane.

Proof on w2 (16 cores, 4 canary flags x 2 trees, 24 busy loops added; per-check timeout set to 60 s instead of 1200 so a test fits):

| run | loadavg1 at start | gate wait | canary run | result |
|---|---|---|---|---|
| idle baseline (new script) | 10 | 0 s | 114 s | pass (aimkit 28 s / 24 s) |
| before (old script) | 26 -> 41 | none | 127 s | 8 of 8 rc124 (aimkit 61 s), ENV-BROKEN, exit 3 |
| after (new script) | 26 -> 18 | 205 s | 53 s | pass (aimkit 25 s / 22 s), exit 0 |

(evo-check is red on both trees here: 1 of 4, below the half threshold, so the canary passes.) The retry-after-timeout path is
untested under load; the "run the canary on a worker" option was not built (the wait is enough and workers lack the trees).
