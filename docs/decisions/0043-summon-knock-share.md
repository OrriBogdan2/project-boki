# 0043: How much of a knock one summon carries (the knock band)

- **Status:** proposed
- **Date:** 2026-11-10
- **Area:** combat (Boki damage while summoned)

## Problem
0042 caps a summon against a Hunter's LMB over the whole window, but a 1v1 knock (7-8 s for Vex or Kael on a Medium
Hunter) is shorter than most windows (7-20 s). Nothing said how much of the knock itself the Boki does. Measured on
0042's tuning: 17.6-27.3% of the knock's damage, knocks 21-43% faster; the shortest windows at the top
(squalltross 27%, zephyrak 25%).

## Options
1. A knock band on the Boki's share of the knock's damage, tuned by `dmg_k` (content only).
2. A band on time saved: it also counts what the Boki does without damage (armour strip, marks, slows), so it
   swings far more with the kit (wisplet 22% of the damage but 43% faster).

## Decision
Option 1: `knock_band` [0.15, 0.25] in `content/rules/boki_summon.json`. The Hunter always does at least three
quarters of its own knock, and every summon still visibly speeds it up. To make 0042 agree, its `aim` top goes from
0.37 to 0.34 of a Hunter's LMB (about 25% of a knock); squalltross `dmg_k` 0.54 -> 0.48, zephyrak 0.47 -> 0.44.
Windows and cooldowns are untouched. Time saved is reported, not banded (alternative left open: band it too).

## Consequences
- `--summon-share-check` (tools/summon_share_check.gd): per species, three seeded fights per Hunter with and without
  the summon; asserts the band and that the knock is faster. Its rows are the summon column of docs/TTK_MATRIX.md.
- No Net or save change. Retune with `--summon-band-check` and this check together.
