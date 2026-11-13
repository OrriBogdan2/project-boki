# Tutorial timing: the new-player path, step by step (0.24.5 line)

Measured on `ext/release-integ-0245` (garden core and Ways Out) with `godot --headless --path . -- --tutorial-timing-check`
(`tools/tutorial_timing_check.gd`, a subclass of `--new-player-flow-check`): one fresh save, temp `XDG_DATA_HOME`, the scripted
drivers. It is **advisory**: it prints one `TUTT` row per step and only a stall in the run fails it. Nothing here is a human
playtest. DECISIONS 2026-11-08 ask for a match tutorial of about 8 steps and a garden one of 4 to 5, one banner line each, with a
visible Skip; the tables show how far the line is from that (section 5).

Columns: **Time** is sim seconds of the instant-reacting `TutorialDrive` (no reading, no misses; screens: wall seconds; farm and
garden: the driver ticks them off at once, so n/a). **Read s** = words / 3.5 + 0.45 s, the pace of `docs/TUTORIAL_PACE.md` (add it to
Time for a person). **Words** = the banner line plus the plain-words line under it (screens: every visible label and button,
cards underneath included, so a stack counts twice). **Keys named** = caps in the text or on the key-cap chip. **Live keys**: the
check rebinds the actions to F-keys and reads each tutorial, farm and garden line again; a default cap that survives is flagged
`hard-coded key`. None did. **Flags**: `nagged` = 8 s with no progress, the panel pulses and the Boki says it again;
`repeated` = the step came round again.

## 1. Mask pick (hatch, naming, first Relic)

| Step | Time s | Kind | Words | Read s | Keys named | Flags | Text on screen |
|---|---|---|---|---|---|---|---|
| prologue: the skipped prologue lands on the hatch | 0.2 | wall | 13 | 4.2 | - | - | Every new adventurer picks a Boki to take into battle. Choose your Boki |
| hatch: card and look: the hatch opens on its card | 0.0 | wall | 13 | 4.2 | - | - | Every new adventurer picks a Boki to take into battle. Choose your Boki |
| hatch: card and look: then you make yourself | 0.0 | wall | 56 | 16.4 | - | - | Make yourself You are one of the Empty. Drag (or hold A / D) to turn round. Every new adventurer picks a Boki  |
| hatch: card and look: then the eggs | 0.0 | wall | 121 | 35.0 | - | - | Choose your first Boki Every Boki is different. It will remember how you treat it. Venom Egg BOLD A dark plum  |
| hatch: egg pick and knocks: the egg waits for knocks | 0.0 | wall | 218 | 62.7 | - | - | Knock on the shell Every Boki is different. It will remember how you treat it. Venom Egg BOLD A dark plum shel |
| hatch: egg pick and knocks: seven knocks hatch it | 10.6 | wall | 33 | 9.9 | - | - | Vespyx VENOM A sly fox with a scorpion's curled tail. MOVES  ·  HOVER ONE Stinger Hook Stinger Dash Bond move  |
| hatch: its look and naming: the new Boki meets you | 4.8 | wall | 43 | 12.7 | - | - | Vespyx It's looking at you. It knows your face now. Vespyx VENOM A sly fox with a scorpion's curled tail. MOVE |
| hatch: its look and naming: then it can be named | 0.3 | wall | 57 | 16.7 | - | - | It's looking at you. Every Boki is different. It will remember how you treat it. A NEW BOKI Name your Vespyx " |
| first Relic: naming leads into the starter pick | 0.0 | wall | 95 | 27.6 | - | - | A NEW BOKI Name your Vespyx "Cin-cin! Vespyx!" It's sly and eager, and it can only babble for now. Whatever yo |
| first Relic: the pick leads into the first Relic | 0.0 | wall | 105 | 30.4 | - | - | A NEW BOKI Name your Vespyx "Cin-cin! Vespyx!" It's sly and eager, and it can only babble for now. Whatever yo |
| first Relic: the Relic waits by your face | 3.3 | wall | 22 | 6.7 | - | - | This Relic is the mask of a fallen Hunter. Put it on, and their soul becomes yours. F Put on the Relic |
| first Relic: putting it on opens its page | 6.3 | wall | 83 | 24.2 | - | - | Vex the Hired Gun 145 health  ·  1 dash  ·  Quill Rifle SHIFT Slipstep Skid or slide, and keep shooting. LMB Q |
| first Relic: the page has a way on | 0.0 | wall | 83 | 24.2 | - | - | Vex the Hired Gun 145 health  ·  1 dash  ·  Quill Rifle SHIFT Slipstep Skid or slide, and keep shooting. LMB Q |

