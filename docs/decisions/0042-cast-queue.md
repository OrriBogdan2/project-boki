# 0042: Ability presses during another ability (the cast queue)

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** combat

## Problem
DashFlow decides presses during a dash, recasts are buffered, but an RMB or E pressed during another ability's
wind-up or recovery went wherever each kit happened to send it: fired mid-cast (Vex's grenade in the Railgun's
charge), was refused by a `busy()` (Zedran's guard, Ostra's well, Ryzz's Kitefall, Claire's seal, Dredge's reel,
Bjorn's plant), or was dropped on purpose (Cinder's flight, owner item 66). The source's data and footage show
one such press (Brall's Scorching Spin "DURING Feysteel Chain pull") and are silent on the rest.

## Options
1. Leave it per kit. Every kit keeps its own answer; three silent exits for one press (STATE_MACHINES 3.3).
2. One shared rule in the ability runner, exceptions as data rows where the source or an owner call differs.
3. The full M3a `Slot` machine (WINDUP/ACTIVE/RECOVERY/COOLDOWN per slot) first, then this on top.

## Decision
Option 2, with the explicit `Fsm` pattern (STATE_MACHINES section 1). `CastQueue` (scripts/arch/cast_queue.gd,
OPEN/HELD) runs at the end of `ArchKit.tick`; each kit names the slot that owns the body in `move_slot()`. The
shared rule queues the press and lets it go the step the move ends, like DashFlow's missing row ("nothing is
dropped"). Rows in content/rules/cast_queue.json carry "fire" or "drop" with their source;
docs/heroes/cast_queue.md is generated from them. Option 3 stays the M3a job; `move_slot()` is what it replaces.

## Consequences
- Seven presses that were refused now wait for the move's end; Vex's grenade in the Railgun charge waits.
- scripts/core/fsm.gd is ext/fsm-m1's file verbatim (an add/add that merges clean).
- `--cast-queue-check` presses every row's pair mid-cast. Net and saves: untouched (local input routing).
