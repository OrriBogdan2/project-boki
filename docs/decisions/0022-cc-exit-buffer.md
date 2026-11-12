# 0022: Presses at the end of a crowd control

- **Status:** accepted
- **Date:** 2026-11-10
- **Area:** combat / movement

## Problem
A press made while stunned, rooted or Grounded was refused, so a player who pressed a hair before the CC ended
had to press again: they mashed at every stun's end. Parity: the source's data gives no CC-exit window, and
the footage (briefs/hero-ref) shows only dummies stunned; the one hunter-side CC, Dredge's own Grounded while
reeling, is followed by Iron Smash, which Grounded doesn't forbid. At 5 fps no window can be measured.

## Options
1. A new CC-exit timer per slot in Hunter: a second buffer next to DashFlow's.
2. DashFlow (0010) holds the press: the same `held` slots, the same `Loco.press_buffer`, the same replay path.

## Decision
Option 2. A press the CC still forbids, made within `Loco.press_buffer` (0.15 s) of its end, is held and
replayed on the first step the CC allows it. A stun forbids LMB, RMB, E, R (not an ult's recast) and Shift
and jump; a root, Shift; Grounded, Shift and jump (not a reeling Dredge's Shift). Q's glove goes through a stun
and is never held. An earlier press is refused as before. A held press that is still forbidden after
`Loco.press_buffer` (a fresh stun) goes through its own path, which refuses it. While the hunter's own cast holds them
(`cast_locked`: Rimelock's statue roots its caster) the kit reads the presses, as before.

## Consequences
`DashFlow.cc_left` / `_route_cc` and `KitStatus.grounded_left`. A kit's own refusal under a root or Grounded
(the juggernaut's chain throw on E) is not held: only the slots above. Check `--cc-exit-buffer-check`. No Net
or save change.

## Addendum 2026-11-12: a kit's own cast lock
A press during another ability's cast lock (`ArchKit.busy()` beyond `disabled()`: Motley's 1.0 s Nightwell cast,
Kael's Riposte guard and cleave, Vex's Kitefall from the crouch to the landing) went to the kit, which refused it
with the deny cue, so a press a hair before the lock's end was lost. Parity (briefs/hero-ref): Void acts freely
through the Nightwell; Brall's guard and Ghost's recoveries are silent on presses; no footage shows one dropped.
So the same rule holds: `DashFlow._route_lock` holds RMB and E (`LOCK_SLOTS`) the lock refuses
(`ArchKit.lock_refuses`, which Kael's E on a held chain passes, owner 113.7) and replays them on the first step
the lock lets them, at most `Loco.press_buffer` after the press; a lock that runs on past that answers with the deny cue
then. X stays the ult's own recast, Q's glove goes through. Check `--cast-lock-buffer-check`.