13 rows, 942 words, 275 s of reading at 3.5 words/s plus 0.45 s a row; 26 s of driven play.
Wall stage totals: prologue (held to skip) 0.8 s, hatch card+look 0.1, egg pick and 7 knocks 12.2, its look and naming 5.2, first
Relic (starter pick, drift-in, put on, page) 9.7. Nothing blocked or repeated. The pick card text is the longest block on screen
(the Relic page is 83 words). Hard-coded key names found on these screens: "hold A / D" (hatch) and "A / D" (Boki reveal),
plain text: fixed (section 4).

## 2. Match tutorial (the course, 23 rows)

| Step | Time s | Kind | Words | Read s | Keys named | Flags | Text on screen |
|---|---|---|---|---|---|---|---|
| land | 3.7 | sim | 5 | 1.9 | WASD | - | Steer down to the meadow |
| points | 3.5 | sim | 19 | 5.9 | - | - | You start with 1 ability point Choose wisely: every level gives one more. Monsters give XP when they fall. |
| pick_sec | 0.6 | sim | 12 | 3.9 | RMB | - | Unlock Burr Charge Fire the charge from your cannon; its blast Dazes. |
| sec | 0.6 | sim | 6 | 2.2 | RMB | - | Hit the monsters with Burr Charge |
| shoot | 2.3 | sim | 11 | 3.6 | LMB | - | Now shoot them down Full-auto rifle. Dazed foes take 90% more. |
| pick_dash | 0.6 | sim | 10 | 3.3 | SHIFT | - | Level 2! Unlock Slipstep Skid or slide, and keep shooting. |
| dash | 3.8 | sim | 4 | 1.6 | SHIFT | - | Dash across the gap |
| exdash | 2.2 | sim | 5 | 1.9 | SHIFT | - | Jump, then dash in mid-air |
| glide | 4.4 | sim | 6 | 2.2 | SPACE | - | Jump, press SPACE again to glide |
| wallkick | 1.6 | sim | 15 | 4.7 | SPACE | - | Jump at the cliff, then again A jump against a wall kicks you up it. |
| crouch | 1.6 | sim | 11 | 3.6 | CTRL | - | Hold to crouch and scout Crouching shows what lies far ahead. |
| gkey | 3.0 | sim | 17 | 5.3 | G | - | Send Vespyx at the monsters G sends Vespyx at a monster. Tap again to call it back. |
| pick_kin | 0.6 | sim | 12 | 3.9 | E | - | Level 3! Unlock Longneedle Stand still, then fire a beam through walls. |
| kin | 26.0 | sim | 5 | 1.9 | E | nagged | Hit the line with Longneedle |
| glove | 11.4 | sim | 11 | 3.6 | F,Q | - | Grab the glove Gloves need no points. Q uses this one. |
| hook | 3.4 | sim | 16 | 5.0 | Q | - | Hook the Sentinel to you It shoots from afar. Your glove drags it to your feet. |
| pick_ult | 0.6 | sim | 17 | 5.3 | X | - | Level 6! Unlock your ultimate Fuse with Vespyx: one body, its power and yours, for a while. |
| ult | 15.4 | sim | 5 | 1.9 | X | nagged | Fuse with Vespyx and win |
| ranks | 0.6 | sim | 17 | 5.3 | Alt + E,E | - | Spend your spare points Ranks make an ability stronger: Alt + E, or click a gold +. |
| wayout | 2.0 | sim | 22 | 6.7 | - | - | Few ways out: reach the Uplink A match has only a few ways out. This one is the Uplink at the outpost. |
| uplink | 2.0 | sim | 18 | 5.6 | F | - | Capture the uplink mast Stay inside the circle until it's yours. Step out and the capture slips back! |
| defend | 14.0 | sim | 14 | 4.5 | - | - | Defend the outpost Stay inside the circle. Step out and the capture slips back! |
| extract | 0.0 | sim | 4 | 1.6 | - | - | Step into the light |

23 rows, 262 words, 85 s of reading at 3.5 words/s plus 0.45 s a row; 104 s of driven play.
Stage totals: load 0.6 s wall, course 95 to 104 s sim, results 1.6 s wall. Steps over 10 s of play: `kin` (11 to 26 s), `glove`
(7 to 14 s), `ult` (12 to 17 s), `defend` (14 s, the capture timer). In all 5 complete runs `kin` and `ult` nagged.

