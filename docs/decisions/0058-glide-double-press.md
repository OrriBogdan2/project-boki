# 0058: The glider opens only on a double press

- **Status:** accepted
- **Date:** 2026-11-08 (owner, repeated 2026-11-10)
- **Area:** movement

## Problem
Holding Space from the jump opened the glider 0.1 s after take-off (`GLIDE_ENGAGE`), so every held jump became a glide,
and holding Space while doing anything else (Albert's held swing) glided too. The owner wants the glider only on purpose.

## Options
1. Keep the hold path with a longer engage delay: still opens by accident on a long hold.
2. Hold only keeps an open glider open; opening takes a second press of Space in the air (`Hunter.jump`), the glide
   button (Mouse 4/5), or a jump pad / updraft (`auto_glide`). Scripted inputs (bots, demos, checks) must press again.

## Decision
Option 2. `inp.glide` means "keep it open"; `inp.glide_btn` and `auto_glide` open it at once; a Space press in the air
opens it through `jump()`. `GLIDE_ENGAGE` and the farm's `glide_hold` timer are gone.

## Consequences
`hunter.gd`, `home.gd`, `match.gd` (local input, demos, the tutorial step text), `bot.gd` and `tutorial_drive.gd` (press
again while the glider is wanted and shut). Checks that opened the glider by holding `glide` now hold `glide_btn`.
`--move-feel-check` asserts: Space held 2 s from a jump never glides; jump, let go, press and hold glides and stays open;
Albert holding LMB and Space never glides. No Net.VERSION bump (the input shape is unchanged). No debt.
