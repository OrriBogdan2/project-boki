# The first garden hour, played (no expedition)

DECISIONS 2026-11-09/11-10: the game must be fun with only the garden (raise, feed, play, race, breed), and done means played.
This is one scripted play of the first in-game hour of a fresh save on `origin/main` fb360f614 with `base_mode` on (it ships
**off**: see item 11), no expedition, one hatched starter. No game code was changed. Each friction item is a one-line backlog proposal.

## How it was played

- A scratch driver (not committed) built a fresh save (`Save.fresh()` plus one hatched level-1 Boki, trust 55, `tutorial.hatched`),
  opened the real farm (`main._hb_home()`), and ran the real `Home._process` at a fixed 0.05 s step for 3600 s of farm time. It called
  the same functions the UI calls: `_pet_kin`, `_care_feed`, the Market and Nook panels, `BlackMarket.buy`, `GardenZones.attune`,
  the whistle, `BaseRace.use`. Times below are **farm seconds**; the farm day is 300 s (`care.json care_day_s`).
- The player was an efficient one: pet every 20 s, fed whenever hungry from what the snack patch gave, bought the Wayseed as soon as
  the trader had one. It did **not** use fetch, training or the Dash (no second Boki, see item 2), so XP is a lower bound.
- Shots: [`docs/shots/farm-first-hour/`](shots/farm-first-hour). Log: [`run_log.txt`](shots/farm-first-hour/run_log.txt).
  **Renderer: software (llvmpipe under Xvfb), not the GPU.** The two `--needs gpu` jobs (`20261112-142541-23216`, the hour;
  `20261112-142607-28778`, the Ridge zone) sat at queue position 10 of 35-45 for 25+ minutes and never started. The 2D UI and layout are
  the same; 3D light and water differ. Replace the shots if they finish.
- Proof: `--garden-first-day-check` 0 failures (10 s headless), `--garden-unlock-pace-check` PASS (5 s; garden-only player opens the
  2nd zone on day 3, all five by day 12), `health.py --strict`, `gen_wiki.py --check`: see the last section.
- Forced steps (marked FORCED): the Dash, the nap pile and the Nook cannot run with one Boki, so a second level-8 Boki was added by
  code only to see those screens. That is a shortcut, not play.

## The hour, step by step

