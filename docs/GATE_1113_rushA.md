# Merge rush batch A gate (ext/merge-rush-1113)

Base: origin/main ce8bb5edd0 (PR #48). Built by job 20261113-153649-a4, re-based on main and gated by 20261113-173510-a5 (rpc4).

## Merged (merge, branch)
- f0d7dc07a0 ext/anim-v2-audit-slice
- b65e102b05 ext/sparkle-tooltip-parity
- 6d890d2b19 ext/kael-lmb-chain
- ce4407df6f ext/lace-hail-wisps-rebased
- 676eeb2d51 ext/garden-zones-decision
- 4bc3c61555 ext/perf-merged-drops
- a74794e150 ext/feel-move-ults
- 674364fe40 ext/anim-timing-tender
- 754544224f ext/feel-cast-move-rebased
- 7b57280f04 ext/spec-chao-core-garden
- dfc1d8e93b ext/anim-boss-states
- d964644711 ext/combat-xp-no-trickle
- 88f335775d ext/anim-uthana-pilot
- c87f395de8 ext/anim-uthana-rank
- e5a87816be ext/feel-glide-camera
- 3acb6df4fb ext/feel-online-150
- 2ff3e79614 ext/feel-online-hearth-call
- 134d72a6dd ext/perch-reds
- 490c703ff8 ext/sfx-ui-controls
- 4a69884be2 ext/sfx-remote-casts
- 62c21a0eec ext/anim-boki-stance-linear
- 6130ab56fd ext/feel-dash-exit-shed
- 4ad5aa4c2e ext/tut-first-race-garden
- d1a1aa0d9a ext/cast-move-eight
- d440291a33 ext/sorbeast-t3
- c4a370e385 ext/pitch-reel-1112
- 7005769648 ext/pitch-reel-watchdog
- 2f653fb861 ext/feel-dash-lmb-kael-albert
- 3c56a8f4f9 ext/feel-glide-start-flat

Also: integ 1112d check fixes (aimkit, Grimble slugs, abyss), regenerated docs, the garden check fix below.

## Gate
- Full suite: all 362 registered `-check` flags, headless, 12 at a time, on this branch and on main side by side (same load).
  Red (rc!=0 or a SCRIPT ERROR): branch 81, main 85. Fixed by the batch: --aimkit-check --boss-anim-check --dredge-combo-check --drop-merge-check --online-displace-check --perch-check --sfx-remote-check 
- New reds, all fixed: --garden-first-day-check and --garden-sfx-check (bisected to the tut-first-race-garden merge: a fresh save now opens the one-time practice lap first; the checks mark first_race, as race_check does); --unref-check (tools/anim/uthana_bake.gd is an offline `-s` tool, allow-listed).
- tools/check.sh: STYLE OK, HEALTH OK; SAVECOMPAT fails on the missing v14 golden, same on main (save.gd untouched).
- Export dry run (tools/size_budget.py): every preset packs; 641.3 MB vs baseline 471.5 MB, same 641.3 MB on main (main's baseline is stale; not bumped here).
