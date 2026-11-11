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

## Addendum 2026-11-11: the 0.24.4 gate reds (ext/remote-smooth-reds)

`--remote-smooth-check` failed 5 rows under the gate's load (1 to 4 on a loaded worker). Two causes:

- **The check:** it stepped each game one DT per frame, so on a loaded machine the two match clocks drifted
  apart, which never happens in play (`Match._process` steps the frame's real time). It now steps both games
  the same way and draws the body at the render alpha. Snaps and jerks skip frames longer than the 0.1 s step
  cap (the game's own stutter), and "the whole run" means 20 frames a second or more, not 400 frames. The
  lift may be one quick sweep (at most 0.25 s) when the snapshot before it was lost: 5 m over 0.2 s with both
  ends at rest reads the same at 10 Hz as a standing dash.
- **NetSmooth:** an owner whose clock lost time (a hitch past its step cap) left the drawn moment running past
  the newest snapshot, and the 0.25 s run-on then jumped 4.8 m when the next one came in. Also: a lost
  snapshot before a stop made the Hermite run past the stop and come back, a late snapshot pulled the run-on
  back in one step, and a fall ran on 0.6 m into the floor. Fixes: `off` is the quickest arrival of the last
  second, the drawn clock slews (10%) instead of jumping, the run-on eases to a stop, the tangents are held to
  3x the step (Fritsch-Carlson), a run-on's miss is taken back with the body's own movement, and a run-on stops
  on the floor. Wire shape unchanged (Net.VERSION as is).
