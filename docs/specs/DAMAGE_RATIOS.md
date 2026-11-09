# Damage ratios: ours vs the source

Parity first (DECISIONS 2026-11-07): absolute damage can't match (our HP is 124/145/193, the source's 1100-1475), so this compares each number as a **share of an average Hunter's health**. Ours: the 12 hunters' class HPs average 154 (scripts/core/data.gd). Source: the 12 base HPs average 1285.4 at level 1 and 2361.7 at level 15 (supervive_physics.md; numbers the kit file marks "@15" use the level-15 average). Source damage is supervive_kits.md. Our side is read from `content/archetypes/*.json` and `content/weapons/*.json` by `python3 tools/damage_ratios.py`, which regenerates this table. Mapping: Vex=Ghost, Mossy=Oath, Sparkle=Joule, Kael=Brall, Lace=Myth, Cinder=Felix, Grimble=Kingpin, Meeko=Elluna, Neve=Celeste, Tenzo=Tetra, Motley=Void, Sable=Shiv.

Limits: the source kit text gives a fire rate for no LMB, so "LMB DPS" has a source figure only for Cinder (258/s); the others compare per hit, and the rest show "-". Tenzo's kit text has no damage numbers at all. Heals and shields are not compared. "R" is the kit's ult slot (`x`), not the Boki merge. Ours/source above 1.5 or below 0.67 is flagged **OFF**.

## Table (ours/source: above 1 means we hit harder for our health)

| Hero | Slot | Ours (what) | Ours dmg | Ours % HP | Source dmg | Source % HP | ours/source | Flag |
|---|---|---|---|---|---|---|---|---|
| Vex | LMB hit | quill rifle round | 6 | 3.9% | 51 | 4.0% | 0.98 | source rate unknown |
| Vex | LMB DPS | quill rifle | 50 | 32.5% | - | - | - | source rate not in the kit text |
| Vex | RMB | Burr hit (the cone is the wall case) / Spike Grenade | 22 | 14.3% | 165 | 12.8% | 1.11 |  |
| Vex | E | Longneedle / Railgun | 36 | 23.4% | 202 | 15.7% | 1.49 |  |
| Vex | R | Cinderfall impact+3s burn / Napalm 203+3x59 | 42 | 27.3% | 380 | 29.6% | 0.92 |  |
| Mossy | LMB hit | tower shield bash (source: hammer throw 192@15) | 11 | 7.1% | 192 | 8.1% | 0.88 | different weapon |
| Mossy | LMB charged | charged bash / charged swing 522@15 | 28 | 18.2% | 522 | 22.1% | 0.82 |  |
| Mossy | RMB shield slam / Shield Bash | slam | 18 | 11.7% | 198 | 8.4% | 1.39 |  |
| Mossy | Dash | 360 Smash whirl / Spin Dash | 24 | 15.6% | 364 | 15.4% | 1.01 |  |
| Mossy | R | Abyssal Breaker strike+blast / fissure 31+396 | 22 | 14.3% | 427 | 18.1% | 0.79 |  |
| Sparkle | LMB | coilcaster bolt / Jolt | 12 | 7.8% | 90 | 7.0% | 1.11 |  |
| Sparkle | RMB | Coil max / Voltaic Spear | 30 | 19.5% | 133 | 10.3% | 1.88 | **OFF** |
| Sparkle | Dash | Wirerun tap / Surge press | 20 | 13.0% | 153 | 11.9% | 1.09 |  |
| Sparkle | E | Strike / Lightning Strike | 20 | 13.0% | 162 | 12.6% | 1.03 |  |
| Sparkle | R | Crash / Thunderstorm | 9 | 5.8% | 72 | 5.6% | 1.04 |  |
| Kael | LMB hit | greatsword slash / Caldera | 11 | 7.1% | 43 | 3.3% | 2.14 | **OFF** |
| Kael | LMB charged | charged slash / fireblast | 34 | 22.1% | 107 | 8.3% | 2.65 | **OFF** |
| Kael | RMB | Smash / Execution Slam | 26 | 16.9% | 130 | 10.1% | 1.67 | **OFF** |
| Kael | RMB lunge | lunge max / Fiery Lunge | 20 | 13.0% | 84 | 6.5% | 1.99 | **OFF** |
| Kael | RMB air | Meteor Drop / Obsidian Slam | 18 | 11.7% | 88 | 6.8% | 1.71 | **OFF** |
| Kael | RMB spin | spin / Scorching Spin | 18 | 11.7% | 99 | 7.7% | 1.52 | **OFF** |
| Kael | Dash | Rampage tip / Flame Step | 18 | 11.7% | 49 | 3.8% | 3.07 | **OFF** |
| Kael | E | Warchain / Feysteel | 8 | 5.2% | 30 | 2.3% | 2.23 | **OFF** |
| Kael | R | Cleave / Volcanic Rebuke | 43 | 27.9% | 230 | 17.9% | 1.56 | **OFF** |
| Lace | RMB | Heavy Shot max (no wall) / Heartpiercer | 30 | 19.5% | 35 | 2.7% | 7.15 | **OFF** |
| Lace | RMB wall | Heavy Shot into wall / 35+173 | 178.2 | 115.7% | 208 | 16.2% | 7.15 | **OFF** |
| Lace | E DPS | Rain / Rain of Arrows 61/s | 10 | 6.5% | 61 | 4.7% | 1.37 |  |
| Lace | R final shot | Starpiercer 3rd / Fury 422 | 25 | 16.2% | 422 | 32.8% | 0.49 | **OFF** |
| Lace | R shots 1-2 | Starpiercer / Fury 326 | 18 | 11.7% | 326 | 25.4% | 0.46 | **OFF** |
| Cinder | LMB DPS | flamethrower / 258 per s | 27 | 17.5% | 258 | 20.1% | 0.87 |  |
| Cinder | RMB | Ember bolt / Embry Bolt | 14 | 9.1% | 106 | 8.2% | 1.10 |  |
| Cinder | Dash | Spark Leap / Pyro Pounce | 16 | 10.4% | 150.4 | 11.7% | 0.89 |  |
| Cinder | E | pull / Heat Shield | 7 | 4.5% | 76.8 | 6.0% | 0.76 |  |
| Cinder | R DPS | trail / Flight 239.2 per s | 4.5 | 2.9% | 239.2 | 18.6% | 0.16 | **OFF** see ashwick_jet.gd:236 |
| Grimble | LMB DPS | shotgun (7 pellets) | 28 | 18.2% | - | - | - | source gives no number |
| Grimble | E | slam / Primal Slam | 25 | 16.2% | 264 | 20.5% | 0.79 |  |
| Grimble | R | Slugwave: 2 waves x 6 orbs, all hit | 48 | 31.2% | - | - | - | 'massive', no number |
| Meeko | LMB DPS | lantern crook | 20 | 13.0% | - | - | - | no number |
| Meeko | RMB | seed hit+burst / Darkside 49 | 41 | 26.6% | 49 | 3.8% | 6.98 | **OFF** |
| Neve | RMB | lance+burst / Cryo Spear 156+190 | 41 | 26.6% | 346 | 26.9% | 0.99 |  |
| Neve | R | Whiteout / Chilling Finale | 19 | 12.3% | 155 | 12.1% | 1.02 |  |
| Neve | LMB DPS | hoar fan | 22.2 | 14.4% | - | - | - | no number |
| Tenzo | all | kit text gives no damage numbers | - | - | - | - | - | Tetra: only upgrade deltas |
| Motley | LMB hit | orb / Gravity Orb 263@15 | 9 | 5.8% | 263 | 11.1% | 0.52 | **OFF** item 117: kept |
| Motley | RMB | snap / Void Snap 277@15 | 9.5 | 6.2% | 277 | 11.7% | 0.53 | **OFF** |
| Motley | E | bomb x3.5 / Anomaly 365@15 up to 3.5x | 43.8 | 28.4% | 1277.5 | 54.1% | 0.53 | **OFF** |
| Sable | LMB hit | arc bolt / Arcslinger 160@15 | 13 | 8.4% | 160 | 6.8% | 1.25 |  |
| Sable | RMB | bola+pair / Chain Bolas 46+94 | 18 | 11.7% | 140 | 10.9% | 1.07 |  |
| Sable | R | barrage 10 shots+rim / Fusillade 69+48 | 40 | 26.0% | 117 | 5.0% | 5.24 | **OFF** per target |

