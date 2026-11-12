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
2. DashFlow (0010) holds the press: the same `held` slots, the same `BUFFER_S`, the same replay path.

## Decision
Option 2. A press the CC still forbids, made within `DashFlow.BUFFER_S` (0.15 s) of its end, is held and
replayed on the first step the CC allows it. A stun forbids LMB, RMB, E, R (not an ult's recast) and Shift
and jump; a root, Shift; Grounded, Shift and jump (not a reeling Dredge's Shift). Q's glove goes through a stun
and is never held. An earlier press is refused as before. A held press that is still forbidden after
`BUFFER_S` (a fresh stun) goes through its own path, which refuses it. While the hunter's own cast holds them
(`cast_locked`: Rimelock's statue roots its caster) the kit reads the presses, as before.

## Consequences
`DashFlow.cc_left` / `_route_cc` and `KitStatus.grounded_left`. A kit's own refusal under a root or Grounded
(the juggernaut's chain throw on E) is not held: only the slots above. Check `--cc-exit-buffer-check`. No Net
or save change.

## Addendum (2026-11-12): the end of an ult's cast lock
The same hold covers a kit's own cast lock (docs/heroes/ults.md: in the source a Shift, LMB or jump pressed in the
lock's last part comes out on the first free frame). `ArchKit.lock_left()` gives the seconds left (Albert's plant,
Kael's guard and cleave, Motley's dome, Sparkle until her strike; 0 for every other kit) and `cc_left` counts it for
`DashFlow.LOCK_SLOTS` (Shift, LMB, jump). A lock with an end is routed even while the kit's cast holds the hunter
(`cast_locked`, Motley) or moves him in a dash (Kael's cleave lunge). No new timer. Rows in each hero's ult check
(`tools/ult_exit.gd`).
