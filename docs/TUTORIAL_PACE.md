# Tutorial pace: how long each beat takes a new player

`docs/UI_FIRST15.md` shots were driven by `TutorialDrive`, which reads nothing, never misses and reacts in one frame, so Boki and kills
happened faster than a person plays. This file measures the same path with a human-pace drive. **Re-measured 2026-11-19 on main cb8ae58b30** (the Ways Out
exits, the 20-step course); the one fix made is in section 4.

## 0. Eight banner steps (`ext/tutorial-match-eight`, 2026-11-22)

DECISIONS 2026-11-08: the match tutorial is about 8 steps; everything else is a one-line first-time hint. Counted on main `cc36e78ec9`
with `--tutorial-check` (gunslinger, driven, instant reactions):

| | Before | After |
|---|---|---|
| Steps in `content/rules/tutorial.json` | 23 | 23 (ids and course unchanged) |
| Steps a run visits (Boki rides along; `ult`, `pick_ult` never apply) | 21 | 21 |
| **Banner steps** (strip, check, sting, 0.6 s pause) | **21** | **8** |
| Hint-only steps (one line in the message lane, once per save) | 0 | 13 |
| Game time to the lift (driver, no reading) | 61.5 s | 55.5 s |

Banner steps now: land, shoot, sec (the fight), dash, glide, gkey (send your Boki), kin (E), extract. A Boki that rides as a wisp
gets `summon` in place of `gkey`. There is no chest on the course (the first-match guide has the chest line), so it is not a step.

Hint-only (`"quiet"` in the rules file, `TutorialHints`): points, the three ability picks (made for you, the line says what was unlocked
and on which key), exdash, wallkick, crouch, pack, glove, hook, ranks, wayout, uplink, defend. They keep their stop, camp, marker and
Boki lead, so the course and the driver are unchanged; they lose the strip, the done check, the sting, the 0.6 s wait after, the 3.5 s
"points" wait and the 20 s "ranks" wait. The line is said once per save (`tuth_<step>` in `Save.d.tutorial`) and again when the player
stalls on it. The 6 s gain is the instant driver's; the human-pace figure in section 2 (134 s of course play) was not re-measured with
`--tutorial-pace-check`.

Checks on this branch (all 0 failures): `--tutorial-check` (gunslinger, juggernaut, archer:wisps), `--tutorial-fight-check`, `-hud-`, `-retry-`,
`-lane-`, `-clean-`, `-idle-`, `-resume-`, `-text-`, `-skip-`, `-dead-air-`, `-playthrough-check`, `--duo-tutorial-check`. Check changes: the
first pick is made for you (fight check), a hint step has no chime or banner width (hud check), and `--tutorial-check` asserts 7 to 9
banner steps. One driver fix: `TutorialDrive` never cleared `sec_hold`, so a `sec` step that ended mid-hold left the right click held
and the Juggernaut could not open its glider (main passed by timing luck; the shorter course exposed it).

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

## 6. Playthrough at a fixed 30 fps and at 60 (`--tutorial-fps-pace-check`, 2026-11-28, `ext/tut-playthrough-30fps`)

The stabilize sprint's gate (DECISIONS 11-19: a tutorial playthrough that must finish). `tools/tutorial_fps_pace_check.gd` plays the full match
course (Vex, the default starter; `-- --starter=archer|juggernaut` for Lace, Kael) and the garden tutorial (`tools/farm_tutorial_fps_pace.gd`, the
five garden steps) with the bot, in the game's own frame loop on the Low preset with `Engine.max_fps` at 30, then at 60. It judges **every drawn
frame** as the player sees it and fails on: a step over its budget (12 s of game time, `pack` 30 s and `defend` 15 s: a cooldown and a wave; the
garden 20 s); a span over **8 s** with no prompt (banner, hint line in the message lane, or marker); and a banner step with any frame where the
objective banner is not up. Banner up = the line is set and the `TutorialStrip` rect is on screen, no wider than `WIDTH_FRAC`, no taller than
`HEIGHT_FRAC` and inside the top 20 % of the screen (slim, top-centre, never over the play). Hint-only steps (`quiet` in `tutorial.json`) have no
banner by design: for them the check counts the prompt gap only. Game seconds, so the 30 and 60 columns differ by frame granularity only.

**Result: 0 failures** (every step inside its budget, no gap over 8 s, banner up on every frame of every banner step, the course and the garden
finish at both rates). Course 74.9 s at 30 fps and 76.6 s at 60 (game time, 22 steps).

**One bug fixed.** The strip's drop-in (`TutorialStrip.shown`) started fully above the screen, so the first drawn frame of every banner step
(one frame, 17 to 33 ms) had no objective on screen: 6 banner steps at 30 fps and 7 at 60 each lost one frame (13 failures in the first run). It now starts with `POP_SEEN` (25 %) of the strip in view and drops the rest in the same 0.25 s. The match HUD, the
farm strip and the first-match guide share `shown`, so all three changed alike. Before: 13 failures; after: 0.

