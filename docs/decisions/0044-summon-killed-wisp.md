# 0044: A killed summon turns back into a wisp

- **Status:** accepted (prototype, behind the boki_wisps setting)
- **Date:** 2026-11-09
- **Area:** match flow, networking

## Problem
DECISIONS 2026-11-09: damage does not end a summon, killing the Boki does, and the killed summon turns back into a
wisp. Owner's lean: it is stealable only if its owner is down or dead, else it flies home and briefly shows where
its owner is. WISP_DESIGN_OPEN.md Q5/Q8 give the numbers.

## Options
1. A killed summon is stealable wherever its owner is. Harsher; the Boki becomes a liability.
2. Stealable only while its owner is downed or dead; otherwise it flies home and reveals the owner. Monsters'
   kills just send it home (no reveal, plain cooldown).

## Decision
Option 2, in `KinSummon.killed(by)` (replaces the old `knocked()`; `Kin.go_down` passes the killer through).
- Rival hunter kill (the hunter or a rival's Boki): cooldown x `killed_cd_mult` 1.25; owner standing: the wisp
  streaks home at `home_speed` 25 m/s and the owner is revealed `reveal_s` 2 s (Hunter.reveal_t, which rides the
  hunter snapshot) plus a minimap ping for the killer's squad; owner downed or dead: `KinSteal.break_loose` where it fell.
- Monster, fall or no killer: plain cooldown, goes home even if the owner is down (`back_home`), no reveal.
- A thief's stolen summon killed: loose again where it fell, anyone may grab it.
Damage alone never ends the window (unchanged).

## Consequences
- Net.VERSION 0.31.0: kcmd "wkill" (owner's id, extra = the killer's team) pings that squad's minimap; the wisp
  form already rides the kin snapshot. The flight streak draws only in the owner's game (a rival sees the wisp
  already on its owner), the ping and outline are the rival's cue.
- hud.gd: a sound ping may carry its own `life` (the "wisp" kind lasts 2 s). `--summon-death-check` covers it.
