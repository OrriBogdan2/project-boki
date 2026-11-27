# Stuck-integ 3b85ff7d (job 20261127-200024-a3, worker w2, 2026-11-27 ~15:40 EST)

Skipped-READY list: 489 names. triage.tsv has one row each (verdict, last commit, commits ahead of main, conflict files).

- 157 gone, 11 already in main.
- 5 merge clean but add nothing over main (superseded): anim-dash-drive-hold, farm-tut-ends, tenzo-press-windup,
  train-auto-1124-1907-b912-2, vfx-rival-read.
- 11 merged here. Base: ext/mc-integ-f1-1118 (the newest mc, 31 behind main), then origin/main, then
  anim-boki-eat-sleep-clips, anim-boki-own-clips-sttv, boki-own-clips-b, farm-garden-day-replay, merge-lane-M7-1121,
  merge-lane-N2-1122, p02-port-1118, sfx-grimble-slug-hits, stuck-integ-dcde0252, ui-native-plate-height.
  These were each clean vs main but conflicted with each other. Fixes:
  - boki_home_clips.gd: kept the eat/sleep branch's `_own()` (the train had its callers but not the function).
  - build_boki.py SPECS: kept both sides (the train's 4 own-anim scans and boki-own-clips-b's glaciyak).
  - sfx_set_check.gd: the only conflict was blank lines; kept the train's.
  - ANIM_COVERAGE.md and wiki/Rules.md: regenerated (--anim-coverage-check, tools/gen_wiki.py).
  - kit golden re-blessed: the plate_offset rows from ui-native-plate-height (5 changed, 6 new) and N2's Sable
    e.ring_r 2.7 (ee825518757).
- 205 conflict with main by themselves. The ones updated since 11-25 are on their own PR or regate path, usually
  1-10 files. The older ones are 1k-11k commits behind and need a port, not a merge.
- 99 were not rescanned: unchanged since the 11-18 triage (ops/stuck-integ-8a30c285), so that verdict still holds.
- stuck-integ-ed6637f4: merge-tree took over 60 s, so it was skipped.

Next: remove the gone, in-main, superseded and 11-18-triaged names from merge-candidate's READY list. Re-posting
them just produces this job again.
