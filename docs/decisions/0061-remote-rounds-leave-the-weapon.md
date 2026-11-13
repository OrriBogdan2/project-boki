# 0061: The other player's game draws your rounds from your weapon

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking

## Problem
On the wide match camera a round's look leaves the drawn weapon (`Muzzle`, `s["vis"]`), but only in the shooter's
own game. The "s" event that copies a round to the other games carries no shooter and no slot, so there the round is
still drawn from the fixed body offset, up to 2 m from the weapon on screen.

## Options
1. Guess the shooter on the receiving side (the nearest Hunter of that team to the start). No Net change, but it
   picks the wrong Hunter in a crowd and cannot know the slot (Neve's palms, Meeko's seed, Sable's hands differ).
2. Append the shooter's nid and the muzzle slot to the "s" event. Two short strings per round; exact.

## Decision
Option 2. The receiving game looks up the Hunter by nid and sets the copy's `vis` with `Muzzle.offset` from its own
copy of that Hunter's model and its own camera, which is what that player sees. Only the look moves, as in the
shooter's game: the copy's start, path and life are the shooter's.

## Consequences
`Match.spawn_shot` (sender) and `Match._net_ev` "s" (receiver), a few lines. Net.VERSION 0.24.5 -> 0.24.6 (the "s"
event grew two fields). No save change. `--muzzle-live-check` asserts a copied round gets the same offset.
