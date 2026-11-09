# Handoff: branch `polish` (demo-video polish)

Setup: worktree `/home/claude/kinfall-polish`, branch `polish` = integ29 + loopqa (b7c613d, f6e5970)
merged, then the commits below. Godot runs go through `/home/claude/gq`; my runner
`/home/claude/pol_tools/g.sh <log> [xvfb] <args>` uses a fresh temp XDG_DATA_HOME per run (logs in
`/home/claude/pol_tools/logs/`). Screenshots: `/home/claude/shots/polish/`.

## Done (each commit passed `--check` with 0 failures)

| Item | Commit | What |
|---|---|---|
| 1 + 2 | 9cf9ffb | See-through trees and pillars: `shaders/see.gdshaderinc` (sphere-vs-line-of-sight test per instance, stipple discard), used by `flora.gdshader` and a new `outline_see.gdshader`. `scripts/match/see_through.gd` (SeeThrough) sets globals `see_cam`/`see_a`/`see_b` (added to project.godot) from Match._process and Home._process; off on exit. `--no-see` disables it, `--see-demo[=style]` puts the hunter behind a tree. Out-of-sight dimming in `vis.gdshaderinc` lightened (42%/60% grey to 70%/40%); motes 0.75 to 0.6. Recording mode doesn't touch it. |
| 3 | 7900572 | Farm Boki drawn 1.7x (`Home.FARM_BOKI_SCALE`). Presentation only. |
| 4 | d525471 | Lair escape updraft: the 12 m "Air" column is hidden from your view while you're outside the lair on its far side from the camera (`Lairs._updraft_view`). New `--lair-demo=updraft` rides it (prints LAIRDEMO timings). |
| 5 | 9eb9bfc | Training: glove rack laid out 2.6 m apart in staggered rows within 6.2 m (skips void/blocked/other-terrace spots); practice sniper moved; HUD pickup tags declutter (step up when overlapping); DUEL ROOM label higher with render_priority 100. |
| 6 | 1a943fb | Loading: "Solo · 20 hunters" (squads still counted for duos/trios); `finish()` now covers with ScreenFade ink, frees itself, then reveals, so it never fades over the planning map. Only `finish()` and the mode line touched (loadsmooth owns the rest). |
| 7 | 52b5cd7 | Lair Label3D name boards fade (transparency) while a toast overlaps them (`Hud._clear_under_toasts`); earned weapon drops (chests, crates, Warden, Glimmerkin) 75% from the earner's archetype family (`Match.earned_weapon_id`); offline ground/cache weapons 60% swapped to the player's family via hash (`Match.ground_weapon_id`, online unchanged); "Make it home" marks cleared when the panel closes any other way (`HomeBuild.tick`). |

## Item 8 (done)

| Part | Commit | What |
|---|---|---|
| Stairs | d973f38 | Drawn as one flight across their full width (`terrain_mesh.gd` `_stairs`), not one-block stairs side by side. Flights come from `PolishTools.stair_flights(world)` (widest first). `--at-stairs[=N or E/W/S/N]` starts you at a flight and prints every flight's width. |
| Chests | 648c43e | Chunkier lacquered chest with claw feet, a lid crest and a glow, three tier colours (`PropSculpt.chest`), clearly different from the crates, pots and barrels. `--chest-demo` lays a row of crate, chest, pot, rare chest and keg (`PolishTools.chest_row`). |

## After merging sync56 (main 0.8.0)

