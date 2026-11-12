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

## Base-only breeding

`--base-breed-check` plays a fresh base_mode save that never leaves the base through every gate of the Nesting Nook (briefs/design/GARDEN.md 6) and prints the play minutes of each. Measured: hatch 0; friends 6 min (bond 0.55 after a ball and a nap, trust 62); egg ready 10 min after it is laid; a parent can lay again after 20 min. Both Grown takes about 18 h per Boki on farm XP and 10 h with runs (ratio 1.75, limit `pace.max_ratio`), so the baby comes long after two sessions (`BREED OVER`). Fixed with data: the Nesting Nook and the Training post open from the start and cost gems only (45 and 30; they wanted farm level 3 and wood, fibre and stone that base_mode cannot get). Fixed in code: `NookRules.friends` read the -1..1 bond against 50, so no pair with a recorded bond could ever be friends. Still open: a second Boki, the Grown pace and the `loose` type clash (docs/DEBT.md).
