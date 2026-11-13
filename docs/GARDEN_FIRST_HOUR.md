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
   `scripts/home/base_race.gd entrants`. *Proposal: let a lone Boki draw the first visitor (`ext/garden-play-0246` 7a9d77741 sets
   `lone_residents 0`), or hatch two starters; and say in the Dash toast how to get a second Boki.*
3. **The tutorial blocks the thing it just asked for.** "Place a toy" came after "Feed it", but while Feed is open the Boki stays in the
   Lead state and ignores the toy for up to 10 minutes (here 579 s). Owner: `scripts/home/base_tut_lead.gd`,
   `scripts/home/base_life.gd` (line 220), `content/rules/farm_tutorial.json` base steps. *Proposal: free the toy step from the feed step
   (free_order) or let the Boki play while the step is `watch`.*
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
   day reaches level 8 on day 29). Owner: `content/rules/garden_xp.json`, `scripts/home/garden_xp.gd`. *Proposal: raise `pet`/`feed` XP
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
10. **The tutorial never ends on its own.** Step 4 "Head out or stay" stays on the banner after an hour (shot 10), and its line runs past
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
