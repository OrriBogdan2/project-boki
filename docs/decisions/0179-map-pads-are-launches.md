# 0179: Map pads are launches, not scripted arcs

- **Status:** accepted
- **Date:** 2026-11-27
- **Area:** movement

## Problem
Owner 11-26: "do the jump pads also have no 'set' path now?" A map pad (`World.pads`, the time trial's pad) flew a scripted arc (`Hunter.pad`, `_pad_fly`) to a set landing, clamped onto the target island's terrace; keys did nothing and bots rode the same arc. The reference's launch only replaces the vertical velocity and adds to the planar one, then the body falls under its normal air physics with full air control and the glider free.

## Options
1. A launch on our normal air step (`Loco.air_step`). Rejected: speed over the run cap bleeds at air.drag 2/s, so a 20 m throw needs ~38 m/s and a 50 m one over 100 m/s, and a side key brakes the throw at 9.6 m/s^2 (into the void).
2. A launch whose speed over the run cap follows the reference's falling step (`Loco.launch_step`): bleeds at 0.75/s, keys add 7.5 m/s^2 clamped to the speed you had (they bend the throw); at or under the run cap it is any jump.

## Decision
Option 2. `PadFlight.launch`: up speed from the old arc's apex height, plus a boost along the pad's facing solved (bisection on the same step) so a standing no-key flight lands on the pad's spot, plus the planar speed you brought (x1.15 in a dash, at most 14 m/s). No landing is set or clamped. Bots steer in flight against the predicted no-key landing (`PadFlight.steer_bot`) and open the glider if short.

## Consequences
hunter.gd: `launch_air` (on until you land, glide, dash or get knocked) picks the step. UtilityUse loses the scripted throw and the terrace clamp. Ledge pops and lip mantles keep `Hunter.pad`. No Net or save change (velocity is already synced). Checks: `--launch-arc-check` map_* rows.
