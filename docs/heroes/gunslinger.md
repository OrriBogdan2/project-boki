# Marlowe (archetype id `gunslinger`, Medium)

Internal design note (may cite the source for traceability; nothing in the game does).
Source behaviour reference: SUPERVIVE hero Ghost. Our hero is an original character, the burr-and-needle
marksman: a visored cap, a cropped jacket, a long streaming scarf, a bandolier of spiked burr charges,
one bronze pauldron. Palette: ember orange and bronze. Payoff word: SKEWERED.

## Research summary
Sources (gameplay only):
- https://supervive.wiki.gg/wiki/Ghost (passive, LMB, RMB, Shift, Q, R, rank upgrades)
- https://supervive.wiki.gg/wiki/Patch_Week_1_Open_Beta and the Leveling Rework patch page (rank and cooldown changes)
- https://supervive.wiki.gg/wiki/Leveling_Rework_%2B_Big_Balance_Patch
- Guide listings found by search (esports.gg, gamer-guides) for role and combo order.

Where they disagreed: the passive stack bonus is 6% on the current wiki and was 8% before 19 March 2025
(we took 6%). Rank 4 effects (grenade reset on a knock, railgun cooldown per target) are the late
upgrades; we mapped them onto our rank 3.

Version chosen: the current wiki page (6% passive stack, post Leveling Rework cooldowns), later
values over earlier ones.

## Scaling
Our Medium has 145 HP against roughly 1.4k to 1.6k, about 1/10. Rifle 6 per round (24 round drum,
0.12s), Burr Charge 13 blast (2 on attach), cone 10, Longneedle 36. Ranges at about 1/100.

## Per-slot table
| Slot | Input | Our text | Source behaviour | Difference and why |
|---|---|---|---|---|
| LMB | hold | **Quill Rifle**: auto rifle, 24 rounds; after 10 rounds a string loses half its punch; Rattled foes take 28% more. | rifle: 30 rounds, damage decays to 50% over 10, bonus vs Dazed | Same shape. Fixed weapon `quill_rifle`. |
| Passive | | **Fever**: each ability that lands (a Burr Charge counts twice) adds a stack, up to 8, 3.5s; each stack makes your damage heal you for 6%, rifle included. A knock heals 25% and refreshes Slipstep. | Combat Rush: omnivamp stacks from non-LMB abilities, grenade attach and detonate are two hits; knock heals and resets slide | Capped at 8 (source uncapped) to keep healing sane at our TTK. |
| RMB | tap | **Burr Charge**: lob 11m. Sticks to a hunter or monster, pops after 0.7s: 13 damage in 1.9m, Rattled 1.2s. On a wall it blasts a cone back out: 10 damage, a shove, Rattled 2s; a hunter shoved into more terrain is stunned 0.7s and the cooldown drops 40%. | Spike Grenade | Same. Terrain cone uses the incoming direction as the wall normal. |
| Shift | tap / hold | **Slipstep**: tap, a 3.4m skid; hold, a 6m low slide you can shoot from; let go early to get 30% back; rank 3: +25% speed for 2s after a slide. A knock refreshes it. In the air a short plain dash. | Combat Slide | Same; rank 4 speed buff mapped to our rank 3. |
| E | tap, stand and charge | **Longneedle**: charge 0.8s (slowed 55%, lane shown), then a 14m needle that passes through cover and everything in line: 36 damage, +20% on a Rattled foe, a Rattled hunter hit is **Skewered** (payoff). Each hunter hit takes 30% off its cooldown (every hunter hit at rank 3). | Arcane Railgun | Same. |
| R | | none | Summon Napalm | See below. |

## R (ultimate) choice
Dropped. The napalm is a zone of burst damage that feeds the passive but the loop (Rattle, then rifle
and needle, fed by Fever) does not need it. Nothing was folded in.

## Combinations
| Combination | What fires | Check |
|---|---|---|
| Burr Charge (attach + pop) | two Fever stacks, target Rattled | `--gunslinger-combo-check` |
| Rattled foe + rifle | +28% on weapon hits only | `--gunslinger-combo-check` |
| Rattled foe + Longneedle | +20%, Skewered payoff on a hunter | `--gunslinger-combo-check` |
| Longneedle hit on a hunter | cooldown -30% (per hunter at rank 3) | `--gunslinger-combo-check` |
| Longneedle through a wall | still hits | `--gunslinger-combo-check` |
| Stun during the charge | the charge is cancelled | `--gunslinger-combo-check` |
| Burr Charge stuck in a wall | cone, Rattled 2s, shove into terrain stuns, Burr cooldown -40% | `--gunslinger-combo-check` |
| Knock | +25% heal, Slipstep refreshed; at rank 3 Burr Charge reset | `--gunslinger-combo-check` |
| Slipstep released early | 30% back | `--gunslinger-combo-check` |
| Fever + rifle | lifesteal on every shot | `--archetype-check` |

## Animation moves (`HunterAnim.KMOVES`)
| Ability | Move id | Look |
|---|---|---|
| LMB Quill Rifle | none (stock firing pose) | muzzle flash and casings carry it |
| RMB Burr Charge | `gunslinger_rmb` | burr cocked by the ear, then the lob |
| Shift Slipstep | `gunslinger_dash` | sat back into the skid, arms out for balance |
| E Longneedle | `gunslinger_e` | braced low behind the barrel for the 0.8s charge, recoil throws the chest back |
Frame strips: `~/shots/heroes-joule-ghost/strip_gunslinger_*.png`.

## Engine notes
- Rattled is a `KitStatus` status (Net event `["kst", nid, kind, seconds, k]`, Net 0.7.0, already on main);
  the target's own game applies the slow and every game shows the stars.
- No new Net events or state keys: this branch keeps main's Net version.
- Kit: `scripts/arch/kits/gunslinger_kit.gd`, data `content/archetypes/gunslinger.json`, weapon
  `content/weapons/quill_rifle.json`. Look: `scripts/match/hero_gear.gd`.
- Skewered has its own sound `hero_skewer` (`tools/gen_hero_sfx.py`, pure Python).
