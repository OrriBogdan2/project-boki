# 0086: Smooth, not just quick (movement feel pass 11-11)

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
Owner 11-11: movement, gliding and mantling "still feel mid", "formulaic". The sim already answers in one step and
matches the source's numbers (--move-feel-check, 139 rows). What reads as robotic is what the body shows: a stationary
land clip held while running (feet sliding), no roll into turns or under the glider, a climb that smacks the face at
run speed and floats up leaning back, and a camera lead that starts at full speed.

## Options
1. Retune the sim (accel curves, turn rate): would break the parity rows, and momentum-1111 / move-speed-1111 own it.
2. Lay weight on the body and soften the joins, keep every sim number: visual changes plus one mantle approach rule.

## Decision
Option 2. A Hero's clips get HunterAnim's bank, a lean over the lip and an eased landing squash on the root bone (FEEL);
a moving landing keeps the legs running; the rise eases speed into the face (MantleCarry.approach); the camera's glide
lead is a spring. Measured by the new --move-butter-check (docs/MOVEMENT_FEEL.md "Smooth, not just quick").

## Consequences
WardenClips (feel, land pick), HunterAnim (bank under the glider, rise tuck, soft glide landing), MantleCarry, CamRig;
Hunter: one anim-state line. No Net or save change (visual, plus a local step rule). Checks: --move-butter-check, clip-check.
