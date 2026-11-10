# 0051: Limited Ways Out (the Heart's two seats)

- **Status:** accepted (owner DECISIONS 2026-11-10 "LIMITED WAY OUTS, one mode"; spec briefs/specs/LIMITED_WAY_OUTS.md)
- **Date:** 2026-11-10
- **Area:** match flow / networking

## Problem
Open extraction lets every squad leave, so nothing is at stake at the end. The owner wants one mode with four
seats out, one squad each, each used once: Sealed Lair (2:00-5:30), Heart early (4:00 on, MINOR), Uplink
(6:00-8:00), Heart final (10:00, MAJOR, last squad standing). 12:00 match. This note covers the numbers and the
Heart's two seats (spec tasks 1-2); the quest seats, deleting docks/hatches/keys, results, map, bots and UI follow.

## Options
1. Keep the 0023 loop (cooldown, one carrier out per spark, several per match) and add a final ring next to it.
   Rejected: unlimited Heart exits, and two machines over one Heart.
2. One state enum on `Heart`: ASLEEP > CHARGING > READY <> CARRIED > WAITING > FINAL > DONE (any pre-final state
   jumps to FINAL at 10:00 or when one squad is left). The Gate takes the carrier's squad within 8 m; the ring
   fills for a squad alone (Exits.crew_rate), stalls with a standing rival, drains when empty.
3. A boss at the Heart for the final. Rejected (spec section 2: perf with 5-8 squads on one island).

## Decision
Option 2. Every time, window, reward, placement pay and bot knob is in content/rules/heart.json (no second rules
file); `Data.MATCH.length` is gone, the match reads `match_s` (720, no 1.7 big-map factor). The enum follows
briefs/STATE_MACHINES.md: a `NEXT` table, only `go()` moves the state (refusals counted and logged), the host owns
it; `_force()` is the client mirror and the demo. An early seat nobody used by 10:00 stays open in FINAL
(`early_team < 0`), so the spark is sub-state data (`carrier`) there, not a second machine. `Fsm` (ext/movement-unify)
is not on main; the table is local and moves to `Fsm` once that merges.

## Consequences
heart.gd rewritten (cooldown loop deleted), heart_hud.gd reads the enum, match.gd wiring only (+1 net line:
`heart.on_last_team()`). `how` is `heart_early` / `heart_final`. Net.VERSION 0.25.2: "ht" "s" carries the state
int, early/final squads, ring progress and rush; new "ht" "take" (each game takes its own Hunters of that squad).
No save change. Checks: --heart-check (early seat), new --heart-seats-check (squad take, final, order, rush, Net).

## Seat looks (ext/vfx-ways-out-seats)
Every seat reads from across the island with one of five looks: locked (dim stub, countdown glyph), open (tall clear
beam in neutral light), in use (the using squad's colour, ring filling with the hold), taken (the beam sinks in 0.7 s,
the seat goes dark), lost (low dark haze: the tide covers it or its window shut). `WaysOutLook` maps a seat's own state
to a look (Heart gate and ring, a lair's updraft, an outpost's uplink); `SeatBeacon` draws it (one column shader
`seat_beam.gdshader`, one ring, one glyph, two materials made once); `WaysOutVfx` owns the beacons. No bursts and no
rings on a change. The quest seats read optional `seat_open` (lair) / `open_at` (outpost) and `shut_at` times and the
outpost's `taken` flag; spec task 4 sets them. Check: --ways-out-vfx-check; shots: --ways-out-vfx-shots (GPU).
