# Tutorial pace: how long each beat takes a new player

`docs/UI_FIRST15.md` shots were driven by `TutorialDrive`, which reads nothing, never misses and reacts in one frame, so Boki and kills
happened faster than a person plays. This file measures the same path with a human-pace drive. **Re-measured 2026-11-19 on main cb8ae58b30** (the Ways Out
exits, the 20-step course); the one fix made is in section 4.

## 1. How it was measured

`godot --headless --path . -- --tutorial-pace-check` (tool: `tools/tutorial_pace_check.gd`, a subclass of `--new-player-flow-check`).
One fresh save, title to the first finished expedition (back on the farm after the Uplink lift), one run, fixed seed. It is **advisory**: the
flags below print as `PACE FLAG` lines and never fail the check; only a stall in the run fails it.

Human pace is `TutorialDrive.human` (`scripts/match/tutorial_drive.gd`), all named constants:
- **Reading:** every new line on the tutorial panel (its line plus the plain-words line under it) is read at `READ_WPS` 3.5 words/s,
  then `REACT_S` 0.45 s passes before the first input. Nothing is pressed while reading. A line that changes mid-step is read again.
- **Misses:** 30 % of 0.5 s aim windows land 3 m to the side of the monster (`MISS_RATE`, `MISS_OFF`, `MISS_WINDOW`).
- **Walking:** at run speed through the real movement (no sprint, no teleport), jumping ledges as before.
- **Screens outside the match** (title, prologue, hatch, Relic, results, expedition screens): the screen's own wait (animations,
  countdowns) in wall seconds, plus reading every new label on it at the same speed, plus 0.45 s reaction and 0.6 s per click. The
  prologue is watched through (nothing on screen says a key skips it).

Seconds are of three kinds (column **Kind**):
- **sim:** game seconds at human pace (the tutorial course, the drop, the Uplink).
- **wall:** the screen's own animation seconds plus reading and clicks. Headless wall time, so loading and the countdown are as fast as this
  server; a slower machine adds to them.
- **est:** worked out from the game's data, not played: the farm tutorial (hint reading, plus 8 s a walk, 3 s a menu pick, and swings at one
  per unit of the house's cost times `HunterTool.period`), and the walk from the landing to the Uplink (straight line x 1.3 at run speed).

**Idle** = seconds the player has no input and nothing to do: reading text, and waiting on a prompt, an animation, a timer or the Uplink to open.
The **longest wait** is the longest single stretch of idle that was *not* reading (in a screen row: its longest single wait).
Flags: a beat over **45 s**, a wait over **5 s** with nothing to do.

## 2. Result

**1001 s (16.7 min) over 51 beats; 756 s of it idle, of which 383 s is reading and 373 s is waiting.** By part: the front screens (title to the first
Relic) 236 s; the tutorial course 134 s of play (22 rows: 20 steps, the 2 s intro card and the extract), 30 s on its results screen; the farm
tutorial about 148 s (est.); the first expedition 452 s with its screens, 284 s of it the wait for the Uplink to open at 6:00. Every figure is one run
of one seed (the expedition map is fixed at seed 4242), so read a difference of a few seconds as noise. Since the 11-12 run the course dropped 157
to 134 s, and the skiff (call and board 58 s) became the Ways Out Uplink, which the old run did not measure: `_skiff` in
`tools/tutorial_pace_check.gd` was left behind when the flow check's exit became `_ways_out`, so the expedition's exit rows had stopped printing.
They are back (rows 46 to 51).