## Fixed in this pass (explicit level-1 source numbers, no owner note, no other branch touching them)

| Row | Was | Now | Source | Ratio now |
|---|---|---|---|---|
| Sparkle R, Kitefall crash | 22 (2.55x) | 9 | Thunderstorm 72 | 1.04 |
| Neve R, Rimelock burst | 40 (2.15x) | 19 | Chilling Finale 155 | 1.02 |
| Neve RMB, Cryo Spear burst (hit 18 + burst) | 60 (1.88x) | 23 | 156 + 190 | 0.99 |

Asserted by `tools/damage_ratio_check.gd`, called from `--hero-combo-check` (archer_bulwark_combo_check.gd).

## Kept, with the reason

- Motley LMB, RMB, E (0.52-0.53, we hit too softly): the source numbers are level-15 readings (Void @15), so the scale is the least certain here, and item 117 (DECISIONS 2026-11-06) accepted a ~15% held-fire DPS loss with no compensation buff. Listed for the owner, not touched.
- Lace Heavy Shot, wall case (7.15x): `wall_mult` 4.94 = 173/35 is asserted in archer_bulwark_combo_check and is the source's ratio. The base 30 is what is off (35 maps to about 4). A full-charge wall pin is 178 damage, 116% of a medium hunter's health. Needs an owner call, because it is Lace's signature.
- Cinder R trail (0.16): ours is 4.5/s plus Char build; the source is 239/s. The Char/Ignite model (ashwick_jet.gd:236) carries damage we don't count here, so it can't be fixed from a number alone.

## For the owner: off by over 1.5x, not fixed

- Kael: every row is 1.5-3x too strong for our HP (LMB hit 11 vs 43, charged 34 vs 107, Smash 26 vs 130, lunge, air slam, spin, Rampage tip 18 vs 49, chain 8 vs 30, ult 43 vs 230). One consistent scale error; the cheapest fix is about x0.5 on the juggernaut damage set. Kael is feel-critical (item 22), so not touched blind.
- Lace R shots (0.46-0.49): Starpiercer 18/18/25 vs Fury 326/326/422; ours also has shred and a 12% execute that the table doesn't count.
- Meeko RMB (6.98): seed 9 + burst 32 vs Darkside 49. Unclear whether the source's delayed hit is part of the 49.
- Sable R (5.24): 10 shots x 4 on one target vs Fusillade 69 (+48 edge) @15; it is spread over targets in play, so it needs a per-target test.
- Sparkle RMB (1.88, charged max 30 vs 133): the source's charge curve is not in the kit text; the tap value (18) is 1.13.
- Vex Railgun 1.49 and Mossy Shield Bash 1.39: under the line.

## Suggestions (ours, not the build)

- Add a charge-curve note per hold ability to supervive_kits.md so the hold rows can be compared fairly.
- Run `tools/damage_ratios.py` after any damage edit.
