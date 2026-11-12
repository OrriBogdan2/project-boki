# 0055: Hits on the glider

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement, combat

## Problem
A Hunter under the glider can be shot, knocked, stunned or pulled. Shots, stuns and Grimble's reel already
matched the source. A hard shove (over 4 m/s) folded the glider for 0.4 s, because the gate that holds a shut
glider through a knock (`kb_t`) also shut an open one. The source's 1.0 glider rules say a hit doesn't knock
you out of the air, and the source lets you steer a knockback, so you keep control.

## Options
1. Keep the fold: it is [est], and nothing in the source supports it.
2. Shut the glider on a knock and spike the Hunter: the source spikes only on full heat.
3. Keep the glider open: the knock moves it with the body, and the knock's damage heats it as any hit does.

## Choice
3. In `Hunter._update_glide`, the knock gate (`kb_t`, 0.4 s) only stops a glider from opening. Glider heat
per point of damage is now a named const, `Hunter.GLIDER_HIT_HEAT` (sync64's 3x). The full case table is in
docs/MOVEMENT_FEEL.md, "Hits on the glider".

## Affects
Knocks on gliding Hunters, from players and bots alike. This changes no Net shape and no save data.
Asserted by `--glide-hit-check`.
