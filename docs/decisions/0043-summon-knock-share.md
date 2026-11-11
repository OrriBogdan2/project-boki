# 0043: How much of a knock one summon carries (the knock band)

- **Status:** proposed
- **Date:** 2026-11-10 (ported to the 0.24.6 wisp line 2026-11-11, ext/summon-share-port)
- **Area:** combat (Boki damage while summoned)

## Problem
A 1v1 knock (7-8 s for Vex or Kael on a Medium Hunter) is shorter than most summon windows (7-20 s). Nothing said
how much of the knock itself the Boki does. On the soul-link line (with decision 0042's per-species `dmg_k`) it
measured 17.6-27.3% of the knock's damage, knocks 21-43% faster.

## Options
1. A knock band on the Boki's share of the knock's damage, tuned in content only.
2. A band on time saved: it also counts what the Boki does without damage (armour strip, marks, slows), so it
   swings far more with the kit (wisplet 22% of the damage but 43% faster).

## Decision
Option 1: `knock_band` [0.15, 0.25] in `content/rules/boki_summon.json`. The Hunter always does at least three
quarters of its own knock, and every summon still visibly speeds it up. Windows and cooldowns are untouched. Time
saved is reported, not banded (alternative left open: band it too).

The 0.24.6 wisp line does not carry decision 0042 (the summon band and its `dmg_k` damage scale), so the port
measures each species' own damage while summoned; see the port notes below for what was tuned.

## Consequences
- `--summon-share-check` (tools/summon_share_check.gd): per species, three seeded fights per Hunter with and without
  the summon; asserts the band and that the knock is faster. Its rows are the summon column of docs/TTK_MATRIX.md
  (`python3 tools/ttk_matrix.py log slog`).
- No Net or save change.

## Port notes (ext/summon-share-port, 2026-11-11)
- Base: origin/ext/w0246-misc f23d91db7 (main + 0.24.5 + the 0.24.6 misc wave, with the wisp summon and its lane).
- Untuned on that base every one of the 91 species sat over the band (24.4-51.9%: no damage scale while summoned).
  The one code piece the tuning needs is 0042's reader, taken as written from the soul-link line:
  `KinSummon.damage_k` / `out_k` and the `summon_k` line at the top of `Ent.hurt` (host side, burns too).
- `dmg_k` per species fitted to a 20% share (k = 0.25 (1 - s) / s from the untuned share s): 0.23-0.77.
  Measured after: 16.1-23.5%, every knock faster. `--summon-band-check` (0042's band of a Hunter's LMB) is not on
  this line; when soul-link lands, retune its `aim` and these `dmg_k` together.
