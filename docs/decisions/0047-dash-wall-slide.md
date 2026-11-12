# 0047: A dash into a wall slides along it

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement

## Problem
What does a ground dash do when it meets a cliff, a Tenzo rock, Neve's wall or a prop at 20, 45 or 80 degrees: slide, stop
or kick? Source, by rank: [game data] SUPERVIVE moves on Unreal's CharacterMovementComponent (briefs/supervive-data/
supervive_physics.md) and its dashes are velocity curves (DashCurves) on it. A blocked move there slides along the surface:
the part into the wall is dropped, the tangent part kept, at any angle, no stop and no rebound. So a dash keeps cos(angle to
the wall) of its length along a flat face: 0.94 at 20 degrees, 0.71 at 45, 0.17 at 80. [footage] owner_mantle_clip
17.9-18.6 s: a dash into a rim carries on at dash speed. No clip of an angled dash into a wall was on hand; the wiki is silent.
`--dash-wall-check` on 0022's wall slide: 125 of 144 tries; cliff dashes at 80 degrees kept 19-20% (the corner slip pushed
them on), and along a straight three-tile prop face dashes caught at the tile seams (6-8% at 80 degrees, 56-63% at 45).

## Options
1. Per kit: rejected (one shared motion, as 0022).
2. Shared motion: no corner slip on a dash step sliding with one axis free; the rock-tile push-out resolves the deepest
   overlap first (scan order let the next tile's corner push a body back along the row); a long step is pushed out in
   pieces of half the block radius (a fast dash's step ended deep in a tile and came out of the wrong side).

## Decision
Option 2: `HunterMove.caught`, `HunterMove.push_out_swept`, `World.push_out_blocks` rewritten in place (net 0 lines).
Walks are one piece, so walking is unchanged. The wall bounce and kick (0007, in the air) are untouched. Kits that stop on
purpose keep it: Cinder on the first foe; Tenzo's Rock Hop leaps to a spot picked short of a wall (BreahHop.spot_for).
Archer's Spirit Walk now ends with her kit (a practice class change left the next class walking through rocks).

## Consequences
- `--dash-wall-check`: 12 Hunters x 4 surfaces x 3 angles, the distance kept within 10% of the table: 144 of 144.
- No Net or save change: each game steps its own hunter.
