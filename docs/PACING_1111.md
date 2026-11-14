# Real-paced expedition clock, 11-11 (the "not judged with real pacing" item of docs/FUN_AUDIT_1111.md)

Five full bot-only matches on The Hollow Crown, 10 squads of 3 (30 bots; the player's squad on autoplay), seeds 1 to 5, stepped at the
game's own 1/60 s rate with no shortcuts (real drop, real waits, no granted levels, no instant uplink) to the island fall at 12:00 or the
last Hunter out. Tool: `godot --headless --path . -- --pacing-sim --seed=N` (tools/pacing_sim.gd, reads the match and changes nothing;
tools/pacing_report.py prints the tables below). Logs (the PACE lines of each run): docs/pacing_1111/seed1..5.log. All times are match
time m:ss from the drop. Built on `origin/ext/release-integ-0245` 272368589 (see "What the tree has").

## What the tree has (read this first)
`origin/main` (0.24.4) has no Ways Out at all (no heart.gd, no heart.json), and `origin/ext/early-camps-0244` has the camp and XP rules
but no Ways Out; the two lineages conflict in match.gd, net.gd and hollowcrown.json, so no tree has both. This run is on the 0.24.5
integration tree (Ways Out: lair seat 2:00-5:30, Heart early seat from 4:00, Uplink 6:00-8:00, Heart final 10:00), which still has the
**old XP rules**: a 1.2 XP/s trickle (hunter.gd:1923), XP for damage (match.gd:1768: 0.35 per mob damage, 0.6 per Hunter damage),
90 per knock, 260 from a lair boss (lairs.gd:730), and the old XP_TO curve (70, 170, 300 ...). The DECISIONS rule "XP from kills only,
no trickle" (briefs/DECISIONS.md 2026-11-10 1:20 PM) and the early-camps pace table (briefs/specs/EARLY_CAMPS_DROP.md 2.5 and 6.2,
last-hit XP, sized camps) are therefore **not in the game being measured**; the level columns below are the old rules against that
table. Branch note: the task said branch from origin/main; that tree cannot be measured for Heart seats, so this is on the 0.24.5 tree.

## The clock (all five runs)
| run | landed (first-last) | first damage after landing (median/worst) | first knock | first camp clear | 5th | camps cleared | L2 | L3 | L4 | L6 |
|---|---|---|---|---|---|---|---|---|---|---|
| seed1 | 0:17-0:30 | 2 s / 24 s | 0:32 | 0:21 | 0:42 | 10/19 | 0:20 | 0:35 | 0:42 | 1:11 |
| seed2 | 0:14-0:30 | 2 s / 13 s | 0:39 | 0:26 | 0:42 | 12/19 | 0:25 | 0:35 | 0:49 | 1:51 |
| seed3 | 0:14-0:30 | 2 s / 58 s | 0:28 | 0:26 | 0:44 | 13/19 | 0:26 | 0:33 | 0:39 | 0:55 |
| seed4 | 0:13-0:30 | 5 s / 13 s | 0:33 | 0:19 | 0:37 | 12/19 | 0:27 | 0:33 | 0:47 | 1:32 |
| seed5 | 0:15-0:30 | 1 s / 7 s | 0:40 | 0:25 | 0:39 | 16/19 | 0:21 | 0:25 | 0:47 | 1:29 |

| run | squads' mean level at 2:00 (min/med/max, squads still in) | 4:00 | 5:15 | 8:00 | 10:00 |
|---|---|---|---|---|---|
| seed1 | 3.7 / 5.0 / 5.3 | 7.0 / 7.0 / 7.0 | 7.3 / 7.3 / 7.3 | 8.7 / 9.0 / 9.3 | 9.0 / 9.0 / 9.0 |
| seed2 | 3.3 / 4.2 / 5.7 | 6.0 / 6.3 / 7.3 | 7.0 / 7.0 / 8.3 | 8.0 / 9.0 / 9.0 | 9.3 / 9.3 / 9.3 |
| seed3 | 2.7 / 4.0 / 6.0 | 7.0 / 8.0 / 8.0 | 7.7 / 8.0 / 8.3 | 8.3 / 9.0 / 9.3 | 8.3 / 9.3 / 9.7 |
| seed4 | 3.7 / 4.7 / 5.7 | 6.3 / 7.0 / 7.7 | 7.0 / 7.5 / 8.0 | 8.7 / 8.8 / 9.0 | 9.0 / 9.3 / 9.7 |
| seed5 | 3.3 / 4.0 / 5.3 | 5.3 / 6.0 / 6.7 | 5.3 / 6.3 / 7.3 | 6.7 / 8.2 / 9.7 | 6.7 / 8.3 / 10.0 |

