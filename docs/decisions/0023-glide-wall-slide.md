# 0023: The glider slides along walls

- **Status:** accepted (source parity)
- **Date:** 2026-11-10
- **Area:** movement

## Problem
A glider meeting a cliff face, a ruin wall or a Tenzo rock 20 to 70 degrees off the normal at 4 m/s or more into it
reflected off it (the `WallMoves` bounce of decision 0007 listed "a glide"), and any other hit gave it 10% of its
into-wall speed back each step, so head-on it shivered on the face and a shallow hit jittered in and out. SUPERVIVE's
glide runs on UE's CharacterMovementComponent, whose wall hit slides (HandleImpact, SlideAlongSurface): the part of
the velocity into the wall is dropped, the part along it kept, no bounce, no stop, and the canopy stays open.
[?] The physics dump (briefs/supervive-data/supervive_physics.md) has no glide-wall row of its own and the hero-ref
footage never shows a glider on a wall; GlidePreserveSpeedSteeringAngle/Rate exist by name only.

## Options
1. Keep the bounce for gliders (decision 0007, the owner's movement pass, asked that a wall at speed not just stop
   you): rejected for the glider only; the source slides. The dash and boosted-jump bounce stays.
2. A glide-only push-out for Tenzo rocks: rejected, it would copy `HunterMove.push_out_walls` (decision 0022).
3. `WallMoves.stopped()`: a glider keeps none of the speed on an axis a wall stopped (everyone else the old
   `WALL_BACK` nudge); `WallMoves.hit()` skips gliders; the rock push-out comes from ext/feel-wall-slide (decided).

## Decision
Option 3. Along a wall the glide force (`Hunter.GLIDE_ACCEL`) then settles the slide at cruise x sin(angle off the
normal), which is what UE's force-toward-target-speed does once the normal part is projected away every step.

## Consequences
- `hunter.gd`: two lines route the axis push-back through `WallMoves.stopped`. `wall_moves.gd`: `stopped()`,
  `WALL_BACK`, the glider guard in `hit()`. Movement is owner-side: no Net or save change.
- Merges ext/feel-wall-slide 4de2100f4: without its push-out a rock turned off the grid still dead-stops a glider.
- `--move-feel-check` rows `glide_wall_*`: cliff, ruin wall and Tenzo rock at 0, 30 and 60 degrees: along-wall
  speed within 10% of the tangent speed it hit with, never a dead stop or a sign flip over 1 s, no rebound, open.
- Follow-up: a block tile on a raised terrace (a rock on a cliff edge) still catches a glider, since the block body
  (0.7 r) and the terrain body (r) disagree on where the face is.
