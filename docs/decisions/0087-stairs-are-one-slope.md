# 0087: Stairs are one walkable slope

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** movement

## Problem
The owner said walking up stairs was "bugged, not smooth". A flight's ground (`World.ground_at`) is already a straight
ramp (one terrace per tile), but the body treated it as a series of small ledges. Going up, the leading sample of the
body's ring read the ramp ahead as a wall, so the terrace step-up snapped you to that higher point and you were in the
air the next step (95 of 140 steps up a Hollow Crown flight). Bots that aren't local also "leaned up" the slope as a
ledge and mantled up every flight in hops. Going down, the slope dropped more per step than the 5 cm "left the ground"
limit, so you fell and landed over and over (55 steps).

## Options
1. Stepped colliders with a bigger step height and a visual ease of each pop: matches the drawn steps, but keeps a pop
   per riser and needs smoothing in the model and camera.
2. Keep the ramp and teach the body that a stair's rise and fall is a slope: walls ignore a rise the slope gives over
   the sample's distance, the ledge lean ignores it too, and a grounded body keeps its feet over a drop the slope gives
   over its step (floor snap, stairs only).

## Decision
Option 2. The ramp was already the smooth ground; only three tests misread it. One World helper (`stair_slope`)
answers "how much rise or fall is still one slope here", and it is 0 off stairs, so terrace ledges, island rims and
every off-stairs drop behave exactly as before.

## Consequences
`World.occupy`, `World.on_stairs`, `World.stair_slope`, two conditions in `Hunter._physics` / `_try_ledge_grab`.
No Net or save change. `--stairs-check` walks real flights on every map with stairs both ways. Feet follow the ramp
while the stairs are drawn as four treads a tile, so feet sit up to 0.2 m into a tread (left as is).
