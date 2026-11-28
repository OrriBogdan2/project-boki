## Cinder ignite tiers (reference note 11-27 gap 1, ext/cinder-ignite-tiers)

The note's first Cinder gap ("ignite L2 + spread + % max HP bonus") was read from kit text, not code. Main already has all
three, so nothing was built (checked against origin/main c78b7cba28).

| Reference rule | Ours | Where |
|---|---|---|
| two ignite tiers, L2 on a re-hit | Ablaze (31 Char, 0.5%/s), then Flashover on the next stoke (1%/s) | `ashwick_kit.gd stoke`, `resource.dps1/dps2`; first cut 6dce74161a |
| bolt on a burning foe upgrades it and ignites nearby foes | Cinder Shot on a burning foe stokes it and lights foes within `rmb.spread_r` 4m in sight; allies are skipped (`foes_in` takes `foes_of(team)`) | `ashwick_kit.gd _cinder_hit` |
| % max-health damage on an ignited foe | stream chip `ignite_bonus.tick_pct` 0.4% / 0.6% a second, direct hits x1.06 / x1.10; sized by `--ttk-check` | `ignite_bonus`, 90c71388b7 |
| L4 ability refund on ignite | skipped on purpose (levels are out of scope) | `1127-refund-loops.md` |

`--ashwick-combo-check` already asserts the tier-up and the spread ("combo: lance burn > Cinder Shot = upgrade + spread");
an ally-not-lit line is the one missing assert.
