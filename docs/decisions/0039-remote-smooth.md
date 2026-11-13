# 0039: Drawing other players' Hunters from a snapshot buffer

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** networking

## Problem
Each game simulates only its own Hunter; everyone else's is drawn from 10-a-second snapshots. The proxy
chased the newest one, dead-reckoned from when it *arrived*, so jitter and loss showed as speed kicks.
Measured by `--remote-smooth-check` (80 ms ping, 20 ms jitter, 2% loss): 21-22 frames of jerk and a
backstep per 9 s run of run/stop/turn/dash/glide/knock, about 125 ms behind.

## Options
1. Keep dead reckoning, tune the chase gain. Least delay; corrections stay visible.
2. Interpolation buffer on the owner's clock (the `st` header's match time): draw a fixed delay behind
   the quickest arrival, Hermite between the two snapshots around that moment, snap on teleports.
3. Option 2 plus 20 snapshots a second, so the delay could be 100 ms. Doubles snapshot traffic; Net change.

## Decision
Option 2 with a 0.15 s delay (one 0.1 s snapshot gap plus the jitter): 5-12 jerk frames, no backsteps,
at most 0.07 m off the true path, about 200 ms behind. A 0.1 s delay measured 19 jerk frames and a stray
snap, because a jittered snapshot often arrives after it is needed. Option 3 is the way to 100 ms.

## Consequences
`scripts/match/net_smooth.gd` (NetSmooth), 3 lines in `Ent.net_follow`, 3 in `Match._net_apply`. Hunters
only; Boki and monsters keep the old chase. No wire change, so no Net.VERSION bump. Remote Hunters are hit
where they are drawn, now ~75 ms further behind their owner. Check: `--remote-smooth-check`.
