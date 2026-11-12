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
| Garden-only | 5 min | 1108 min (18.5 h) | 33 min | 2230 min (37 h) |
| 1 expedition a session | 29 min | 629 min (10.5 h) | 108 min | 1266 min (21 h) |

The 30 minute target is missed by far (1 to 2 days of play for the egg): care XP is about 2.5 XP a minute, a Grown Boki needs 2800 XP (the level table
is 100 x level), and the Nook needs two. The second Boki and friends are not the bottleneck (minutes); only levels are.
That is why no friend-threshold option is listed: the threshold would change nothing.

Data-only options (`breed_options` in content/rules/garden_xp.json, read by the check, not applied anywhere):

| Option | Grown | Garden-only: Grown / first egg | 1 run a session: Grown / first egg |
|---|---|---|---|
| xp_x3 (every care XP times 3) | 8 | 371 / 730 min | 596 / 1184 min |
| grown_5 (the Nook asks level 5) | 5 | 400 / 787 min | 223 / 454 min |
| xp_x2_grown_6 | 6 | 294 / 588 min | 320 / 648 min |

Even the best option is 7 to 10 hours of play to a first egg. A 30 minute egg needs both a far larger XP rate and a
Grown level near 2 (roughly 20x the XP, or a Nook that takes Youngling kin); that is a design call.
