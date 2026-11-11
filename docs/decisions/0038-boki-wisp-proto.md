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
