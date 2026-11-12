# Time to down: every Hunter's LMB into every other Hunter

Companion to docs/TTK.md (`--ttk-check`, ext/ttk-table): that table is the per-Hunter parity bar (LMB and combo, rank 0/max); this matrix is LMB only, attacker by defender.

Parity first (briefs/DECISIONS.md 2026-11-07): the owner asked for TTK in the combat area. `--ttk-matrix-check` puts a Training Area dummy at 8 m with the defender's base health and armour (124/145/193 hp, armour durability 2.2x, 20% off every hit while it lasts) and holds the attacker's LMB on it with perfect aim (aim dead on the dummy, shooter and dummy pinned, no dodging, no dash, no ability). It tries every LMB mode the weapon has (hold, taps, hold-to-charge) and keeps the fastest that reaches. An LMB that cannot reach 8 m (melee, short guns) is measured at 80% of its range and the cell carries a `~`. Cells are seconds to down; the check fails if a cell never downs the dummy in 20 s. Regenerate: `godot --headless --path . -- --ttk-matrix-check > log; godot --headless --path . -- --summon-share-check > slog; python3 tools/ttk_matrix.py log slog > docs/TTK_MATRIX.md`.

**Source figure.** Effective HP = Base HP / 0.8 (the source's Common armour is also 20% and its 2,500 durability outlasts any single life, so armour only ever scales HP; docs/SUPERVIVE_DATA.md section 3). Source seconds = that / the Hunter's LMB DPS from `tools/ttk_matrix_source.json` (kit text damage and cadence). Seconds are scale-free: our HP and damage are both about 1/8 of the source's, so the two columns compare directly. Cells show `ours / source`; a cell with no source figure shows ours only. **Bold** = ours off the source by more than 15%.

## Seconds to down (ours / source)

| Attacker \ defender | Vex | Mossy | Ryzz | Kael | Ravyl | Nivi | Grimble | Lumi | Cinder | Tarek | Motley | Sable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Vex (hold) | **7.6 / 2.4** | **10.7 / 2.9** | **6.4 / 2.5** | **10.7 / 2.5** | **6.4 / 2.2** | **6.4 / 2.5** | **10.7 / 2.8** | **7.6 / 2.5** | **10.7 / 2.5** | **7.6 / 2.5** | **7.6 / 2.3** | **6.4 / 2.5** |
| Mossy (tap) | 6.2 / 6.6 | 8.4 / 7.9 | **4.8 / 6.9** | **8.4 / 6.9** | **4.8 / 5.9** | **5.2 / 6.9** | 8.0 / 7.8 | 6.2 / 6.9 | **8.4 / 6.9** | 6.2 / 6.9 | 6.2 / 6.2 | **4.8 / 6.9** |
| Ryzz (hold) | **10.0 / 13.6** | **13.2 / 16.4** | **8.0 / 14.3** | 13.2 / 14.3 | **8.0 / 12.2** | **8.0 / 14.3** | **13.2 / 16.1** | **10.0 / 14.3** | 13.2 / 14.3 | **10.0 / 14.3** | **10.0 / 12.8** | **8.0 / 14.3** |
| Kael (tap) | **~8.7 / 7.1** | **~11.1 / 8.6** | ~6.7 / 7.5 | **~11.5 / 7.5** | ~7.1 / 6.4 | ~7.1 / 7.5 | **~11.5 / 8.4** | ~8.3 / 7.5 | **~10.7 / 7.5** | **~8.7 / 7.5** | **~8.3 / 6.7** | ~6.7 / 7.5 |
| Ravyl (tap) | 7.4 | 9.8 | 6.2 | 9.8 | 6.2 | 6.2 | 9.8 | 7.4 | 9.8 | 7.4 | 7.4 | 6.2 |
| Nivi (hold) | 3.4 | 4.3 | 2.4 | 4.3 | 2.2 | 3.4 | 4.3 | 2.4 | 4.3 | 2.3 | 3.2 | 3.4 |
| Grimble (hold) | ~13.2 | ~18.3 | ~11.1 | ~18.3 | ~11.1 | ~11.1 | ~18.3 | ~13.2 | ~18.3 | ~13.2 | ~13.2 | ~11.1 |
| Lumi (hold) | 6.9 | 8.6 | 5.7 | 8.6 | 5.7 | 5.7 | 8.6 | 6.5 | 8.6 | 6.5 | 6.5 | 5.7 |
| Cinder (hold) | **5.0 / 5.9** | **5.4 / 7.1** | **4.0 / 6.2** | 5.4 / 6.2 | **3.9 / 5.3** | **4.0 / 6.2** | **5.4 / 7.0** | **4.4 / 6.2** | 5.4 / 6.2 | **4.4 / 6.2** | **4.5 / 5.6** | **4.0 / 6.2** |
| Tarek (tap) | 14.4 | 18.6 | 12.3 | 18.6 | 12.3 | 12.3 | 18.6 | 14.4 | 18.6 | 14.4 | 14.4 | 12.3 |
| Motley (hold) | 11.6 | 15.8 | 9.8 | 15.8 | 9.8 | 9.8 | 15.8 | 11.6 | 15.8 | 11.6 | 11.6 | 9.8 |
| Sable (hold) | 4.4 | 5.3 | 3.9 | 5.3 | 3.9 | 3.9 | 5.3 | 4.4 | 5.3 | 4.4 | 4.4 | 3.9 |

Rows are the attacker (best LMB mode in brackets), columns the defender. `~` = measured near (80% of weapon range).

## Hits to down (ours / source), where the source gives a damage per hit

Cadence-free: defender effective HP over damage per hit (level-15 numbers scaled by the average HP ratio, as docs/specs/DAMAGE_RATIOS.md does). Ours is the count of hits that landed (CombatBus.hit_landed).

| Attacker \ defender | Vex | Mossy | Ryzz | Kael | Ravyl | Nivi | Grimble | Lumi | Cinder | Tarek | Motley | Sable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Vex (hold) | **50 / 30.0** | **66 / 36.2** | **41 / 31.6** | **66 / 31.6** | **41 / 27.0** | **41 / 31.6** | **66 / 35.4** | **50 / 31.6** | **66 / 31.6** | **50 / 31.6** | **50 / 28.2** | **41 / 31.6** |
| Mossy (tap) | 16 / 14.7 | **21 / 17.6** | **13 / 15.4** | **21 / 15.4** | 13 / 13.2 | **13 / 15.4** | **21 / 17.3** | 16 / 15.4 | **21 / 15.4** | 16 / 15.4 | **16 / 13.8** | **13 / 15.4** |
| Ryzz (hold) | 16 / 17.0 | 21 / 20.5 | **13 / 17.9** | **21 / 17.9** | 13 / 15.3 | **13 / 17.9** | 21 / 20.1 | 16 / 17.9 | **21 / 17.9** | 16 / 17.9 | 16 / 16.0 | **13 / 17.9** |
| Kael (tap) | **23 / 35.6** | **29 / 42.9** | **18 / 37.5** | **30 / 37.5** | **19 / 32.0** | **19 / 37.5** | **30 / 42.0** | **22 / 37.5** | **28 / 37.5** | **23 / 37.5** | **22 / 33.4** | **18 / 37.5** |
| Motley (hold) | **20 / 10.7** | **27 / 12.9** | **17 / 11.3** | **27 / 11.3** | **17 / 9.6** | **17 / 11.3** | **27 / 12.6** | **20 / 11.3** | **27 / 11.3** | **20 / 11.3** | **20 / 10.0** | **17 / 11.3** |
| Sable (hold) | **10 / 17.6** | **12 / 21.2** | **9 / 18.5** | **12 / 18.5** | **9 / 15.8** | **9 / 18.5** | **12 / 20.7** | **10 / 18.5** | **12 / 18.5** | **10 / 18.5** | **10 / 16.5** | **9 / 18.5** |

## What the source gives, and what is off

| Attacker | Source DPS (basis) | Why ours differs |
|---|---|---|
| Vex / Ghost | 638 (51/round, ~12.5 rounds/s, 30-round magazine; cadence 0.08 s [F]) | ours/source seconds x3.26, DPS share x0.31, damage per hit x0.60, cadence x0.51 (6.4/s vs 12.5/s) | Cadence: ours 0.12 s a round against ~0.08 s [F, not D], and our sustain rule halves damage after round 10 (the wiki's fall-to-50% reading) with a 1 s refill gap after 30 rounds. Damage per hit is at parity for the first 10 rounds (51 = 3.97% of average HP, ours 6 = 3.9%). Not fixed: the cadence is not [D] and KIT_PARITY row LMB (Vex) calls it a match. |
| Mossy / Oath | 232 (hammer throw 192@15; cadence 0.45 s [card]) | ours/source seconds x0.93, DPS share x1.08, damage per hit x0.92, cadence x1.17 (2.6/s vs 2.2/s) | Within 15% on damage and cadence; the flags are the defender HP share (light Hunters x0.80 die sooner than the source's flat 1290). Different weapon: our tap is a shield throw/bash, the source's an Oath hammer throw (owner call, KIT_PARITY). |
| Ryzz / Joule | 112 (Jolt 90; cadence 0.8 s [F]) | ours/source seconds x0.73, DPS share x1.38, damage per hit x1.07, cadence x1.28 (1.6/s vs 1.2/s) | Cadence: ours 0.648 s against the source's 0.8 s [F, not D] and damage per hit x1.10. The owner kept 0.648 (KIT_PARITY Ryzz LMB, items 70 and 116). Light defenders (x0.80) add to the flags. |
| Kael / Brall | 215 (Caldera press 43, swings ~0.2 s apart; hold = fireblast 107; cadence 0.2 s [F]) | ours/source seconds x1.18, DPS share x0.84, damage per hit x1.60, cadence x0.53 (2.6/s vs 5.0/s) | Measured with the press combo (the source's 43-damage figure) at 2.7 m: it cannot reach 8 m, the 8 m LMB is the hold fireblast. Cadence 0.34 s against ~0.2 s [F]; damage per hit 11 against 43 [D], x1.63 after the HP scale. The two roughly cancel (DPS share x0.87), so halving the damage to match the [D] number would make Kael slower, not closer. Not changed. |
| Ravyl / Myth | none (bow, no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Nivi / Celeste | none (darts, no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Grimble / Kingpin | none (shotgun, no damage number (only a % ladder by slugs landed); cadence 0.9 s [F]) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Lumi / Elluna | none (no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Cinder / Felix | 258 (flamethrower 258/s) | ours/source seconds x0.75, DPS share x1.33 | Our figure includes the Flashover rules (+25% on a burning foe, 1.5% max HP a second, 2% a second burn); the source's 258/s is the base stream, its Ignite bonus (a % of max HP) has no number in the data. The bare stream is 27/s = x0.87 of the source. Not fixed: no [D] number to match the bonus. |
| Tarek / Tetra | none (kit text has no damage numbers) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Motley / Void | none (Gravity Orb 263@15, no cadence) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Sable / Shiv | none (Arcslinger 160@15, no cadence) | no seconds figure | no source cadence or damage number, so nothing to flag |

Defender HP shares (ours over source, from docs/KIT_PARITY.md Health): Vex x0.99, Mossy x1.09, Ryzz x0.80, Kael x1.25, Ravyl x0.94, Nivi x0.80, Grimble x1.11, Lumi x0.94, Cinder x1.25, Tarek x0.94, Motley x1.05, Sable x0.80. Armour is not a cause anywhere: both games take 20% off while it lasts and neither runs out in one life.

## Summon column: what one summoned Boki adds to a 1v1 knock

`--summon-share-check`: Vex holding LMB at 6 m and Kael tapping at 2 m down a pinned dummy with a Medium Hunter's base health and armour, alone (Vex 7.6 s, Kael 7.8 s) and with the Boki burst out on the first frame, three seeded fights each. Share = the Boki's damage over all the knock's damage; faster = knock time saved. Band (decision 0043): 15-25% of the knock. `dmg_k` = the species' damage while summoned, from content/rules/boki_summon.json (1 when unlisted).

| Boki | Window s | Knock alone s | With summon s | Faster | Share of knock | dmg_k |
|---|---|---|---|---|---|---|
| heatherhorn | 18 | 7.67 | 5.32 | 31% | 24% | 0.30 |
| marchleaf | 8 | 7.67 | 5.62 | 27% | 24% | 0.27 |
| glaciatee | 13 | 7.67 | 5.51 | 28% | 24% | 0.39 |
| dreadnoyak | 13 | 7.67 | 5.67 | 26% | 24% | 0.40 |
| vespox | 13 | 7.67 | 5.62 | 27% | 23% | 0.30 |
| velvorm | 13 | 7.67 | 5.67 | 26% | 23% | 0.30 |
| murmurling | 9 | 7.67 | 4.99 | 35% | 23% | 0.36 |
| rimink | 13 | 7.67 | 5.88 | 23% | 23% | 0.37 |
| caecilith | 10 | 7.67 | 4.51 | 41% | 22% | 0.68 |
| basaltoad | 16 | 7.67 | 5.41 | 30% | 22% | 0.33 |
| cairnback | 18 | 7.67 | 5.38 | 30% | 22% | 0.30 |
| glaivyx | 13 | 7.67 | 5.75 | 25% | 22% | 0.30 |
| gloamspire | 10 | 7.67 | 4.39 | 43% | 22% | 0.70 |
| goliathite | 18 | 7.67 | 5.38 | 30% | 22% | 0.30 |
| hivara | 8 | 7.67 | 5.73 | 25% | 22% | 0.25 |
| chandelapi | 10 | 7.67 | 4.28 | 44% | 22% | 0.70 |
| floenatee | 20 | 7.67 | 5.99 | 22% | 22% | 0.73 |
| glintmole | 11 | 7.67 | 5.18 | 32% | 22% | 0.50 |
| duskapi | 12 | 7.67 | 4.28 | 44% | 22% | 0.72 |
| ermink | 16 | 7.67 | 6.00 | 22% | 22% | 0.72 |
| hoarheron | 13 | 7.67 | 5.68 | 26% | 22% | 0.38 |
| moundvark | 18 | 7.67 | 5.70 | 26% | 22% | 0.28 |
| rimeshrew | 7 | 7.67 | 5.16 | 33% | 22% | 0.30 |
| selenfin | 16 | 7.67 | 5.99 | 22% | 22% | 0.73 |
| seamwyrm | 10 | 7.67 | 3.84 | 50% | 22% | 0.77 |
| blossmink | 18 | 7.67 | 5.99 | 22% | 22% | 0.72 |
| nettlynx | 8 | 7.67 | 5.54 | 28% | 21% | 0.35 |
| skidlet | 7 | 7.67 | 5.28 | 31% | 21% | 0.29 |
| spatewader | 18 | 7.67 | 5.23 | 32% | 21% | 0.30 |
| coolatee | 7 | 7.67 | 5.19 | 32% | 21% | 0.29 |
| crofthollow | 18 | 7.67 | 6.00 | 22% | 21% | 0.72 |
| sentrikat | 18 | 7.67 | 4.72 | 38% | 21% | 0.45 |
| umbrink | 10 | 7.67 | 4.34 | 44% | 21% | 0.67 |
| orchisloth | 18 | 7.67 | 5.99 | 22% | 21% | 0.70 |
| zapple | 7 | 7.67 | 4.86 | 37% | 21% | 0.42 |
| kayak | 7 | 7.67 | 5.22 | 32% | 21% | 0.29 |
| burrlet | 11 | 7.67 | 6.10 | 20% | 21% | 0.34 |
| lunink | 18 | 7.67 | 4.95 | 36% | 21% | 0.66 |
| lilybara | 20 | 7.67 | 6.01 | 22% | 21% | 0.68 |
| sporcupine | 13 | 7.67 | 6.02 | 22% | 21% | 0.36 |
| casquebill | 13 | 7.67 | 5.36 | 30% | 21% | 0.47 |
| gravitank | 13 | 7.67 | 5.41 | 30% | 21% | 0.43 |
| howlop | 13 | 7.67 | 4.89 | 36% | 21% | 0.41 |
| kestrike | 7 | 7.67 | 5.22 | 32% | 21% | 0.30 |
| opalisk | 8 | 7.67 | 4.95 | 36% | 20% | 0.58 |
| gibbelle | 13 | 7.67 | 5.02 | 35% | 20% | 0.41 |
| nimbostrich | 11 | 7.67 | 5.35 | 30% | 20% | 0.30 |
| prismink | 16 | 7.67 | 6.02 | 22% | 20% | 0.53 |
| puddlet | 16 | 7.67 | 6.02 | 22% | 20% | 0.68 |
| voltmink | 18 | 7.67 | 4.95 | 36% | 20% | 0.43 |
| glomwort | 11 | 7.67 | 6.08 | 21% | 20% | 0.35 |
| moatpole | 16 | 7.67 | 6.04 | 21% | 20% | 0.67 |
| ringrove | 13 | 7.67 | 5.89 | 23% | 20% | 0.30 |
| glassolotl | 16 | 7.67 | 6.07 | 21% | 20% | 0.51 |
| lodestick | 8 | 7.67 | 4.96 | 35% | 20% | 0.58 |
| anchorhorn | 13 | 7.67 | 5.49 | 28% | 20% | 0.44 |
| geodemole | 16 | 7.67 | 5.57 | 27% | 20% | 0.31 |
| mossgrade | 16 | 7.67 | 6.04 | 21% | 20% | 0.67 |
| zephyrak | 7 | 7.67 | 5.65 | 26% | 20% | 0.33 |
| zipling | 11 | 7.67 | 5.98 | 22% | 20% | 0.30 |
| glomworth | 13 | 7.67 | 6.06 | 21% | 20% | 0.32 |
| gongrowl | 13 | 7.67 | 5.05 | 34% | 20% | 0.41 |
| threadwyrm | 13 | 7.67 | 6.05 | 21% | 20% | 0.32 |
| wisplet | 8 | 7.67 | 4.96 | 35% | 20% | 0.63 |
| nacrolin | 16 | 7.67 | 6.07 | 21% | 20% | 0.52 |
| chandelotl | 16 | 7.67 | 6.07 | 21% | 20% | 0.52 |
| furnacowary | 16 | 7.67 | 6.12 | 20% | 20% | 0.34 |
| limpetor | 18 | 7.67 | 5.47 | 29% | 20% | 0.26 |
| rippmink | 16 | 7.67 | 6.07 | 21% | 20% | 0.51 |
| thrumbird | 16 | 7.67 | 5.52 | 28% | 20% | 0.73 |
| cindle | 8 | 7.67 | 5.35 | 30% | 19% | 0.33 |
| gloamshell | 11 | 7.67 | 6.16 | 20% | 19% | 0.34 |
| pebbit | 18 | 7.67 | 6.16 | 20% | 19% | 0.30 |
| squalltross | 11 | 7.67 | 5.77 | 25% | 19% | 0.35 |
| umbrathere | 18 | 7.67 | 6.06 | 21% | 19% | 0.29 |
| wickapi | 11 | 7.67 | 6.04 | 21% | 19% | 0.31 |
| mothlet | 16 | 7.67 | 6.12 | 20% | 19% | 0.65 |
| kindlewren | 7 | 7.67 | 5.80 | 24% | 19% | 0.28 |
| eclipsowl | 18 | 7.67 | 5.12 | 33% | 19% | 0.62 |
| kilnbadger | 16 | 7.67 | 6.18 | 19% | 18% | 0.32 |
| scaldamus | 18 | 7.67 | 6.22 | 19% | 18% | 0.28 |
| flarmink | 16 | 7.67 | 6.50 | 15% | 18% | 0.31 |
| glaciyak | 18 | 7.67 | 6.12 | 20% | 18% | 0.30 |
| cindowary | 12 | 7.67 | 5.69 | 26% | 18% | 0.25 |
| wyrmink | 16 | 7.67 | 5.61 | 27% | 18% | 0.27 |
| bellowlet | 7 | 7.67 | 5.36 | 30% | 18% | 0.28 |
| moonloris | 18 | 7.67 | 5.06 | 34% | 18% | 0.60 |
| mortarfly | 16 | 7.67 | 5.69 | 26% | 18% | 0.26 |
| tuatrune | 16 | 7.67 | 5.66 | 26% | 18% | 0.26 |
| druzemole | 16 | 7.67 | 5.69 | 26% | 17% | 0.25 |
| effigoon | 16 | 7.67 | 5.69 | 26% | 16% | 0.23 |
