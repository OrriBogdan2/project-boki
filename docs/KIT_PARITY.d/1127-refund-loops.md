## Cooldown refund and reset loops (reference pass 11-27, ext/kit-refund-loops-1127)

The 11-27 reference note's refund / reset-on-hit / knock / dash-through rules for the HIGH-confidence hunters (Vex and
Gil skipped), against the code. Most were already in; three were built, smallest first. No mana, no ability levels.

| Hunter | Reference rule | Ours before | Now | Where |
|---|---|---|---|---|
| Tenzo | slam cooldown resets on a knock/kill | none | Quakefall ready at once on a knock his blow lands (not an assist) | `dolm_kit.gd on_knock`, `--kit-refund-check` |
| Albert | blocking lowers the dash cooldown | none | a blow the raised aegis takes feeds the 360 Smash: a whole aegis's HP of damage blocked = 1 charge (`rmb.shield.block_dash` 1.0) | `bulwark_kit.gd _block_hastens_smash`, `--kit-refund-check` |
| Meeko | dash through allies refunds half its cooldown and 1s of the heal ring | none (cut by the owner's data pass as invented, `docs/heroes/tender.md` "Ally-pass refund") | Relay Step past a teammate: half the hop (half the glide's cooldown in the air) back, Hearthlight -1s; `dash.ally_r` 1.1, `refund` 0.5, `e_refund` 1.0 | `tender_kit.gd _relay_pass`, `--kit-refund-check`, `--support-check` (its "refunds nothing" line flipped) |
| Cinder | heal-shield cooldown resets on a knock | in: `ashwick_kit.gd on_knock` resets E | unchanged | |
| Kael | ult resets on a knock or kill; slam sweet spot + knock resets it | in: `juggernaut_ult.gd _reset`, `juggernaut_kit.gd on_knock` | unchanged | |
| Sparkle | dash through a 4-stack resets it; spear leaves an orb that resets the dash | in: `mage_kit.gd grant_reset`, motes | unchanged (the mana refund has no counterpart: no mana) | |
| Sable | dash reset on the empowered hit; ult refreshes the dash; dagger stick cuts its cooldown | in: `thief_kit.gd` (Vault, `refund_foe` / `refund_wall`), `thief_ult.gd` | unchanged | |
| Neve | skate early release refunds its cooldown | in: `rimewright_kit.gd` (`dash.refund`) | unchanged | |
| Lace, Grimble, Motley | no refund or reset rule in the reference | | unchanged | |

Skipped on purpose: the Cinder level-4 ignite refund and every mana return (levels and mana are out of scope).
