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
throws or hits; its ability and the merge go off through you (see R and E below). Left behind (its
hunter goes out in a risky match) it turns back into the walking Boki and the loss rules run unchanged.

## Consequences
- `scripts/match/kin_wisp.gd` (new), a few lines in kin.gd, kin_follow.gd, kin_net.gd, settings, overlay.
- Net.VERSION 0.24.14: the kin snapshot gains index 24, 1 when it rides as a wisp; other games swap the model.
- `--summon-check` covers it; `--perf-bench --bench-hunters=30 [--boki-wisps]` measures it.

- Proc cue (`KinWispProc`): the carry passive acting on its hunter (heal, shield soak, damage on a shot, run boost) gives
  one quiet chirp from the wisp, and your Boki's first cue names the passive once (`Match._tips`, tip key `proc`, in the
  existing tips dict so no save migration). Only the sound and the tip; the visual flash of the old ext/vfx-wisp-proc
  branch is not ported. `--wisp-proc-check` covers it.
- R and E from the wisp (soul link T4, lifts the "wisp casts nothing" block): R fuses the wisp as the Boki itself
  (`KinSummon.fuse`; a mount grows giant) and it folds back into the wisp when the merge ends, the summon cooldown
  untouched. R while summoned leaps it in: the window ends and its one cooldown starts at the press (held during the
  leap). E (C with an archetype) from a wisp is the carried rule at the carried power; a dash, leap or blink ability
  waits for the summon (`KinCommand.c_deny_text` says so), and the order wheel stays shut. `--wisp-check` covers it.
