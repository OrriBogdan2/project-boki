# Performance audit, 2026-11-11 (owner priority: general game performance)

Godot 4.6.2, base origin/main 92df78ce4. Load: `--perf-bench` (tools/perf_bench.gd): a 60 s busy expedition at the fixed
6-Hunter load and at the MATCH_PLAYERS cap of 30 (new `--bench-hunters=30`), ash storm, Blight, a lair, a brought fight
(2 rivals, 6 monsters), then the farm, the base demo (6 Boki, a Dash) and the hub. Quality medium.

Headless numbers are CPU script time per frame on worker rpc3 (32 cores, software GL, shared with other sessions' Godot
runs that day, so about ±20 % between runs; sections were compared within the same run). Wall, draw and GPU time only
mean something on a real GPU: the GPU column is the jobq `--needs gpu` run (section 4), never this box.

## 1. Where a match frame goes (ms per frame, 6 Hunters / 30 Hunters)

Step sections are `Match.prof` (printed by the bench); the finer rows came from one-off probes inside Hunter.sim,
Kin.sim, Bot.think and HUD._draw_all (not committed). Visuals are the new "visual sections" bench line.

| # | cost | 6 Hunters | 30 Hunters | what it is |
|---|---|---|---|---|
| 1 | HUD canvas draw (`hud` column) | 3.0 | 4.0 | `_draw_all` every frame: world labels 0.5-0.7 (nameplates, exits, lairs, wisp rings 0.25), prompts + lair dial + crosshair 0.24, kit 0.15, hover tips 0.15, overhead + glider heat 0.13, panels; spread over ten drawers, no single hog |
| 2 | Boki state sim (`k:state`) | 1.1 | 4.6 | `Kin._sim_active` 0.73 of it at 6 (target pick 0.40, steer 0.16, ground move 0.12), `_sim_wild` 0.29; **fixed below** |
| 3 | monsters (`mobs`) | 1.2 | 1.3 | `Mob.sim` for the pack and the map's wild packs, about 0.2 ms per live monster per step |
| 4 | kit ticks (`h:ak`) | 1.0 | 2.7 | `ArchKit.tick` per Hunter: cooldown and flow state for 10-20 abilities every step |
| 5 | Hunter render (visual `hunters`) | 1.1 | 2.2 | `Hunter.render`: rig pose, weapon fx, wisp, model basis per frame |
| 6 | separation (`separate`) | 0.9 | 1.1 | `_separate` grid pass + `_collide_breaks` + breakables tick |
| 7 | Hunter physics (`h:physics`) | 0.8 | 2.4 | `_physics`: ground, slide, mantle, pads |
| 8 | Boki and monster render (visual `kins_mobs`) | 0.8 | 1.2 | quarter-rate far, every frame near |
| 9 | pickups (`pickups`) | 0.2 | 1.7 | `_update_pickups`, BeltKeys, Wpicks, PerkOrbs: scans per Hunter × item |
| 10 | camera + bots | 0.6 + 0.3 | 0.5 + 0.4 | `cam.follow`, lead, zoom; bots after SimLod planned them (bots were 1.0 in the quiet baseline run) |

Whole match step + visuals: 12.2 ms script at 6 Hunters (p99 19.5), 33.3 ms at 30 (p99 157). The 30-Hunter
match is over the 16.7 ms frame on script alone: every per-entity row above scales with it.

Build: 60 s expedition build 3.3 s of stages (generate 902, terrain 801, hunters 446, spawns 425, grass 350, walls 323 ms).
Hitches in play: 10 frames over 300 ms in the first 25 s, each with 20-130 MeshInstance3D entering the tree (Hunter
and monster rigs, lair column): model builds are not warmed, see follow-ups.

Scene (same on any renderer): 840 draws, 493k tris, 2090 objects, 8225 nodes, 116 particle systems (54 emitting:
17 Boki auras/trails, 11 match ambience, 7 Aura), 8 lights (1 shadowed), 437 shadow casters. At 30 Hunters: 12212
nodes, 151 particle systems (81 emitting; 23 Fx, 10 glider trails), 15 lights.