| # | Step | Farm time | What happened | Shot |
|---|---|---|---|---|
| 1 | Hub arrival | 0 s | Opens with 200 gems (the first farm entry floors gems at 200, `HomeLayout.FS_GEMS`). Banner "This is your Boki. Walk up and say hello. 1/4". Goals card lists the five first-day lines. | [01](shots/farm-first-hour/01_hub.jpg) |
| 2 | Meet | 1 s | Walking next to the Boki ticks step 1. | [02](shots/farm-first-hour/02_meet.jpg) |
| 3 | Feed (as the tutorial says) | stuck | Bag holds 3 emberberry; the Feed panel says "Nothing to feed it. Harvest crops, or buy kibble and buns at the market stall." Dead end (item 1). | [03](shots/farm-first-hour/03_feed_panel.jpg) |
| 4 | Pet x3 | 6 s | Works: hearts, joy +15, 1 XP each (cooldown 20 s). | [04](shots/farm-first-hour/04_pet.jpg) |
| 5 | Toy | 6 s placed, 12 gems | Placed from Build > Base. The Boki did **not** go to it for 600 s: the Feed step is still open and the lead state holds it (item 3). After the first meal at 579-608 s it walked over within 4 s. | [05](shots/farm-first-hour/05_toy.jpg) |
| 6 | Market | 126 s | Stall opens; Boki tab sells kibble at 6 gems and 7 snacks at 16: the real way to feed on minute 2. | [05c](shots/farm-first-hour/05c_market_boki.jpg) |
| 7 | Whistle | 129 s | Boki 14 m away stood next to the player in **3.0 s**. Best moment of the hour. | [06](shots/farm-first-hour/06_whistle.jpg) |
| 8 | Dash | 126 s | "The Dash needs two rested Boki" (toast, no panel). Cannot race alone (item 2). FORCED with 2 Boki: 14 s run, +6 gems. | [11](shots/farm-first-hour/11_dash.jpg) |
| 9 | Nook | 126 s | One tile, "LV 5 NEEDED" while the real gate is level 8 (item 5); no second Boki to pick. FORCED pair: egg appears in the nest. | [05d](shots/farm-first-hour/05d_nook_alone.jpg), [12](shots/farm-first-hour/12_nook.jpg), [13](shots/farm-first-hour/13_nest.jpg) |
| 10 | Snack patch | placed 6 s, ripe 8 min later | Free from Build > Garden. Ripe at about 580 s: 4 snacks (emberberry, tidebloom, sunroot, puffcorn); then one batch per 480 s. | [07](shots/farm-first-hour/07_patch_ripe.jpg) |
| 11 | First meal | 579 s | Feed, Toy first-day lines and the "Feed it" and "Place a toy" steps all tick within 15 s. | |
| 12 | Wayseed | 129 s | Drift Trader held a Ridge Wayseed that day at 110 gems; bought (gems 188 to 78). | |
| 13 | Wake the next zone | 1521 s (25 min) | Needs the second keys: lean 12 points toward Ridge's types. Puffcorn (flying) gives 9 per meal and one puffcorn ripens per 480 s, so the 2nd meal at 1521 s woke Ridge. Shot is the zone via `--garden-zone-shots`. | [zone](shots/farm-first-hour/zone_ridge_zone_day.jpg) |
| 14 | Rest of the hour | to 3600 s | 173 pets, 3 meals. Level 2 at 1049-1989 s, level 2-3 at the end (182-358 XP total across two runs). Tutorial banner still on 4/4. | [10](shots/farm-first-hour/10_55min.jpg) |

Totals: 2 of 5 first-day lines ticked without help (feed, toy), 3 impossible alone (race, nap pile, pair). Gems 200 to 78, no income.
One zone woke (only because the trader had its Wayseed on the day the run started; see item 4).

## Friction, ranked

Rank = how likely a new player stops, quits or learns the wrong thing. Each line: what, owner file, one-line backlog proposal.

1. **Dead end: the tutorial's food cannot be fed.** Step 2 says "give it the emberberry"; the Feed panel lists crops from `Save.d.crops` and
   prepared foods from `items`, and the tutorial puts emberberry (a crop) into `items`, so the panel is empty (shot 03). Everything after
   (toy step, first-day lines) waits behind it; the way out is a market purchase nobody is pointed to. Owner:
   `scripts/home/farm_tutorial.gd` `give_food` + `content/rules/farm_tutorial.json` `base.start_food` (and `home.gd` `_open_feed`).
   *Proposal: hand the starter food over as `kibble` (in `Care.FOODS`) or store crops in `crops`; the unmerged `ext/farm-first-kibble`
   fa63c25ad does the first.*
2. **Dead end: three of five first-day lines need a second Boki and nothing in the hour gives one.** Dash "needs two rested Boki", nap
   pile and pair need company, and the wild visitor needs 2 residents of the zone's group (`garden_visitor.json residents: 2`). The
   only other source is a 420-gem Rare Egg at the trader. Owner: `scripts/home/garden_visitor.gd`, `content/rules/garden_visitor.json`,
   `scripts/home/base_race.gd entrants`. **Fixed on ext/garden-second-boki:** base_mode opens the Shelter at stall level 1 (stray 20 gems, 200 on entry); asserted in `--garden-first-day-check`. *Original proposal: let a lone Boki draw the first visitor (`ext/garden-play-0246` 7a9d77741 sets
   `lone_residents 0`), or hatch two starters; and say in the Dash toast how to get a second Boki.*
