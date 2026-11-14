# 0094: World pings: enemy pings follow, kind colours, two per player

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** networking / UI

## Problem
The ping key already marks an enemy, loot or the ground under the cursor (PingInput, "sping" carries the kind since 0.21.0). But an enemy ping stays where the enemy was, every ping wears the pinger's squad colour, and a second ping wipes the first, so a fight callout erases your "go here".

## Options
1. Receivers guess the followed enemy from the nearest hunter to the ping spot: no Net change, but wrong when two foes stand close and out of sync between peers.
2. "sping" carries the enemy's nid as a 7th field: every peer follows the same hunter. Needs a Net.VERSION bump.

## Decision
Option 2. An enemy ping is red, follows its hunter and lasts PingInput.ENEMY_T (4 s). A loot ping is gold, a ground ping is white ("go here"); both last 45 s as before. Each player keeps PingInput.CAP (2) pings: a third drops their oldest, on every peer, because each peer applies the same rule to the same events. Alt+click pings as well as the rebindable ping key (middle mouse, as before: Mouse 4 already glides). While Alt is held, a left click does not shoot.

## Consequences
Net.VERSION bump (the "sping" shape). Expiry and following move out of match.gd into PingInput.tick. The newest ping is the one `my_ping` and the drop planner use. --ping-check covers kinds, colours, cap, expiry, following and the Net round trip. No save change.
