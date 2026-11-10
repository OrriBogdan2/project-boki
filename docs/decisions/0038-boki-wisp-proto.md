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
throws or hits. Left behind (its hunter goes out in a risky match) it turns back into the walking Boki and the
loss rules run unchanged.
**Changed (T4, 2026-11-09):** the first cut also blocked the Boki's ability and the merge (`ready_to_fight`
false while a wisp). WISP_DESIGN_OPEN.md Q2/Q7, which the owner's soul-link decisions follow, keep both:
- E (C with an archetype) from the wisp is the carried rule: the ability goes off through you at 85 % power.
  One that moves its caster (dash, leap, blink) is refused ("Summon <name> to use it"): a Boki never moves you
  (DECISIONS 2026-11-06). Alternative: the wisp hops off and does it as the walking Boki; that is a summon.
- R from the wisp merges: it fuses as the Boki itself (`KinSummon.fuse`; a mount grows giant) and folds back
  into the wisp when the merge ends; the summon cooldown is untouched. R while summoned leaps it in: the window
  ends and its one cooldown starts at the press (held during the leap), never restarted by the merge.
- The bond meter now fills with a wisp along (`has_kin_ready`), so R can be earned in wisp matches.

## Consequences
- `scripts/match/kin_wisp.gd` (new), a few lines in kin.gd, kin_follow.gd, kin_net.gd, settings, overlay.
- Net.VERSION 0.31.0 (shipped with 0039-0041 on ext/soul-link-integ): kin snapshot index 24 (KinNet.WISP_AT), 1 when
  it rides as a wisp; other games swap the model.
- `--wisp-check` covers it (and R / E from the wisp); `--perf-bench --bench-hunters=30 [--boki-wisps]` measures it.
