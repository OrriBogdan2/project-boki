# 0098: Abilities drain a Wisp's bleed, they never hit it

- **Status:** proposed (owner to confirm; docs/specs/DOWNED_ABILITIES.md rule 2)
- **Date:** 2026-11-12
- **Area:** combat

## Problem
Some source kits touch downed Hunters (Lace's Hail Wall, Motley's rank 3 shield). Ours ignore Wisps, and nobody had
said whether a Wisp takes ability damage, how much, or only slows. Those parity rows wait on it.

## Options
1. Slow only (x0.65 in the wall): safe, but the wall does nearly nothing to a Wisp.
2. Real damage to the pool through `Hunter.hurt`: every kit can then finish Wisps and the stomp (DECISIONS 2026-11-11)
   stops being the finisher; the earlier tick x2.5 build kills a fresh Wisp in 4 s.
3. An ability drain: listed area abilities speed the bleed and slow the Wisp; nothing hits the pool directly.

## Decision
Option 3. Inside Hail Wall a rival Wisp bleeds x2.0 (+6.7/s, 3.3 a tick) and drifts x0.65; the higher drain and the
lower speed win against a stander or a stomp, never both. The wall's share keeps running during a revive (a race the
4 s revive wins from 27 pool). Ally and carried Wisps are untouched. A Wisp under Motley's shield ignores ability drain
for 3 s. The stomp stays the only finisher besides the bleed.

## Consequences
Build later in life.gd plus the archer and ostra kits; no `Hunter.hurt` branch. Net.VERSION: no (`down_hp` already in
`"st"`). Extends `--wisp-check`. Reads as a blue burn flicker and 3-point bar steps, never red, no numbers.
