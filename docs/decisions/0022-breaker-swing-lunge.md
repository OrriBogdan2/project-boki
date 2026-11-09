# 0022: Breaker's swing lunge, boop, rope and Faultline hop

- **Status:** accepted
- **Date:** 2026-11-09
- **Area:** combat (Albert the Barnacle Knight, `bulwark`)

## Problem
Owner 11-09 feel brief for Albert: the swings felt stuck in place, the aegis gave LMB nothing to do, the
thrown hammer could be left anywhere forever, and the Faultline's plant-and-raise read as weightless. The
model also read too big next to the other heroes.

## Options
1. Lunge as a fixed step after the swing (the old `carry`, 1.5-1.8 m). Same distance standing or running,
   so a running swing slowed him down.
2. Lunge as a short dash along the aim whose speed is the pull plus his current run along the aim (capped
   at run speed). Running swings go further; standing ones land on the data distance because the dash's
   exit slide is taken off the pull.
3. Boop as a separate hitbox in front of him, or as a move of the aegis wall itself.
4. Rope as a fixed timer only, or a distance and a timer.

## Decision
- Option 2 (`BjornLunge`, `lmb.lunge`): a part charge pulls 1.4 m, a full charge (the finisher) 2.4 m, the
  360 Smash's spin 1.6 m; in the air 55% and he leaves the air lunge at the speed he came in with (in the
  air nothing brakes a dash's exit). The combo/finisher split maps to part/full charge, as Breaker has no
  hit chain. A swing let go inside a dash rides the dash and only measures.
- The boop moves the aegis wall itself (`BjornBoop`, `rmb.shield.boop`), so the block and the look go out
  together; it shoves 2.8 m and does no damage (it makes room, the Crushing Blow stays the damage).
- The rope reels the hammer home past 14 m or after 6 s (`lmb.rope`); the throw stays shut till the catch.
- Faultline: the 0.4 s wind-up is a 1.2 m hop (`x.leap_h`) and the 0.2 s plant keeps its place; the lane is
  5.5 m wide (+22%), one value for the telegraph and the hits. The impact gets hit-stop, a shake for the
  players round it (never his own screen: owner #50), dust, rock debris, a crack decal and a low quake.
- `body.size` 2.0 -> 1.8; `body.hit_r` stays 0.46 so the smaller look is not a smaller target.

## Consequences
- New: `scripts/arch/kits/bjorn_lunge.gd`, `bjorn_boop.gd`; three sounds from `tools/gen_sfx_breaker.py`;
  `shield_boop` and a reworked `x_wind` in the Breaker GLB (`tools/art1/breaker_anims.py`).
- The hop's drive down uses `ArchKit.dive_speed()` to pass the 12 m/s fall cap for its last 0.08 s.
- Checks: `tools/albert_feel_check.gd` (from `--bulwark-combo-check`); `#49`'s step range and the "never
  comes back by itself" check were updated to the new behaviour.
- Net.VERSION bump: no. The lunge is a dash and the hop is velocity (both already in the snapshot); the
  boop's thrust is local only and its anim id is shared like every kit move.
