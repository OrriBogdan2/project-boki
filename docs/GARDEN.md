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

## A garden day in every zone

`--garden-day-check` plays 20 minutes of game time (four in-game days, about 6 s of wall time a zone) in
Bramblebank, Glasswater, Cinderstep, Hushwood and Kitewind with six residents each, leaning toward the zone's
types (so they thrive there), the zone's toys and the snack patch, then the hub with the partner. `--day-zone=<id>`
runs one. It fails on a Boki with under 4 base-life states, 90 s in one non-Nap state, 20 s still off a nav point,
falling out of the zone, never playing at a toy, or (unless nocturnal) missing a night's nap; on a toy nobody
played at; on the zone's game not finishing a match (Dash, Spark Volley, Stump Shove, Seek, the ridge's Dash) with
two residents; and on a zone part over its nodes, emitters or script ms (GARDEN.md 10.6).

| Zone | Toys | States seen | Fewest by one Boki | Toys used | Night naps (4 nights) | Game match |
|---|---|---|---|---|---|---|
| Bramblebank | ball, post, tub | Roam, Play, PlayWith, Watch, Chore, Nap | 4 | 3 of 3 | 20 | The Dash, 18 s |
| Glasswater Shallows | tub | Roam, Play, PlayWith, Watch, Chore, Nap | 4 | 1 of 1 | 20 | Spark Volley, 24 s |
| Cinderstep | stone, post | Roam, Play, PlayWith, Watch, Chore, Nap | 4 | 2 of 2 | 24 | Stump Shove, 4 s |
| Hushwood | ball, post, tub | Roam, Play, PlayWith, Watch, Chore, Nap | 5 | 3 of 3 | 20 | Seek, 17 s |
| Kitewind Ridge | ball, post, tub | Roam, Play, PlayWith, Watch, Chore, Nap | 4 | 3 of 3 | 20 | The Dash (ridge track), 19 s |
| Hub | none | nobody lives here | | | | |

Eat shows when a Boki gets hungry in the day (the five-zone run does not always hit it, so it is not a bar).
Night naps are the nights a Boki that is not nocturnal (Work.NOCTURNAL: wisplet, zapple) napped in, summed over
its residents. Hushwood and Kitewind have no island of their own on this line (no `build` in garden_zones.json),
so they run on the Bramblebank island with the three demo toys; a Boki there leans to their types all the same.
