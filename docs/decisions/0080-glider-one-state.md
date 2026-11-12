# 0080: The glider is one Locomotion state with one entry edge

- **Status:** accepted
- **Date:** 2026-11-12
- **Area:** movement (briefs/STATE_MACHINES.md M2a; follows 0022 and the HunterLoco owner, 11-11)

## Problem
The glider's rules lived in eight flags and timers on `Hunter` next to the `Loco.S.GLIDING` state they mirrored:
`auto_glide`, `_auto_glide_held`, `_glide_armed`, `_glide_btn_held`, `glide_off_t` (0 = just let go, 9 = long ago),
`lift_t`, `heat_burn`, and three open sites (`do_jump`, `_open_glider`, `_update_glide`) that each repeated the
open's effects. Which path opened it and why was not readable in the F7 log, and a new rule had to be added three times.

## Options
1. Leave the flags, add a check per rule. Cons: the owner bugs this pattern exists for (hold-Space glides, a fold that
   reopens on a held key) come back with every new open site.
2. Move the glider's data and its step into `HunterLoco`, the machine's owner: one guarded entry edge, the open's
   effects in the enter hook, the per-step rules in `glide_tick`. Chosen.

## Choice
`HunterLoco` owns `auto_glide`, `armed`, `let_go_t` (INF when the last fold was not a let-go), `lift_t`, `heat_burn`
and the held-key memories. GLIDING's target guard holds what every open shares (in the air, no dash left, cooldown
over, not stunned, downed, shot down or dropping, no knock under a dash or ledge rise); each press path keeps its own
extra rules (`Hunter.can_glide`, `dash_into_glide`, the hold's `stays`) so behaviour is unchanged. `open_glider(why)`
is the one way in and logs the press ("press", "button", "auto", "held", "pad"); `press_glide` is the second Space.
Scripted opens (the drop, the net, checks writing `gliding`) still bypass the guard and get no open kick.

One effect merged: the open's below-the-lip sound and the "feathers" stat used to count only the held/button
opens; every open counts now. `shot_down` and `glide_cd` stay on `Hunter` (set by combat and kits: M2b).

## Affects
hunter.gd -93 lines; hunter_loco.gd, glide_lift.gd, pad_flight.gd, lairs.gd, main.gd (`moves.auto_glide`),
`--fsm-check` (table shape + the glider's edges). No Net or save change.
