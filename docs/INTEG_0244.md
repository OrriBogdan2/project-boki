# 0.24.4 integration (ext/release-integ-0244)

Built on origin/main d255acbee by two integrator jobs: 20261110-041746-a4 (merges up to ec7bccf3b; killed, out of memory on w3) and 20261110-065226-a4 (the rest, the gate, this file). `Net.VERSION` is 0.24.4.

## What is in
- **Base:** ext/gatefix-w2 at ad678cd20, with the Tier 2 branches it carries (see `git log --first-parent --merges origin/main..`).
- **Tier 1, all merged:** tutorial-visibility, pick-order, calm-hud, glide-fixes, tut-starter-three, tut-fight-per-starter, sparkle-dash, cinder-lmb, motley-tune, meeko-root, brall-slam, vex-daze, vex-rmb-hit, vex-rmb-terrain, kael-rmb-unlock, dredge-hook, dredge-rmb, dredge-auto, gil-hunter-art (up to 75c194aa9), tenzo-edge, grimble-v95.
- **Tier 0 reds, all fixed:** bot-sanity seed 5 ring-up (337185db0, then acb8a7648: seeds 3/5/9 now flag 0 windows, as on main), the `--glide-hold-check` fold reopen (green), and the `health --strict` style ratchet on main.gd/models.gd/check_registry.gd (HEALTH OK).
- **Fixes from this job's gate:**
  - The matchmaker's `HUNTERS` list now includes Gil and follows Arch.ORDER again. Without this, release.yml's unittest step failed.
  - `--clip-check` and `--crouch-check` skip Gil, whose .glb has no clips yet. `--rig-standard-check` already did this.
  - `--new-player-flow-check` now takes Vex on tut-starter-three's starter pick.
  - `--dredge-combo-check` and `--dash-flow-check` now wait for dredge-hook's slower Abyssal Hand.
  - Bots at a glide take-off spot now turn toward the landing before they jump.

## What was left out
- **ext/spike-slam** (f0b10ce78): it conflicts in 7 files (displace.gd, effects.gd, dredge_kit.gd, breah_slam.gd, dolm.json, dredge.json, the Stone Seer wiki page). The brief said to merge it last and only if clean, so it needs a rebase onto this branch.
- **ext/tut-first-race** (06ce66f82): it is stacked on ext/garden-integrated and ext/boki-react-clips, which adds 74 garden commits that are not on main. It should land with the garden integration.
- **ext/vfx-telegraph-timing:** reverted in b4dec3a81. Its `--telegraph-sync-check` failed 12 here, because Albert's Faultline and Kael's Meteor Drop were reworked after it was cut.
- **ext/feel-impact-tiers** (371e736ab): READY on top of this branch but not in this release's list. It is for the next pass.
- **`--feel-golden-check`:** 84 drift lines, which gatefix-w2 introduced. They do not fail the check (rc 0) and are left for an `--update` that comes with gatefix-w2's reasons.

## Gate (w2, headless, one Godot at a time, 2026-11-10)
The suite ran on all 231 registered and inline check flags except shots/gallery/reel/bench/bake, plus `--check`. 209 passed on the first run. Every red was rerun on origin/main, or on gatefix-w2 for checks main does not have.

| Check | Integ | Baseline | Verdict |
|---|---|---|---|
| `--check` (smoke), matchmaker unittests | pass | | green |
| export-pack "Linux", "Linux Server" (no templates on w2) | rc 0, no errors, 422 MB | | green |
| health.py --strict | HEALTH OK | | green |
| bot-sanity, glide-hold | 0 / 0 | main 0 | green after acb8a7648 |
| clip, crouch, new-player-flow, dredge-combo, dash-flow | 0 | main 0 | NEW-RED, fixed |
| cliff-mantle | pass, 308 s | main pass | the suite's 300 s timeout was too short |
| build-hold, online-displace, remote-anim | pass on rerun | | flaky under load (other workers' Godot runs) |
| grammar-runtime (5), merge-form (1), pack-ui (2), load-check (slow frames), hitch (over budget) | red | main red too | pre-existing |
| rate-card | all ok, then crashes at exit (heap corruption, rc 134) | main same | pre-existing |
| bot-kit-use (Tenzo never casts his ult), load-trim (3), perf-budget (65 ms), remote-smooth (2), stretch (Sable's walk), ttk (22) | red | not on main; gatefix-w2 red too | pre-existing in gatefix-w2 |
| gameplay-media, parity-strip | needs a display or args | | tools, not checks |

Not done here: real `--export-release` binaries, because w2 has no export templates. The CI release workflow builds them.
