# Tutorial pace: how long each beat takes a new player

`docs/UI_FIRST15.md` shots were driven by `TutorialDrive`, which reads nothing, never misses and reacts in one frame, so Boki and kills
happened faster than a person plays. This file measures the same path with a human-pace drive. **Nothing in the tutorial was changed;
the fixes are listed in section 4.**

## 1. How it was measured

`godot --headless --path . -- --tutorial-pace-check` (tool: `tools/tutorial_pace_check.gd`, a subclass of `--new-player-flow-check`).
One fresh save, title to the first finished expedition (back on the farm after the skiff), one run, fixed seed. It is **advisory**: the
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
- **sim:** game seconds at human pace (the tutorial course, the drop, the dock).
- **wall:** the screen's own animation seconds plus reading and clicks. Headless wall time, so loading and the countdown are as fast as this
  server; a slower machine adds to them.
- **est:** worked out from the game's data, not played: the farm tutorial (hint reading, plus 8 s a walk, 3 s a menu pick, and swings at one
  per unit of the house's cost times `HunterTool.period`), and the walk from the landing to the skiff dock (straight line x 1.3 at run speed).

**Idle** = seconds the player has no input and nothing to do: reading text, and waiting on a prompt, an animation, a timer or the skiff.
The **longest wait** is the longest single stretch of idle that was *not* reading (in a screen row: its longest single wait).
Flags: a beat over **45 s**, a wait over **5 s** with nothing to do.

## 2. Result

**779 s (13 min) over 50 beats; 568 s of it idle, of which 369 s is reading and 199 s is waiting.** By part: the front screens (title to the first
Relic) 189 s; the tutorial course 157 s of play (22 steps, plus the 2 s intro card) and 35 s on its results screen; the farm tutorial about
182 s (est.); the first expedition 217 s with its screens. Every figure is one run of one seed (the expedition map is fixed at seed 4242),
so read a difference of a few seconds as noise.

