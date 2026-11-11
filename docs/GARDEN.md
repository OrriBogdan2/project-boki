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

## A new Boki from the Shelter (base_mode)

DECISIONS 2026-11-11: the Shelter always has strays, so adopting is a moment at home, built from what
exists. The new Boki steps out at the zone's pad (the stone, `HubWaystone.pad`); the Boki near by come to
look (`BaseLife._arrived` and `ComeLook`) and the first to reach it keeps "was there the day <name> arrived".
It is shy for its first farm day (`BaseShy`, `base_life.json` "shy": 300 s of farm time, the length of one day):
it keeps to the island's edge, joins no tag and no toy and is nobody's play mate, then cheers up and goes to
join in. `rec["shy_s"]` holds the time left; a Boki without it is settled, so old saves need no migration.
Default taken: the shy day runs only while its zone is loaded. The alternative is real time, which would let a
closed game cure it. Checked by `--base-stray-check`.
