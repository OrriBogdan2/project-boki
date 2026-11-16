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

## Addendum 2026-11-12: knocked in an air dash
A knock or a stun past an air dash's i-frames used to do nothing: the dash's velocity overwrote the push every
step and a stunned Hunter dashed on. Options: let the dash ride through (no source: dashes have short i-frames,
not knock immunity), or end it. Choice: a knock that sets `knock_t`, or a stun, ends an air Shift dash that step
(`HunterMove.cut_air_dash`, called from `Hunter.impulse` and the dash step). Kit rushes and ground dashes are not
changed. Table and rows: docs/MOVEMENT_FEEL.md "Knocked in the air", `--glide-hit-check`.
