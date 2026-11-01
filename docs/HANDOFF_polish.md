# Handoff: branch `polish` (demo-video polish)

Setup: worktree `/home/claude/kinfall-polish`, branch `polish` = integ29 + loopqa (b7c613d, f6e5970)
merged, then the commits below. Nothing pushed. Godot runs go through `/home/claude/gq`; my runner
`/home/claude/pol_tools/g.sh <log> [xvfb] <args>` uses a fresh temp XDG_DATA_HOME per run (logs in
`/home/claude/pol_tools/logs/`). Screenshots: `/home/claude/shots/polish/`.

## Done (each commit passed `--check` with 0 failures)

| Item | Commit | What |
|---|---|---|
| 1 + 2 | 9cf9ffb | See-through trees and pillars: `shaders/see.gdshaderinc` (sphere-vs-line-of-sight test per instance, stipple discard), used by `flora.gdshader` and a new `outline_see.gdshader`. `scripts/match/see_through.gd` (SeeThrough) sets globals `see_cam`/`see_a`/`see_b` (added to project.godot) from Match._process and Home._process; off on exit. `--no-see` disables it, `--see-demo[=style]` puts the hunter behind a tree. Out-of-sight dimming in `vis.gdshaderinc` lightened (42%/60% grey to 70%/40%); motes 0.75 to 0.6. Recording mode doesn't touch it. |
| 3 | 7900572 | Farm Boki drawn 1.7x (`Home.FARM_BOKI_SCALE`, eases to 1.0 on the Training Grounds isle). Presentation only. |
| 4 | d525471 | Lair escape updraft: the 12 m "Air" column is hidden from your view while you're outside the lair on its far side from the camera (`Lairs._updraft_view`). New `--lair-demo=updraft` rides it (prints LAIRDEMO timings). |
| 5 | 9eb9bfc | Training: glove rack laid out 2.6 m apart in staggered rows within 6.2 m (skips void/blocked/other-terrace spots); practice sniper moved; HUD pickup tags declutter (step up when overlapping); DUEL ROOM label higher with render_priority 100. |
| 6 | 1a943fb | Loading: "Solo · 20 hunters" (squads still counted for duos/trios); `finish()` now covers with ScreenFade ink, frees itself, then reveals, so it never fades over the planning map. Only `finish()` and the mode line touched (loadsmooth owns the rest). |
| 7 | 52b5cd7 | Lair Label3D name boards fade (transparency) while a toast overlaps them (`Hud._clear_under_toasts`); earned weapon drops (chests, crates, Warden, Glimmerkin) 75% from the earner's archetype family (`Match.earned_weapon_id`); offline ground/cache weapons 60% swapped to the player's family via hash (`Match.ground_weapon_id`, online unchanged); "Make it home" marks cleared when the panel closes any other way (`HomeBuild.tick`). |

## In progress: item 8 (owner art notes), nothing changed in code yet

- **Stairs one block wide**: the generator already enforces STAIR_MIN_W=3 (`World._place_stairs`).
  A debug report on seeds 5 and 11 (`--match --no-drop`) found flight widths only 3-5 and no stair
  tile turned non-ground afterwards. So the "one block" look is likely visual: check
  `terrain_mesh.gd` `_stairs` / `_stairs_cut` (side walls per tile, `same` neighbour test at ~line
  529) or authored-map stairs, or widen STAIR_MIN_W to 4 and make 3-wide flights rarer. Get a
  screenshot first (`--match --no-drop --at-stairs --shot-time=2 --shot=...`).
- **Chests vs breakables**: not started. Chests: `Models.chest(t)` / `Models.CHEST_COLS`
  (scripts/match/models.gd); breakables: `Models.breakable(kind)`. Goal: chunkier chest
  silhouette plus a distinct colour/glow (e.g. a gold-rimmed lid and soft beacon glow) vs the plain
  crates/pots/barrels.

## Left from the task list

- Item 8 (both parts above).
- Before shots missing for items 6 (fade, only after sequence) and 7 (after only).
- Full final check suite NOT run yet: `--check` passes (0 failures) after every commit, but
  `--arena-check, --archetype-check, --record-check, --home-build-check, --drop-check,
  --extract-check, --boss-check, --duel-check, --bot-sanity-check, --obstacle-check,
  --simtest --seed=5` still need running. Watch especially: drop-check and simtest (item 7 changes
  which weapon ids drop and uses global randf/randi, not the match rng), duel-check and
  arena-check (SeeThrough runs in every Match), home-build-check (Make it home tick).

## Screenshots (/home/claude/shots/polish/)

01_tree_before/after, 02_vision_before/after (+ _b pair: same tree scene), 03_farm_boki_before/after
(+ _crop), 04_updraft_landed_before/after and 04_updraft_sheet_before/after (sequence in upd/),
05_training_before/after, 06_loading_before/after, 06_loading_to_map_after (frames in loadfade/),
07_banner_after_1..4 + sheet.

## Gotchas

- New `class_name` scripts need `godot --headless --path . --import` once (updates the global class
  cache and writes .uid files) or `--check` fails with "SeeThrough not declared".
- The see-through stipple also thins that prop's shadow (same shader in the shadow pass); accepted.
- `Lairs._updraft_view` assumes the camera isn't yawed (uses the camera's forward on the ground,
  so it is fine if it is).
- The queue is shared with other agents; runs can wait several minutes.
