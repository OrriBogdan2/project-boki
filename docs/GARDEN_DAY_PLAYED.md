# One garden day, played (2026-11-11)

Tree: `ext/release-integ-0245` 272368589 (the 0.24.5 line; `origin/main` is 0.24.4 and has no garden code), plus the
fixes below. The run is `--garden-day-played-check [--shots-dir=<dir>]` (`tools/garden_day_played_check.gd`): the
`--base-demo` seed (`BaseDemo.save()`, Cinderstep opened as the second zone), driven through the real screens
(`Game.goto`, the feed menu, the Dash post, the Nook panel, the zone cards, the Waystone, Stump Shove, the away card).
Headless it takes about 55 s and prints `GDAY ok/FAIL/NOTE` per beat; last run 0 failures. A throwaway `XDG_DATA_HOME`
and `Save.no_write`: the real save file's md5 is checked unchanged.

## The day, beat by beat

| # | Beat | Result | Notes |
|---|---|---|---|
| 1 | Arrive (demo, Bramblebank) | works, one confusing screen | row A below |
| 2 | Hold an item to preview | works | Zipseed row in the feed menu shows the exact line ("Speed +3 (0 to 3)"); reading it changes no stat, need, lean or level. There is no hold gesture: the preview is always printed on the row |
| 3 | Feed it | works | stat moves by the preview, item leaves the bag, journal line written |
| 4 | Game 1, Bramblebank: the Dash | works | result card with prize rows; 5 races at ~4 s each (4x time) |
| 5 | Win a cup | works, hard to reach | Dash Crown after 3 straight wins; row E |
| 6 | Pair two Boki in the Nook | **break, fixed** | rows B and C |
| 7 | Move a Boki between zones | works | Move to... lists the zones, Moss walks to the pad (12 s) and goes to Cinderstep; the egg stays in the Nook |
| 8 | Game 2, Cinderstep: Stump Shove | works | hub hop, then Cinderstep: Pip and Moss only, a bout in about 3 s, gems paid (4 for a backed win, 1 otherwise) |
| 9 | Away 8 h, come back | works, one break fixed | card lists gifts, toy training, the ready egg; never says lost or starved; lowest food 24; row D |

## Breaks and dead ends

| Row | What | Status |
|---|---|---|
| A | The demo opens with a "While you were away: A Rare Spore Egg is ready to hatch" card over the whole base (already row 13 of `docs/GARDEN_SLICE_CHECK.md`, still there). Any demo film or first screenshot hides the Boki | Follow-up 1 |
| B | The Nook's "Friends" gate compared the base's bond (`rec.bonds`, -1..1) with 50, so in a base no pair could ever be friends: "Pip and Moss need to be friends" at bond 0.9 | **Fixed** (`NookRules.friends` reads `base_life.friend_at`, 0.5; `ext/farm-garden-default` has the same hunk, so it merges clean); `--nook-check` moved to the -1..1 scale |
| C | The Nook tile said "Lv 5 needed" while Grown is level 8 | **Fixed** (`home.gd` `_pair_short` prints `NookRules.GROWN_LV`) |
| D | Away card: a Boki living in Cinderstep trained "at the toys" of the zone you arrive in (Bramblebank's toys, +3 focus on the card) | **Fixed** (`GardenAway._toys` skips Boki that do not walk the arrival zone). The check asserts it |
| E | The Crown needs 3 wins in a row against rivals whose stat TOTAL is at least 1.1x yours, but the Dash is run on Speed and friends run together (pace pull), so the demo's friend pair is a coin flip against each other. With near-equal Boki (Pip 20 each, rivals 1.15x) one try gave the Crown in 5 races, another 5 wins in 30 races and no Crown; with Pip fast (Speed 70, friend bonds cleared) it took 3 races. | | Follow-ups 3 and 4 (balance, owner) |
| F | A fresh Boki cannot pair on day one: Grown is level 8 and the first-day list asks for "Pair two Boki" (known: GARDEN_SLICE_CHECK row 11; the tile now at least says Lv 8) | Follow-up 5 |
| G | The Heirloom Thread (a nest item) has no row in the feed menu and nothing there says it works only in the Nook | Follow-up 6 (low) |
| I | Every zone arrival shows its own "While you were away: A Rare Spore Egg is ready to hatch" card for the same egg (it showed again on arriving in Cinderstep, though the Nook is in Bramblebank), until the egg is hatched | Follow-up 7 |
| H | The away card is one flat list with two zones open: gifts and toy lines are not under zone names, a gift can come from a Boki living in another zone, and the other zone's toys never train while away (the shared `away_seen` is used up by the first arrival) | Follow-up 2 |

## Follow-up tasks (not done here)

1. Demo: skip or close the first-arrival card in `BaseDemo.stage`, and assert no panel open at 5 s in `--base-demo-check`.
2. Away card by zone: group the `GardenAway` gift/toy/patch lines under zone names when two zones are open, and run each zone's toy training on arrival in that zone (per-zone `away_seen`).
3. Dash/Cup: make the weekly Crown reachable by intent. Either compare the game's own stat (Speed for the Dash) in `GardenPrizes._cup`, or show the Crown rival's total on the Dash card.
4. Same as 3 for friends in a race: say on the card that friends pull together.
5. First-day list: move "Pair two Boki" behind Grown (apply `garden_sim.json` proposal).
6. Feed menu: a one-line "Goes in the Nook" row for the nest items.
7. Ready-egg line: show it once per ready egg, not on every zone arrival (`CareJournal.arrival` adds it each time).

## Shots

Frames from `--garden-day-played-check --shots-dir=` with a renderer, in `docs/shots/garden-day-played/`:
`feed_menu.jpg` (beat 2: the exact preview lines, Bramble Honey once per lean type), `dash_card.jpg` (beat 4: result, gems,
prize, "Cup: beat the Sprout round"), `nook_pair.jpg` (beat 6: Lv 8 and picked, "Lv 8 needed" tags on the others, the
pair button), `move_cards.jpg` (beat 7), `hub.jpg`, `cinderstep.jpg` (beat 8: Moss and Pip, return pad), `shove_card.jpg`
(also shows the ready-egg card again, row I), `away_card.jpg` (beat 9).
The GPU queue was 60 deep (jobq job 20261111-195322-08251, `--needs gpu`, still queued after 34 min), so these were
rendered on rpc3 under `xvfb-run` with the OpenGL driver; the job's own frames will land in `/home/boki/jobq/done/<id>/out`
if it runs. The run takes 18 frames; only these eight are committed.

## Checks

`--garden-day-played-check` 0 fail; `--nook-check` 0, `--garden-daily-check` 0, `--garden-first-day-check` 0, `--nest-items-check` 0;
`--old-saves-check` 0 (files from `ext/verify-garden-save-chain` put into the tree for the run, not committed);
`python3 tools/health.py --strict` OK; `python3 tools/gen_wiki.py --check` OK (50 unchanged).
