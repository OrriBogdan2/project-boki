# suite load gate (11-15)

Problem: on 11-15, gate-0249 and the anim-lane suite were ENV-BROKEN. The aimkit canary hit rc124 on both trees while hetzner was at
load 26-34 on 16 cores with 3-4 GB free (23 Godot runs at once). The trees were fine. The canary runs in `suite-fast.sh` `canary()`
(master `coord/boki-tools/suite-fast.sh`, installed with `boki-install` to `~/bin/suite-fast.sh`). FINDINGS 'suite-env-broken'
(11-13) had a different cause: a broken environment where every check was red. This one is CPU overload.

Files:
- `suite-fast.sh`: the patched master. `suite-fast.patch` is `diff -u` against the 11-15 08:11Z master (md5 6f2118d4631c...).
  It applies with `patch` and gives exactly `suite-fast.sh`.
- `load-wait [secs]`: the same wait for other scripts (an optional `~/bin` helper).

What the patch does (`SUITE_MAX_LOAD`, default 1.5 x nproc = 24 on hetzner; `0` turns all of it off):
1. **Start gate** (before the canary): wait at most `SUITE_LOAD_WAIT` s (900) while loadavg1 > the limit OR
   >= `SUITE_MAX_SUITES` (3) other suites are live. Live suites are pid files in `$SUITE_CACHE_DIR/running/`; dead pids are
   pruned and the file is removed on exit. This caps concurrent suites by load and by count for every launcher: merge lanes,
   merge-candidate, regate and worker gates all go through suite-fast. So there is no separate pacer change.
2. **Per-run gate**: every `run()` waits at most `SUITE_RUN_LOAD_WAIT` s (300) after the memory gate, so concurrent suites back off.
3. **Canary retry**: canary runs with rc124 are rerun once after another wait (`SUITE_RETRY_LOAD_WAIT`, default `SUITE_LOAD_WAIT`).
   Only after that is ENV-BROKEN declared, and its line now carries loadavg1 and the limit.
4. Test hooks: `SUITE_RUN_TIMEOUT` (1200) and `SUITE_CANARY_ONLY=1` (exit 0 after a passing canary).

Proof on rpc7 (32 cores; suite and load pinned to cpus 0-15 with taskset, so nproc = 16 and the limit is 24 like hetzner).
The canary has 10 flags x 2 sides. Load = 26 pinned busy loops for 400 s. The per-run timeout was 60 s instead of 1200, so the
run fits into a test (the idle max is 34 s). Results are in the table below.

| run | script | loadavg1 at start | waits | canary time | rc124 | aimkit merge/main | result |
|---|---|---|---|---|---|---|---|
| idle baseline | new | 15 | 0 s | 69 s | 0 of 20 | 34 s / 24 s | pass, exit 0 |
| **before** | old master | 43 -> 61 | none | 244 s | **20 of 20** | 61 s / 61 s (timeout) | **ENV-BROKEN, exit 3** |
| **after** (start gate) | new | 46 | start 650 s, then 6 per-run 300 s waits | 1029 s | **0 of 20** | 21 s / 17 s | **pass, exit 0** |
| after (retry path: start/per-run waits off) | new | 40 -> 44 | retry 125 s | 362 s | 13 -> 0 | 23 s / 55 s | pass, exit 0 |

(evo-check is red on both trees on this box: 1 of 10, which is below the half threshold.) The 6 x 300 s per-run waits in the
"after" row were a flaw: after the start gate gives up, a box that stays loaded made every run wait again. That is fixed by
`OUT/LOADCAP`: once a wait hits its cap, runs skip the per-run wait for 10 min. A fake-Godot run (`SUITE_MAX_LOAD=1`) gave a
10 s start gate, LOADCAP set, 0 per-run waits. The count cap was tested with a fake live pid plus a dead pid: "1 other suites live
(cap 1)", start gate 10 s, the dead pid pruned, and the suite's own pid file removed on exit. In the "after" row the start gate
waited 650 s, not just until the busy loops ended, because other jobs on rpc7 kept the global loadavg near 28. On hetzner the
gate and the load are on the same 16 cores.

Not built: running the canary on a worker when hetzner is overloaded (the workers do not have the gate trees, and the wait
plus retry is enough). The alternative is a pod canary through `suite-pod`.

Install on hetzner: `cp ops/suite-load-gate/suite-fast.sh /home/boki/coord/boki-tools/suite-fast.sh && boki-install` (or
`patch` the master with `suite-fast.patch`), and optionally `cp ops/suite-load-gate/load-wait ~/bin/`.
