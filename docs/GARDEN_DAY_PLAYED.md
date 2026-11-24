# One garden day, played (2026-11-11; replayed on main 2026-11-23, see the end)

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
| A | The demo opens with a "While you were away: A Rare Spore Egg is ready to hatch" card over the whole base (already row 13 of `docs/GARDEN_SLICE_CHECK.md`, still there). Any demo film or first screenshot hides the Boki | **Fixed** (`BaseDemo.stage` sets `arrivals.quiet`, so no arrival card opens; `--base-demo-check` asserts no panel at 5 s). The demo now places the Nook only when the hub doesn't hold it (base mode: the egg waits in the hub's Incubator), and the check accepts that; `--base-demo-check` is all green |
| B | The Nook's "Friends" gate compared the base's bond (`rec.bonds`, -1..1) with 50, so in a base no pair could ever be friends: "Pip and Moss need to be friends" at bond 0.9 | **Fixed** (`NookRules.friends` reads `base_life.friend_at`, 0.5; `ext/farm-garden-default` has the same hunk, so it merges clean); `--nook-check` moved to the -1..1 scale |
| C | The Nook tile said "Lv 5 needed" while Grown is level 8 | **Fixed** (`home.gd` `_pair_short` prints `NookRules.GROWN_LV`) |
| D | Away card: a Boki living in Cinderstep trained "at the toys" of the zone you arrive in (Bramblebank's toys, +3 focus on the card) | **Fixed** (`GardenAway._toys` skips Boki that do not walk the arrival zone). The check asserts it |
| E | The Crown needs 3 wins in a row against rivals whose stat TOTAL is at least 1.1x yours, but the Dash is run on Speed and friends run together (pace pull), so the demo's friend pair is a coin flip against each other. With near-equal Boki (Pip 20 each, rivals 1.15x) one try gave the Crown in 5 races, another 5 wins in 30 races and no Crown; with Pip fast (Speed 70, friend bonds cleared) it took 3 races. | **Fixed** (`ext/garden-crown-intent`): `GardenPrizes._cup` compares the game's own stat (`stat` in `garden_prizes.json`: Speed for the Dash, Power for the Shove, Focus for Seek and Echo, `best` for the Show); the Dash rival is the fastest runner, and the Dash card says "Friends pull together" when friends ran. Wins to the Crown, demo seed, Pip Speed 70 (`--garden-day-played-check`, solo runs): before (rivals Speed 8, total 1.15x) the Crown came in 4 races (3 wins) in 3 of 3 runs; after (rivals Speed 1.1x of 70) it came in 4 races in 2 runs and not at all in 24 races in 2 runs (5 and 7 races won): the Crown is now a Speed race, so train Speed | Follow-ups 3 and 4 done |
| F | A fresh Boki cannot pair on day one: Grown is level 8 and the first-day list asks for "Pair two Boki" (known: GARDEN_SLICE_CHECK row 11; the tile now at least says Lv 8) | **Fixed** (`farm_tutorial.json` row `pair` has `needs_grown`: `GardenFirstDay.rows` shows it only once a roster Boki is level `NookRules.GROWN_LV`; asserted in `--garden-first-day-check`) |
| G | The Heirloom Thread (a nest item) has no row in the feed menu and nothing there says it works only in the Nook | **Fixed** (`GardenItemRows.add_bag` lists each nest item in the bag with its `desc`, "Goes in the Nook", and no Feed button; `--nest-items-check` asserts it for every item of kind nest; Hatchling Down is eaten, so it keeps its Feed row) |
| I | Every zone arrival shows its own "While you were away: A Rare Spore Egg is ready to hatch" card for the same egg (it showed again on arriving in Cinderstep, though the Nook is in Bramblebank), until the egg is hatched | Follow-up 7 |
| H | The away card is one flat list with two zones open: gifts and toy lines are not under zone names, a gift can come from a Boki living in another zone, and the other zone's toys never train while away (the shared `away_seen` is used up by the first arrival) | **Fixed** (`GardenAway.mark` keeps `Save.d["away_zone"]` per zone; gifts come only from Boki that walk the arrival zone; the lines sit under the zone name via `ZoneAway.grouped`). Beat 9 asserts both |
| J | Back after 2 h, 24 h or 7 days the garden opened a 520 px "While you were away" panel with a dimmed backdrop over the Boki | **Fixed** (`ZoneAway.card`: in the garden the return is the HUD card's one line, `BaseCard.away_line`, with no zone name as its first fact; the classic home keeps its card). Work is capped per return (`Work.ASSIGN` `cap`, `AWAY_MAX` 2 h), credited once, and a clock moved back credits nothing: rows in `--garden-daily-check` |

## Follow-up tasks (not done here)

1. Demo: skip or close the first-arrival card in `BaseDemo.stage`, and assert no panel open at 5 s in `--base-demo-check`.
2. ~~Away card by zone~~ done (row H).
3. ~~Dash/Cup: make the weekly Crown reachable by intent. Either compare the game's own stat (Speed for the Dash) in `GardenPrizes._cup`, or show the Crown rival's total on the Dash card.~~ done (row E).
4. ~~Same as 3 for friends in a race: say on the card that friends pull together.~~ done (row E).
5. ~~First-day list: "Pair two Boki" behind Grown~~ done (row F).
6. ~~Feed menu: a one-line "Goes in the Nook" row for the nest items~~ done (row G).
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


## Replay on today's main (2026-11-23, `ext/farm-garden-day-replay`)

Many garden branches merged since the first run (zones, Fetch Cup, rivals, placement clearance, the Dash and Shove
practice laps). `--garden-day-played-check` now also plays the nap, the food bowl, the Fetch Cup and the hatch, and
prints `GDAY TIME <what>: N s` (game seconds, the 4x time scale counted) for each; a beat that does not end inside its
cap is `GDAY FAIL STALL`. `--beats=food,nap,fetch,...` runs just some beats (all when absent). Headless, about 2.5 min.

**Before** (old check on main 05d78b9e87): 2 FAIL in 7 beats, then the check stopped (`GDAY FAIL a result card follows
the first race`, `Stump Shove starts at the stump`). Neither was a game bug: the first Dash race and the first Shove
bout are practice rounds (no card, no gems; a press ends them), and the check had no word for them. The check also never
reached hatch, nap, food or the Fetch Cup (the demo has no Training post, so no toss mat). **After**: 56 ok, 0 FAIL
(three green full runs in a row after the last change); the check handles the practice rounds and places a Training post.

| Beat | Seconds (game) | Verdict |
|---|---|---|
| Dash lap (practice / paid) | 4 (a press ends it) / 14 to 18 | ok. Crown: 3 of 19 races won and crowned in one run; 6 and 7 of 24 won, no Crown, in others (row E: a coin flip at 1.1x, by design) |
| Fetch Cup round, then its card | 61 to 63; card 6.0 | ok, pays 1 to 3 gems. Needs the Training post (30 gems): the demo base has none |
| Hungry Boki to the bowl (asleep or not) | before 45 and 49 (napping Moss, Ash); after 4 to 12, worst 34 | **stall fixed**, see below |
| Nap: lies down / wakes rested | 4 to 10 / 30 (82 once, bed walk) | ok |
| Stump Shove: practice / bout / card | 0.1 / 4 to 22 / 6.0 | ok (22 s once: the bar waits for the marker) |
| Zone move (walk to the pad) | 0.3 to 3.2 | ok |
| Egg hatch to the Boki's card | 15.6 | ok, naming then closes the panel (the check names it and the screen is clear) |
| Away 8 h, both zones | per-zone cards, lowest food 24 | ok |

**Stalls found.** One real one, fixed: a hungry Boki that was asleep (a 20 to 40 s day nap) or in a game of tag
(up to 40 s) ignored a snack dropped in the bowl until it woke, so it reached food after 45 to 49 s. `FeedBowl.drop`
now calls `BaseLife.hungry_wake`: a hungry day napper or tag player gets up at once (night sleepers sleep on till dawn);
measured with two napping Boki, 45.4 and 48.6 s before, 7.2 and 8.4 s after. A second, smaller one, fixed: a hungry Boki
that had wandered more than 9 m from the bowl never answered it (one sat in Roam, food 8, 10 m away, for 120 s).
`FeedBowl.reach(food)` now grows from 9 m (just hungry) to 27 m (starving).
A third, found on the integration tree (`ext/stuck-integ-4409db43`), fixed: a hungry Boki with low joy was sent to a
toy (`HomeToys.pick`), dropped from it the next frame (food under 30 is "busy"), and kept the toy's 30 s think timer, so
it stood in Roam ignoring the bowl, 30 s at a time; a hungry Boki could also be pulled into tag. 2 of 6 full runs
failed the bowl row before (Moss 64 s; Moss 104 s and Rocky never), 6 of 6 green after (worst 14.4 s).

**Not fixed, listed.**

| Item | Seconds | HARD | BLOCKS |
|---|---|---|---|
| A starving Boki more than 27 m from the bowl, or on another island, still never answers it (the pantry fallback needs a snack the patch grows) | never | 4/10 | 2/10 |
| A Boki that hates the only snack in the bowl stays hungry (by design; Hand-feeding works) | never | 3/10 | 1/10 |
| Night: sleepers sleep till dawn, hungry or not | up to a night (150 s) | 3/10 | 1/10 |
| Arrival in Cinderstep can play a waiting evolution (Pip busy, then a "changing" card): the Shove is blocked until it closes (seen in some runs, not timed) | few s + a click | 2/10 | 2/10 |
| The demo seed opens with the "While you were away" card over the base (the check's NOTE; `BaseDemo.stage` only quiets it after the first build) | one click | 1/10 | 1/10 |
| Follow-ups 6 (Heirloom Thread has no feed row) and 7 (ready-egg card on every zone arrival) | n/a | 2/10 | 1/10 |
| `--feed-check` is flaky on main (1 and 4 failures in 3 runs of the unchanged tree; 0 failures in 7 runs with this branch) | n/a | 3/10 | 2/10 |
| `docs/wiki/Rules.md` was out of date on main (base_life rules changed, wiki not regenerated); regenerated here | n/a | 1/10 | 1/10 |

Checks on this branch: `--garden-day-played-check` 0 FAIL (56 ok); `--base-breed-check` 0 failures (both Grown 488 min,
the baby 498 min: the known pace `BREED OVER`, GARDEN.md); `--feed-check`, `--base-life-check`, `--nest-items-check`,
`--nook-check`, `--fetch-check`, `--garden-first-day-check` 0; `python3 tools/gen_wiki.py --check` OK;
`python3 tools/health.py --strict`: see the PR (two files, `warden_props.gd` and `camp_clear_check.gd`, were already over the
style ratchet on main).