| # | Beat | Kind | Seconds | Reading s | Idle s | Longest wait s | Flag | Note |
|---|---|---|---|---|---|---|---|---|
| 1 | title | wall | 4.3 | 4.2 | 4.3 | 0.0 |  |  |
| 2 | prologue | wall | 44.3 | 40.9 | 44.3 | 4.0 |  |  |
| 3 | hatch: card and look | wall | 33.8 | 33.7 | 33.8 | 0.0 |  |  |
| 4 | hatch: egg pick and knocks | wall | 34.8 | 24.4 | 34.8 | 10.6 | wait>5 s |  |
| 5 | hatch: its look and naming | wall | 23.8 | 18.7 | 23.8 | 4.8 |  |  |
| 6 | first Relic | wall | 95.2 | 77.5 | 95.2 | 14.2 | >45 s, wait>5 s |  |
| 7 | tutorial match: load | wall | 1.0 | 0.0 | 1.0 | 1.0 |  |  |
| 8 | tutorial: intro card | sim | 2.0 | 2.0 | 2.0 | 0.0 |  | auto-closes; any key sooner |
| 9 | tutorial: land | sim | 3.7 | 2.2 | 3.7 | 1.5 |  |  |
| 10 | tutorial: shoot | sim | 6.8 | 6.7 | 6.8 | 0.0 |  |  |
| 11 | tutorial: points | sim | 3.5 | 3.5 | 3.5 | 0.0 |  |  |
| 12 | tutorial: pick_sec | sim | 9.1 | 9.1 | 9.1 | 0.0 |  |  |
| 13 | tutorial: sec | sim | 4.1 | 2.5 | 2.5 | 0.0 |  |  |
| 14 | tutorial: pick_dash | sim | 5.0 | 5.0 | 5.0 | 0.0 |  |  |
| 15 | tutorial: dash | sim | 3.8 | 1.9 | 1.9 | 0.0 |  |  |
| 16 | tutorial: exdash | sim | 4.5 | 2.2 | 2.2 | 0.0 |  |  |
| 17 | tutorial: glide | sim | 9.7 | 5.6 | 5.6 | 0.0 |  |  |
| 18 | tutorial: wallkick | sim | 6.4 | 5.0 | 5.0 | 0.0 |  |  |
| 19 | tutorial: crouch | sim | 6.0 | 4.5 | 4.5 | 0.0 |  |  |
| 20 | tutorial: gkey | sim | 9.9 | 5.9 | 5.9 | 0.0 |  |  |
| 21 | tutorial: pick_kin | sim | 5.9 | 5.9 | 5.9 | 0.0 |  |  |
| 22 | tutorial: kin | sim | 7.4 | 5.6 | 5.6 | 0.0 |  |  |
| 23 | tutorial: glove | sim | 9.8 | 3.9 | 3.9 | 0.0 |  |  |
| 24 | tutorial: hook | sim | 6.7 | 6.2 | 6.2 | 0.0 |  |  |
| 25 | tutorial: ranks | sim | 6.2 | 6.2 | 6.2 | 0.0 |  |  |
| 26 | tutorial: wayout | sim | 8.9 | 5.9 | 5.9 | 0.0 |  |  |
| 27 | tutorial: uplink | sim | 6.6 | 4.7 | 4.7 | 0.0 |  |  |
| 28 | tutorial: defend | sim | 8.0 | 5.0 | 7.7 | 2.7 |  |  |
| 29 | tutorial: extract | sim | 0.0 | 0.0 | 0.0 | 0.0 |  |  |
| 30 | results | wall | 29.6 | 27.9 | 29.6 | 1.7 |  |  |
| 31 | farm: first arrival | wall | 0.5 | 0.0 | 0.5 | 0.5 |  |  |
| 32 | farm: hob | est | 10.7 | 2.7 | 2.7 | 0.0 |  | 1 walks, 0 menu picks, 0 swings |
| 33 | farm: axe | est | 2.2 | 2.2 | 2.2 | 0.0 |  | 0 walks, 0 menu picks, 0 swings |
| 34 | farm: chop | est | 21.6 | 3.6 | 3.6 | 0.0 |  | 1 walks, 0 menu picks, 10 swings |
| 35 | farm: stone | est | 17.0 | 3.6 | 3.6 | 0.0 |  | 1 walks, 0 menu picks, 6 swings |
| 36 | farm: house | est | 17.0 | 3.0 | 3.0 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 37 | farm: task | est | 6.6 | 3.6 | 3.6 | 0.0 |  | 0 walks, 1 menu picks, 0 swings |
| 38 | farm: feed | est | 16.4 | 2.5 | 2.5 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 39 | farm: crop | est | 17.0 | 3.0 | 3.0 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 40 | farm: buy | est | 14.0 | 3.0 | 3.0 | 0.0 |  | 1 walks, 1 menu picks, 0 swings |
| 41 | farm: sell | est | 14.0 | 3.0 | 3.0 | 0.0 |  | 1 walks, 1 menu picks, 0 swings |
| 42 | farm: expedition | est | 11.3 | 3.3 | 3.3 | 0.0 |  | 1 walks, 0 menu picks, 0 swings |
| 43 | first expedition: start | wall | 14.0 | 13.9 | 14.0 | 0.1 |  |  |
| 44 | first expedition: pre-match countdown | wall | 25.0 | 0.0 | 25.0 | 25.0 | wait>5 s |  |
| 45 | expedition: ship and drop | sim | 21.4 | 0.0 | 16.8 | 16.8 | wait>5 s | on the ship until the jump (17 s), then the fall |
| 46 | expedition: walk to the Uplink | est | 54.1 | 0.0 | 0.0 | 0.0 | >45 s | straight line x 1.3 at run speed 5.3 m/s |
| 47 | expedition: wait for the Uplink to open | sim | 284.4 | 0.0 | 284.4 | 284.4 | >45 s, wait>5 s | opens at 360 s; free to loot or fight meanwhile |
| 48 | expedition: hold the console | sim | 2.5 | 0.0 | 0.0 | 0.0 |  | hold interact 2.5 s (the console takes 1.5 s) |
| 49 | expedition: hold the yard | sim | 39.0 | 0.0 | 0.0 | 0.0 |  | the yard charge (UPLINK_T 40 s alone); waves every 12 s |
| 50 | expedition: the lift | sim | 0.0 | 0.0 | 0.0 | 0.0 |  | stand in the light until it takes you (Exits.LIFT_T 15 s) |
| 51 | first expedition: results | wall | 11.5 | 9.3 | 11.5 | 1.8 |  |  |


## 3. The worst five (by seconds, 2026-11-19)