3. **The tutorial blocks the thing it just asked for.** "Place a toy" came after "Feed it", but while Feed is open the Boki stays in the
   Lead state and ignores the toy for up to 10 minutes (here 579 s). Owner: `scripts/home/base_tut_lead.gd`,
   `scripts/home/base_life.gd` (line 220), `content/rules/farm_tutorial.json` base steps. *Proposal: free the toy step from the feed step
   (free_order) or let the Boki play while the step is `watch`.* **Fixed on ext/tut-garden-toy-free:** `BaseTutLead.tick` lets the led Boki go to a placed toy while "patch" or "eat" is open (once per Boki, then the lead resumes). `--garden-first-day-check` has a phase with the tutorial on and Feed open: before the fix your Boki never played in 240 s of farm time (the old 579 s was only its end), after it plays at the toy in 12 s (limit 60 s).
4. **The next zone depends on the calendar, not the hour.** The Wayseed is on the Drift Trader one real day in three
   (`market.json black_market wayseed_days 3`, price 110). On a day without it the second key cannot be had for up to 3 days, however well
   you play; the farm day is 5 minutes, so "day 3" in the pace check is three calendar days. The hub hint says only "A dark stone needs two
   keys: a Wayseed and a Boki leaning its way". Owner: `scripts/core/black_market.gd`, `content/rules/market.json`,
   `content/rules/garden_zones.json hub_hints`. *Proposal: a garden-only player's first zone Wayseed always in stock on day 1 (or in the
   starter bag), and the hint names the trader.*
5. **The Nook tile and the rule disagree.** Tile says "LV 5 NEEDED"; `NookRules.GROWN_LV` is 8. A player who reaches 5 is still refused
   (shot 05d). Owner: `scripts/home/home.gd:4652` `_pair_short`. *Proposal: print `NookRules.GROWN_LV` instead of a hard-coded 5.*
6. **Breeding is about 8-15 hours of this play away.** Level 8 is 2800 XP (100 x level); pets give 1 (2 if loved) per 20 s, meals 2-5;
   182-358 XP in the hour here, so 8-15 hours, with no fetch or drills tried. The pace tool flags the same (`garden_sim.py`: home-only 5 min a
   day reaches level 8 on day 29). Owner: `content/rules/garden_xp.json`, `scripts/home/garden_xp.gd`. *Done on ext/garden-xp-pace (numbers only, see docs/GARDEN.md): garden-only level 4 now 28 min (was 123), a 20 min a day home player's first egg day 6 (was 12, `garden_sim.py`). Original proposal: raise `pet`/`feed` XP
   and give toy play and Dash laps XP so the first hour reaches level 4; the proposal block in `garden_sim.json` is the target.*
7. **Toy play seems to give no XP.** The Boki played at the toy more than once in the hour, and the XP total is about what the pets and meals alone give (plays were not counted separately, so this is unconfirmed).
   Owner: `scripts/home/home_toys.gd` (line 197 only calls `FarmTutorial.event`). *Proposal: one
   `GardenXp.give(rec, "toy")` per play and a toast.*
8. **The first minutes are quiet.** Needs barely move: food 70 to 55 in 10 minutes, joy 100 while petted, nothing is hungry until about
   minute 30 (food 25 in a run with no meals). That is gentle, but with nothing to feed and no second Boki the first ten minutes are only petting
   and waiting for the patch (ripe at 8 minutes). Owner: `content/rules/snack_patch.json grow_secs 480`, `scripts/home/snack_patch.gd`.
   *Proposal: the first patch ripens in 60 s (the starter gift) so the Feed step is doable by minute 2.*