- Merged `origin/main` (sync56) into polish. Conflicts in `match.gd` only: kept main's `--shot-bright` and `--at=x,z`, kept the lighter `vis_dark` default (0.7).
- `match.gd` and `world.gd` were over their `tools/health.py` budgets, so polish logic moved out: `scripts/match/polish_tools.gd` (PolishTools: `stair_flights`, `stairs_start`, `chest_row`, `clear_mobs`) and `scripts/match/drop_family.gd` (DropFamily: `earned`, `ground`, replacing `Match.earned_weapon_id` / `ground_weapon_id`). `python3 tools/health.py --strict` passes.
- New `--polish-check` (`tools/polish_check.gd`): drop families, every stair tile in a flight, chest footprint and tier colours.
- Net.VERSION untouched (polish changes no sync shape; drop families use the earner's own archetype, online ground rolls unchanged).

## After merging sync57 (e85193d, Net 0.9.0)

Merged cleanly (one trivial conflict in the `main.gd` check hooks). Standard suite 0 failures except two things that are the same on plain main: `--teammate-check` "it leads you to (or gets to) the chest and the outpost" (the tutorial now leads on shoot/kin1/throw/goexit/uplink/defend, no "chest"), and `--simtest --seed=5` ends "team wiped" (main: sim 30 s; polish: 63 s) instead of extracting. Both belong to the Boki-system merge.

## After merging sync58 (e5f25ec, Net 0.10.0)

- One conflict, `match.gd` `_exit_tree`: kept both `SeeThrough.off()` and main's `Capture.teardown(self)`. No shoulder-start or hold-F text in polish's files (`see_through.gd` only skips a Boki whose state is "shoulder", which stays harmless). Net.VERSION untouched, sync shape untouched (main's version kept).
- `after_03_farm.png` not retaken: the farm Boki is Home presentation (`FARM_BOKI_SCALE`) and doesn't depend on the match start state.
- Checks: health --strict, gen_wiki --check, --check, --polish-check, --teammate-check, --arena-check, --bot-sanity-check, --boki-system-check all 0 failures; `--simtest --seed=5` EXTRACTED (Rift Hatch, sim 227 s; the old "team wiped" is gone).
- Merged sync59 (fcc3745, mergeforms, Net 0.11.0) too: clean, no reserved file touched, Net.VERSION stays 0.11.0. Re-ran the suite on that tree: health --strict, gen_wiki --check, --check, --polish-check, --teammate-check, --arena-check, --bot-sanity-check, --boki-system-check all 0 failures, no SCRIPT ERROR; `--simtest --seed=5` EXTRACTED (Rift Hatch, sim 208 s).
- **RESOLVED: `--drop-check` "squad bots ignore pings" on polish.** Cause: `PropSculpt.chest` built its sparks with a `CPUParticles3D`, and making one draws a seed from Godot's global random stream. `Match._start` seeds that stream (`seed(seed_val)`), so every chest in the match advanced it and every later global `randf` (the squad bots' break-off heights, what they decide, where they land) came out different from main's. In the check Graizor then landed 30 m from where he does on main, beside a wild Boki: his "boki" goal outranks the ping goal in `bot.gd`, so he said "omw" but never walked (stayed 10.7 m off). Not stairs, not `DropFamily` (stubbing it changed nothing), not see-through. Found by restoring main's files in bulk, then `props_sculpt.gd`, then the chest's particle block. Fix: sparks are now a `MultiMeshInstance3D` with `shaders/chest_sparks.gdshader` (positions, phase and fade from `INSTANCE_ID` and `TIME`), which draws nothing from the stream; `--drop-check` output is identical to main's. (`GPUParticles3D` draws a seed too, so don't swap to that.) `--polish-check` has a new line that building chests leaves the seeded stream alone. Plain main fcc3745 passes `--drop-check` too; a first run in `/home/claude/boki-mainchk` sat idle only because that checkout's `.godot` class cache was stale (`FieldBook`, `HandLayout`, `KinFollow`... "not declared" SCRIPT ERRORs, never reaching the check); after `godot --headless --path . --import` it passes in about a minute.

## Left

Nothing. Before shots are missing for items 6 (fade) and 7 (after only).

## Screenshots

Older set in `/home/claude/shots/polish/` (items 1-7: 01_tree .. 07_banner). Item 8 and the post-merge set in `/home/claude/shots/A/` (before_/after_ stairs and chest, chest_gallery, hollow_*).

## Gotchas

- New `class_name` scripts need `godot --headless --path . --import` once (updates the global class
  cache and writes .uid files) or `--check` fails with "SeeThrough not declared".
- The see-through stipple also thins that prop's shadow (same shader in the shadow pass); accepted.
- `Lairs._updraft_view` assumes the camera isn't yawed (uses the camera's forward on the ground,
  so it is fine if it is).
- The queue is shared with other agents; runs can wait several minutes.
