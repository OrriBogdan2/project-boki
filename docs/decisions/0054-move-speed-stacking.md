# 0054: Move-speed bonuses add, slows multiply, 7.0 m/s cap

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
Speed bonuses (haste status, boots and perk orbs, kin carry passives and points, kin ability and merge buffs, kit bursts such as Sable's Vault, Cinder's Pounce, Motley's Snap and Lace's spirit walk, mounts, the kin-thief chase) were each multiplied into the run speed in different places. A kin buff was even counted twice (gear_stat and _chase_mod). Nothing capped the result, and the run clip's playback rate stopped at 1.5x, so a hasted run slid its feet.

## Options
1. Highest bonus wins. The data has no sign of this. Ostra's Snap replacing its own earlier burst is one ability refreshing itself, not a rule across sources.
2. Bonuses add, as one attribute ([game data] MoveSpeed in CT_LokiCharacterAttributes is a single attribute, its Add modifiers sum, the kit numbers are flat "+75 move speed"), slows multiply the total, and the result clamps to MaxMoveSpeed 700 uu/s, which all 12 heroes share.

## Decision
Option 2. HunterMove.ground_speed(run, bonus, mult) is the one rule. HunterMove.speed_bonus(h, mv) sums every bonus, and Hunter._move_mult() multiplies every slow. Kits return their bursts from speed_bonus(), and move_k() is only their slows. The cap clamps the final speed. The alternative of clamping before the slows was not taken: the cap is the fastest you move. WardenGait.rate_for lets the run clip rate ceiling grow with the speed above the run (up to speed_cap), so a hasted run keeps its feet planted.

## Consequences
hunter_move.json gains speed_cap 7.0 and haste 0.35 (the old 1.35). Stacked bonuses are a little slower than before (1.5x rather than 1.55x), and Vex's rank-3 slide-end buff is +25% instead of the double-counted +56%. No Net or save change. --move-feel-check has 4 new haste_* rows. The Boki's own haste (Kin, x1.3) is a single bonus and is unchanged.
