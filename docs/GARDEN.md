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

## Glint Fishing looks
`scripts/home/glint_fx.gd` draws four small looks on the water with the shared cel pass (`shaders/glint_water.gdshader`,
recipes in `content/rules/glint_fishing_vfx.json`): a ripple where the bobber lands (on a glint or in empty water), rings
that hold wide while you wait and close in as the ears go up so they meet at the bite (the same warning the ears give,
so Focus still sets it), one sharp splash on the bite (the moment to press), and one glint on a catch, sized snack, item
or rare (rare is gold). Each is one quad, one at a time, with no particles. `--glint-fishing-check` covers them;
`--glint-fx-shots --shots-dir=<dir>` (through `jobq submit --needs gpu`) writes the sheet `looks.png`.
Default taken: the rings' timing is tied to the ears, not to the hidden bite time, so they never warn earlier than Focus
allows. The alternative (rings closing over the whole wait) would leak the bite to a player with no Focus.
