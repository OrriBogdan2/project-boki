# Dredge (archetype `dredge`, heavy)

Internal design doc. Source behaviour: SUPERVIVE hero Kingpin (traceability only; none of its names, text
or looks appear in the game). Everything the player sees and hears is ours.

## Research summary
Sources (gameplay facts only, written in our own words):
- https://supervive.wiki.gg/wiki/Kingpin (kit page: passive, LMB, RMB, Shift, Q, R, upgrade lines, patch notes inline)
- https://deltiasgaming.com/?p=298298 and https://www.breakflip.com/guides/13513.html (role and ability overview)
- https://www.ludo.guide/guide/supervive/hunters-abilities/hunter-guides/kingpin (ability priority, grab on an ally)

Where they disagree: the guides call him a bruiser or an initiator and rank his R first; the wiki lists the numbers.
The wiki lists no E slot (our E carries the source's Q). Version chosen: the wiki's current page (patches
20.11.2024 shotgun damage, 05.02.2025 dash-turn restriction and the halved attack-speed reset are included).
Only three of the five planned sources had usable detail; patch notes were taken from the wiki page itself.

## Scaling
Source Kingpin 1531 HP against our heavy 193 HP: damage x0.13 (Q 196 -> 25), cooldowns about x0.8, distances
by feel. Cooldown ratios and the source's relative ranges are kept (Grapnel is the longest cooldown, the barge
the shortest). Rank 2 and 3 use the shared -10%/+15% steps and the per-slot specials below.

## Per-slot table
| Slot | Input | What it does (ours) | Source behaviour | Difference and why |
|---|---|---|---|---|
| Passive, Salvage | none | Knocks and assists stack Salvage (+2.5% health each, max 10); being downed costs one; hits on a hunter's back +50%; a knock heals 16% of your health | stacks of max health per knock/assist, lose one on death, +50% backstab, heal on knock | heal as a share of health (250 of 1531) |
| LMB | hold/tap | the shotgun: 7 slugs stopping at 5m, bloom grows, the barge resets it | 7 slugs, bloom, no-spread shreds armor | armor shred not reproduced (the shotgun keeps its own pellet floor) |
| RMB, Grapnel | tap | rope-hook 11.5m to the first foe or wall; reels the foe in (15 m/s, up to 3s); they land Grounded 1s. Only the barge works meanwhile. 14s | arm pierces terrain, pulls until 3s or arrival, grounds, only dash castable | stops at walls and the reel is blocked by walls (brief: no pulling through walls); too-heavy bodies (wardens) cannot be pulled |
| Shift, Barge | tap | 4.6m shoulder barge, 2 charges (heavy class), shoves for 5; turn limited to 35 degrees for 0.8s after the Anchor | ground and air dash with separate cooldowns, turn restriction after Q | air dash uses the class air dash; one charge pool |
| E, Anchor Drop | tap | 0.22s wind-up, 3m cone: 25 damage, stun 0.45s, slam to the ground and Grounded; in the air it drives you down (never over the abyss). 10s | Q: fist strike, stun and ground slam, self downward force, none over abyss | wind-up a little longer (0.15 -> 0.22) so the pose is readable |
| R | | not built (R is the Boki Merge) | Slugwave, two volleys with Anti-Heal | see ult choice |

Rank 2 / 3: Grapnel -10% cooldown steps, rank 3 refunds 33% on a hit. Barge rank 3: pellet hits trim 0.25s off the recharge. Anchor rank 3: up to +75% damage by height above ground, +0.1s stun per rank.

## Ult choice
Dropped. Slugwave is flavour: nothing in the loop (Salvage, grapnel, anchor, back hits) resets on it or feeds from it.

## Combinations (all scripted in `--dredge-combo-check`)
| Do this | You get |
|---|---|
| Grapnel hit, then wait for the arrival | foe lands Grounded at your feet, "HAULED" payoff |
| Grapnel, then Anchor Drop on the Grounded foe | 25 damage, stun, slam; the combo the kit is built for |
| During the reel: RMB, E, the gun | denied (only the barge works) |
| During the reel: barge | works; the reel continues |
| Anchor Drop, then barge within 0.8s | barge turns at most 35 degrees |
| Anchor in the air (rank 3) | driven down; up to +75% damage by height |
| Anchor over the abyss | no downward push |
| Grapnel into a wall | the hook stops there, nobody is pulled |
| Reel with a wall in the way | the foe is stopped at the wall |
| Reel over a gap in the island | the body is carried over the void and falls (existing knock/abyss rules) |
| A hit from behind | +50% |
| Knock or assist | +1 Salvage (+2.5% health); a knock also heals |
| Downed | -1 Salvage |
| Rank 3 Grapnel hit | refunds 33% of its cooldown |
| Rank 3 pellet hit | trims the barge recharge |

## Engine notes
The reel moves the foe in small steps against the world's occupancy test (walls and cliffs block, the void does not),
so it follows the same rules as a knock. A foe owned by another player's game (remote) takes the hit and Grounded
only (their body is not moved by our game). Statuses use `KitStatus` ("kst" event); no new sync shape.
