# 0095: The glide swoop

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** movement

## Problem
The source glider turns sink speed into forward speed when you level out (GlideDownwardForceSwoopSpeedTransferRatio
2.5, SwoopSpeedFadeTime 1.5 s). Ours dropped that swoop on 11-08, reading the owner's item 8 ("opening the glider
adds no horizontal speed") as "no fall ever becomes speed", so feathering and diving had no payoff.

## Options
1. Any fall the canopy catches becomes speed (the pre-11-08 swoop). Breaks item 8: a long fall into an opening swoops.
2. Only fall the glider's own forces built swoops: its pull above glide_height (the source's downward force) and the
   crouch dive. A fall you open the glider in is absorbed as before.

## Choice
Option 2, in `GlideLift`: `build` notes fall past the sink that the pull or dive added; `fall_vy`'s catch pays the
part of it shed as `tuning.json glide.swoop` x m/s of forward speed (half overheated, like the abyss lift), fading
linearly to 0 over `glide.swoop_fade`. The swoop rides on top of the glide's own steering (`unswoop`/`reswoop`), so
the glide drag does not eat it; it tops out where a cruise glide reaches `glide.max`. Folding the glider ends it.

## Affects
Hunter glide only (farm avatar unchanged). No Net or save change: the swoop is local physics state.
Checked by --move-feel-check (`glide_high_swoop_x`, `swoop_x`, `swoop_fade_s`, `swoop_left`, `swoop_hot_x`).
