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
   fills for a squad alone (Exits.crew_rate), stalls with a standing rival, drains when empty; downed Hunters neither hold nor stall it, and with no holder standing in it a squad
   alone in it takes it over from nothing (spec risk 4: no beaten squad stalls the final to 12:00).
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
No save change. Check: --heart-check (both seats, every edge of the state table, rush, Net), --ways-out-map-check (map sites).

Map (spec task 6, section 8): each map authors `"heart": [x, z]` (the Throne / vault crown) and two uplink
outposts; the 305 m Hollow Crown also carries `"ways_scale": 1.412` (SIZE / 216), which stretches the tide radii,
gate_dist and the map bands (heart.json "map"), never times. Heart.setup puts the Heart on that site and seeds the
Gate angle among spots gate_clear from both outposts. tools/ways_out_sites.py (both generators) and
--ways-out-map-check enforce the bands from the same heart.json numbers.

Task 3 (open extraction gone): skiff docks, rift hatches and Rift Keys are deleted from the code, the maps and
both generators; `Exits` is uplink outposts only and `MATCH.portal_open` is gone. Net.VERSION 0.24.5 (0.25.3 on the branch) (the exit
list and its "xc" index are outposts only; no "key" pickup). Save: the v5 migration that refunds market Rift Keys
as gems stays; a live h.rift_keys never reached the save. Outposts stay as they are (the tutorial's uplink step)
until task 4 reworks them; alternative considered: switch off non-tutorial outposts now. --extract-check keeps
only its uplink sections.

UI (spec task 8, first part): scripts/ui/ways_out_hud.gd draws the Ways Out strip (four pips) top centre
and the carrier's Heart Gate prompt; `Exits.clock_line` is deleted. The Lair and Uplink pips read the lairs and
outposts and the "quest" times in heart.json until task 4 gives Exits its own seat states. Checks:
--ways-out-hud-check, --ways-out-hud-shots (GPU). Not built yet: the dead/watching line, banner calls, map icons.

## The quest seats (spec task 4)
`QuestSeats` (scripts/match/quest_seats.gd, `Exits.seats`, null outside the mode) owns the schedule from heart.json
"quest"; each seat is one `QuestSeat` machine (quest_seat.gd): LOCKED > OPEN <> IN_USE > TAKEN | SHUT, the same
NEXT / `go()` / `_force()` shape as the Heart. The pick is the match seed's alone (every game makes it): the Sealed
Lair is one of all the lairs (woken if the spawn plan left it asleep), the Uplink the outpost farthest from it, the
other outposts dark. The host polls the lair and outpost it already runs and moves the states; clients mirror
`["xc", "seat", kind, state, team, out]` (Net.VERSION 0.24.5). What a state does to the world each game does itself:
a LOCKED lair keeps its gate shut (a crack before 2:00 is remembered and opens it at 2:00); the boss killer's squad
TAKEs it and leaves (`how` "lair") when one of it steps into the updraft or the victory lock ends, its downed in the
lair too, rivals not; unused at 5:30 its gate seals again. The Uplink starts only 6:00-8:00, its lift carries the
finishing squad alone (and their downed in the yard), then it is "closed"; a charge still running at 8:00 is SHUT.
Not done here: late joiners get the seat state only on its next change; the HUD strip, the map marks and the bots'
seat plans are the later tasks. Checks: --lair-lock-check section 5, --extract-check section 3d
(tools/uplink_seat_check.gd).

## Results (spec task 5)
`WaysResult` (scripts/match/ways_result.gd) owns the results lines: `how` (lair, heart_early, uplink, heart_final) for a
squad that left, `place`/`squads` for one that did not (`Match._finish`; replaces the dead `placed` stub). A squad's place
is 1 + the squads still in or already gone when its last Hunter went out; the islands falling on everyone is a tie; a
squad with a Hunter out the door has a seat, not a place. Placement pay (`heart.json` "place": 5 gems per squad below,
max 40) goes through `Game.apply_result` into `gems`. `KinLoss.resolve`: "nobody took it, or its taker is out" is now
`home` (was `ransom`); results show one line per Boki, "came home" or "held by <name>". No save-shape change, no Net change.
The skiff and hatch lines are gone from the screen (task 3 deletes those exits). Open: `Ransom.lose`'s non-rival branch
is no longer reached from a match.

## Bots (spec task 7)
`BotWays` (scripts/match/bot_ways.gd) gives each squad a plan by the match seed from heart.json "bots" "plans":
raider (the Sealed Lair from `raider_at_s`, in through `Lairs.bot_lair`), runner (at the Heart by `runner_at_s`,
takes the spark with no rival within `runner_rival_r`, carries it to the Gate and holds; squadmates stand within
the Gate's reach), holder (the Uplink from `holder_at_s`, then the existing yard and lift goals) or stayer (loots).
A squad whose seat is taken, shut or capped falls through to the next open early seat, then the final (the Heart
ring, from 20 s before it opens or at once on the last-squad rush); a rival on a squad's own seat is chased (the
carrier) or stood on (the uplink yard). Fairness (risk 5): a bot squad starts a seat `seat_delay_s` after it opens
(the spark: after it is charged) and bot squads hold or take at most min(2, bot squads / 3) of the three early
seats; a squad with a human in it (the player's, on --autoplay too) has neither. Every bot keeps inside the tide
ring: goals are pulled in to ground inside the ring 20 s on, and a bot near the edge drops everything and walks
in. In the mode `Bot._choose` skips the old leave rule (time_left < 170, gems > 40, a random leave); outside it
(tutorial, endless-clock tests) it stays. Checks: --bot-ways-check (plans, cap, delay, fall-through, ring),
--ways-out-sim (whole bot matches, below).

First --ways-out-sim, seeds 1-50, Hollow Crown, 10 trios (the --autoplay player's squad is the human one; 9 bot
squads, cap 2), on 0.24.5 tip 272368589 plus this: squads out 18.2% (91/500, max 3 a match; gate at most 40%: pass);
Sealed Lair used 40% (median 4:40), Uplink 32% (7:20) (gate over 50% each: miss), spark 68% (6:12), final 68% (7:51);
2.08 seats a match, first seat at 5:59 (median); no-winner finals 4/50 = 8% (gate at most 5%: miss: two with two
squads still in at 12:00, one where a Hunter left behind by its squad's Gate seat stood alone); the human squad got
out 6/50; bots never passed the cap. Seat tries over the 50: 41 lair seal-ins, 37 spark pick-ups, 25 uplink starts.
What drives the misses is the pace, not the seat plans: 6 squads are left at 2:00 (median, the spec guesses 9-10)
and 0.3 at 10:00 (the spec 2-4), so 44 of 50 finals open early on the last-squad rush (docs/PACING_1111.md on
ext/verify-expedition-pacing saw the same early wipe with no Ways Out bots). heart.json is not tuned here (task 9).

## The end phase (ext/combat-blight-endgame)
DECISIONS 2026-11-10: everyone without an earned exit plays last team standing as the Blight closes. Measured first
with `--ways-out-sim` (10 trios, Hollow Crown, 0.24.5 + ext/ways-out-sim, seeds 1-10): 9 of 10 matches were down to
one squad before the tide's last close at 10:00 (at 5:54-9:56), so the end played out once (2 squads, settled 13 s
after 10:00); no timeout, nobody apart. To play the end itself, `--final=4` lands 4 squads, jumps the clock to 8:30
and sets each squad down inside the ring: on the held 48 m ring 7 of 10 settled within 90 s of 10:00, 2 timed out
and 3 fell with no winner, one pair stood 62 s apart, 9 Blight downs in the safe ring. Why: bots below The Crown's
raised Heart ground never found its two ramps (the tile path's window was too tight), a Boki keeps reviving its
owner out in the Blight (no bleed while it revives), and Blight mobs fight in the final.

The rule (heart.json `end_*`; `Heart.ring_at`, `tick_dmg`, `end_phase`):
- **Final circle.** At the last close (10:00, as the final seat opens) the Blight closes on from `tide_r1` (48 m,
  The Crown) to `end_r` over `end_close_s`: 28 m round the Heart on the 2x Hollow Crown by 11:00 (0.33 m/s, a
  Hunter runs 13x faster), then holds. 28 m keeps the raised Heart ground, both its ramps (23 m out) and a strip of
  its foot inside, so the way in never lies in the Blight; the 6 m Heart ring is its middle. The spec's 12 m (and
  16 and 25 m) were run: they cut off the ramps or the ground below them and caught bots on their way in. The Heart
  Gate (34 m) goes under at about 10:43: the "leave small" choice ends as the last fight starts.
- **Damage ramp.** Outside, a tick deals the last stage's damage at 10:00 (3 ticks down a medium Hunter), ramping
  to `end_dmg_k` (2x, 2 ticks) by 11:00. In the end phase the Blight also wears down the down health of those it
  downed itself (out in 1-2 ticks); one a rival downed keeps the usual bleed, edge past them or not. Its creatures
  inside the ring burrow and none come up for a squad inside it (BlightDir): the final circle is squad against squad.
- **At zero (12:00)**, squads still in and the final seat not taken: the islands fall on all of them. Both lose: no
  winner, no MAJOR, a tie for place (WaysResult), as LIMITED_WAY_OUTS rev 2 section 6 says. Not sudden death (the
  circle closing to nothing, last one standing wins): the Heart ring picks the winner.
- **Bots.** BotWays drops the spark seat once the Blight closes over the Gate. Heading for the Heart ring or back in
  out of the Blight, `Bot._grid_path` retries a failed tight window (8 tiles) in a wide one (24), so a bot below the
  raised ground finds a ramp; for every goal the wide window had bots turning between detours (--bot-sanity-check).
  No tile path leads farther from the Heart than the ring or the bot itself (`BotWays.path_r`): the wide window had
  bots walking round the cliff out through the Blight. A detour (a goal given up on) is kept inside the ring like
  every other goal (it was random ground: bots roamed out to the edge and back). In the end phase a bot walks in
  from `bots.end_edge_m` (5 m, 7 m on The Crown) inside the edge, not 2 m, so a rival's knock-back leaves it inside.

Result. The first build looked fine on seeds 1-10, but 20 more (`--final=4`, seeds 11-30) had 10 Blight downs of
bots that stood in the ring 5 s before, 2 timeouts and 3 finals over 90 s: bots on a detour out to the edge, a path
round the cliff through the Blight, knock-back at the 28 m edge. With the three bot fixes above, `--final=4` seeds
1-30: 30 of 30 settled within 90 s (4-85 s), no timeout, no no-winner final, longest apart 9 s, no Blight down at
all. Real 10 trios (seeds 1-10): 7 down to one squad before 10:00 (at 7:04-9:55),
3 with 2 squads at 10:00 settled +5, +15 and +19 s; no timeout, longest apart 14 s, one tide down 41 m out in the
Blight (not in the ring), one no-winner (seed 3: the lone squad, the DEBT below). --bot-sanity-check 0 flagged. Left (DEBT): a lone last squad does not
always take the rush final (one real run fell at 12:00 with it on the low ground). Checks: --heart-check (the ring
through the end), --blight-check (the ramp, the downed), --ways-out-map-ui-check (the dashed ring), --bot-ways-check
(the Gate), --ways-out-sim (`WAYS end` lines and sum; the sim does not repeat a match run to run).

## Seat looks (ext/vfx-ways-out-seats)
Every seat reads from across the island with one of five looks: locked (dim stub, countdown glyph), open (tall clear
beam in neutral light), in use (the using squad's colour, ring filling with the hold), taken (the beam sinks in 0.7 s,
the seat goes dark), lost (low dark haze: the tide covers it or its window shut). `WaysOutLook` maps a seat's own state
to a look (Heart gate and ring, a lair's updraft, an outpost's uplink); `SeatBeacon` draws it (one column shader
`seat_beam.gdshader`, one ring, one glyph, two materials made once); `WaysOutVfx` owns the beacons. No bursts and no
rings on a change. The quest seats read optional `seat_open` (lair) / `open_at` (outpost) and `shut_at` times and the
outpost's `taken` flag; spec task 4 sets them. Check: --ways-out-vfx-check; shots: --ways-out-vfx-shots (GPU).

## First-time hints (a new player's first match)
`WaysHints` (scripts/match/ways_hints.gd) gives the three moments that teach the mode one plain line each in the
message lane, the shortened tutorials' hint pattern (Match._tip: once per save in Save.d["tutorial"] as
"ways_<id>", tips setting, no tutorial step, nothing blocks): the Blight's tide first closes, a quest seat first
opens, the Heart wakes. Texts: heart.json "hints". No save-format or Net change. Check: --ways-hints-check.
## Heart reward gap (ext/combat-heart-reward-gap)
Owner 2026-11-10: the early seat pays MINOR, the final seat MAJOR. Code pays exactly heart.json "reward" (`Heart.pay`: gems, seeds,
materials and Boki trust at the exit; the Rare Egg and materials home through `Game.apply_result`). Loot kept and the Boki
outcome are the same for both seats: any Heart exit is an extraction, so the haul and Bokis come home. The results screen
says which seat you took (`how_line`), the reward, and what the other seat would have paid (`WaysResult.other_line`).
Open question (the owner's words give no number): how big is the gap? Current: gems 150 vs 40 (3.75x), seeds and materials 2x to 3x,
the Rare Egg only in major; the old heart.json note said "about 5x". Kept as is; --heart-check holds it between 3x and 5x.
