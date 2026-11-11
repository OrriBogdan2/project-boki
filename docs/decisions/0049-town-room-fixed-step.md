# 0049: Town and interior move in fixed steps; the facing is blended between steps

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** movement / farm, town

## Problem
Decision 0048 moved the farm avatar onto the match's fixed step, but the town and the interior still moved on frame time with their own numbers (town 5.0 m/s and a jump of 8.5 at gravity 26, room 4.2 m/s). Their jump height, stop slide and turns changed with the display rate, and none of the three drawn a facing that turned smoothly: the facing changed once per fixed step.

## Options
1. Leave town and room alone (they are small, flat places). The first thing a player sees after a match is the town, and it moves unlike the farm and the match.
2. Run them on `FarmStep` with the hero's rows from `content/rules/hunter_move.json`, and blend the facing in `FarmStep`.

## Decision
Option 2. `FarmStep.walk` is the one ground-speed step (row speed and accel, the walking brake), `FarmStep.face` reports the stepped facing and `run` shows it blended between the last two steps. Home, town and room call the same two functions. Town's jump is the match's (`Hunter.JUMP_V`, `Hunter.H_GRAV`) with coyote time and the buffer; the room has no jump. The alternative (keep the old town jump of 8.5 / 26) was dropped: the owner's goal is one feel everywhere.

## Consequences
Town and room walk at the hero's run speed (4.55 by default) and turn at `turn_rate`; the town jump is higher (about 1.52 m against 1.39). `--move-rate-check` gains `town` and `room` rows and a facing assert. No Net or save change (the town's presence still sends the stepped position and facing).

## Addendum (2026-11-11): drawn at the present
`FarmStep` drew the body between its last two steps, a step behind; a match draws its own Hunter at the present (`Hunter.render_pos`). The farm, town and room now use the same lead: the last step carried on by the time since. The facing stays blended between steps (alternative: lead it too, which makes the first frame of a turn jump a whole step at 144 fps). Like the match, a lead can sit up to one step's fall below the ground on the frame of a landing. `--move-rate-check` asserts the drawn body is at the present at 30, 60 and 144 fps.
