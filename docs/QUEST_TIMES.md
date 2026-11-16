# Quest seat times (Limited Ways Out, 0051)

Measured 2026-11-12 on origin/main 53e2fe7f3 with `--quest-race-sim` (tools/quest_race_sim.gd): seeds 1-10, 10 squads of 3
(30 hunters, tier 1, `autoplay` bots, a real 12:00 match), headless; each match stops once both seats are TAKEN or SHUT.
Three runs of the same ten seeds (A, B, C = 30 matches). The seed fixes the map, the Lair and the Uplink; the bots roll
the global `randf()` (bot.gd), so one seed does not replay the same match: the runs differ, which is why there are three.

Target (0051): Sealed Lair open 2:00, shut 5:30; Uplink open 6:00, shut 8:00. A finish is "in target" if the seat is
TAKEN before it shuts. 0051 names no share of matches that should finish, or how long a finish may take; see Proposal.

## Before (nothing changed: the knobs below were left alone)
| seat | run | engaged | taken | shut unused/unfinished | mean engage (s) | taken at (s) | squads near (mean) |
|---|---|---|---|---|---|---|---|
| Lair (open 120) | A | 0 | 0 | 10 | - | - | 1.3 |
| Lair | B | 4 | 2 | 8 | 193 | 237, 193 | 1.4 |
| Lair | C | 2 | 2 | 8 | 200 | 214, 232 | 0.8 |
| Uplink (open 360) | A | 3 | 2 | 8 | 395 | 477, 437 | 0.9 |
| Uplink | B | 1 | 1 | 9 | 371 | 426 | 0.7 |
| Uplink | C | 3 | 2 | 8 | 399 | 464, 425 | 0.7 |

All 30: Lair taken 4 (mean 219 s = 3:39, all inside 2:00-5:30), first engaged 6 (mean 195 s, 75 s after it opened).
Uplink taken 5 (mean 446 s = 7:26, all inside 6:00-8:00, one at 7:57), first engaged 7 (mean 393 s, 33 s after it opened).
Both seats opened exactly on the clock in all 30 matches. No refused state edge. Stalled (shut with no finish): Lair 26 of 30,
Uplink 25 of 30; an engaged seat falling back to OPEN (a lost fight, a drained yard) happened 1-2 times in a few matches.
Squads contesting: at most 3 ever came within 30 m while it was open, usually 0-1.
Lair entry kinds of the picked lair (seed): dial only (4, 7, 10), dial + runes (2, 3, 5, 8, 9), dial + wards (1, 6).

## What the numbers say
The windows are not too short: every finish that happens lands well inside them. The seats are not being tried: a squad
engaged the Lair in 6 of 30 matches and the Uplink in 7 of 30, and one squad at a time at most. Bots reach the seats only as
side effects of the old goals (boss hunt 12-57% of bots, "yard" when an outpost is theirs); the seat plans written into
`content/rules/heart.json` "bots" (raider, runner, holder, stayer, seat_delay_s, ...) are read by no code (spec task 7 is
not built), nor are `quest.lair_fight_max_s`, `uplink_hold_s`, `uplink_steal_s` or `uplink_lift_s` (the Uplink's 40 s hold is
`Exits.UPLINK_T`, the Lair's 90 s fight `Lairs.LOCK_T`).

## After
Unchanged. The only live data knobs that move a finish are the four window times, which are the owner's numbers and the
target itself; nothing the bots read (their plan weights, the hold times) is a data knob today. Widening the windows to hide
low engagement would break 0051, so none of them were touched. Alternative considered: make every lair dial-only in the maps
(runes and wards slow a bot down). Not done: it changes the lairs in every mode, and the data does not show it helps (the
dial-only Lairs of seeds 4 and 10 were never engaged; seeds 3 and 7 were taken, one dial + runes, one dial only).

## Proposal (owner decides)
1. Target to add to 0051: in a trio match of 10 squads, each quest seat is taken in at least 6 of 10 matches, the Lair by
   4:30 and the Uplink by 7:30 (a finish inside the last 30 s before shut is a near miss, not a pass).
2. To get there, build the bot seat plans (spec task 7) so `heart.json` "bots" is read; then re-run `--quest-race-sim` and
   tune `bots.seat_delay_s`, the plan weights and `raider_at_s` / `runner_at_s`, which are data.
3. Make bot rolls seedable (bot.gd `randf()`), so one seed replays and before/after tables are comparable with one run.

Run: `XDG_DATA_HOME=<tmp> godot --headless --path . -- --quest-race-sim [--seeds=1,2,3] [--teams=10] [--squad=3] [--tier=1]`
(about 3-4 minutes a seed; run seeds in parallel processes).
