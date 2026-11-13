# 0.24.4 integration (ext/release-integ-0244)

Built on origin/main d255acbee. Three integrator jobs worked on it:
- 20261110-041746-a4 made the merges up to ec7bccf3b, then was killed (out of memory on w3).
- 20261110-070137-a4 finished the merges up to 315233359 and posted READY.
- 20261110-065226-a4 ran in parallel. Its two fixes this head lacked sit on top: the matchmaker list and the new-player-flow starter pick. It also ran the full-suite gate and wrote this file.

`Net.VERSION` is 0.24.4.

## What is in
- **Base:** ext/gatefix-w2 at ad678cd20, with the Tier 2 branches it carries.
- **Tier 1, all merged except the two below:** tutorial-visibility, pick-order, calm-hud, glide-fixes, tut-starter-three, tut-fight-per-starter, sparkle-dash, cinder-lmb, motley-tune, meeko-root, brall-slam, vex-daze, vex-rmb-hit, vex-rmb-terrain, kael-rmb-unlock, dredge-hook2 (b1f06fb96, supersedes dredge-hook), dredge-rmb, dredge-auto, gil-hunter-art (75c194aa9), tenzo-edge, grimble-v95 (449680294).
- **Tier 2:** feel-cc-exit-buffer, feel-dash-scale-source, anim-additive-flinch, vfx-albert-kit, vfx-dash-streak, vfx-sparkle-kit, sfx-glider, sfx-capture, sfx-run-stingers, sfx-dash-per-hunter, ui-boki-quick-keys, ui-squad-rows, combat-ranges-radii, combat-dmg-to-boki, combat-hp-regen.
- **Tier 0, all fixed:** bot-sanity flags 0 windows (bots now open the glider past the top of the take-off jump), `--glide-hold-check` passes, and `health --strict` passes.
- **Fixes on top of 315233359:**
  - The matchmaker's `HUNTERS` list now includes Gil and follows Arch.ORDER again. Without it, the unittest step in release.yml fails `test_hunters_match_the_game`.
  - `--new-player-flow-check` now takes Vex on tut-starter-three's starter pick. Before this, it stalled for 60 s waiting for the first Relic.

## What was left out (and why)
- **spike-slam:** it conflicts in 7 combat/kit files (displace, effects, dredge_kit, breah_slam, dolm/dredge data) and needs a rebase.
- **tut-first-race** and **sfx-garden-games:** they are stacked on the unmerged ext/garden-integrated line (74 commits). They should land with the garden integration.
- **feel-knock-recover** and **feel-slope-run:** merged, then reverted for new reds. They need a rebase onto the Loco movement model.
- **vfx-telegraph-timing:** reverted, because its `--telegraph-sync-check` fails 12 after the Faultline and Meteor Drop rework.
- **garden-first** and **feel-dash-off-ledge:** see the READY line for 315233359.
- **feel-impact-tiers:** READY on top of this branch, but not in this release's list.

## Gate
The full suite ran on w2, headless, one Godot at a time. It covered all 231 registered and inline check flags except shots/gallery/reel/bench/bake, plus `--check`.

It ran on ec7bccf3b + gil-hunter-art, which is this branch before the 070137 job's Tier 2 merges. 209 passed on the first run. Every red was rerun on origin/main, or on gatefix-w2 for checks main does not have.

