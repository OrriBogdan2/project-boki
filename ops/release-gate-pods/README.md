# release-gate-pods (11-19)
Why: the 0.24.18 release gate (11-18 5:20 PM EST) took 7h19m on 11-18 and about 5.5 h on 11-19 (619/622 red, re-run).
Pods ran the 623 merge checks in about 36 min but delivered only PASSES; 147 of 441 pod results were reds (53 % false,
mostly the shared rpc pods under load), and the loaded server (load 19-57, 8 slots) re-ran every pod red: 21.9 server-hours,
13.1 of them pod-red reruns, 20 timeouts at 1200 s. Merge-candidate used the same rpc pods and the server at the same time.

What changed (diff: `release-gate-pods.patch`, apply from `~/bin`; installed 11-19, old copies `*.bak-1119`):
- `release-gate.sh`: writes `~/cj/release-pods.lock` (pid + aliases) from the start until it exits, then uses the pods in
  `~/.release_pods` (`rpg1:8 rpg2:8 rpg3:8`) that are idle in their own cgroup (cgroup v1 pods rpg1/2/4 have no `cpu.stat`: falls back to
  `cpuacct.usage`) with `SUITE_POD_CONFIRM=1`. None idle: `~/.mc_pods` as before.
- `regate_common.gate_workers()` drops the reserved aliases (a PR gate already on a pod finishes); `merge-candidate.sh` skips them.
- `suite-pod` with `SUITE_POD_CONFIRM=1` (dedicated idle pods only): a failing run (exit 1-123) is run once more; red twice, or a
  1200 s timeout (rc 124), is delivered as the verdict. Crashes (134/137/139), ssh loss (255) and not-run codes still go to the server.
- Slots: 8 per pod. The pod container is capped at 64 GB, a Godot run is 4-5 GB: 12 slots x 3 pods gave 44 rc-137 OOM kills.
- Load cap on the server: the existing priority yield (release = 2) already stops merge-candidate (1) starting checks while a release gate lives.

Measured (same 623-check suite, 3 pods x 8 slots, server 4 slots under load 16-39, `suite-fast.sh` end to end, GW=MW copy):
- before: 5.5 h (11-19), 7h19m (11-18)
- after: 2h29m (merge 1h49m incl. a 60 min server tail of pod timeouts and OOMs, main 41 min). The rc-124 verdict rule was added
  during the run (main side used it): its merge tail (~60 min) should go to ~0, not measured.
- Pod accuracy vs the 11-19 server result (idle dedicated pods): 12 slots: 6 false reds of 145 non-OOM reds (4 %) vs 53 % on rpc;
  confirm mode: 1 false red of 141 delivered reds. Pod timeouts matched the server's 6 of 6.
Open: rpg pods are cgroup v1 or v2 mixed, merge-candidate.sh has the same cpu.stat-only idle check (rpc pods are all v2 today).
