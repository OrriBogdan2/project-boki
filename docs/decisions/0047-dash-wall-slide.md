# 0047: A dash into a wall slides along it

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
What does a ground dash do when it meets a cliff, a Tenzo rock, Neve's wall or a prop at 20, 45 or 80 degrees: slide, stop
or kick? Source, by rank: [game data] SUPERVIVE moves on Unreal's CharacterMovementComponent (its settings are in
briefs/supervive-data/supervive_physics.md), and its dashes are velocity curves (DashCurves) on it. A blocked move there
slides along the surface: the part into the wall is dropped and the tangent part is kept, at any angle, with no stop and
no rebound. So a dash keeps cos(angle to the wall) of its length along the face: 0.94 at 20 degrees, 0.71 at 45, 0.17
at 80. [footage] owner_mantle_clip 17.9-18.6 s: a dash into a rim carries on at dash speed (no stop). No source clip of
an angled dash into a wall was on hand; the wiki says nothing.

## Options
1. Leave it: with 0022's push-out, rocks, barriers and props already gave cos; cliffs gave 16-19% at 80 degrees.
2. Per kit: rejected (the task and 0022: one shared motion).
3. Shared motion: on a dash step (and the step that hands it over to the run) that slides along a face with one axis free,
   skip the corner slip, which pushed it sideways on top of the tangent part.

## Decision
Option 3: `HunterMove.caught`, one line of wiring in `hunter.gd`. The wall bounce and wall kick (0007, airborne) are
untouched. Kits that stop on purpose keep it: Cinder's Soot Ram on the first foe; Tenzo's Rock Hop is a leap to a spot
picked short of what it would hop into (BreahHop.spot_for), and off Neve's wall it rebounds in the air (the bounce).

## Consequences
- `--dash-wall-check`: 12 Hunters x 4 surfaces x 3 angles, the distance kept within 10% of the table.
- No Net or save change: each game steps its own hunter.
