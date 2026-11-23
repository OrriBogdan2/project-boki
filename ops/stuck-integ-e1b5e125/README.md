# Stuck-integ e1b5e125 (job 20261117-075513-a6, worker rpc4, main 01df2cea19, 2026-11-17)

Same skipped-READY list as ext/stuck-integ-62ec7ba9 (11-15, 825 rows; see its triage.tsv for unlanded-line counts)
plus 32 newer lane/batch branches. Merging ~600 branches that are 1k-17k commits behind main is not useful:
62ec7ba9 showed most conflicts are main fixing the same thing another way. This pass refreshes the classes.

refresh.tsv (one row per branch, vs main 01df2cea19):
- MERGED / MERGED-NOW 179: READY sha is now an ancestor of main (159 landed since 11-15 via the merge-lane trains). Drop from the stuck list.
- GONE 88, MISSING 1: branch deleted / READY sha not on the remote. Drop.
- CLEAN 3: same as 62ec7ba9 (all judged superseded or needing their own gate there).
- CONFLICT 587: unchanged; port per area, smallest unlanded first (62ec7ba9 triage.tsv).

Newer branches checked by hand (all other new rows are MERGED):
- merge-lane-feelcombat-1115 03628d40b2: TAKEN (cherry-pick). Main's msg_queue_check still writes hud.dealt_at, which moved to
  hud.reticle: SCRIPT ERROR on main, gone here (MSGQ failures 0 both, error only on main).
- merge-lane-hunters8-1114 d3c7a0bfe8: superseded, camera source_scale A/B (cam.gd, camera_ab_shots.gd) is on main.
- merge-lane-vfx1-1114 c092a744c9: superseded, main kept boki_unfuse (content/sfx/boki.json) so its fallback is valid.
- fix-strafe-cadence-1115: only a WIP checkpoint + its cleanup; nothing to take.
- hero-portraits-a-1114: art (13 hero portraits, 0 on main). Image-only: route through art-merge, not code integ.
- merge-lane-misc2-1115: merge commits only.
- garden1, hunters2-b/3/4, uihud/-b, misc2-b, batch-15/24 (46-269 ahead): left CONFLICT for per-area port jobs.