## 2. Hub and garden (headless counts; GARDEN_PERF.md has the measured GPU frames)

| part | draws | tris | objects | nodes | fx | casters | script ms/frame |
|---|---|---|---|---|---|---|---|
| farm (farm_secs 20) | 1258 | 814k | 1544 | 1304 | 50 | 146 | process - render ≈ 26 (software GL; unreliable) |
| base demo (6 Boki, a Dash) | 1084 | 657k | 1333 | 1412 | 56 | 89 | garden steps 1.4: move_kin 0.86, sky 0.14, bubbles 0.12, separate 0.09 |
| hub (1 Boki) | 961 | 539k | 1132 | 1062 | 51 | 96 | - |
| hub, horizon hidden | 601 | 541k | 601 | 1062 | 51 | 96 | - |

The hub's horizon is 360 of its 961 draws with the UI (the UI itself is ~300). Garden CPU is small; the farm's and
hub's cost is draw count (GARDEN_PERF.md: over target everywhere, static fixtures unmerged). The zone parts of the
headless run were cut by the 28-minute cap; their GPU numbers are in section 4.

## 3. The fix: Boki target pick (top row that scales with Hunters)

`KinTactics.pick_target` ran every sim step for every active Boki without a target (most of a match): two
`foes_of` scans (one inside `owner_focus`), every filter on every foe, and `walkable_to` (a line of ground samples)
on every foe in range. Now: one distance test per foe, the other filters and your focus only for the few in range,
the walk test only for the winner (then the next best if it cannot be walked to). Same result in every case:
`--kin-target-check` compares it with the rule written out in full over 60 random layouts (foes in and out of range,
over the void, ignored, downed, stunned; attacker, focus and current target set at random).

| | before | after |
|---|---|---|
| `k:state` 6 Hunters (ms/frame) | 1.07-1.36 (pick 0.40) | 0.91 (pick 0.19) |
| `k:state` 30 Hunters | 4.57 | 2.1 (pick 0.63) |
| match script 6 / 30 (ms, contended box) | 16.2 / 33.3 | 13.8 / 29.9 |

## 4. Real GPU frame (jobq --needs gpu, pc-MRROBOTO RTX 4070 SUPER, 1920x1080 medium)

Not measured yet: every `--needs gpu` job submitted on 2026-11-11 (rp1-0, rp2-3, pc-MRROBOTO) came back
`worker lost` or never left the queue (jobq ids 20261111-090705-18287, 20261111-092738-01989, 20261111-094551-24533).
The command to run when a GPU worker is back, against the base worktree and this branch:
`jobq submit --needs gpu --tree <tree> --out bench -- --perf-bench --bench-secs=60 --bench-farm=20 --bench-base=60
--bench-zone=all --quality=medium --bench-view=1920x1080`. Until then the GPU-side ranking rests on the counts in
sections 1-2 and GARDEN_PERF.md's measured zone frames (hub 3.4-4.1 ms, zones 8-18 ms on an RTX 4090 / M5).

## 5. Follow-ups (filed in the backlog as [perf] items)
- HUD: 3-4 ms a frame of canvas draw; cache the fixed-text TextLines (nameplates, prompts, lair dial) and skip
  `_draw_world_labels` for Hunters off screen before unprojecting.
- Mob.sim: 0.2 ms per live monster per step; put far packs on SimLod's 20 Hz like far bots.
- ArchKit.tick: 0.15 ms per Hunter per step for cooldown bookkeeping; tick only abilities with a running timer.
- Pickups: `_update_pickups` + BeltKeys + Wpicks + PerkOrbs scan every Hunter against every item (1.7 ms at 30);
  use the separation grid or a per-Hunter near list.
- Hunter.render: 1.1-2.2 ms; far Hunters pose every 2nd-4th frame like kins_mobs.
- Build hitches: 300-700 ms frames when rigs enter the tree in the first 25 s; warm the Hunter, monster and lair
  models in WarmUp.
- Draws: 840 in a match, 961-1258 in the garden; GARDEN_PERF.md's static merge is still the way.
