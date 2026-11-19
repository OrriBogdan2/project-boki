# Combat numbers (ours)

Measured numbers for the combat rules, asserted by a check. Our values only.

## Closing zone damage by phase

Standing outside the closing edge costs a share of your own max health a second, so a full-health Hunter lasts the same number of seconds whatever its health. The shares are the closing-circle curve in `content/rules/heart.json` (`tide_dmg`, linear between its stages 0, 1, 2 and 10) over its medium-Hunter health (1290), the same ratio our health scale keeps to theirs (our mean max health 154 against 1285, docs/KIT_PARITY.md Health). Each phase in `content/rules/shrink_zone.json` names its `stage`; any stage in between interpolates. Damage lands in 1 s ticks, through armor, no glider drain.

| Close (stage) | Share of max health a second | Hurt a second at 154 health | Seconds to down a full-health Hunter, 3 bots outside |
|---|---|---|---|
| 1 (0) | 0.23% | 0.36 | 430 (430, 430, 431) |
| 2 (1) | 0.47% | 0.72 | 215 |
| 3 (2) | 3.9% | 6.0 | 26 |
| 4 (10) | 35% | 54 | 3 |

Early closes only nudge (a full-health Hunter outlasts the next close), the last one downs in 3 s. Asserted per phase by `--shrink-zone-check` ("trio outside downs a full-health Hunter").

## Our targets

The combat values Project Boki ships and the target each is tuned to. Per-hero numbers live in `content/archetypes/*.json`,
rules in `content/rules/`; this page is the short list of what we aim for. Checks: `--ttk-check` (time to knock,
[TTK.md](TTK.md)), `--kit-parity-check` ([KIT_PARITY.md](KIT_PARITY.md)).

- **Time to knock:** every hunter's LMB-only and full-combo time to knock a full-health, full-armour target lands inside the bar in TTK.md (0.8 to 1.25 of the target time) unless the owner set an override.
- **Health and armour:** mean health 154 (the 12 hunters), armour 339 at 2.2x, 20% damage reduction from armour. Health is the limit, so the 20% is what counts.
- **Down and revive:** at 0 health you become a wisp: you crawl, cannot be shot, and bleed out in 15 s. A teammate standing on you brings you back (DEATH_AND_REVIVE.md).
- **Gliders:** a hit on a glider deals double damage and knocks it out of the air; spiking an overheated or sunk glider stuns it (0.7 s over ground).
- **Casts:** windups 0.1 to 0.65 s (median 0.45), charge to full 0.5 to 1.25 s (median 1.0); more in DASHES_AND_ABILITY_FEEL.md.
- **Class baselines:** Kinfall's own light, medium and heavy numbers (KINFALL_CLASSES.md); retune the data files, not code.
- **Aim line:** the aim laser is 8.5 m long.
- **Dash cooldowns:** per kit in the archetype JSON; a held dash is longer on a longer cooldown (`dash_hold_for_ex`).
