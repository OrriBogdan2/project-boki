# 0022: Snag audit: slip past corners on the keys' pull, eject a body from inside a wall

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** movement

## Problem
Getting caught on a lip, rock or prop corner ruins movement feel; the source slides along edges. `--snag-check` (12 Hunters, 50 seeded run/dash/glide paths on The Hollow Crown) found 32 stalls (speed under half the wanted speed for over 0.15 s, keys held, no wall above mantle reach straight on). Causes: (1) a body running at a shallow angle into a wall corner: the corner zeroes the axis, the speed drops under the 1 m/s the corner-slip needs, so the slip never fires and the body crawls past; (2) a body that dropped off a terrace edge (it lands inside the column of the wall it left) or glided down onto a prop top (it sinks into the prop) is inside a solid, so every step is blocked until the 0.9 s wedge net.

## Options
1. Replace the axis-separated terrain collision with a circle push-out like props. Right shape, but wall kick, mantle and wall slam read the axis hits (`b1`/`b2`); too much risk to the move feel.
2. Keep the collision; let the corner-slip use the keys' pull when the speed is gone, and eject a body found inside a solid to the nearest free spot (`BodySlip.eject`).

## Decision
Option 2. Run speed, mantle reach and jump are untouched. The slip uses `spd * mv` as the wanted speed and the keys as its direction when the velocity is under 1 m/s. The eject runs only on a blocked step, only when the body's own spot is blocked (`_occ > 0`, not a one-terrace step up), never for a Spirit Walk.

## Consequences
`hunter.gd` (slip condition, the eject and corner-round wiring), `scripts/match/body_slip.gd` (`eject`, `round_corner`), `tools/snag_check.gd` registered as `--snag-check`. No Net or save change. 32 stalls fall to 2, then to 0 (ext/feel-snag-last-two: the slip's last try rounds a terrace corner, and a glide sunk beside a prop is put out of its side before the axis moves; see docs/MOVEMENT_FEEL.md).
