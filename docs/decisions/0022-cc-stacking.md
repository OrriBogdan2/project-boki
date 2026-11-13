# 0022: One rule for overlapping Slows, Roots and Stuns

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** combat

## Problem
Every source of a slow wrote `slow_k`/`slow_t` itself (Ent.hurt, KitStatus Disoriented, Bjorn's scar, the
Oomph stagger, Claire's rink and lance zone, Boki merge riders, biome mutations, zone fields). All kept the
stronger strength for the longer time, so a 0.5 s 60% burst plus a 2 s 20% zone slowed 60% for 2 s, a plain
slow after a weak explicit one dropped to the weaker strength, and zone fields refreshed only the time.
Stuns and roots were already `maxf` everywhere, but spread over a dozen call sites.

## Options
1. Keep the scattered writes, fix each formula. Leaves the next kit to get it wrong again.
2. One rule on `Ent`: `add_slow(secs, k)`, `add_stun`, `add_root`; every path calls it.

## Decision
Option 2. The source data (briefs/supervive-data) and the cited wiki pages say nothing about overlaps, so
the rule is strongest-wins plus refresh: the strongest running slow sets the speed, each slow keeps its own
clock (a weaker, longer one takes over when the strong one ends), and overlaps never add strength or time.
Stuns and roots: the longest wins, they run side by side. Grounded stays its own status beside a slow.
A plain slow (no `slow_k`) counts as the body's `usual_slow()` (Hunter 35%, Boki 40%, others 45%).

## Consequences
- `Ent.slows` (a short list, pruned on insert) behind `slow_k`/`slow_t`; zeroing `slow_t` still clears.
- Net.VERSION bump: no. Hits already go to the body's owner with `slow`/`slow_k`/`stun`/`root`; the owner
  runs the same rule (`--cc-stack-check` replays them through `_net_hit_in`).
- Ours, not touched: diminishing returns (KinRules) and self-slows while holding a cast (CastHold).