### The three slowest steps, shortened (`ext/tut-slowest-three`)

The table above is the "before". Medians of 3 runs each (before: the table above and two re-runs on the same line; after:
three runs of `--tutorial-timing-check` on the branch, all with the gunslinger starter Vex):

| Step | Before s (runs) | Median | Why it was slow | Change | After s (runs) | Median |
|---|---|---|---|---|---|---|
| `kin` | 26.0, 17.1, 12.6 | 17.1 | A second E press during the 0.6 s unlock step fired Longneedle at nothing, so "Hit the line" opened on an 11 s cooldown with nothing saying why. The row stood 8 m away, inside an idle monster's 7.5 m notice range, so it charged in and the line broke up. Your Boki killed the camp before the cast, so the camp came back. Then three 2.5x-health skitters to shoot down. | The step's E is ready when the step opens. The row starts 10 m out and holds its line. The row's monsters have 1x health, so one Longneedle clears the line. | 2.7, 1.7, 1.4 | 1.7 |
| `ult` | 15.4, 14.2, 14.9 | 14.9 | After the fuse, a 7-monster fight (8 for Kael) at 2.5x health: the lesson is the fuse, not the fight | The ult camp is 3 monsters (skitter, spitter, skitter) for every starter, in `camps.ult`. The per-starter `fight_foes` list is gone. | 4.6, 7.0, 6.6 | 6.6 |
| `defend` | 14.0, 14.0, 14.0 | 14.0 | A fixed 14 s capture timer (`Exits.TUT_UPLINK_T`) | 8 s: still long enough for its one wave of 2 skitters to arrive | 8.0, 8.0, 8.0 | 8.0 |

The match course went from 87 to 104 s of driven play to 61 to 65 s. `kin` and `ult` no longer nag. A kill in the step's camp now
counts as progress (`Tutorial._stall`), so a fight that is going well no longer pulses the panel. What each step teaches is the
same: E fired through a line of monsters, a fuse and a fight while fused, holding the circle while a wave comes. The fight beats
per starter (`--tutorial-fight-check`) went from 41/53/35 s (Lace/Kael/Vex) to 17/38/17 s, so its floor `FIGHT_MIN` is 12 s
(it was 30). The longest step is now `glove` (7 to 12 s: the walk over the bridge to the glove).

## 3. Farm tutorial (11 rows) and garden first day (5 lines)

| Step | Time s | Kind | Words | Read s | Keys named | Flags | Text on screen |
|---|---|---|---|---|---|---|---|
| hob | n/a | n/a | 14 | 4.5 | F | - | Hob is calling you over at the market stall: walk up and press F. |
| axe | n/a | n/a | 11 | 3.6 | - | - | Here, take this axe. Trees give wood, and wood builds things. |
| chop | n/a | n/a | 30 | 9.0 | F | - | Walk up to a tree and hold F to chop. The house takes 10 wood · 6 stone: keep chopping and mining until the ba |
| stone | n/a | n/a | 12 | 3.9 | F | - | Rocks give stone. Take this pickaxe and hold F at a rock. |
| house | n/a | n/a | 30 | 9.0 | B | - | Now for a house. Press B, choose House, then click the marked spot. Marking it out is free. The 10 wood · 6 st |
| task | n/a | n/a | 24 | 7.3 | C | - | Click Vespyx, or press C next to it, to open its page. Or press 2 (Boki on the bar below) for all your Boki. |
| feed | n/a | n/a | 14 | 4.5 | B | - | A hungry Boki is a slow Boki. Press B and set the trough down |
| crop | n/a | n/a | 20 | 6.2 | B | - | Crops grow in patches. Press B and place a patch by the water. The water keeps it wet for you. |
| buy | n/a | n/a | 16 | 5.0 | F | - | Go to the market stall and press F. Open the Seeds tab and buy one seed. |
| sell | n/a | n/a | 21 | 6.5 | F | - | Back at the stall, press F. Open the Sell tab and sell your crop. Gems come from selling, expeditions and Goal |
| expedition | n/a | n/a | 27 | 8.2 | F | - | This Relic is the mask of a fallen Hunter. Put it on, and their soul becomes yours. Press F at the portal to s |

11 rows, 219 words, 68 s of reading at 3.5 words/s plus 0.45 s a row; 0 s of driven play.

