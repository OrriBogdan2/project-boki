# Merge archive 11-13: rpc7 copy + delta (job 20261113-225202-a5, restart of 161526-a4)

The archive pass itself was done by job 20261113-173508-a3 (escalated from 161526-a4) on `ext/merge-archive-1113` ec8eaa0c68, main ce8bb5edd0. Full report below, unchanged. Delta vs main 96d778d036 (after PRs #54 #55 #56):

- 34 of the 717 keep branches are now ancestors of main (landed with lane C #54 / #56): they leave merge-gap by themselves; no tag or exclude needed. Lane C/D may tag+delete them as with their 29.
- 5 keep branches no longer exist on origin (deleted after merge by lane C; restore lines in coord/merge-week-1113-laneC-archive.log where listed).
- No new (a)/(b)/(c) archives: no new merged branch covers a kept branch beyond those that landed outright (not re-run line by line; the 40 archived stay).
- Keep list now about 678. Gap: 1448 -> 1408 (pass) -> about 1369 after the 39 above; hetzner merge-gap not run (not on rpc7).

## Now on main or gone (39)

- `ext/albert-hold-cinder-orb` deleted from origin
- `ext/anim-boki-stance-linear` 5d8e58e447 on main
- `ext/anim-lace-release-snap` a9320f4402 on main
- `ext/anim-timing-dolm` 7427be4d3b on main
- `ext/anim-uthana-rank` 8eb9e732a4 on main
## Now on main or gone (39)

- `ext/albert-hold-cinder-orb` deleted from origin
- `ext/anim-boki-stance-linear` 5d8e58e447 on main
- `ext/anim-lace-release-snap` a9320f4402 on main
- `ext/anim-timing-dolm` 7427be4d3b on main
- `ext/anim-uthana-rank` 8eb9e732a4 on main
- `ext/art-keepers` 44c59c8d52 on main
- `ext/cast-move-eight` 139fbc5f52 on main
- `ext/combat-blockers` b871bdb2d0 on main
- `ext/combat-far-bot-ground` ddef9fe17a on main
- `ext/combat-lace-spirit-ledges-rebased` 92117d4ea6 on main
- `ext/combat-ranks-a` 793a547bc9 on main
- `ext/feel-glide-start-flat` a7adf785a1 on main
- `ext/feel-online-150` a3d6d7942a on main
- `ext/feel-online-hearth-call` f3ca10626d on main
- `ext/garden-zones-decision` c312e6c577 on main
- `ext/online-displace-reds` 2372f1b680 on main
- `ext/parity-tenzo-ridge` a922cd7cd9 on main
- `ext/perch-reds` db8bcad687 on main
- `ext/perf-1111` d98e4f6c6c on main
- `ext/perf-anim-distance-rate` be0f7e959b on main
- `ext/perf-assets-1111` d7cd210b43 on main
- `ext/pitch-reel-1112` 3b75ca7897 on main
- `ext/pitch-reel-watchdog` 6c89ec19b1 on main
- `ext/sfx-remote-casts` 7adceb3241 on main
- `ext/sfx-ways-out-ticks` 171de513a1 on main
- `ext/tenzo-arm-slate` deleted from origin
- `ext/tut-first-egg-line` ecd5757c8a on main
- `ext/tut-first-ult` 9563f53ebc on main
- `ext/tut-first-zone` 4eee5d9090 on main
- `ext/ui-counter-overlap` d784ca2c18 on main
- `ext/ui-edge-markers-one` deleted from origin
- `ext/ui-keybind-conflicts` 3e1ef972d0 on main
- `ext/ui-kit-panel-fight` 9ac27981ee on main
- `ext/ui-results-plain` deleted from origin
- `ext/ui-self-shield-strip` cda55bd826 on main
- `ext/ui-zone-cards` deleted from origin
- `ext/uplink-tour-stall` 6b851bbd0a on main
- `ext/vfx-particle-budget-fight` de83d37d9f on main
- `ext/vfx-vex-ult-core` 213cb4fed6 on main