| run | tide radius m at 2:00 / 4:00 / 6:00 / 8:00 / 10:00 | lair gate opens | boss awake | boss dies | Heart wakes | spark charged | Heart final | squads left <=5 / <=3 / 1 | ended |
|---|---|---|---|---|---|---|---|---|---|
| seed1 | 176 / 144 / 112 / 80 / 48 | 1:17 | 1:18 | 2:03 | 4:00 | 5:15 | 9:19 | 1:38 / 2:07 / 9:19 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| seed2 | 176 / 144 / 112 / 80 / 48 | 1:35 | 1:37 | 2:49 | 4:00 | 5:15 | 10:00 | 2:51 / 4:38 / 12:00 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| seed3 | 176 / 144 / 112 / 80 / 48 | 2:03 | 2:04 | 2:46 | 4:00 | 5:15 | 10:00 | 3:38 / 3:47 / 12:00 | t 720.5 result { "extracted": false, "why": "finished", "ending": true |
| seed4 | 176 / 144 / 112 / 80 / 48 | 1:11 | 1:16 | 1:55 | 4:00 | 5:15 | 10:00 | 1:46 / 2:41 / 12:00 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |
| seed5 | 176 / 144 / 112 / 80 / 48 | 3:16 | - | - | 4:00 | 5:15 | 10:00 | 1:54 / 7:24 / 12:00 | t 720.5 result { "extracted": false, "why": "team wiped", "ending": tr |

- seed1 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 6:29 IN_USE 6:34 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 9:19 READY>FINAL
- seed2 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- seed3 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- seed4 extractions: none; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 8:00 SHUT; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL
- seed5 extractions: 7:40 b29 t9, 7:41 b28 t9, 7:44 b27 t9; Sealed Lair seat 2:00 OPEN 5:30 SHUT; Uplink seat 6:00 OPEN 7:14 IN_USE 7:40 TAKEN; Heart 4:00 ASLEEP>CHARGING 5:15 CHARGING>READY 10:00 READY>FINAL

Camps: 19 live camps a run (the match rolls which of the map's camp spots are live). Cleared by 2:00 / 4:00 / 6:00: seed1 8/10/10,
seed2 10/11/12, seed3 13/13/13, seed4 11/12/12, seed5 9/15/16. So the camps are gone by about 2:00 and the Blight does not move
anyone to them later. Knocks per run 30-51; squads left at the end 2 (seeds 2-5), 1 (seed 1, stood alone from 9:19), 0 at 12:00 in all.
Heart: wakes 4:00 and the spark is charged 5:15 in every run (75 s charge), then it lies READY to the end: nobody carried it.
Heart final opens 10:00 (seed 1: 9:19, last squad). The Sealed Lair seat opens at 2:00 and its boss died at 1:55-2:49 in four runs
(awake at 1:16-2:04), so the seat opens on a lair already cleared or a minute from it, and nobody took it. The Uplink was used once (seed 5,
3 Hunters, 7:40). Extractions per run: 0, 0, 0, 0, 3 (of 30). The tide ring (Heart.tide_r) closes continuously 1:30 to 10:00, 176 m at
2:00 and 48 m at 10:00 on this map; it is not five beats.
`--bot-sanity-check`: 1 flagged window in two runs (run 1 seed 3 bot at lair_dial, 46 facing flips; run 2 seed 5 bot on roam, 22 flips),
rc=1 both times, logs docs/pacing_1111/bot_sanity_run*.log. GATE_0245 lists bot-sanity as green, no game code changed here, and the
flag moved between seeds, so it is flaky on this tree and not caused by this branch. The same seed gave different clocks across my
test runs (seed 4: last squad at 6:51 once, 12:00 in the final run), so a run is not exactly replayable; read the five as a spread.

## Against the pace table (briefs/specs/EARLY_CAMPS_DROP.md 2.5 / 6.2, XP model in briefs/DECISIONS.md)
Spec: pace level L3 at 1:45, L4 at 2:45, L5 4:00, L6 (ultimate) 5:15, L7 6:40, L8 8:10, L9 10:00; "nobody has an ultimate before 2:30";
the hot-zone winner is one to two levels up at 4:00, never three; first Small Camp = level 2; at least 85% of XP before 2:30 is camps.

| | spec (mid drop / hot zone) | measured (median squad of those still in, five runs) |
|---|---|---|
| landed to first damage | not specified | 1-5 s median, worst squad 7-58 s |
| first level-up (L2) | first Small Camp, level 2 | 0:20-0:27, 1-2 s after the first camp clear |
| first camp clear | | 0:19-0:26; 5th at 0:37-0:44 |
| first L4 / first L6 (ultimate) | L4 at 2:45 / ultimate not before 2:30, 5:15 on pace | L4 0:39-0:49, L6 0:55-1:51 (one Hunter, not a squad mean) |
| squad level at 2:00 | L4 / L5 | 4.0-5.0 (range 2.7-6.0): on the spec |
| squad level at 4:00 | L5 / L6-7 | 6.0-8.0 (max 8.0): at or over the hot-zone winner |
| squad level at 5:15 | L6 / L7 | 6.3-8.0 |
| squad level at 8:00 / 10:00 | L7-8 / L8-9 | 8.2-9.0 / 8.3-9.3 |
| first knock | "before 2:30 at least 85% of XP is camps" | 0:28-0:40, as the last squad lands (0:30) |
| lair boss | Sealed Lair 2:00, "300 XP, no steals once the gate seals" | dead 1:55-2:49 (4 of 5 runs); the 5th never |
| Heart wake / spark / final | 4:00 / 5:15 / 10:00 | 4:00 / 5:15 / 10:00 (exact) |
| Blight | five beats 2:00-10:00 (EARLY_CAMPS) | one continuous tide, 184 m at 1:30 to 48 m at 10:00 |
| last squad | the squeeze to the end | 1 squad stood in only 1 of 5; the rest end with 2 squads on the island fall |

## The three biggest gaps
1. **The match is played out by about 2:30, not by 12:00.** Bots land (0:13-0:30), hit something within 5 s, knock Hunters from 0:28,
   clear 8-13 of 19 camps by 2:00 and have half the squads eliminated by 1:38-3:38 (squads left <= 5), and the lair boss is dead by
   1:55-2:49, around the time its own seat opens at 2:00. The pace table assumes camps carry the first 4 minutes; here they are done in 2.
   Squads that survive are L6-8 at 4:00 and L8-9 by 8:00: one to two levels over the table from 4:00 on, with the ultimate (first L6 at
   0:55-1:51) 3-4 minutes before the 5:15 target. Cause on this tree: the old XP rules (trickle + damage XP + 90 per knock), which the
   DECISIONS entry removes; the early-camps branch with those rules is not merged with Ways Out, so the two have never been run together.
2. **The ways out are never used, so the squeeze, the Heartspark race and the last-squad finish are unmeasured.** 4 of 5 matches
   end with zero extractions and the fifth with 3 of 30. The Heartspark is READY from 5:15 and never carried (the early seat is taken
   by nobody in five runs); the Sealed Lair seat opens on a lair already (nearly) cleared; the Heart final opens at 10:00 and nobody leaves; seeds
   2-5 reach the island fall with two squads alive. Bots do not have a working Ways Out plan (or the seats are unreachable for them), so the
   expedition clock after 5:00 is empty: the only thing playing it is the tide. This blocks reading the 6:00-12:00 pacing at all.
3. **The Blight's closes are a slow ring that does not push anyone.** The spec's pacing hangs on five beats (2:00, 4:00, 6:00, 8:00,
   10:00) that move squads into fights; the tree has one continuous tide from 1:30 (176 m at 2:00, 144 m at 4:00, 112 m at 6:00, 80 m at
   8:00, 48 m at 10:00). With the camps gone and the fights over by 2:30 (gap 1) the ring is the only mid-game pressure, and with
   bots never taking a seat (gap 2) it ends matches by attrition at 12:00 ("team wiped" or islands fall) rather than at a place and time.

Not covered: human pacing (bots land on camps and fight at once; a human reads the map, so gap 1 is an upper bound on speed), a hot zone
versus a quiet rim split (the table has rows per drop; the logs have per-squad levels but not the squads' drop regions), and the
camp-XP bend (catch-up) which is not in this tree. Alternatives not taken: merging early-camps-0244 into the 0.24.5 tree to measure
both rule sets together (three conflicting files, an integrator's job); adding probes to match.gd (task: no game code change).
