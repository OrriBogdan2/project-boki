# 0022: The body turns onto the cursor at the source's rate

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Our body yaw eased onto the cursor at 20/s (a 90-degree flick settled in ~0.22 s, a 180 in ~0.26 s). In the footage of the four slice Wardens the upper body is on the cursor "at once" (Ghost, Myth, Brall, 5 fps) and Felix turns on the spot within 1-2 frames at 60 fps. PARITY FIRST (briefs/DECISIONS.md 2026-11-07): match the source.

## Options
1. Keep the ease and raise its rate: still a tail, and no number to assert against.
2. A capped turn rate, `Hunter.FACE_TURN` 5400 deg/s: 90 degrees in one 60 Hz step, 180 in two. One constant with a unit, measured by `--move-feel-check`.
3. Per-state rules (run faces the move direction when not firing): the four sheets show the body on the cursor in every state, so there is no source for it.

## Decision
Option 2. The per-state rules already in the code stay as they are, because they match the footage: the legs turn toward the travel direction (`HunterAnim.legs_yaw`), a dash turns the body along the dash unless the kit aims through it (`aims_in_dash`), and a kit freezes the facing only through `face_locked()` / `aim_lock()`. None of the four slice kits locks facing in the footage, so none is changed (Vex's E aim cap is the owner's, on ext/vex-e-turn).

## Consequences
`scripts/match/hunter.gd` (one constant, one line), `--move-feel-check` moved into the check registry and given nine facing rows (90/180-degree flips standing, running, firing, gliding; the legs on the run), `docs/MOVEMENT_FEEL.md` Facing section. No Net change (face is already synced, only its local rate changed), no save change.
