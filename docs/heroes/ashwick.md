# Ashwick (archetype `ashwick`, heavy)

Internal design doc. Source behaviour: SUPERVIVE hero Felix (traceability only; none of its names, text or looks
appear in the game). Everything the player sees and hears is ours.

## Research summary
Sources (gameplay facts only, written in our own words):
- https://supervive.wiki.gg/wiki/Felix (kit page, upgrade lines, patch log inline)
- https://deltiasgaming.com/?p=298994 (ability guide and the two-charge spread combo)
- https://www.breakflip.com/guides/13625.html (role overview)

Where they disagreed: one guide attributes the pull, Anti-Heal and shield to the bolt; the wiki puts them on the
shield ability (Q), which is what we follow. Patch changes taken from the wiki: 19.03.25 level-1 burn became
lethal and the burn lasts 3s; 18.12.24 the bolt no longer knocks back; 20.11.2024 the flamethrower's 0.35s
cooldown and self-slow. Latest version chosen. Only three sources were usable.

## Scaling
Source Felix 1367 HP against our heavy 193 HP: damage x0.13 (flamethrower 205/s -> 27/s), cooldowns about x0.8.
Burn is a share of the foe's health per second (source level 1 = 1.3% plus a scaling term; ours 2% and 4%).

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Flashover | none | Every hit builds Char on a foe; at 31 they Flash over (burn 3s, 2% of their health a second); fed to 31 again they burn at 4%. Anything stoking a burning foe upgrades it. Char falls off after 5s. A knock heals 16% and resets the cloak | Light Burns to 31 = Ignite, two levels, 3s, spread by the bolt | food removing the burn not reproduced |
| LMB, Torch Lance | hold | 6m, 44 degree cone of fire (walls stop it), 27 damage a second, builds 30 Char/s (half while burning); 0.18s spool-up pilot flame, 0.35s slow after release | hold flamethrower, 2 Light Burns every 65ms, self-slow after release | needs its own weapon (`flamethrower`) |
| RMB, Cinder Shot | tap | 14 damage bolt 14m: Flashes the foe; on a burning foe upgrades the burn and spreads it to foes within 4m. 7s | bolt applies Ignite; on an ignited foe spreads and upgrades | none |
| Shift, Spark Leap | tap | 4.4m leap through the foe, 13 damage, 17 Char; 2 charges. Rank 3: stokes at once and leaves a 3s fire trail | dash through, 17 Light Burns, rank 4 upgrades the burn | trail comes from the folded ultimate |
| E, Furnace Cloak | tap | 4.5m wave: 9 damage, 16 Char, Anti-Heal 3s, foes in sight dragged to you (walls stop them), shield 6.4% + 5.1% per foe for 3s. A knock resets it. 10.5s | Q: damage, pull, anti-heal, shield, knock resets, line of sight | none |
| R | | not built (R is the Boki Merge) | Firefox flight leaving a fire trail | see ult choice |

Rank 2 / 3: shared cooldown and damage steps; rank 3 Cinder Shot +60% damage, refunds 25% when it stokes; Leap stokes at once plus trail; Cloak +50% damage and shield, refunds 25% when it stokes.

## Ult choice
Folded in as a rank-3 upgrade of Spark Leap (the fire trail, 3s, slows and builds Char, never over the abyss). The
flight itself is flavour, but its burn zone is the one place the source builds Ignite without aiming.

## Combinations (all scripted in `--ashwick-combo-check`)
| Do this | You get |
|---|---|
| Hold the lance ~1s | Char to 31: Flashover level 1 |
| Keep holding on a burning foe | burn upgrades to level 2 (FLASHOVER payoff) |
| Cinder Shot on an unburnt foe | Flashover level 1 |
| Cinder Shot on a burning foe | upgrade + spread (to foes within 4m, at the original level) |
| Spark Leap | 17 Char on the foe it passes |
| Spark Leap rank 3 | burn upgrades at once, fire trail burns whoever stands in it |
| Furnace Cloak | damage, 16 Char, Anti-Heal, drag, shield |
| Cloak or lance behind a wall | nothing (line of sight and walls) |
| Knock | heal and the cloak resets |
| Rank 3 ability that stokes | 25% cooldown refund |
| Char past 31 | discarded; Char left alone falls off after 5s |
| Fire trail over the abyss | never forms |

## Engine notes
The burn uses the engine's own burn status (damage over time, credit to Ashwick); remote bodies get it through a
hit with a burn option. The lance and cloak test line of sight with the world's own check; the cloak's drag moves
foes in steps against the world's occupancy test like a knock. No new sync shape.