| Step | Time s | Kind | Words | Read s | Keys named | Flags | Text on screen |
|---|---|---|---|---|---|---|---|
| feed | n/a | n/a | 3 | 1.3 | - | - | Feed your Boki |
| toy | n/a | n/a | 4 | 1.6 | - | - | Play with a toy |
| race | n/a | n/a | 4 | 1.6 | - | - | Run your first race |
| nap | n/a | n/a | 4 | 1.6 | - | - | See a nap pile |
| pair | n/a | n/a | 6 | 2.2 | - | - | Pair two Boki in the Nook |

5 rows, 21 words, 8 s of reading at 3.5 words/s plus 0.45 s a row; 0 s of driven play.
The garden first day is the Goals tracker list (`GardenFirstDay`), not a guided tutorial: one short line each, no key named, no
Skip needed. The bot of `--garden-first-day-check` does all five (the race is 20 s of sim; a toy is picked up within 60 s of
farm time, `toy_check`). The farm tutorial on this line is still the 11-row axe/chop/house one; `ext/tut-garden-no-gather`
(READY, based on this line) cuts it to the garden four steps.

First match (first expedition, same run): 'Go' to the countdown 16 s wall, drop 31 s sim, then `--new-player-flow-check` fails
on "there is a skiff to take" (the known skiff red, `docs/GATE_0245.md`), so no per-step rows exist for it.

## 4. Fixed here
- The `defend` step nagged (panel pulse and Boki line) after 8 s even though the player stood in the circle doing what it asks;
  holding the circle now counts as progress (`Tutorial._stall`, two lines).
- The hatch and Boki-reveal turn hints named `A / D` as plain text; they now read the live `left`/`right` caps.

## 5. Follow-ups (not fixed)
1. The match tutorial is 23 steps (decision: about 8); 262 words, about 85 s of reading on top of 104 s of play. `pick_*`, `points`,
   `ranks` and the three gap steps are the obvious merges.
2. No visible Skip on the match tutorial panel: it is only in the pause menu ("Skip the tutorial") and on the naming card.
3. Done: `kin` and `ult` no longer nag and take 1 to 7 s (section 2, the slowest three).
4. `glove` stalled for the whole 900 s course in 2 of 9 runs (not seen on the repeat); it needs a seeded repro. Seen again on the slowest-three branch (1 of 3 baseline timing runs, 2 of 8 fight-check starter runs after; the same
   in both), and a trace caught the bot walking off the bridge into the void on the way to the glove. Separately, `--tutorial-fight-check`
   sometimes reports "missing kick": the bot can reach the lookout without a wall kick (2 of 8 runs).
5. Taking a second Relic from Hob (juggernaut) and then starting an expedition played as the saved pick of the tutorial Relic
   (`gunslinger`): the flow check's own `Arch.of_save()` says it, unverified by hand.
6. The farm tutorial is 11 steps and 219 words (decision: 4 to 5); take `ext/tut-garden-no-gather`.
7. The Mask page is 83 words and the egg screen 218: the largest text blocks of the first minutes.
# Tutorial guidance, garden only

## Garden first 15 (`--garden-first-15-check`)

The game is playable without extraction, and in the first visit the player must never be left without
a next step. The check plays a fresh save that skips the match tutorial ("Skip the tutorial" on the
naming card), takes the first Relic and lands on the garden (`base_mode` on). A bot then plays 15
minutes of garden time, never opens a match, and every second asks what is on screen to guide the
player:

