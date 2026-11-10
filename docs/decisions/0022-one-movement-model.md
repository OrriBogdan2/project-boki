# 0022: One movement model for the farm and the match, as an explicit state machine

- **Status:** accepted
- **Date:** 2026-11-08
- **Area:** movement / farm

## Problem
The farm (`Home._move_player`) and the match (`Hunter._physics`) moved with two controllers: the farm's air WASD was an exponential pull (rate 6/s), the match's `HunterMove.air_steer` was SUPERVIVE's 0.015 AirControl. The owner overruled the low air control (DECISIONS 11-08) and asked for one feel everywhere, a glide that adds no speed, glide drag, and Shift cancelling into the glide.

## Options
1. Copy the farm's numbers into the match: still two code paths that drift.
2. One shared module (`Loco`, scripts/core/locomotion.gd) with all air/glide/dash-ease numbers in content/rules/tuning.json, called by both movers, plus a small explicit state machine (`Fsm`, scripts/core/fsm.gd) both own.

## Decision
Option 2. `Loco.air_step` adds acceleration onto carried velocity (counter-steer x2.5, run cap, drag above it); `Loco.glide_step` bleeds speed over cruise back in ~1.5 s and faster above a per-hunter carry cap; opening the glider adds nothing (the open kick and the swoop are gone; the canopy eases the fall). `Fsm` pattern: one state int, a transition table, guards, enter/exit hooks, a short history; a change the table lacks is refused and counted. Both movers sync `Loco.S` each step from their timers; opening the glider asks the machine first (no glide from the ground, a knock or a stun).

## Consequences
Hunter, Home, GlideLift, GlideDive, HunterMove (air_steer, air_control, air_friction, swoop_* gone), the dash-to-glide handoff boost removed (a press during an air dash now ends it and glides at its speed). Net: no shape change (no VERSION bump). Saves: none. Checks: --air-control-check added; move_feel / airdash_glide / air_limits expectations updated to the owner's ruling. Follow-up (11-09): the farm dashes through `Loco.dash_hv` too, and a jump out of a dash keeps `Loco.dash_jump_keep` in both (was 55% in the match, all of it at home). Debt: Hunter's state still lives in its timers (roll_t, knock_t, gliding...); the machine mirrors it and gates the glider, it does not own every transition yet (docs/DEBT.md). Older numbers still in hunter consts and hunter_move.json move to tuning.json as they are touched.
