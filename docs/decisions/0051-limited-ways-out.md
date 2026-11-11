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
No save change. Check: --heart-check (both seats, every edge of the state table, rush, Net).

## The quest seats (spec task 4)
`QuestSeats` (scripts/match/quest_seats.gd, `Exits.seats`, null outside the mode) owns the schedule from heart.json
"quest"; each seat is one `QuestSeat` machine (quest_seat.gd): LOCKED > OPEN <> IN_USE > TAKEN | SHUT, the same
NEXT / `go()` / `_force()` shape as the Heart. The pick is the match seed's alone (every game makes it): the Sealed
Lair is one of all the lairs (woken if the spawn plan left it asleep), the Uplink the outpost farthest from it, the
other outposts dark. The host polls the lair and outpost it already runs and moves the states; clients mirror
`["xc", "seat", kind, state, team, out]` (Net.VERSION 0.25.3). What a state does to the world each game does itself:
a LOCKED lair keeps its gate shut (a crack before 2:00 is remembered and opens it at 2:00); the boss killer's squad
TAKEs it and leaves (`how` "lair") when one of it steps into the updraft or the victory lock ends, its downed in the
lair too, rivals not; unused at 5:30 its gate seals again. The Uplink starts only 6:00-8:00, its lift carries the
finishing squad alone (and their downed in the yard), then it is "closed"; a charge still running at 8:00 is SHUT.
Not done here: late joiners get the seat state only on its next change; the HUD strip, the map marks and the bots'
seat plans are the later tasks. Checks: --lair-lock-check section 5, --extract-check section 3d
(tools/uplink_seat_check.gd).

## One seat per squad (OneSeat)
`OneSeat` (scripts/match/one_seat.gd, `Exits.one_seat`) is the rule's one home. Each seat, in every game, calls
`taken(how, team, where, col, at, reach)` when it fires (Heart `_leave`, the lair's `_leave_lair`, the Uplink's first
TAKEN): it marks the squad used and puts each of this game's own living members not in the seat on a `late_s` clock
(heart.json, 20 s). `tick` extracts one who `reach`es the seat in time (the seat's own reward), and sends home one who
does not: gems, seeds and caught Boki dropped, `out` + `gone`, the result "left behind"; their Boki is never lost. A
used squad is refused every other seat (`spent`: Heartspark pick, ring crew, Uplink start, prompts). No new Net message
(each game handles its own Hunters from the seat events it already gets). The HUD draws the countdown through
`HeartHud.world_labels`. Not done: bots left behind are not steered to the seat; the lair race is not blocked while
the grace runs (a boss fight cannot end in 20 s); the final ring's islands fall 15 s after it is taken, so the grace is
15 s there in practice. Check: --extract-check section 3e (tools/one_seat_check.gd).