| Check | Result | Baseline | Verdict |
|---|---|---|---|
| `--check`, health --strict, matchmaker unittests | pass (also on this head) | | green |
| new-player-flow, dash-flow | pass on this head | main pass | fixed |
| clip, crouch (Gil has no clips yet), bot-sanity | fixed by both jobs | main pass | green |
| dredge-combo | `dr_blast` .glb clip 2.07 s vs the kit's 2.10 s on this head | main pass | grimble-v95's clip needs a re-bake (Blender, not on w2) |
| cliff-mantle | pass in 308 s | main pass | the suite's 300 s timeout was too short |
| build-hold, online-displace, remote-anim | pass on rerun | | flaky under load (other workers' Godot runs) |
| grammar-runtime 5, merge-form 1, pack-ui 2, load-check, hitch | red | main red too | pre-existing |
| rate-card | all ok, then crashes at exit (rc 134) | main same | pre-existing |
| bot-kit-use (Tenzo's ult), load-trim 3, perf-budget, remote-smooth 2, stretch, ttk 22 | red | not on main; gatefix-w2 red too | pre-existing in gatefix-w2 |
| feel-golden | 84 drift lines, rc 0 | | gatefix-w2's drifts, left for an `--update` with its reasons |
| gameplay-media, parity-strip | needs a display or args | | tools, not checks |
| Release export dry-run | export-pack Linux and Linux Server: rc 0, no errors (w2 has no templates). The 070137 job's Linux and Windows export: rc 0. | | green |

The 070137 job's READY line lists the other open reds it measured on this head: title 10, wallmove 3, capture 2, warden-glb 2, boki-wisp 1, and move-feel ledge and felt-dash rows.

An alternative version of this job's work is on ext/release-integ-0244-a4alt (997038187). It has a different bot take-off fix (turn for the landing before jumping) and dredge check timing helpers. It is kept for reference only; this head's dredge-hook2 and glide fixes cover the same reds.

## Release fix (ext/release-integ-0244-fix)

The coordinator's gate against main d255acbee found these reds on 2e277c342. Each one was traced to the commit that brought it in.

| Check | Before | After | Commit and cause | What was done |
|---|---|---|---|---|
| dredge-combo | 1 | 0 | grimble-v95's `v95_swap.py` re-export dropped the last frame of `dr_blast` (2.07 s vs the kit's 2.10 s Brass Broadside). A regression. | 466f2d6ec: clip padded to 2.1 s; the script fixes the frame range before export |
| title | 12 + rc 124 | 8, rc 0 (main 10) | 666ba8d8f (ext/tg-text) renamed the Arena to Training Grounds; the check still wanted "Arena". The stalled run was the same. | 66a8912fe: the check wants "Training Grounds". The 8 left are the xvfb baseline main has too |
| warden-glb | 2 | 0 (main 1) | Pip's companions draw from the mood atlas (`WardenMood.ATLAS_SHADER`, 66402808c, on main); reading its absent `use_tex` was a script error on main, and 7bcbcf5d7 made it a reported fail. A gap exposed, not a regression. | b6de0681a: skipped like the glass `FACE_SHADER` (neither is a toon surface) |
| move-feel ledge (5 rows) | 5 | 0 | fbf2e50d0 (lace-phasewalk-verify): a Spirit-Walking hunter climbs a ledge face grounded, with no mantle. The felt-dash rows dash as Lace first, and nothing counted `Hunter.spirit_t` down after a reclass. A real bug: a Training Grounds swap mid Phase Walk left the next hunter ghosting terrain for good. | Lace's kit ends the walk in `teardown()` |
| wallmove | 3 | 1 | The per-Hunter rows are new with wallkick-all (bee700ed6, merged at bd9462672; main runs only the old wallmove check). The harness let one case's Spirit Walk run into the next, and `_at_wall()` counted a ghost inside the wall, or a thief standing on its top, as at the wall. | b6de0681a: each case starts with no Spirit Walk; through or over the wall is not at it |
| move-feel felt dash (4 rows) | 4 | 4 | The rows are new at 61fafbe3f (feel-dash-scale-source). That branch came off main without dash-curve, glide-fixes or sparkle-dash. | Known gaps, below |

Known gaps (none of them a regression: main has no such rows, and changing the rows or the kits would need an owner call):

- **wallmove, rimewright `bounce:sig@0.45/0.80`.** Her E is the Rink Wall (74447a97b, on main). It erupts and slides along her aim, and the harness aims at the test wall. She meets her own ice wall side-on (normal (0,-1), into-speed below the bounce minimum), so she never reaches the test wall at an angle. Possible fix: aim the bounce cases along the wall, or add the case to `COMMITS` with this reason. Neither was done here, since both loosen the case.
- **felt dash, archer ground 0.400 s vs 0.27 s.** The source footage says 0.27 s. tuning.json `dash_speed {archer: 0.7}` is the owner's "slower, lower dash" (item 9, 6503f4fa8): 0.27 / 0.7 = 0.386 s, plus one step. The owner call and the footage row disagree.
- **felt dash, thief air 5.19 m / 0.217 s vs 8.4 m / 0.95 s.** Item 183 (glide-fixes, bdb7703bd) made her air cartwheel the ground one, ending where she lands. The kit retires the sheet's 8.4 m air cartwheel because it "flew far past the cast". The row predates that call.
- **felt dash, mage ground 5.29 m / 0.167 s vs 7.5 m / 0.216 s.** The row's 7.5 m is the item 70 lane. The owner's 11-10 playtest (754d177a0, sparkle-dash) cut the lane to 5.6–9.75 m. Even with the row moved to 5.6 m, the streak measures 5.5% short (the run lands on its ring). That needs the owner to pick the number.
- **felt dash, dredge air 3.99 m vs 3.672 m.** `_air_barge` (unchanged from main) gives a 0.184 s roll at a flat speed. Hunter `_physics` runs the last partial step at full speed in the air (only a ground dash hands over through `HunterMove.dash_exit`), so 12 steps × 19.96 m/s / 60 = 3.99 m. Every air dash shares this, so a fix belongs in the movement code, not in a release fix.

Re-run on this head (xvfb, `LP_NUM_THREADS=2`): wallmove 1, move-feel 4, warden-glb 0, title 8 (rc 0), dredge-combo 0, capture 0, boki-wisp 0, archer-combo 0 (Lace's kit changed). `tools/health.py --strict` OK.
