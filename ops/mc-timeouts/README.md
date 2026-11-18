# merge-candidate timeouts (coord retro 11-18)

Problem: merge-candidate.sh (meant to take < 4 h) ran 6 h 57 min. suite-plan said WAIT_FOR_WORKER, the script waited 90 min for a GPU
worker, then every suite ran on hetzner alone under xvfb. merge-candidate.log was quiet from 07:23Z: nothing logged per suite.

Files: patched masters (`merge-candidate.sh`, `suite-fast.sh`) and `diff -u` patches against the installed masters
(`coord/boki-tools/merge-candidate.sh` md5 of 11-17 09:32, `~/bin/suite-fast.sh` of 11-18 01:29).

1. **Log (a)** `suite-fast.sh run()`: `suite start <side> <flag>` and `suite end <side> <flag> rc=N Ns` lines on stdout, i.e. in
   merge-candidate.log. A heartbeat every 10 min prints merge/main results done, claims running here and the pods in use (checks that pods
   deliver print no start/end line here, the heartbeat covers them).
2. **Wait cap + split (b)** `merge-candidate.sh`: the WAIT_FOR_WORKER wait is `MC_WAIT_MAX` (1800 s, was 5400). If no GPU worker came
   alive, the idle test (same cgroup CPU probe as the pods) runs over `MC_FALLBACK_WORKERS` / `~/.mc_workers` (ssh aliases `alias:slots`,
   one per line or space separated) plus the normal pods; the idle ones are passed to suite-fast as SUITE_PODS (suite-pod shards).
   None idle: the log says "ran on the server alone (P=6)". The pod probe is now a function `probe_pods`.
3. **Cap (c)** `MC_MAX_SECS` (14400 = 4 h) from T0, minus `MC_TAIL_RESERVE` (900 s) for release/report; the suite gets the rest (min 600 s).
   suite-fast runs under `setsid` and a watchdog TERMs its group by the pid the script saved (KILL after 90 s). The log gets
   `TIMEOUT: ...`, the report headline is `SUITE STOPPED ... TIMEOUT: ...` (existing SUITE-INCOMPLETE path). gpu-perf-report is also
   stopped at cap + 15 min.

Tested (rpc1, synthetic): watchdog with a fake suite and cap 8 s: TIMEOUT logged at 8 s, group killed (children gone, the fake's EXIT trap
ran), rc 143, MC_TIMEOUT flag written, total 20 s. run() with a fake godot logs start/end lines. `bash -n` OK on both. Not tested: a real
4 h run, suite-pod on a non-pod worker (needs the same /root/mcshard + Godot setup as rpc3/rpc5, so list only such hosts in ~/.mc_workers;
a shard that cannot start just leaves its flags to the server, as before).

Install on hetzner (after the live run ends; do not replace the script while it runs): `cp ops/mc-timeouts/merge-candidate.sh
/home/boki/coord/boki-tools/ && cp ops/mc-timeouts/suite-fast.sh /home/boki/coord/boki-tools/suite-fast.sh && boki-install`, and create
`~/.mc_workers` if wanted. INFRA tool: needs the infra-review stamp (no stamp tool exists on this worker).