9. **No prompt that the toy and the patch are free or where.** The banner says "Press B, open Base and set a toy down"; the Snack patch is
   in the Garden tab at 0 gems and is not mentioned by any step, yet it is the only food source that keeps the Boki fed and leans it toward
   a zone. Owner: `content/rules/farm_tutorial.json base steps`, `scripts/home/farm_task_guide.gd`. *Proposal: add a "Plant the snack
   patch" step before "Feed it".*
   *Done on `ext/garden-free-toy-hint`: the toy step's line names both tabs (Play ball with its price, Snack patch free) and the two tiles glow green in
   the Build bar while that step is open (`marks` in the step; `hl` on the entry). The ball is not free: it costs 12 of the 200 starting gems.*
   **Fixed (ext/farm-tut-patch-step):** the base tutorial is now five steps: meet, **Plant the snack patch** (build bar, Garden tab,
   the patch tile lit by the spotlight like the trough tile in the farm tutorial), feed, toy, head out. The step ticks when the patch
   is down (or the Boki has already been fed); the Boki stays at your side for it. `farm_task_guide.gd` is the farm path's job
   guide and is retired in base mode, so it needed no change. Re-timed first hour: the patch is down at about 10 s of play (one
   build-bar visit, free), so the 8-minute ripening clock starts about 5 s earlier than in the played run and the first meal and the
   Feed and Toy lines still tick together at about 580 s; nothing else moves (item 8 is what would shorten that wait).
10. **(fixed on ext/farm-tut-ends) The tutorial never ended on its own.** Step 4 "Head out or stay" stays on the banner after an hour (shot 10), and its line runs past
    the 4/4 counter. Owner: `scripts/home/farm_tutorial.gd` `event` ("stay" is a button press only), banner width in
    `scripts/ui/`. *Proposal: finish the step when the first zone wakes or after the toy ticks, and wrap the banner text.*
11. **`base_mode` ships off.** On `main` a fresh save gets the full farm (chop, mine, build a house) and the garden tutorial is not shown at all;
    this whole hour only exists with the flag on (`farm_build.json base_mode`). Owner: `content/rules/farm_build.json`. *Proposal: flip it
    after items 1-3 are merged, in one commit with the checks.*
12. **Order of the first hour on `main`:** a new save does the hatch, the Relic pick and the combat tutorial before the garden; this run
    started after those. `ext/tut-first-hour-order` 989b739a5 reorders it; not played here.

## What worked (keep)

- The whistle (3 s, any distance on the island). Petting feedback (hearts, +joy). The market's Boki tab (kibble 6 gems). The first-day
  list is honest: five short lines and a +15 gem finish. The first zone looks like a different place (Ridge shot) and shows its goal.
- The two checks pass on `main`: `--garden-first-day-check` 0 failures; `--garden-unlock-pace-check` PASS.

## Proof

```
godot --headless --path . -- --garden-first-day-check     # FIRSTDAY DONE, failures: 0
godot --headless --path . -- --garden-unlock-pace-check   # UNLOCKPACE PASS (0 failures)
python3 tools/health.py --strict
python3 tools/gen_wiki.py --check
```

Not covered: the 3D look on a real GPU (jobs queued), fetch/training XP, real calendar days of the trader, the Nap pile except through the check.

---

# Re-played 2026-11-28 (origin/main c78b7cba28, `base_mode` on as shipped)

The 11-1x hour listed 11 problems. Most are fixed. This is the same hour played again on current main with the same kind of driver,
plus the five problems that are left, worst first. Analysis only: no game code changed.

## How it was played

- **Driver:** a scratch script (copy: [`garden_hour_1128.gd.txt`](shots/farm-first-hour-1128/garden_hour_1128.gd.txt), registered locally
  only, never committed to the registry). Fresh save, one hatched starter (trust 55), the tutorial on, the real farm
  (`main._hb_home()`), the real `Home._process` at a fixed 0.05 s step for 3600 s of **farm time**. It calls what the UI calls:
  `_pet_kin`, `_care_feed`, the build bar's `place_held`, `_open_feed`, the market and Nook panels, `BlackMarket.buy`,
  `Shelter.adopt`, `GardenZones.attune`, `_whistle`, `BaseRace.use`.
- **Clock:** the game stamps the snack patch and the wild visitor with unix time, so the driver moves those stamps back one step per
  step. The pet window is rolled by hand every 300 s (`care_day_s`). Care XP (`GardenXp._first_today`) pays once per **real** day
  (`garden_prizes.json day_s 86400`), so it pays once in this hour, as it would for a player.
