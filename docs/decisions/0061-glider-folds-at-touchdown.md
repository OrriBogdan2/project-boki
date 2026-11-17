# 0061: The glider folds on the step it touches down

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
A step reads its presses before it moves the hunter, and the ground closes the glider only at the end of that move.
A shot, a cast or a kit dash pressed on the step a glide or a glide dive touches down was read while the glider was
still open, so it was refused and never came back (`--dash-flow-check` landing rows: Albert's and Vex's LMB, Vex's
dash). A landing held nothing else: its absorb is the model's alone (HunterAnim, WardenClips).

## Options
1. Buffer every press refused under the glider near the ground, like the jump's JUMP_BUFFER. Needs a buffer per slot.
2. Fold the glider before the presses are read, on the step the fall reaches the ground. One check, no buffers.

## Decision
Option 2. `AirLimits.fold_at_touchdown` closes the glider (and its dive) when this step's fall reaches the ground, so
that step's presses act as they do in the air without a glider, and the hunter lands at the end of the step as before.
The opening drop keeps its own lock (item 162) until it lands.

## Consequences
hunter.gd +1 line of wiring. The glide's touchdown puff moves to the fold. `--dash-flow-check` asserts that a dash, a
jump and every slot pressed on a landing's step, or in its absorb, act as soon as they do standing. No Net or save
change.
