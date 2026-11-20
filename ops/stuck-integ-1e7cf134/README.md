# Stuck-integ 1e7cf134 (job 20261120-155510-a1, worker rpc1, main 81c76afa43, 2026-11-20)

Same skipped-READY list as stuck-integ-8a30c285 / f3c93892 (634 names; 467 still on the remote).
Those 539 rows in ops/stuck-integ-8a30c285/triage.tsv and the 28 in f3c93892 keep their verdict
(superseded / port-from-intent, nothing to merge). This pass only covers names that are new or have commits
since 11-17 19:00 and that no running integ lane or open PR owns.

Base: origin/main, not ext/mc-20261119-0240 (the newest mc): that mc is 593 behind main and 1193 ahead of it,
so a union built on it could not land.

Merged here:
- merge-lane-misc-1117 (1de057df7a): 7 conflicts, both sides kept: main's %K key caps, kin tip, save v21 and
  BokiWispPop consts; the branch's wisp/steal tutorial steps, steal_grab alt, wb.alt line and KILLED_HINT.
- tenzo-eyestones-1118 (9b64740729), with rig-ship-1117 (ee085f2807) merged first: tarek.glb = the branch's
  glb_prop_paint run (eye_stone, shard -> metal-v95) re-run on rig-ship's main-rebuilt tarek.glb (the tool
  reproduces the branch's own glb byte-same); 60439 tris.

Dropped, already in main (0 commits ahead): anim-stop-start-port, tutorial-beats-5-6-port, ui-stolen-wisps-port,
vex-dash-charge-port.
Dropped, owned: boki-more-ingame-1118 (PR #292, merges clean with main), rig-ship-1117 (PR #284; included here
as tenzo-eyestones' base), idle-bulwark-rebased-port (PR #214); everything in the supersedes lists of
stuck-integ-4dec4626 / b996ff59 / f44ae5a2 / d7919026 / 03fec497 (all moved 11-18..11-20).
Superseded: hunters-v95-1117, rig-bakeoff-meshy-1117, rig-bakeoff-weights-1117 (their conflicts are only the
warden glbs; main has newer v95 swaps, 3D CURRENT rule), integ-1113-D3 and stuck-integ-b771bcef (older union
trains, 833-11636 behind; their parts are triaged above).

Next: retire this list from merge-candidate; every name is merged, owned, superseded or in the port backlog.
