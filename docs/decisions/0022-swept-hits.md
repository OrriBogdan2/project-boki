# 0022: Swept hits for fast shots and dashes

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat

## Problem
At 30 fps a 40 m/s shot or dash moves 1.3 m a frame, more than a Hunter is wide. A hit test on where the
mover ends up each frame can skip a body or a thin wall.

## Options
1. Leave it: shots already walk their path in 0.25 m slices (`Match._update_shots`), so they do not skip.
2. One shared helper, `Swept` (`dist` to a segment, `clip` a segment at the first block), used by every
   non-shot mover that tests hits per frame: Hunter dashes (`_pass_along`, `_shove_along`), the boss dash,
   the Boki recall sweep, and the dash's own movement step.
3. Substep the whole physics tick at low fps. Much wider, and it changes feel.

## Decision
Option 2. Shots are left as they are (the check proves them at 30 and 144 fps, with thin cover). The dash step
is clipped at the first block taller than the dasher's feet, so a 30 fps dash no longer tunnels a 1 m block,
and dash hits test the segment from the position to where this step ends (clipped the same way). The pierce
rules are untouched: the hit sets and "once per dash" rules stay where they were.

## Consequences
- `scripts/combat/swept.gd` (new), a few lines each in `hunter.gd`, `boss.gd`, `kin_strike.gd`.
- Behaviour change: a dash of more than 0.5 m a frame stops at a block instead of sliding along it or passing
  through it (slower frames only; at 60 fps and up a dash is under 0.5 m a step and slides as before).
- `--swept-hit-check` (registered) holds the contract: every fast shot and dash hit, a still dummy, three
  ranges, 30 and 144 fps, 100% hits; the same casts behind one thin block, 0% hits.
- Net.VERSION bump: no. Nothing synced changes shape.
