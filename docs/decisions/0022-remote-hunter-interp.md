# 0022: Remote Hunters drawn from a snapshot buffer

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** networking

## Problem
Other players' Hunters chased their newest "st" snapshot (`Ent.net_follow`: up to 0.25 s of extrapolation,
an exponential chase, a snap past 4 m). With 100 ms latency and 2% loss they lurched: on the two-game check
the largest per-frame move was 0.62 m against the owner's own 0.37 m, and 1 of 2 walks, 1 of 3 dashes
and 1 of 2 Warchain pulls jumped more than 0.45 m in a frame. With this change: 0.38 m, no snaps.

## Options
1. Tune the chase (stiffer or softer). It trades lag for overshoot; it can't remove the correction jumps.
2. Snapshot interpolation: queue the snapshots with the sender's stamp (already in the "st" header) and
   draw one send interval in the past, extrapolating at most 150 ms when one is late.
3. The same, with the owner flagging teleports in the snapshot. Tows move bodies with per-step teleports,
   so a flag would fire every frame of a pull; it also changes the snapshot shape.

## Decision
Option 2, in `NetInterp` (scripts/match/net_interp.gd), for remote Hunters only. A move between two
snapshots faster than 45 m/s (+1 m) is a teleport: hard reset. A sender's clock resync shifts the queue.
No snapshot change, no `Net.VERSION` bump. The host's bots are Hunters too and use it; monsters and Boki keep the chase.

## Consequences
Remote Hunters show ~100 ms further in the past than before (they were extrapolated toward the present),
so a fast target is drawn slightly behind; hits are still judged by the owner. A teleport under 5.5 m
within one interval glides over that interval instead of snapping. Checked by --remote-smooth-check.
