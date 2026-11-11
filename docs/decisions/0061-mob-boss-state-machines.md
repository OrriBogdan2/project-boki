# 0061: Monsters and lair bosses on one explicit state each

- **Status:** accepted
- **Date:** 2026-11-11
- **Area:** combat

## Problem
DECISIONS 2026-11-08 (one explicit state per machine; briefs/STATE_MACHINES.md M9). `Mob` ran on a free string `st` plus an `st_t` countdown that five other files wrote (lairs, exits, blight_dir, match.gd's snapshot, checks); a stun cut a wind-up only through an if in `sim`, and a stunned chaser could still start one (its tell flashed for a step, then was cancelled). `Boss` ran on `dormant`, `atk != ""` and the stun timers: a plain stun paused an attack while its tells kept filling, so a blow could land after its tell was gone.

## Options
1. One `Fsm` (scripts/core/fsm.gd) per monster with states idle, notice, chase, windup, attack, recover, stunned, return, owned by Mob; the boss on the same states with its own table. `st`/`st_t` stay as read-only views in the old five names.
2. Keep `st` writable and mirror it into an Fsm each step. Rejected: a mirror reports an illegal combo only after it happened (STATE_MACHINES 1.1).

## Decision
Option 1. Only Mob and its subclasses move the machine (`_go`, `_stun`); other files ask with `aggro(t, why)`, `calm(why)`, `Boss.wake(why)` and `Boss.fall_asleep(why)`. ATTACK is only reachable from WINDUP, so the tell always leads the hit. A stun moves any fighting state to STUNNED and cuts the wind-up or blow, tells and all. The guard on WINDUP refuses a wind-up while stunned. The hold times are the old ones: a cut wind-up 0.4 s (CUT_HOLD), a wall knock 1.0 s, a stagger 2.2/3 s, or what was left of a recovery. Wind-ups stay data (`md.windup`, each boss attack's own). The bosses' thrown boulders and globs keep their landing tells through a cut.

## Consequences
mob.gd, boss.gd, blight.gd, shrubling.gd (they share the machine), lairs.gd, exits.gd, blight_dir.gd and match.gd (two wiring lines fewer). No Net change: the snapshot still carries the `MOB_STATES` index of the look (NOTICE shows as chase, ATTACK as lunge, STUNNED as recover, RETURN as idle) and proxies take it through `Mob.follow`. A boss stunned mid-attack now loses the rest of that attack instead of resuming it, and one stunned as it crosses a phase line still roars and shoves but skips that phase's rockfall. The F7 readout shows the machine of the monster you last hit (`Mob.readout`). New check: `--mob-fsm-check`. The animation hooks of ext/anim-mob-states and ext/anim-boss-states read `st`, `st_t`, `atk`, `atk_t`, `dormant` and `awake_t`, which all keep their meaning.
