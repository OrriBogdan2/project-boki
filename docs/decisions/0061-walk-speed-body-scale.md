# 0061: Walk speed at the source's pace for our body size, the same in every mode

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner playtest 11-11 (0.24.4): "base movement speed is way too slow, feels like molasses" and "the walking in
expedition is stupidly slow, it should be same speed as supervive". The owner also asked that the expedition,
the Training Grounds and the farm move the same way.

A headless measure (`--move-speed-check`, run through the real frame) gave these results. Every hunter
walked at its `hunter_move.json` row (4.45–4.85 m/s) in all three modes. That is SUPERVIVE's MoveSpeed
(445–485 uu/s) in metres, the same since Nov 2, so nothing regressed. On screen that is 0.19 screen widths
per second in a match and 0.13 on the farm, because the farm's camera shows 34 m across against the match's 23 m.
The farm and indoors walked through their own code: home.gd had its own ground step and a stale
`SPEED 5.0`, and interior.gd had a 4.2 m/s ease.

The difference with the source is body size. The source hunter is 1.76 m (bot nav agent height 176 uu), and
our plain medium hunter is 2.04 m (`--move-feel-check`, at `Hunter.VIS_SCALE`). The same m/s therefore covers
14% fewer of our own body heights per second: 2.23/s for us against 2.59/s in the source.

## Options
1. Keep metre parity (4.55 m/s). It matches the data but not what the owner sees.
2. Scale the walk by the body ratio, 2.04 / 1.76 = 1.16 (`body_scale`). The rows stay verbatim game data, and
   the source's per-hunter ratios hold.
3. Scale the whole movement (glide, dash, jump) by it. That is out of this change's reach, and three other
   jobs own those numbers.

## Decision
Option 2, applied to both speed and acceleration, so the walk is still reached in the source's ~0.08 s.
`HunterMove.speed`, `HunterMove.accel` and `HunterMove.walk` (the ground step) are the only path. The match,
the farm and indoors all call them, and `HunterMove.CROUCH_K` replaces the two copies of 0.55. The dead class
speed (`Data.CLASSES` "speed", always overwritten) is gone.

## Consequences
Walking goes from 4.45–4.85 to 5.16–5.63 m/s (455 uu/s hunters: 5.28). Glide cruise (5.0, glide jobs) is now
under the walk: the source's glide is 1.1x its run, so the glide owners should scale cruise by `body_scale`
too (noted for ext/glide-smooth-1111). The match camera shows ~23 m across, while the source's CameraDistance is
55 m (~36–40 m across in the hero-ref footage scale); that is a separate camera question. No Net or save change.
