# 0038: Boki wisp prototype (behind a setting)

- **Status:** accepted (prototype)
- **Date:** 2026-11-09
- **Area:** match flow, networking

## Problem
DECISIONS 2026-11-09: in matches your Boki rides as a small wisp at shoulder height, no walking AI, carry
passive always on. Rollout is a prototype behind a setting, frame time measured on a real GPU both ways.
Summon, steal and the ult wait on briefs/boki-art/WISP_DESIGN_OPEN.md.

## Options
1. A new wisp entity next to Kin. Duplicates the kin's record, stats, carry passives and net path.
2. A `wisp` flag on Kin, handled by a focused `KinWisp` module: the kin stays in state "shoulder" with the
   Return order (so `carried()` and the carry passives need no change), the sim returns before the state
   machine, KinTactics and KinCompanion, and render draws the `BokiWispLook` model on an orbit.

## Decision
Option 2. Setting `boki_wisps` (default off; Settings > Gameplay > Boki), read per game for its own Boki and
bots; match opts can force it (`--perf-bench --boki-wisps`). Never in the tutorial. A wisp takes no orders,
throws or hits and casts neither its ability nor the merge (`ready_to_fight` is false). Left behind (its
hunter goes out in a risky match) it turns back into the walking Boki and the loss rules run unchanged.
Alternative noted: keep the kin's ability/merge castable from the wisp; left for the summon design.

## Consequences
- `scripts/match/kin_wisp.gd` (new), a few lines in kin.gd, kin_follow.gd, kin_net.gd, settings, overlay.
- Net.VERSION 0.27.0: the kin snapshot gains index 24, 1 when it rides as a wisp; other games swap the model.
- `--wisp-check` covers it; `--perf-bench --bench-hunters=30 [--boki-wisps]` measures it.

## Cosmetic line (DECISIONS 2026-11-09)
A second sellable line for Boki wisps, beside the Hunter Wisp looks (`wisp_looks.json`): a trail, a sparkle
colour and an orbit style, as data in `content/rules/boki_wisp_cosmetics.json` (`BokiWispCosmetics`). They
touch only the sparkles (`BokiWispLook` trail) and the orbit path (`KinWisp.orbit_spot`), never the critter
body mesh and never the sparkle count, so the outline rule and the particle budget hold. Picked per player on
the Hunters screen (`WispPick`, under the glider), saved in `Save.d["look"]["boki_wisp"]` (save v12, migration
fills the defaults). Only your own Boki wear them; nothing is synced (no Net bump), others see the defaults.
Alternative noted: per-Boki picks in the Boki record; left until the line is sold per species.
`--wisp-cosmetic-check` covers it; `--kin-gallery --kin-wisps --kin-cosmetics` shows them.

## Follow (DECISIONS 2026-11-09, 2026-11-11)
Targets: the riding wisp stays within 1 m of its orbit point, is never inside the level, and shows no visible
step (5 cm, 3 px at the match camera) on another player's game over an 80 ms line; no 60 Hz judder at 144 fps.
It was drawn rigidly round the animated shoulder bone with the orbit and hop on the 60 Hz match clock: through
walls whenever its Hunter ran along one, flung up to 2.6 m by a flip or a dive pose, and still on 58% of frames
at 144 fps. Now `WispFollow` (scripts/match/wisp_follow.gd): a critically damped spring (exact step, OMEGA
20/s, damper on the speed relative to the orbit point so a steady speed leaves no lag) on the fixed step, a
0.75 m leash and a 3 m teleport snap; the orbit goes round the Hunter where their render has them as the next
step comes (`Hunter.render_pos`) at their shoulder measured standing still; the orbit point is pushed out of
the level's tile columns and the wisp slides out of them at most 0.1 m at a time (collision push-out); it is
drawn between its last two steps, its orbit angle and hop on the drawn time. Presentation only: no Net, save
or rules change. Alternatives noted: a rigid orbit with only a push-out (pose swings and remote snaps pass
straight through); a world spring without the relative damper (it trails 2v/OMEGA: 3 m in a glide dive).
`--wisp-follow-check` (every Hunter x dash, chained dash, glide dive at 32.5 m/s, Sparkle's Wirerun x 60/144 fps
x local/remote over a simulated 80 ms line), worst over all 13 Hunters, before -> after:

| move | lag m | clip frames | wobble cm local 60/144 | remote 60/144 | held frames 144 |
|---|---|---|---|---|---|
| dash | 2.27 -> 0.81 | 3358 -> 0 | 103/105 -> 7.9/2.3 | 35/18 -> 1.9/1.7 | 5460 -> 0 |
| chained dash | 2.57 -> 0.90 | 3705 -> 0 | 96/94 -> 7.7/2.4 | 72/14 -> 2.8/1.7 | 5460 -> 0 |
| glide dive | 2.35 -> 0.83 | 621 -> 0 | 93/126 -> 6.2/1.6 | 30/36 -> 2.5/1.2 | 5460 -> 0 |
| Wirerun | 0.64 -> 0.75 | 277 -> 0 | 40/40 -> 2.7/1.8 | 33/19 -> 1.9/1.8 | 420 -> 0 |

The 60 fps local wobble left is the spring catching up after a dash starts or a landing (no frame taken back
at 144 fps). The check leaves out frames the level holds the wisp (an Archer dash that phases their body into
a wall, a wisp resting on a wall top its Hunter fell past) with 0.2 s after; it counts them. GPU strips:
`--wisp-follow-shots --shots-dir=<dir> --tag=<name>` on the first lane under a cliff the map has.