- **Player:** efficient. Pets until the Boki has had enough (1-3 pats, `pet_react.json cap`), then stops. Places the free patch at once,
  the toy as soon as the banner says so, feeds when food is under 60, buys the Wayseed and adopts a stray at 120 s. Two feed policies:
  **wait** (gives only the food the banner names) and **kibble-first** (gives what the Feed panel lists).
- **Shots:** [`docs/shots/farm-first-hour-1128/`](shots/farm-first-hour-1128), software renderer (llvmpipe under Xvfb, not a GPU), so
  3D light differs. Same names as the 11-1x shots. Logs: [`run_log_wait_seed2.txt`](shots/farm-first-hour-1128/run_log_wait_seed2.txt),
  [`run_log_kibble_first_seed2.txt`](shots/farm-first-hour-1128/run_log_kibble_first_seed2.txt),
  [`run_log_hated_emberberry_full_hour_stuck.txt`](shots/farm-first-hour-1128/run_log_hated_emberberry_full_hour_stuck.txt).
- **Runs:** about 40 headless runs while building the driver (many were thrown away: a feed-spam loop, a glued player that walked its
  Boki off the island, an unclosed evolution card and a practice lap all froze the Boki; each was the driver, not the game). The numbers
  below are from the final driver: 6 wait runs and 18 kibble-first runs.
- **Forced (not play):** the whistle test (the Boki is teleported 14 m away first) and the Dash with two Boki (energy set to 90) are
  run at the end of the hour; the driver closes the evolution card when it opens.

## The hour, step by step (wait policy, farm seconds)

| # | Step | Farm time | What happened | Shot |
|---|---|---|---|---|
| 1 | Hub arrival | 0 s | 60 gems become 200 on first entry. Banner "This is your Boki. Walk up and say hello." Goals card: Feed your Boki, Play with a toy, Run your first race. Bag: 2 kibble, 1 tonic. | [01](shots/farm-first-hour-1128/01_hub.jpg) |
| 2 | Meet, plant the patch | 0 s | Meet ticks at once. The snack patch is free in Build > Garden, ticks the step, and the banner moves to "Feed it". | |
| 3 | Feed panel | 0 s | Banner: "give it the Emberberry". The Feed panel lists **Boki kibble x2 only**. The 3 starter emberberry sit in `items` and are not listed (problem 1). | [03](shots/farm-first-hour-1128/03_feed_panel.jpg) |
| 4 | Pet | 0-60 s | First pat: joy +5 to +12, trust +2, 15 XP. Pats past the Boki's cap (1-3 a farm day, 20 s apart): joy +0, trust +0, XP +0, no message (problem 4). | [04](shots/farm-first-hour-1128/04_pet.jpg) |
| 5 | First batch ripe | 59 s | The patch's first batch ripens in 59 s (was 8 min): 4 snacks plus 2 extras. The player feeds emberberry at 60 s: the Feed step ticks. | [07](shots/farm-first-hour-1128/07_patch_ripe.jpg) |
| 6 | Toy | 61 s placed, 12 gems | Toy step ticks at 69 s (the Boki played 8 s after it went down). "Head out or stay" ticks itself at 79 s: the banner is gone. | [05](shots/farm-first-hour-1128/05_toy.jpg) |
| 7 | Market | 120 s | Boki tab sells food. The note under the tabs still says an upgrade "opens: Shelter..." although Shelter is already a tab (problem 5). | [05b](shots/farm-first-hour-1128/05b_market.jpg), [05c](shots/farm-first-hour-1128/05c_market_boki.jpg) |
| 8 | Wayseed, stray | 120 s | The trader had the Glasswater Wayseed (110 gems) on this date; bought. A stray costs 20 gems at stall level 1: adopted. Goals become: first race, nap pile, "Raise Pip to level 3". | |
| 9 | Nook | 120 s | Both tiles say **LV 8 NEEDED**, the real gate. | [05d](shots/farm-first-hour-1128/05d_nook_alone.jpg), [12](shots/farm-first-hour-1128/12_nook.jpg) |
| 10 | Toy play | 69-3600 s | 138 plays x 5 XP = about 690 of the hour's 720 XP. Joy stays 95-100. Roam, Play, Nap, Chore and PlayWith all show. The "nap pile" first-day line ticked on its own. | [08](shots/farm-first-hour-1128/08_10min.jpg), [09](shots/farm-first-hour-1128/09_30min.jpg) |
| 11 | Wake the next zone | 2335-3040 s | Glasswater woke by feeding tidebloom when hungry: 2335-3040 s over the runs that logged it (this run 2800 s). | [zone](shots/farm-first-hour-1128/zone_glasswater.jpg) |
| 12 | Whistle (forced) | end | Boki 14 m away was beside the player in 2.0-5.1 s (was 3.0 s). | [06](shots/farm-first-hour-1128/06_whistle.jpg) |
| 13 | Dash, 2 Boki (forced) | end | 15-28 s run, race line ticks. With one Boki the Dash starts a practice lap. | [11](shots/farm-first-hour-1128/11_dash.jpg) |
| 14 | End of hour | 3600 s | Level 6-7 (515-780 XP in 6 runs), tutorial finished since 79 s, gems 58-88 (spent 12 toy + 110 Wayseed + 20 stray; the 15-gem first-day reward is not reached). Goals card: "Next: Run your first race 0/1". | [10](shots/farm-first-hour-1128/10_55min.jpg) |

