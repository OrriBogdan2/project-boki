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

## A Boki carried home from a match (`CarryArrival`)

DECISIONS 2026-11-11 "carry 2 in, 1 extra out": the Boki you claim in a match rides out in the carry-out slot. When it comes home it is an event, not a list entry: it stands at the arrival point (where you appear), up to three residents come to look (`ComeLook`, same as any new Boki), its memory gets `came home from <map> with <Hunter>` (the Hunter's base name, stored in `origin.where.hunter`), and a short card says where it came from and where it went. If the garden already has its out-cap (`KinBox.farm_cap()`) the Boki goes to the Burrow, nobody walks over, and the card says so. The pending list lives in memory only: a game closed between the results screen and the garden keeps the memory line and loses the card. No save migration (`origin.where.hunter` is read with a default). Check: `--come-look-check`.