Slowest steps are fights that wait on the game, not on the player: `pack` 18.4 s (the summon ring is bright after a cooldown, then the pack), `defend`
8.0 s (the wave), `glove` 5.9 s, `kin` 6.3 s at 60 fps (2.7 to 4.8 s at 30; the bot has to be in reach and the Boki has to land the hits). No step is
near its budget bar `pack` (62 % of 30 s). The slow player of `--tutorial-dead-air-check` still goes exactly 8.0 s with nothing new on the match
course at the start of a step (the 5 s stand-still plus the nag at `NAG_T` 8 s); that is at, not over, the 8 s line and is unchanged.

### 6.1 Match course (Vex)

| Step | Kind | 30 fps s | 60 fps s | Budget s | Banner frames missing (30 / 60) | Longest no-prompt gap s (30 / 60) |
|---|---|---|---|---|---|---|
| land | banner | 3.7 | 3.7 | 12 | 0 of 110 / 0 of 219 | 0.0 / 0.0 |
| shoot | banner | 5.1 | 5.1 | 12 | 0 of 152 / 0 of 303 | 0.0 / 0.0 |
| points | hint-only | 0.6 | 0.6 | 12 | 0 of 18 / 0 of 37 | 0.0 / 0.0 |
| pick_sec | hint-only | 0.0 | 0.0 | 12 | 0 of 1 / 0 of 1 | 0.0 / 0.0 |
| sec | banner | 2.3 | 2.3 | 12 | 0 of 68 / 0 of 135 | 0.0 / 0.0 |
| pick_dash | hint-only | 0.6 | 0.6 | 12 | 0 of 18 / 0 of 37 | 0.0 / 0.0 |
| dash | banner | 3.0 | 2.8 | 12 | 0 of 89 / 0 of 167 | 0.0 / 0.0 |
| exdash | hint-only | 2.3 | 2.3 | 12 | 0 of 69 / 0 of 140 | 0.0 / 0.0 |
| glide | banner | 4.2 | 4.1 | 12 | 0 of 125 / 0 of 249 | 0.0 / 0.0 |
| wallkick | hint-only | 1.5 | 1.5 | 12 | 0 of 46 / 0 of 92 | 0.0 / 0.0 |
| crouch | hint-only | 1.5 | 1.5 | 12 | 0 of 46 / 0 of 93 | 0.0 / 0.0 |
| summon | banner | 3.2 | 2.9 | 12 | 0 of 97 / 0 of 174 | 0.0 / 0.0 |
| pack | hint-only | 18.4 | 18.4 | 30 | 0 of 553 / 0 of 1109 | 0.0 / 0.0 |
| pick_kin | hint-only | 0.6 | 0.6 | 12 | 0 of 19 / 0 of 37 | 0.0 / 0.0 |
| kin | banner | 4.8 | 6.3 | 12 | 0 of 143 / 0 of 376 | 0.0 / 0.0 |
| glove | hint-only | 6.8 | 5.9 | 12 | 0 of 205 / 0 of 353 | 0.0 / 0.0 |
| hook | hint-only | 3.8 | 3.9 | 12 | 0 of 115 / 0 of 233 | 0.0 / 0.0 |
| ranks | hint-only | 0.6 | 0.6 | 12 | 0 of 19 / 0 of 37 | 0.0 / 0.0 |
| wayout | hint-only | 4.0 | 1.7 | 12 | 0 of 121 / 0 of 103 | 0.0 / 0.0 |
| uplink | hint-only | 1.9 | 1.9 | 12 | 0 of 57 / 0 of 114 | 0.0 / 0.0 |
| defend | hint-only | 8.0 | 8.0 | 15 | 0 of 240 / 0 of 480 | 0.0 / 0.0 |
| extract | banner | 0.1 | 0.0 | 12 | 0 of 2 / 0 of 2 | 0.0 / 0.0 |

### 6.2 Garden tutorial

| Step | Kind | 30 fps s | 60 fps s | Budget s | Banner frames missing (30 / 60) | Longest no-prompt gap s (30 / 60) |
|---|---|---|---|---|---|---|
| meet | banner | 1.5 | 0.9 | 20 | 0 of 46 / 0 of 57 | 0.0 / 0.0 |
| patch | banner | 0.5 | 0.5 | 20 | 0 of 16 / 0 of 30 | 0.0 / 0.0 |
| eat | banner | 0.5 | 0.5 | 20 | 0 of 16 / 0 of 31 | 0.0 / 0.0 |
| toy | banner | 6.7 | 7.4 | 20 | 0 of 200 / 0 of 445 | 0.0 / 0.0 |
| out | banner | 0.0 | 0.0 | 20 | 0 of 1 / 0 of 1 | 0.0 / 0.0 |

Step seconds in the garden are the guide's own reaction (the bot acts at once): `toy` is the toy's play session (7 s).

Run: `godot --headless --path . -- --tutorial-fps-pace-check` (about 5 min, no GPU). Related: `--tutorial-check --tutorial-low-fps` and
`--farm-tutorial-check --tutorial-low-fps` (steps and stalls, 30 fps and 60 fps with a 100 ms stall every 5th frame), `--tutorial-dead-air-check`,
`--tutorial-playthrough-check`.
