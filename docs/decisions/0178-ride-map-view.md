# 0178: The skyship ride is a map screen

- **Status:** accepted
- **Date:** 2026-11-26
- **Area:** match flow / performance

## Problem
Owner 11-26: the whole map was in view and loaded for the ride, and in the target feel you only see a map while riding, then a rocket going down. Measured on a 4090 pod (`--loadin-fps-check`, 30 players): the plan and the ride drew ~16k objects and ~1.3k draws at 62-113 ms a frame.

## Options
1. Keep the 3D ride view and cull harder (visibility ranges already cut it; the engine still walks ~16k objects).
2. The drop map is the view from the plan until the launch; the 3D view is off behind it (`RideView`, `Viewport.disable_3d`).

## Decision
Option 2. `RideView.tick` (from `Hud._process`) keeps the drop map open while you wait aboard, closes it at your launch, and turns 3D off while it covers the screen, after the loading screen's warm-up (`Match.warmed`) so no shader compiles later. The map's header shows the launch prompt and the seconds left. Closing the map with its key brings the 3D ride view back. `DropRocket`, the rocket camera and ADR 0143's rules are unchanged: the 3D world draws again from the launch.

## Consequences
- No sim, Net, save or map change: the match, the ship, bots and spawns run as before; only drawing changes.
- `--drop-feel-check` part 6 asserts it; `--loadin-fps-check` prints a per-phase table and the build steps.
