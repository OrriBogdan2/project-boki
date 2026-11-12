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
   machine, KinTactics and KinCompanion, and render draws the `BokiWispLook` model on its keep-clear arc (BokiWispClear, note 0019).

## Decision
Option 2. Setting `boki_wisps` (default off; Settings > Gameplay > Boki), read per game for its own Boki and
bots; match opts can force it (`--perf-bench --boki-wisps`). Never in the tutorial. A wisp takes no orders,
throws or hits and casts neither its ability nor the merge (`ready_to_fight` is false). Left behind (its
hunter goes out in a risky match) it turns back into the walking Boki and the loss rules run unchanged.
Alternative noted: keep the kin's ability/merge castable from the wisp; left for the summon design.

## Consequences
- `scripts/match/kin_wisp.gd` (new), a few lines in kin.gd, kin_follow.gd, kin_net.gd, settings, overlay.
- Net.VERSION 0.31.0 (shipped with 0039-0041 on ext/soul-link-integ): kin snapshot index 24 (KinNet.WISP_AT), 1 when
  it rides as a wisp; other games swap the model.
- `--wisp-check` covers it; `--perf-bench --bench-hunters=30 [--boki-wisps]` measures it.
- Proc look (`WispProc`, `--wisp-proc-check`): a carried passive acting (heal, shield, damage bonus, run boost) gives its wisp one small flash in
  its own glow and a thin streak to where it acted, one cue per 0.5 s per wisp, two pooled meshes, no bursts.
  With the wisps off, a walking Boki carried by order cues the same way. Your own Boki's first cue (within 6 s)
  gives one Match tip, "<Boki>'s <passive>: <what it does>" from its carry data (`WispProc.tip`, once per save
  in `Save.d.tutorial.proc`, real matches only), and the wisp flashes again so the eye finds it.
