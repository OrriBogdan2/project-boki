## Lace and Cinder ultimate ranks: the true state (checked on origin/main ae91cbf028, 2026-11-28)

Two docs disagreed. The table "Ultimate ranks vs the source" (11-19) marks Lace's Starpiercer `match` and Cinder's Flue Flight
`match (cd scaled)`. The 11-22 rechecks said Lace's "R differs ... X has no ranks (held)" and Cinder's "R ranks: none built (ADR 0022
is a spec)". **The table is right; the rechecks were stale.** The ult-rank data (`555debe7d2`, 11-19) is not an ancestor of the main
the rechecks read (`c303669761`), so they were written on a tree without it. Their rows are now marked superseded
(`1122-lace-recheck.md` Ranks row, `1122-cinder-recheck.md` R ranks row and its "Not changed" line). No code or data changed.

`--ult-rank-check` on origin/main ae91cbf028: 13 of 13 Hunters have a row, `DONE, failures: 0`. Lace and Cinder lines:

```
ULTRANK ok   archer ranks 1-3: cooldown1 60.00, dmg1 18.00, final_dmg1 23.30, cooldown2 55.00, dmg2 19.80, final_dmg2 25.63, cooldown3 50.00, dmg3 21.60, final_dmg3 27.96
ULTRANK ok   ashwick ranks 1-3: cooldown1 36.00, trail_dps1 4.50, cooldown2 24.00, trail_dps2 4.50, cooldown3 24.00, trail_dps3 5.62
```

Data (`x.per_rank`, steps read by `HeroUlt.ranked` through `ArchKit.x_def()`):

| Hunter | File | `x.per_rank` | Source tiers (II / III) | Ours: rank 1 -> 2 -> 3 | Verdict |
|---|---|---|---|---|---|
| Lace | `content/archetypes/archer.json` | `cooldown [-5, -5]`, `dmg [1.8, 1.8]`, `final_dmg [2.33, 2.33]` | +10% dmg, -5 s, x2 | cd 60 -> 55 -> 50 s; dmg 18 -> 19.8 -> 21.6; last arrow 23.3 -> 25.63 -> 27.96 | match; no gap |
| Cinder | `content/archetypes/ashwick.json` | `cooldown [-12, 0]`, `trail_dps [0.0, 1.125]` | -15 s / +25% dmg | cd 36 -> 24 -> 24 s; trail 4.5 -> 4.5 -> 5.625/s | match (cd scaled: 15 s x 36/45 = 12 s; +25% of 4.5 = 1.125); no gap |

Cinder's tiers come one per step (II is the cooldown, III is the damage), so rank 3 keeps rank 2's cooldown by design; that is the
source, not a missing step. Lace's last arrow follows the 422 : 326 ratio (1.29x) of the first two. The check shows no real gap
for either hunter, so nothing in `content/` or `scripts/` changed.
