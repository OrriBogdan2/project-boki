# 0061: Vex's stuck burr cone online

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** networking

## Problem
When Vex's Burr Charge sticks, her game draws (and hits with) a 0.9 s fuse cone of `cone_len` 6.0 m and `cone_deg` 100 degrees. Other players' games don't run her kit, and nothing sent the cone: the only receiver, Match's Net fx "cone", was a leftover with no sender and a fixed 5 m. A foe online could not read the danger area.

## Options
1. A new fx kind for the burr. Cons: a second cone event next to the unused one.
2. Reuse the Net fx "cone" event: the stick sends point, direction, the cone length and the hunter id; the receiver draws the shooter's AimKit cone under the copy of Vex for the fuse. Degrees and fuse are fixed in `gunslinger.json`, so the receiver reads them from its own data.

## Decision
Option 2, Net.VERSION 0.24.6 (the event's shape changes). Shape: `["fx", "cone", x, y, z, out x, out y, length, hunter id]`, sent once per stick through `Match.net_fx` and `Net.event`. The receiver is `GunslingerKit.net_cone`; Match's line only routes to it. The copy shows the cone without the local fill ramp (one event, no per-frame refresh).

## Consequences
scripts/arch/kits/gunslinger_kit.gd (send and draw), one routed line in match.gd, Net.VERSION. `--remote-anim-check` asserts the copy's cone (point, direction, length, degrees) equals the shooter's. The detonation look (the fan and sparks) still shows on the shooter's game only.
