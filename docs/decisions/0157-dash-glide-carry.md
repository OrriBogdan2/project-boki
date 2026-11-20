# 0099: The glide carries the dash, and Brall's chains into the glider drop no press

- **Status:** accepted
- **Date:** 2026-11-15
- **Area:** movement

## Problem
Owner playtest 11-13: dash-gliding "doesn't give the speed it should (like the reference) ... not fluent, especially Brall ground RMB + glide or dash + glide". Measured on main 8ef7d80c02: 1 s into a dash-glide 8.5 m/s (`--move-feel-check` pinned it at <= 9 for the owner's 11-08 "bleeds back within 1-2 s", while MOVEMENT_FEEL.md asked >= 10.5). Brall: his Rampage and Lunge set a 0.35 s glider wind-down at their end; a jump and a glide press inside it waited 0.2 s with Space, and the glide button's press was dropped (it only armed while the glider could open).

## Options
1. Tuning only (glide drag), Brall untouched.
2. Tuning, plus: a ground jump clears a move's wind-down (the rule a jump out of a dash already had), the glide button arms through a lock like a second Space, Brall's press grace after an air Rampage 0 -> 0.25 s.
3. Drop Brall's wind-down altogether.

## Decision
Option 2 (coordinator, owner's words: take the MOVEMENT_FEEL target, 1 s >= 10.5). tuning.json: `glide.drag` 2.0 -> 1.2, `drag_steer` 1.4 -> 0.8, `glide_carry.default` 12 -> 14, archer 9 -> 11, `dash_glide.grace.juggernaut` 0 -> 0.25. Option 3 stays open if the owner still feels a wait after an air Rampage pressed 0.25-0.35 s late (it now opens as the wind-down ends, <= 0.1 s).

## Consequences
Dash-glide 1 s 8.5 -> 11.6 m/s, 2 s 5.9 -> 8.0, 3 s 5.2 -> 6.3 (new row), cruise 5.0 unchanged. 2 lines in `hunter.gd`. Every glide above cruise (knocks, swoops) also bleeds slower. Net.VERSION: no. Saves: none. Checks: `--move-feel-check` dashglide rows retargeted, `--airdash-glide-check` Brall rows.