Level 8 (pairing) needs about 1105 XP in total (`18 x L^1.5` summed over levels 1-7): about 1.6 h at this pace, so the Nook line is the
second hour's.

## The 11-1x list, one line each

| 11-1x item | Now |
|---|---|
| 1 Tutorial food cannot be fed | **Half.** The patch's first batch (59 s) gives a feedable emberberry; the starter 3 are still unlisted. See problem 1. |
| 2 Three lines need a second Boki | Fixed: stray 20 gems at stall level 1. Nothing *points* a player to it (problem 3). |
| 3 Tutorial blocks the toy | Fixed: toy ticks 8 s after it goes down. |
| 4 Next zone depends on the calendar | Not tested: the trader had a Wayseed on this date in every run. Same date, not independent. |
| 5 Nook text says Lv 5 | Fixed ("LV 8 NEEDED"). |
| 6 Breeding 8-15 h away | Better: about 1.6 h. |
| 7 Toy play gives no XP | Fixed: 5 XP a play, 93% of the hour's XP. |
| 8 First minutes quiet | Fixed: first batch at 59 s. |
| 9 No prompt for the free patch | Fixed (patch step). |
| 10 Tutorial never ends | Fixed: ends itself at 79 s. |
| 11 `base_mode` off | Fixed: `farm_build.json base_mode` true. |
| 12 Order of the first hour | Not played here. |

## The next five problems, worst first

Each line is backlog-ready: title | owner files | proposal | IMPACT, HARD.

1. **Feed step ticks only on a lean crop, but the Feed panel offers kibble.** The starter bag has 2 kibble (`farm_tutorial.json
   first_day.start_items`) and 3 emberberry in `items` (`base.start_food`); the panel lists the kibble and not the emberberry, and kibble
   does not tick the step (`FarmTutorial.detect` needs a Boki with a `lean`). A player who feeds the listed kibble fills the Boki
   (69 to 99, refused at 92 and over), and the step then waits for hunger: **ticked at 396-397 s in 14 of 18 kibble-first runs** (6.6 min,
   instead of 61 s), the Boki held at your side in the Lead state with joy 70 to 12-19 by 10 min. Shot 03 is the moment.
   Owner: `scripts/home/farm_tutorial.gd` (`give_food`, `detect`), `content/rules/farm_tutorial.json` (`base.start_food`,
   `first_day.start_items`), `scripts/home/home.gd` `_open_feed`.
   *Proposal: give the 3 starter emberberry as crops (`Save.d.crops`) so the panel lists them first, and tick "Feed it" on the first meal
   of any food (the lean change then shows on the first emberberry).* IMPACT 7/10, HARD 2/10.
