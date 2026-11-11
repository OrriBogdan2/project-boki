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
