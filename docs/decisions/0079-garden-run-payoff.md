# 0079: Raising pays off on runs (carry passive and summon)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat (owner passives), Boki raising

## Problem
DECISIONS 2026-11-09: the garden and extraction feed each other; a raised Boki should be a better partner on a run. With Boki as wisps the carry passive (and the one summon) is what a run sees, so that is where raising has to show. No new stats, small in PvP, readable on the Boki card.

## Options
1. Per-stat mapping (Power scales damage passives, Guard armor ones...). Cons: four rules to learn, uneven by species.
2. One score from the trained stats (Care.STATS, as counted on expeditions) and the food lean (Evo.lean), one capped multiplier for the carry passive and one for the summon window.

## Decision
Option 2 (`RunPayoff`, numbers in content/rules/care.json `run_payoff`):
- score 0..1 = 0.75 x expedition stat points / (4 x 25) + 0.25 x lean strength. Points past StatBudget `expedition_stat_points` (25) add nothing.
- Carry passive amounts x (1 + score x **carry_max 0.15**). Whole-number passives (jumps, dashes, dodge charges) never scale.
- Summon window x (1 + score x **summon_max 0.10**): `RunPayoff.summon_mult`, read by KinSummon (ext/wisp-summon, not on main yet: one line where it sets the window).
- PvP caps: the passive still stops at its per-stat carry cap (KinParts.OWNER_STATS), so a raised Boki never passes what a wild one can reach; at most +15% passive, +10% summon time.
- Card: the Boki card adds "Raised for runs: carry passive +N%" once N >= 1.

## Consequences
Kin.carry_k (set with Care.match_mods for an owned Boki), Hunter._refresh_kin_stats reads it (no line growth), home.gd +1 card line. No save change (reads rec.stats and rec.lean). No Net change: each peer computes its own hunter's passives as before. Check: --raising-check (run payoff rows).