| # | Beat | Kind | Seconds | Reading s | Idle s | Longest wait s | Flag | Note |
|---|---|---|---|---|---|---|---|---|
| 1 | title | wall | 4.3 | 4.2 | 4.3 | 0.0 |  |  |
| 2 | prologue | wall | 42.1 | 40.9 | 42.1 | 37.0 | wait>5 s |  |
| 3 | hatch: card and look | wall | 36.1 | 36.0 | 36.1 | 0.0 |  |  |
| 4 | hatch: egg pick and knocks | wall | 31.1 | 20.7 | 31.1 | 10.6 | wait>5 s |  |
| 5 | hatch: its look and naming | wall | 19.3 | 14.1 | 19.3 | 4.9 |  |  |
| 6 | first Relic | wall | 56.1 | 46.4 | 56.1 | 6.3 | >45 s, wait>5 s |  |
| 7 | tutorial match: load | wall | 0.6 | 0.0 | 0.6 | 0.6 |  |  |
| 8 | tutorial: intro card | sim | 2.0 | 2.0 | 2.0 | 0.0 |  | auto-closes; any key sooner |
| 9 | tutorial: land | sim | 3.7 | 1.9 | 3.7 | 1.8 |  |  |
| 10 | tutorial: move | sim | 2.9 | 1.9 | 1.9 | 0.0 |  |  |
| 11 | tutorial: dash | sim | 3.5 | 1.6 | 1.6 | 0.0 |  |  |
| 12 | tutorial: exdash | sim | 3.9 | 1.9 | 1.9 | 0.0 |  |  |
| 13 | tutorial: glide | sim | 6.0 | 2.2 | 2.2 | 0.0 |  |  |
| 14 | tutorial: crouch | sim | 4.1 | 2.2 | 2.2 | 0.0 |  |  |
| 15 | tutorial: pickup | sim | 8.9 | 1.6 | 1.6 | 0.0 |  |  |
| 16 | tutorial: gkey | sim | 10.6 | 8.2 | 10.5 | 1.5 |  |  |
| 17 | tutorial: rank | sim | 9.4 | 9.3 | 9.3 | 0.0 |  |  |
| 18 | tutorial: shoot | sim | 1.6 | 1.3 | 1.3 | 0.0 |  |  |
| 19 | tutorial: sig | sim | 19.6 | 7.9 | 13.7 | 0.5 |  |  |
| 20 | tutorial: utility | sim | 8.6 | 1.3 | 7.5 | 1.3 |  |  |
| 21 | tutorial: throw | sim | 8.9 | 4.6 | 8.3 | 1.3 |  |  |
| 22 | tutorial: orders | sim | 2.5 | 2.2 | 2.5 | 0.3 |  |  |
| 23 | tutorial: kin1 | sim | 4.1 | 1.9 | 3.9 | 2.0 |  |  |
| 24 | tutorial: key | sim | 5.1 | 4.5 | 4.5 | 0.0 |  |  |
| 25 | tutorial: chest | sim | 9.9 | 7.0 | 7.0 | 0.0 |  |  |
| 26 | tutorial: fight | sim | 14.5 | 1.6 | 1.6 | 0.0 |  |  |
| 27 | tutorial: goexit | sim | 3.9 | 1.6 | 1.6 | 0.0 |  |  |
| 28 | tutorial: uplink | sim | 7.5 | 5.6 | 5.6 | 0.0 |  |  |
| 29 | tutorial: defend | sim | 14.0 | 4.5 | 13.8 | 9.3 | wait>5 s |  |
| 30 | tutorial: extract | sim | 0.0 | 0.0 | 0.0 | 0.0 |  |  |
| 31 | results | wall | 35.2 | 33.6 | 35.2 | 1.5 |  |  |
| 32 | farm: first arrival | wall | 0.4 | 0.0 | 0.4 | 0.4 |  |  |
| 33 | farm: hob | est | 12.4 | 4.5 | 4.5 | 0.0 |  | 1 walks, 0 menu picks, 0 swings |
| 34 | farm: axe | est | 3.6 | 3.6 | 3.6 | 0.0 |  | 0 walks, 0 menu picks, 0 swings |
| 35 | farm: chop | est | 27.0 | 9.0 | 9.0 | 0.0 |  | 1 walks, 0 menu picks, 10 swings |
| 36 | farm: stone | est | 17.3 | 3.9 | 3.9 | 0.0 |  | 1 walks, 0 menu picks, 6 swings |
| 37 | farm: house | est | 23.0 | 9.0 | 9.0 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 38 | farm: task | est | 10.3 | 7.3 | 7.3 | 0.0 |  | 0 walks, 1 menu picks, 0 swings |
| 39 | farm: feed | est | 18.4 | 4.5 | 4.5 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 40 | farm: crop | est | 20.2 | 6.2 | 6.2 | 0.0 |  | 1 walks, 2 menu picks, 0 swings |
| 41 | farm: buy | est | 16.0 | 5.0 | 5.0 | 0.0 |  | 1 walks, 1 menu picks, 0 swings |
| 42 | farm: sell | est | 17.4 | 6.5 | 6.5 | 0.0 |  | 1 walks, 1 menu picks, 0 swings |
| 43 | farm: expedition | est | 16.2 | 8.2 | 8.2 | 0.0 |  | 1 walks, 0 menu picks, 0 swings |
| 44 | first expedition: start | wall | 14.2 | 14.2 | 14.2 | 0.0 |  |  |
| 45 | first expedition: pre-match countdown | wall | 16.0 | 0.0 | 16.0 | 16.0 | wait>5 s |  |
| 46 | expedition: ship and drop | sim | 24.7 | 0.0 | 13.0 | 13.0 | wait>5 s | on the ship until the jump (13 s), then the fall |
| 47 | expedition: walk to the skiff | est | 34.9 | 0.0 | 0.0 | 0.0 |  | straight line x 1.3 at run speed 4.5 m/s |
| 48 | expedition: wait for the skiff to open | sim | 50.6 | 0.0 | 50.6 | 50.6 | >45 s, wait>5 s | opens at 110 s; free to loot meanwhile |
| 49 | expedition: call and board the skiff | sim | 58.5 | 0.0 | 56.0 | 56.0 | >45 s, wait>5 s | hold interact 2.5 s, then Exits.CALL_T and BOARD_T |
| 50 | first expedition: results | wall | 17.6 | 14.8 | 17.6 | 2.7 |  |  |


