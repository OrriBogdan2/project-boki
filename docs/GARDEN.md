# The garden (the farm at home)

## Pace: playable without extraction

DECISIONS 2026-11-09: the game must be playable without extraction. Before this, a Boki got XP only
from expeditions (`Game.apply_result`, plus the dojo's rest XP after a run), so a garden-only player
never reached a first form. Now the farm gives kin XP too: `content/rules/garden_xp.json`, applied by
`GardenXp.give` through `Game.gain_xp` (the same level table, forms and mutations as a run).

| Action | XP |
|---|---|
| First feed, first pat, first game of fetch of each Boki each day (`care`) | 5 each, then 0 |
| Training yard, per point scored | 1 |
| A played Dash, Shove, Seek or Volley (backed Boki) | 3 |
| ...a win | 5 |
| ...the day's first win in that game | 60 |

Level n to n + 1 needs 50 x n XP, flat at 1,000 from level 20 (`curve` in the same file; `Game.xp_need`).
So level 4 is 300 XP and level 8 is 1,400. Relay and Show Ring pay no XP.

Stat gains are unchanged. An expedition gives 40, +40 for a win, +10 a knock.

**Measured** with `--garden-pace-check` (a fixed play model on the real Care, Game and Evo code; the
assumptions are in the `pace` block of the rules file): time to the first form (level 4, 300 XP).

| Player | Minutes |
|---|---|
| Garden-only (feed, pet, fetch, drill; naps when worn out; no games) | 123 |
| Also runs expeditions (12 min each, half won, 1 knock, 3 min of garden between) | 76 |
| Ratio | 1.63 (limit 2.0, `pace.max_ratio`) |

The first tuning paid per action (feed 2, pat 1, fetch 3, 100 x level): a ratio of 1.6 at 229 and 141 min.
The sim fit replaced it (below): care pays once a kind a day, the games carry most of the XP, and the
curve is halved, so a garden-only first form is 123 min and the runner's 76. The check fails above 2.0x.

Default taken: "about 2x" is the limit. The alternative is a tighter limit (1.5x), which means
roughly 1.5x the XP above.

## Breeding pace (measured, nothing applied)

Gap 2 of docs/GARDEN_PLAY_0246.md: the Nook wants two Grown (level 8) Boki who are friends. Printed by
`--garden-pace-check` after the first-form line (same play model, same real Care, Game and NookRules.friends code,
one seed, repeatable). Minutes of play. The wild visitor is the second Boki: its expected wait is
`check_s / chance` (200 s) plus three favourite meals, counted in garden time only, so it comes in the first
garden minutes of either player; it arrives at trust 50. The player works the starter to Grown, then the visitor.
"With 1 run a session" = a 12 min expedition (half won, 1 knock) then 3 min of garden, over and over; the run's XP
goes to whoever is being raised. "Friends" is the first time trust is 50 or more on both (the starter's trust
climbs 1 a pet and 2 a meal, one of each per 12.5 s).

| Player (shipped numbers) | Second Boki | Grown (starter) | Friends | First egg |
|---|---|---|---|---|
| Garden-only | 5 min | 669 min (11 h) | 33 min | 1346 min (22 h) |
| 1 expedition a session | 29 min | 320 min (5.3 h) | 108 min | 648 min (11 h) |

The model plays care (once a kind a day, so mostly from the training yard) and runs; it does not play the garden
games (the sim in `tools/garden_sim.py` has those). Re-measured after the XP rework (care once a day, games paid,
halved curve: 50 x level); the first version of this table, on the old per-action XP and the 100 x level curve, was
2230 and 1266 min.

The 30 minute target is still missed (half a day to a day of play for the egg): a Grown Boki needs 1400 XP, and the
Nook needs two. The second Boki and friends are not the bottleneck (minutes); only levels are. That is why no
friend-threshold option is listed: the threshold would change nothing.

Data-only options (`breed_options` in content/rules/garden_xp.json, read by the check, not applied anywhere;
`xp_mult` scales care, drill and the game rewards):

| Option | Grown | Garden-only: Grown / first egg | 1 run a session: Grown / first egg |
|---|---|---|---|
| xp_x3 (every XP times 3) | 8 | 213 / 439 min | 320 / 632 min |
| grown_5 (the Nook asks level 5) | 5 | 229 / 467 min | 125 / 243 min |
| xp_x2_grown_6 | 6 | 165 / 345 min | 174 / 340 min |

Even the best option is 4 to 6 hours of play to a first egg. A 30 minute egg needs both a far larger XP rate and a
Grown level near 2 (roughly 10x the XP, or a Nook that takes Youngling kin); that is a design call.
## Base-only breeding

Hold a shaping item (Hold on it in the bag) and walk up to a Boki, or point at its row in the Boki's feed menu:
`ItemPreviewCard` (scripts/ui/item_preview_card.gd) slides in with every change drawn as a ghost. It shows the stat
bars with the real gain after caps, the budget and lean rings, and on a branching line the path meter (both finals
as silhouettes, pips before and after, the verdict, and a Why? list of pip sources). For a second the Boki tries the
change on: its new colour or the path token. While the card is up it ticks softly (`garden_item_tick`, every
`GardenSfx.TICK_S`). Interact there gives the item, and the give plays its family's cue at the Boki (docs/AUDIO.md);
walking away from that Boki ends the hold, and the item stays in the bag. The card does no math of its own: it reads `GardenItems.preview`/`after`,
`EvoPath.pips` and `StatBudget`. `ItemHold` (scripts/home/item_hold.gd) owns the held item; distances and times are
in content/rules/garden_items.json `hold`. Check: `--item-card-check`; shots: `--item-card-shots --shots-dir=<dir>`.
`--base-breed-check` plays a fresh base_mode save that never leaves the base through every gate of the Nesting Nook (briefs/design/GARDEN.md 6) and prints the play minutes of each. Measured: hatch 0; friends 6 min (bond 0.52 after a ball and a nap, trust 65); egg ready 10 min after it is laid; a parent can lay again after 20 min. Both Grown takes about 11 h per Boki on farm XP (667 min) and 5.3 h with runs (319 min), ratio 2.09 against `pace.grown_max_ratio` 2.2 (main's halved level curve and once-a-day care XP made both faster but the ratio wider than the first-form `max_ratio` 2.0; the Grown limit is its own number, a default taken, the alternative is to raise garden XP), so the baby comes long after two sessions (`BREED OVER`). Fixed with data: the Nesting Nook and the Training post open from the start and cost gems only (45 and 30; they wanted farm level 3 and wood, fibre and stone that base_mode cannot get). Fixed in code: `NookRules.friends` read the -1..1 bond against 50, so no pair with a recorded bond could ever be friends. Still open: a second Boki and the Grown pace (docs/DEBT.md).

## Expedition loot into the garden

DECISIONS 2026-11-09: the garden and extraction feed each other. Before this no match drop was a garden item (drops were
gear, treasure, the Rare Egg and Wayseeds). A boss's lair pile now also holds one of the four stat bites (Thumpnut, Shellbark
Chew, Zipseed, Hushpearl) with `lair_drop.chance` in `content/rules/garden_items.json`. They ride the pack as treasure marked
`bag` (`Loot.VALUABLES`, `Loot.is_bag_item`, like the Wayseeds), come home into the garden bag (`Econ._store`), and are eaten from
the feed menu with the exact preview. The use writes the Boki card's journal line (`CareJournal` -> `JournalCard`):
"ate Thumpnut: Power +3 (4 to 7)". `--garden-items-check` (loot part) proves the whole path; `--loot-nudge-shots` shows the card.

## Balance: 30 days for four players

`python3 tools/garden_sim.py` plays 30 garden days, 200 seeds each, for four players (5 minutes plus a run, 30 minutes plus two runs, home only 30, home only 5) on the live care, prize, item, evolution, toy and race rules (`content/rules/garden_sim.json` holds the sim's own guesses). Every number must sit inside `bands` in that file; `--garden-sim-check` and the brief `briefs/design/GARDEN_MODERN_BALANCE.md` (tables regenerated with `--write`) keep it so.

| Band | Range | Why |
|---|---|---|
| First form step (level 4), median day | 1 to 10 | Everyone gets a first form inside the first week and a half |
| First evolution (level 8), garden XP only, median day | 3 to 14 | A home-only player still evolves (DECISIONS 2026-11-09), inside two weeks |
| Budget of 240 full, day (where it fills) | 7 to 30 | Never trivial |
| Stat total on day 30 | 216 to 240 | Even five minutes a day nearly fills it |
| Gems a day | 43 to 300 | At least a weekly Wayseed (300 / 7) so home-only players reach every zone; at most one a day |
| Joy, mean over a visit | 50 to 90 | Above sulky, never always full |

Before (the stack as it stood) and after, per player (before / after):

| Player | Evolution day (Lv 8, garden XP) | Stat total d30 | Gems a day | Joy |
|---|---|---|---|---|
| 5 min (+1 run) | 27 / 12 | 236 / 240 | 77 / 86 | 48 / 52 |
| 30 min (+2 runs) | 7 / 5 | 240 / 240 | 173 / 256 | 50 / 51 |
| home only, 30 min | 8 / 5 | 240 / 240 | 92 / 175 | 50 / 51 |
| home only, 5 min | 29 / 14 | 208.5 / 234 | 36 / 45 | 48 / 52 |

Out of band before: 5 min and home 5 evolution (day 27 and 29), home 5 stat total (208.5), home 5 gems (36), joy at 5 minutes (47.5). What changed:

- `toys.json` `joy_gain` 10 to 14: a toy play lifts a Boki's joy more, so a short visit leaves it above the band floor.
- `base_race.json` `gems_win` 6 to 14: a won game pays enough for a home-only 5-minute player to afford a weekly Wayseed.
- XP, now live (`garden_xp.json`; `garden_sim.json` no longer carries it, the sim reads the file): a played game 3, a win 5, the first win of the day 60, the first care of each kind 5, curve 50 x level flat from level 20.

Sim vs live (the sim's own fitted proposal against what is built, the same numbers; `--garden-sim-check` reads the live file, so they cannot drift):

| Number | Sim fit | Live before this change | Live now |
|---|---|---|---|
| Level curve | 50 x n, flat from 20 | 100 x n, no flat part | 50 x n, flat from 20 |
| Care | 5, first of 3 kinds a day | feed 2 (5), pat 1 (2), fetch 3 (6), every action | 5, first of feed, pat, fetch a day |
| Dash, Shove, Seek, Volley | 3 / 5 / 60 | 0 | 3 / 5 / 60 (play / win / first win of the day) |
| Training yard | not modelled | 1 a point | 1 a point |
| Expedition (lead Boki) | 40 + 40 win + 10 knock | same | same |

Expedition XP still fits: the halved curve makes a won run (90 XP) a level or two early on (level 8 is about 16 won runs, was 31), and the sim's expedition-only player (105 XP a day at 5 minutes, 350 at 30) stays near the garden's 80 to 290, so neither road is a dead end. Existing saves need no migration: `xp` and `level` keep their meaning, a Boki whose stored XP now exceeds its need levels up on its next gain, and `rec.xp_day` (the day of each first care) is created when read. The drill is unmodelled and adds up to 1 XP a point on top.

## Open questions: gates for a player who never extracts

Found by `--garden-only-pass-check` (30 minutes of garden time on a fresh save that skips the match
tutorial and never starts an expedition; it logs every line that points at an expedition and fails on a
new one) plus a read of the garden code. Text and order nags are fixed on this branch (below). These
need a design call:

1. **Old Pell's Black Market never stands on a new island.** `home.gd _fs_arrivals` places it (and the
   Challenge House) only once `matches >= 1`. The zone cards say a Wayseed comes from the Black Market
   (`black_market.gd` stocks one for the next locked zone every `wayseed_days`), so a player who never
   extracts keeps one zone of five: after 30 min the check prints `Black Market placed false, zones open
   1 of 5`. `--garden-unlock-pace-check` does not see it: it buys the Wayseed without the building.
   Fix options: (a) in base mode `_fs_arrivals` places the Black Market straight away (one condition;
   the Challenge House stays after the first expedition); (b) a Wayseed stall at the hub's Waystone.
   Default if nobody decides: (a).
2. **Hunter unlock goals in the Goals card.** Eleven Hunters unlock by match challenges ("Knock 3 enemies
   into walls") and show as `unlock` rows after the home rows. A Boki at the level cap loses its
   "Raise ... to level N" row, and then the first line of the card is one of these. Options: hide the
   `unlock` and `mastery` rows while the save has no match; or show them as "away" rows. Default: keep.
3. **The second starter Hunter waits for the first finished expedition** (`ClassUnlock` bonus). It has
   no goal row now (it printed an empty one, fixed), but nothing at home ever opens it. Fine if Hunters
   are an expedition feature; say so in the Hunter picker if not.
4. **The match tutorial comes before the garden** unless the player presses "Skip the tutorial" on the
   naming card. Skipping is offered; whether the card should say "go straight to the garden" is a
   wording call.
5. **Held Boki and the Black Market ransom** count expeditions ("sold on after your next expedition").
   Only a lost Boki goes there, so a home-only player never sees it.

Fixed here (text only): the zone card names Old Pell's Black Market first and no longer says "once a
week" (it is every 3 days); the egg toast says "hatches in about N min" (it said "after your next
expedition"; an egg hatches by the clock at home); the empty seed list says to buy at the stall first;
the empty Hunter row in Goals is gone.

## A new Boki from the Shelter (base_mode)

DECISIONS 2026-11-11: the Shelter always has strays, so adopting is a moment at home, built from what
exists. The new Boki steps out at the zone's pad (the stone, `HubWaystone.pad`); the Boki near by come to
look (`BaseLife._arrived` and `ComeLook`) and the first to reach it keeps "was there the day <name> arrived".
It is shy for its first farm day (`BaseShy`, `base_life.json` "shy": 300 s of farm time, the length of one day):
it keeps to the island's edge, joins no tag and no toy and is nobody's play mate, then cheers up and goes to
join in. `rec["shy_s"]` holds the time left; a Boki without it is settled, so old saves need no migration.
Default taken: the shy day runs only while its zone is loaded. The alternative is real time, which would let a
closed game cure it. Checked by `--base-stray-check`.

## Glint Fishing looks
`scripts/home/glint_fx.gd` draws four small looks on the water with the shared cel pass (`shaders/glint_water.gdshader`,
recipes in `content/rules/glint_fishing_vfx.json`): a ripple where the bobber lands (on a glint or in empty water), rings
that hold wide while you wait and close in as the ears go up so they meet at the bite (the same warning the ears give,
so Focus still sets it), one sharp splash on the bite (the moment to press), and one glint on a catch, sized snack, item
or rare (rare is gold). Each is one quad, one at a time, with no particles. `--glint-fishing-check` covers them;
`--glint-fx-shots --shots-dir=<dir>` (through `jobq submit --needs gpu`) writes the sheet `looks.png`.
Default taken: the rings' timing is tied to the ears, not to the hidden bite time, so they never warn earlier than Focus
allows. The alternative (rings closing over the whole wait) would leak the bite to a player with no Focus.

## Shaping items: the preview card

Hold a shaping item (Hold on it in the bag) and walk up to a Boki, or point at its row in the Boki's feed menu:
`ItemPreviewCard` (scripts/ui/item_preview_card.gd) slides in with every change drawn as a ghost. It shows the stat
bars with the real gain after caps, the budget and lean rings, and on a branching line the path meter (both finals
as silhouettes, pips before and after, the verdict, and a Why? list of pip sources). For a second the Boki tries the
change on: its new colour or the path token. Interact there gives the item; walking away from that Boki ends the
hold, and the item stays in the bag. The card does no math of its own: it reads `GardenItems.preview`/`after`,
`EvoPath.pips` and `StatBudget`. `ItemHold` (scripts/home/item_hold.gd) owns the held item; distances and times are
in content/rules/garden_items.json `hold`. Check: `--item-card-check`; shots: `--item-card-shots --shots-dir=<dir>`.
