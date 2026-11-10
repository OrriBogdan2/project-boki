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
