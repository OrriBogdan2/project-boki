# 0022: Hits and events leave at once; a dash or cast sends its snapshot early

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** networking

## Problem
`Net.tick` sent the player's snapshot, queued hits and queued events only when a 0.1 s timer ran out, so every
press waited 0-100 ms (mean 50) before leaving, on top of the line. At 100 ms added delay the relay heard a press
24-115 ms late (docs/ONLINE_FEEL.md).

## Options
1. Raise the snapshot rate to 20-30 Hz. Halves the wait but doubles the traffic for everyone, always.
2. Flush hits and events every frame (they are only sent when something is queued) and send the player's snapshot
   early when a dash or kit move starts (velocity jump over 8 m/s or a new kit move), at most once per 30 ms.
3. Send dash/cast intent in the snapshot so the other side animates it whole. Better feel, but a wire change
   (`Net.VERSION` bump); filed as a proposal in ONLINE_FEEL.md.

## Decision
Option 2. No message shape changes, no `Net.VERSION` bump: an old and a new game still talk. Extra traffic is
one snapshot per dash or cast and the hit and event packets that were already being sent.

## Consequences
At 100 ms the game now adds 6-17 ms to the line's delay for dash, LMB, E and recast (was 24-115).
`--online-feel-check` fails if any press adds more than 60 ms; `--displace-net-check` still passes.
