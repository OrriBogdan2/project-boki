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
3. `kin` ("Hit the line with Longneedle") and `ult` nag in every run and take 11 to 26 s with the driver: check the step's aim line.
4. `glove` stalled for the whole 900 s course in 2 of 9 runs (not seen on the repeat); it needs a seeded repro.
5. Taking a second Relic from Hob (juggernaut) and then starting an expedition played as the saved pick of the tutorial Relic
   (`gunslinger`): the flow check's own `Arch.of_save()` says it, unverified by hand.
6. The farm tutorial is 11 steps and 219 words (decision: 4 to 5); take `ext/tut-garden-no-gather`.
7. The Mask page is 83 words and the egg screen 218: the largest text blocks of the first minutes.