## 3. The worst five (by seconds)

1. **Call and board the skiff: 58.5 s**, 56 s of it waiting. Holding interact for 2.5 s, then `Exits.CALL_T` (45 s) until the skiff ties up and
   `Exits.BOARD_T` (12 s) at the pier. The first expedition's whole exit is a 57 s wait with only the exit's waves to deal with.
2. **First Relic: 56.1 s** (46 s reading, longest single wait 6.3 s). The starter pick, then the Relic drifting in, "put it on", then its page.
   The page is the longest text in the first hour that has to be read to go on.
3. **Wait for the skiff to open: 50.6 s** with nothing to do. The dock opens at 110 s (`at_sess(0.18)`); a player who walks straight there (35 s)
   has landed at 25 s and arrives at 60 s. In a real match this is time to loot; on a first expedition nothing says so.
4. **Prologue: 42.1 s**, of which 37 s is one unbroken wait with nothing to do. A key skips it, but nothing says so.
5. **Hatch card and creator: 36.1 s** of reading before the first click (the creator panel has 10 option rows). Choosing a look is not in this figure, only
   reading the labels; a person will take longer.

Close behind: results after the tutorial 35.2 s (33.6 s reading), egg pick and knocks 31.1 s (the hatch reveal alone is a 10.6 s wait), the farm's
`chop` step 27 s (est.), `sig` 19.6 s in the course.

**Flagged (11 lines):** beats over 45 s: first Relic, wait for the skiff, call and board the skiff. Waits over 5 s with nothing to do: prologue
(37 s), egg hatch reveal (10.6 s), first Relic (6.3 s), tutorial `defend` (9.3 s), pre-match countdown (16 s), the ship until the jump (13 s),
wait for the skiff (50.6 s), call and board (56 s). Not flagged but close: the naming card's wait for the new Boki (4.9 s), the tutorial `utility` step
(7.5 s idle in all, longest stretch 1.3 s).

## 4. Fixes to make (not done here)

1. **Skiff call and board (largest):** give the 45 s call something to do (a loot or "scout the pier" prompt) or shorten `CALL_T` for a save's first
   two Extractions (`FirstMatchGuide` already knows them). One "what to do while you wait" line at the dock.
2. **Skiff opens at 110 s:** on a first expedition, open it earlier or show a "loot until 1:50" line from landing; the 50 s wait is the second flag.
3. **Prologue:** show "Space skips" on the first frame, or cut it to the pages with a story line (37 s is one wait).
4. **First Relic:** cut the Relic page's text or let the click go on while it is read; split "put it on" and the page into one step.
5. **Creator:** collapse the 10 option rows to the first 3 on a new save (looks, build, colour) with "More" for the rest.
6. **Hatch reveal (10.6 s) and pre-match countdown (16 s):** show what is coming (the egg's species, the squad list) so the wait is reading, not staring.
7. **Tutorial `defend` (9.3 s of waiting):** start the next wave when the first dies, or end the step on the first kill.
8. **Ship until the jump (13 s):** say "Press Space to jump when you like" on the ship; a new player waits for permission.
9. **Results (35 s of reading):** show 3 numbers first, the lists behind a "More".
10. **Plain-words lines under `gkey` (24 words) and `rank` (26 words)** each cost 8 to 9 s of reading before the first input; one short line each.

## 5. What this does not measure

- Decisions: which look, which egg, which Relic, where to put the house. Only reading is counted for them.
- The farm tutorial and the walk to the dock are estimates from game data, not played. Hob's talk lines are not timed (the check does not click them one by one).
- Fear and mistakes beyond the 30 % miss rate: falls into the void, deaths, getting lost. The drive still steers perfectly to each marker.
- One reader speed. At 2.5 words/s (slow readers) the 369 s of reading becomes about 520 s; change `TutorialDrive.READ_WPS` and rerun.
- Headless wall time for screen waits (see Kind).
