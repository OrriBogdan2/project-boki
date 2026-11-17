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