2. **The tutorial's food may be one the Boki hates.** The hate is random per Boki. In 3 of 18 kibble-first runs the starter hated
   emberberry: the step ticked at 1269 s once and **never in the hour** twice (Boki food 9, joy 12 at 60 min, still in Lead, banner
   still on "Feed it"). Owner: `scripts/home/farm_tutorial.gd` `food()`, `Care.feed` (`hate`). *Proposal: name the lean snack the starter
   does not hate, or tick the step when the Boki refuses a hated food (it has then learned something).* IMPACT 5/10, HARD 2/10.
3. **Nothing points a one-Boki player to the Shelter.** Race (Dash), nap pile and pair need a second Boki; the Goals card lists the race at once. The
   only Shelter line is "No Boki: adopt a stray at the Shelter" (`farm_tutorial.json` line 331), shown with no Boki. A 20-gem stray is on offer
   from minute 0 (`Shelter.open_level` 1), but a new player is not told. Owner: `content/rules/farm_tutorial.json` (`first_day.rows`),
   `scripts/home/goal_tracker.gd`. *Proposal: give the race and nap rows a hint "Need a second Boki? Adopt a stray at the market's
   Shelter (20 gems)", shown while the roster has one Boki.* IMPACT 5/10, HARD 1/10.
4. **Pats past the cap pay nothing and say nothing.** Cap per farm day: playful 3, shy 2, proud 1, sleepy 2 (`pet_react.json`). A pat past the cap: joy +0, trust +0, XP +0; the only cue is that it looks at you (`PetReact._beat`). XP from care is once per **real**
   day (15 XP), so a player who pets for ten minutes earns what the first pat did. Owner: `scripts/home/pet_react.gd`,
   `content/rules/pet_react.json`. *Proposal: a "had enough, come back later" bubble on the first capped pat.* IMPACT 3/10, HARD 1/10.
5. **Two stale lines.** (a) The market note says "Upgrade the stall ... and it opens: Shelter, your stall and search" while the Shelter
   tab is already open at level 1 in base mode (shots 05b, 05c): `scripts/home/home_market.gd` `_next_level`, `Goods.rules()["stall"]
   ["levels"]`. (b) The Boki card's fallback line is always "is happy: take a trip, or place a toy", even at 55 min with a toy down
   since minute 1 (shot 10): `scripts/home/base_card.gd:90` `next_action`. *Proposal: build the note from `Shelter.open_level`; make the
   fallback name something not done yet (a toy, a trip, a stray, a pat).* IMPACT 2/10, HARD 1/10.

## What worked (keep)

- The patch's first batch at 59 s: the first minute now has a meal, a toy and a finished tutorial by 79 s (wait policy).
- Toy play pays: 138 plays and joy 95-100 all hour; the Boki cycles Play, Nap, Chore and PlayWith by itself.
- Whistle 2-5 s at 14 m. A lone Boki gets a practice lap on the Dash. The Nook says LV 8 NEEDED.

## Proof (2026-11-28)

```
godot --headless --import                                   # fresh worktree
godot --headless --path . -- --garden-first-day-check       # FIRSTDAY DONE, failures: 0 (no SCRIPT ERROR / Parse Error)
godot --headless --path . -- --garden-first-15-check        # G15 gaps: worst 0.0 s; G15 DONE, failures: 0
python3 tools/health.py --strict                            # HEALTH OK (registry unchanged vs origin/main)
python3 tools/gen_wiki.py --check                           # RED on main, not from this branch: docs/wiki/Class-Stone-Seer.md#kit and Rules.md out of date
```

Not covered: a real GPU render, real calendar days of the trader, a player who walks (the driver stands still), the evolution card's own flow.