- the tutorial line, or the marker in the world
- a Boki's want bubble
- a Goals row the player can finish at home (first-day list, garden, farm milestone or level; a
  Hunter's unlock or mastery row needs a match and does not count)

A 10 s window with none of them is logged; a stretch of 20 s fails the check. The interact prompt does
not count: it shows only once you stand next to the thing.

The bot acts 8 s after a prompt appears: it does the tutorial steps, then feeds, plays at a toy and
runs the Training post. It has one Boki the whole time, as a new save does.

### Gaps, before and after

| Window | Before | After |
|---|---|---|
| 0-42 s | tutorial line, marker, then the first-day list | same |
| 42-900 s | nothing: first-day list down to the two lines that need a second Boki (nap pile, Nook pair), no other home goal | "Next: Raise <Boki> to level 2" with an XP bar |
| Worst gap | 859 s (85 windows without guidance) | 0 s |

Fixes (Goals tracker, no new screen):

- A `garden` row, "Raise <Boki> to level N", with the Boki's XP towards the next level. It is there
  for the whole game at home, and feeding, petting, fetch and drills all move its bar.
- "See a nap pile" and "Pair two Boki in the Nook" stay off the card while you have one Boki, so the
  top line is never something you cannot do. They show as soon as a second Boki is on the farm.

Left open (not fixed here): a one-Boki save has no garden way to a second Boki before the market
stall is level 2 (the Shelter), and a visitor needs a built zone. The level row covers the gap, but
breeding stays out of reach for a while.
# Match tutorial: steps and hints audit (origin/main fb360f614, 2026-11-12)

Owner decision 2026-11-08: the match tutorial is about 8 steps (land+move, dash+glide, shoot, E, send your Boki, a fight,
open a chest, extract); everything else is a one-line hint the first time it matters.

## 1. Step count: the cut is NOT on main

`content/rules/tutorial.json` has **23 steps** (ids 0-22). A bot-driven run per starter (`--tutorial-fight-check`, Lace/archer,
Kael/juggernaut, Vex/gunslinger) visits all 23 for each, so the count is **23 / 23 / 23** (`gkey` is the only step a kit can skip,
and only without a Boki).

`land, points, pick_sec, sec, shoot, pick_dash, dash, exdash, glide, wallkick, crouch, gkey, pick_kin, kin, glove, hook,
pick_ult, ult, ranks, wayout, uplink, defend, extract`

The 22 -> 8 cut (decision 0023, `37dc18d84`) exists only on `origin/ext/tutorials-cut` (2026-11-08, ~1550 commits off main,
pre-run-levels, pre-Ways Out). It was never merged; main grew its own ability-point course instead (pick steps, one camp per
ability, then Ways Out steps). Nothing on main "crept back": the cut never arrived. It cannot be merged or cherry-picked as is;
it needs a port to the run-levels course (TutorialCamps, TutorialDrive, Ways Out steps) and 6 checks that pin the step ids
(`--tutorial-fight-check`, `-clean-check`, `-hud-check`, `-idle-check`, `--new-player-flow-check`, `--kit-drill-check`,
teammate/drop-feel rows). Mapping of the 23 to the 8: land+move = `land`; dash+glide = `dash, exdash, glide`; shoot = `shoot`;
E = `kin`; send your Boki = `gkey`; a fight = `sec, ult, hook`; chest = none (no chest step; the first-match guide has one);
extract = `wayout, uplink, defend, extract`. Cut to hints: `points, pick_*, ranks, wallkick, crouch, glove`.

## 2. Hints on main and when they fire

Match tips (`Match._tips`, once per save in `Save.d.tutorial`, not in the tutorial, not with tips off):
| key | fires |
|---|---|
| move | 1 s after landing: shoot, dash, glide keys |
| ability | 14 s in: Boki key / signature, fuse key |
| ult | bond full and the Boki has a fusion |
| throw | a rival within 9 m and the Boki is out |
| skill | the Boki is active: stun then shoot combo |
| catch | the interact prompt is a scan |
| exit_uplink | the interact prompt kind is `exit` (an outpost only) |
| down | you are downed |
| rings | within 9 m of an air ring |
| stagger | first staggerable monster |

First-match guide (`FirstMatchGuide`, first 2 Extractions): land, chest, rank, send, squad, blight, exit.
Hub: `HubHints`. Farm: `FarmKeyHints` and the farm tutorial.

## 3. Gaps (hints that never fire, or say the old thing)

- **Ways Out:** `exit_uplink` and the guide's `exit` line ("Go to an exit and hold F to leave") only know outposts
  (`Exits.spots()`, kind `outpost`). Heart, Lair, quest and final-seat ways out never trigger either, so "extract now means
  Heart/quest exits" is not told anywhere. Branches with the fix: `ext/tut-first-ways-out`, `ext/tut-heart-raid-hints`.
- **Mini-rockets:** no hint on main; `ext/tut-rocket-hint`.
- **Stomps:** no hint on main; `ext/tut-stomp-hints`.
- **Closing zone:** the guide's `blight` line fires at 40% left; no "get inside the circle" line on main; `ext/tut-first-zone`.
- **Hot zone / Waystone:** `ext/tut-hot-zone-line`, `ext/tut-waystone-hint`.
- Also open on main: `--new-player-flow-check` stalls at the `glove` step (900 s, 2 FAIL rows: finishes the course, no step over 45 s; not in DEBT yet).

Not changed here: porting the cut is a core change to the tutorial and its checks and collides with the open `ext/tut-*`
branches above, so it needs the owner's order (merge those hint branches first, then cut the course).
