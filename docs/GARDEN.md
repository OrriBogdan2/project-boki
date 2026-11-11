# The garden (the farm at home)

## Pace: playable without extraction

DECISIONS 2026-11-09: the game must be playable without extraction. Before this, a Boki got XP only
from expeditions (`Game.apply_result`, plus the dojo's rest XP after a run), so a garden-only player
never reached a first form. Now the farm gives kin XP too: `content/rules/garden_xp.json`, applied by
`GardenXp.give` through `Game.gain_xp` (the same level table, forms and mutations as a run).

| Action | XP |
|---|---|
| Feed (favourite food) | 2 (5) |
| Pet, once per 20 s (favourite play) | 1 (2) |
| Fetch (favourite play) | 3 (6) |
| Training yard, per point scored | 1 |

Stat gains are unchanged. An expedition gives 40, +40 for a win, +10 a knock.

**Measured** with `--garden-pace-check` (a fixed play model on the real Care, Game and Evo code; the
assumptions are in the `pace` block of the rules file): time to the first form (level 4, 600 XP).

| Player | Minutes |
|---|---|
| Garden-only (feed, pet, fetch, drill; naps when worn out) | 229 |
| Also runs expeditions (12 min each, half won, 1 knock, 3 min of garden between) | 141 |
| Ratio | about 1.6 (limit 2.0, `pace.max_ratio`) |

With the first tuning (2x these XP values) the ratio was 1.32: garden XP per minute matched a run's,
so extraction stopped being the faster way. These values keep runs ahead without making the garden a
dead end. The check fails above 2.0x.

Default taken: "about 2x" is the limit. The alternative is a tighter limit (1.5x), which means
roughly 1.5x the XP above.

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
- XP (garden_sim.json `garden_xp`, `xp_curve`): a played game 3, a win 5, the first win of the day 60, the first care of each kind 5, curve 50 x level and flat 1,000 from level 20. **Not live:** this stack's `garden_xp.json` pays feed, pet, fetch and drill only, and `Game.xp_need` is still 100 x level. The evolution and stat-total rows hold once that XP (backlog 5) and the curve are built with these numbers; with today's live XP a home-only 5-minute player does not reach level 8 in a month. No new system was added here, so those two stay targets for that build.
