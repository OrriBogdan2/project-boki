# 0042: What one summon adds to a fight (the summon band)

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** combat (Boki damage while summoned)

## Problem
DECISIONS 2026-11-09: in matches the Boki rides as a wisp and bursts out on Summon for its own window and
cooldown (0039). Nothing capped what a window adds, and the species ranged from a few percent to well over a
Hunter's LMB over the same seconds.

## Options
1. Scale the summoned Boki's power (also scales its heals and shields: supports would gain more than damage).
2. A per-species damage factor applied only to its hits (burns included) while the window runs.

## Decision
Option 2. `content/rules/boki_summon.json`: `band` [0.25, 0.40] of a Hunter's LMB over the same window (the mean of
Vex holding fire and Kael tapping body slashes on a pinned armourless dummy), each species aimed by its window
along `aim` [0.28, 0.37] inside it: the shortest window at the top, the longest at the bottom (short and strong vs
long and supporting); `dmg_k` per species is what lands it there, `band_tol` how far a species may sit from its
aim. A fight swings on the AI's rolls (Burrlet deals 80 or 210 in the same window), so the check averages six.
Windows and cooldowns are untouched. `KinSummon.out_k` applies it in `Ent.hurt` on the Boki's own game only (a
hit over the net was weighted where it was dealt). `--summon-band-check` measures every species and prints
the table and the fit.

## Consequences
- No sync change: the factor is applied where the hit is dealt.
- Retune `dmg_k` from the check's k_fit column whenever a kit, a stat or the Hunters' LMB change.