1. **Wait for the Uplink to open: 284.4 s.** The seat opens at 6:00 (`quest.uplink_open_s`, decision 0051, an owner rule) and a player who
   walks straight there has landed at 21 s and arrives at 75 s. In a real match this is time to loot, fight and take the Lair (2:00 to 5:30). The
   `Exits` line "The uplink comes online in M:SS" already shows what is coming. Not touched: the open time is the owner's rule.
2. **First Relic: 95.2 s** (77.5 s reading, longest single wait 14.2 s). The starter pick, the Relic drifting in, "put it on" (the MaskBeat memory
   cut-scene, skippable only once seen: DECISIONS 11-11), then its page. The longest text in the first hour that has to be read to go on.
3. **Walk to the Uplink: 54.1 s** (est.). Action, not waiting: straight line x 1.3 at run speed 5.3 m/s.
4. **Prologue: 44.3 s** (40.9 s reading and watching). Before this change 37 s of it was one wait with nothing on screen saying a key ends it;
   now the "Hold to skip" hint shows by itself after 4 s (section 4). The seconds are the story's and are unchanged.
5. **Hold the yard: 39.0 s.** The charge (`Exits.UPLINK_T` 40 s alone). Action: a wave every 12 s to fight, rivals to hold off.

Close behind: egg pick and knocks 34.8 s (the hatch reveal alone is a 10.6 s wait; it already shows "Press any key" after 1.5 s), hatch card 33.8 s
of reading (10 option rows), results after the tutorial 29.6 s (27.9 s reading), pre-match countdown 25.0 s (the squad's pick turns: your own pick is
in it), ship and drop 21.4 s (16.8 s aboard; "Press Space to launch" and the drop plan are on screen).

**Flagged (8 lines):** beats over 45 s: first Relic, walk to the Uplink, wait for the Uplink. Waits over 5 s with nothing to do: egg hatch reveal
(10.6 s), first Relic (14.2 s), pre-match countdown (25.0 s), ship until the jump (16.8 s), wait for the Uplink (284.4 s). The tutorial course
has no flag; its longest wait is `defend` at 2.7 s. Not flagged but close: the naming card's wait for the new Boki (4.8 s).

## 4. The fix made, and the fixes still to make

**Made: the prologue (the worst wait with no decision, owner rule or skip prompt in it).** The 40 s story gave a first-time player no sign that a
key ends it: `HoldSkip` showed its ring and "Hold to skip" only after a press. It now shows the hint by itself after `HoldSkip.HINT_AT` 4 s of
watching with nothing pressed, for `HINT_S` 6 s (`scripts/ui/hold_skip.gd`; the prologue is its only user). The pace tool now counts the wait
with no way out on screen, not the whole story. Asserted in `--new-player-flow-check` and `--tutorial-timing-check` (hint off on the first frame,
up after 4 s). Not chosen: cutting the story or shortening shots (the owner's script).

| Prologue | Before (main cb8ae58b30) | After |
|---|---|---|
| `--tutorial-pace-check` longest wait with no way out shown | **37.0 s** (flag: wait>5 s) | **4.0 s** (no flag) |
| `--tutorial-pace-check` beat seconds (watched through) | 44.3 s | 44.3 s |
| `--tutorial-pace-check` waits over 5 s | 9 flags | 8 flags |
| `--tutorial-timing-check` prologue (skipped at once, wall s) | 2.6 | 2.5 (noise), failures 0 both |
| `--tutorial-timing-check` hint assertions | none | 2 (off at frame 0, up at 4 s) |

Everything else in the run is unchanged within noise (the table in section 2 differs from the "before" run by under 2 s a row, bar `kin` +1.6 s).

Still to make:

1. **First Relic (95 s, a 14.2 s wait):** cut the Relic page's text or let the click go on while it is read. The put-on beat is a story cut-scene (DECISIONS 11-11).
2. **Creator:** collapse the 10 option rows to the first 3 on a new save (looks, build, colour) with "More" for the rest.
3. **Pre-match countdown (25 s):** the squad's turns run while you wait; show the squad list or let a done pick end your own wait.
4. **Ship (16.8 s aboard):** the prompt and the drop plan are on screen; the pace drive jumps at the bots' planned time and so counts it as idle. Model a player who launches on reading the prompt.
5. **Results (30 s of reading):** show 3 numbers first, the lists behind a "More".
6. **Plain-words lines under `gkey`, `pick_sec` and `ranks`** cost 6 to 9 s of reading each before the first input; one short line each.

## 5. What this does not measure

- Decisions: which look, which egg, which Relic, where to put the house. Only reading is counted for them.
- The farm tutorial and the walk to the Uplink are estimates from game data, not played. Hob's talk lines are not timed (the check does not click them one by one).
- Fear and mistakes beyond the 30 % miss rate: falls into the void, deaths, getting lost. The drive still steers perfectly to each marker.
- One reader speed. At 2.5 words/s (slow readers) the 383 s of reading becomes about 540 s; change `TutorialDrive.READ_WPS` and rerun.
- Headless wall time for screen waits (see Kind).
