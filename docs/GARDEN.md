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

## Shaping items: the preview card

Hold a shaping item (Hold on it in the bag) and walk up to a Boki, or point at its row in the Boki's feed menu:
`ItemPreviewCard` (scripts/ui/item_preview_card.gd) slides in with every change drawn as a ghost. It shows the stat
bars with the real gain after caps, the budget and lean rings, and on a branching line the path meter (both finals
as silhouettes, pips before and after, the verdict, and a Why? list of pip sources). For a second the Boki tries the
change on: its new colour or the path token. Interact there gives the item; walking away from that Boki ends the
hold, and the item stays in the bag. The card does no math of its own: it reads `GardenItems.preview`/`after`,
`EvoPath.pips` and `StatBudget`. `ItemHold` (scripts/home/item_hold.gd) owns the held item; distances and times are
in content/rules/garden_items.json `hold`. Check: `--item-card-check`; shots: `--item-card-shots --shots-dir=<dir>`.
