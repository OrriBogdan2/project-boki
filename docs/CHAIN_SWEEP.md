# Chain sweep (11-11 states)

`--chain-sweep-check` (advisory, `tools/chain_sweep_check.gd`; `=archer,gunslinger` picks heroes) walks DECISIONS "every
interaction is chainable": for a light (Lace), medium (Vex) and heavy (Albert) Hunter, in each movement state, it presses
dash, jump, glide, wall kick, mantle, LMB and E on the next step, with a player's keys (`glide_press_only`), and asserts the
move starts within 1 s (a start later than 2 steps is printed as buffered, with its delay) or that a documented rule in the
check's `REFUSE` table refuses it. States: ground, air, glide, ground dash, air dash, rocket free fall, glide ring, lift
ring, Ice Sheet, Deep Water. Wall actions use a carved 1.6 m wall; ring and field states run on the Hollow Crown (seed 5).
A press that does not go off on plain ground in the fixture is `n/a` for that hero.

Result on the merged line (origin/main 0.24.4 + region-hazards-1111 (0.24.5 train) + feel-rocket-fall + air-rings-1111):
0 failures, 33 refusals by a documented rule, 27 n/a (wall actions on the ground and in lanes/sky).
Ice (grip 0.12) and Deep Water (speed 0.55) change how far you move, never whether a press starts.

## Bug found and fixed
- **A dash pressed during a longer dash was lost.** `Hunter.do_dash` buffered it for `DASH_BUFFER` (0.18 s) from the
  press, so a dash with more than 0.18 s left (Lace's 0.35 s skid, Vex's slide) dropped the second press: dash, dash
  did nothing (the first sweep: Lace and Vex dash-in-dash red on ground and air; Albert's 0.17 s dash was fine). The
  buffer is now `DASH_BUFFER + min(dash left, DASH_KEEP 0.5 s)`: kept to the dash's end, then a hair longer. A longer
  lock (Gil's X, 0.97 s, DashFlow row `lock`) still drops the press (--dash-flow-check gil: a flat 0.5 s buffer or an
  uncapped one broke that row). hunter.gd +2 lines (one const, one changed).

## Rule questions for the owner (nothing changed)
1. **LMB while gliding does nothing** (`Hunter.can_fire`: `gliding`). Source-faithful, but "every interaction is
   chainable"; shooting off the glider would need the glider to fold or a rule that it stays open.
2. **Rocket free fall allows no dash, LMB or E** (`ArchKit.locked`: `dropping`); only Space or the glide key (pulls the
   glider) work. Same question for the glider part of the drop. Wall kick is refused there by design (`WallMoves.try_kick`).
3. **Glide on the ground is refused** (a Space press is the jump). Per decision "Space held never opens the glider"; kept.
4. A second dash spends the EX dash (Lace/Vex have one charge): chaining dash, dash is now possible but costs its cooldown.
