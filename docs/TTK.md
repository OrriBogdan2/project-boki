# Time to down: every Hunter's LMB into every other Hunter

Parity first (briefs/DECISIONS.md 2026-11-07): the owner asked for TTK in the combat area. `--ttk-check` puts a Training Area dummy at 8 m with the defender's base health and armour (124/145/193 hp, armour durability 2.2x, 20% off every hit while it lasts) and holds the attacker's LMB on it with perfect aim (aim dead on the dummy, shooter and dummy pinned, no dodging, no dash, no ability). It tries every LMB mode the weapon has (hold, taps, hold-to-charge) and keeps the fastest that reaches. An LMB that cannot reach 8 m (melee, short guns) is measured at 80% of its range and the cell carries a `~`. Cells are seconds to down; the check fails if a cell never downs the dummy in 20 s. Regenerate: `godot --headless --path . -- --ttk-check > log; python3 tools/ttk_table.py log > docs/TTK.md`.

**Source figure.** Effective HP = Base HP / 0.8 (the source's Common armour is also 20% and its 2,500 durability outlasts any single life, so armour only ever scales HP; docs/SUPERVIVE_DATA.md section 3). Source seconds = that / the Hunter's LMB DPS from `tools/ttk_source.json` (kit text damage and cadence). Seconds are scale-free: our HP and damage are both about 1/8 of the source's, so the two columns compare directly. Cells show `ours / source`; a cell with no source figure shows ours only. **Bold** = ours off the source by more than 15%.

## Seconds to down (ours / source)

| Attacker \ defender | Vex | Mossy | Ryzz | Kael | Ravyl | Nivi | Grimble | Lumi | Cinder | Tarek | Motley | Sable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Vex (hold) | **7.6 / 2.4** | **10.7 / 2.9** | **6.4 / 2.5** | **10.7 / 2.5** | **6.4 / 2.2** | **6.4 / 2.5** | **10.3 / 2.8** | **6.8 / 2.5** | **10.2 / 2.5** | **6.8 / 2.5** | **6.8 / 2.3** | **5.9 / 2.5** |
| Mossy (tap) | 6.2 / 6.6 | 8.4 / 7.9 | **4.8 / 6.9** | **8.4 / 6.9** | **4.8 / 5.9** | **5.2 / 6.9** | 7.2 / 7.8 | **5.5 / 6.9** | 7.8 / 6.9 | **5.5 / 6.9** | 5.5 / 6.2 | **4.7 / 6.9** |
| Ryzz (hold) | **10.0 / 13.6** | **13.2 / 16.4** | **8.0 / 14.3** | 13.2 / 14.3 | **8.0 / 12.2** | **8.7 / 14.3** | **13.2 / 16.1** | **10.0 / 14.3** | 12.6 / 14.3 | **8.7 / 14.3** | **8.7 / 12.8** | **7.4 / 14.3** |
| Kael (tap) | **~8.7 / 7.1** | **~11.1 / 8.6** | ~6.7 / 7.5 | **~11.5 / 7.5** | ~7.1 / 6.4 | ~7.1 / 7.5 | **~11.9 / 8.4** | ~8.3 / 7.5 | **~10.7 / 7.5** | ~7.5 / 7.5 | ~7.5 / 6.7 | **~6.3 / 7.5** |
| Ravyl (tap) | 7.4 | 9.8 | 6.2 | 9.8 | 6.2 | 6.2 | 8.6 | 6.8 | 8.6 | 6.2 | 6.2 | 5.6 |
| Nivi (hold) | 3.4 | 4.3 | 2.4 | 4.3 | 2.2 | 2.7 | 2.7 | 2.8 | 3.4 | 3.4 | 3.4 | 2.5 |
| Grimble (hold) | ~13.7 | ~18.9 | ~11.6 | ~19.4 | ~11.6 | ~11.6 | ~17.1 | ~12.4 | ~17.0 | ~13.3 | ~12.4 | ~10.5 |
| Lumi (hold) | 6.9 | 8.6 | 5.7 | 8.6 | 5.7 | 5.7 | 8.6 | 6.5 | 9.0 | 6.1 | 6.1 | 5.2 |
| Cinder (hold) | **5.0 / 5.9** | **5.4 / 7.1** | **4.0 / 6.2** | 5.4 / 6.2 | **3.9 / 5.3** | **4.0 / 6.2** | **5.2 / 7.0** | **4.3 / 6.2** | **5.2 / 6.2** | **4.2 / 6.2** | **4.3 / 5.6** | **3.9 / 6.2** |
| Tarek (tap) | 14.4 | 18.6 | 12.3 | 20.0 | 12.3 | 12.3 | 18.6 | 14.4 | 20.0 | 14.4 | 14.4 | 12.3 |
| Motley (hold) | 11.6 | 15.8 | 9.8 | 15.8 | 11.0 | 9.8 | 15.0 | 11.0 | 14.4 | 9.9 | 9.9 | 9.3 |
| Sable (hold) | 4.4 | 5.3 | 3.9 | 5.3 | 3.9 | 3.9 | 5.3 | 4.4 | 5.3 | 4.1 | 4.1 | 3.7 |

Rows are the attacker (best LMB mode in brackets), columns the defender. `~` = measured near (80% of weapon range).

## Hits to down (ours / source), where the source gives a damage per hit

Cadence-free: defender effective HP over damage per hit (level-15 numbers scaled by the average HP ratio, as docs/specs/DAMAGE_RATIOS.md does). Ours is the count of hits that landed (CombatBus.hit_landed).

| Attacker \ defender | Vex | Mossy | Ryzz | Kael | Ravyl | Nivi | Grimble | Lumi | Cinder | Tarek | Motley | Sable |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Vex (hold) | **50 / 30.0** | **66 / 36.2** | **41 / 31.6** | **66 / 31.6** | **41 / 27.0** | **41 / 31.6** | **63 / 35.4** | **44 / 31.6** | **62 / 31.6** | **44 / 31.6** | **44 / 28.2** | **37 / 31.6** |
| Mossy (tap) | 16 / 14.7 | **21 / 17.6** | **13 / 15.4** | **21 / 15.4** | 13 / 13.2 | **13 / 15.4** | 19 / 17.3 | 14 / 15.4 | **20 / 15.4** | 14 / 15.4 | 14 / 13.8 | **12 / 15.4** |
| Ryzz (hold) | 16 / 17.0 | 21 / 20.5 | **13 / 17.9** | **21 / 17.9** | 13 / 15.3 | **14 / 17.9** | 21 / 20.1 | 16 / 17.9 | 20 / 17.9 | **14 / 17.9** | 14 / 16.0 | **12 / 17.9** |
| Kael (tap) | **23 / 35.6** | **29 / 42.9** | **18 / 37.5** | **30 / 37.5** | **19 / 32.0** | **19 / 37.5** | **31 / 42.0** | **22 / 37.5** | **28 / 37.5** | **20 / 37.5** | **20 / 33.4** | **17 / 37.5** |
| Motley (hold) | **20 / 10.7** | **27 / 12.9** | **17 / 11.3** | **27 / 11.3** | **19 / 9.6** | **17 / 11.3** | **27 / 12.6** | **20 / 11.3** | **26 / 11.3** | **18 / 11.3** | **18 / 10.0** | **17 / 11.3** |
| Sable (hold) | **10 / 17.6** | **12 / 21.2** | **9 / 18.5** | **12 / 18.5** | **9 / 15.8** | **9 / 18.5** | **12 / 20.7** | **10 / 18.5** | **12 / 18.5** | **10 / 18.5** | **10 / 16.5** | **9 / 18.5** |

## What the source gives, and what is off

| Attacker | Source DPS (basis) | Why ours differs |
|---|---|---|
| Vex / Ghost | 638 (51/round, ~12.5 rounds/s, 30-round magazine; cadence 0.08 s [F]) | ours/source seconds x3.13, DPS share x0.32, damage per hit x0.63, cadence x0.51 (6.3/s vs 12.5/s) | Cadence: ours 0.12 s a round against ~0.08 s [F, not D], and our sustain rule halves damage after round 10 (the wiki's fall-to-50% reading) with a 1 s refill gap after 30 rounds. Damage per hit is at parity for the first 10 rounds (51 = 3.97% of average HP, ours 6 = 3.9%). Not fixed: the cadence is not [D] and KIT_PARITY row LMB (Vex) calls it a match. |
| Mossy / Oath | 232 (hammer throw 192@15; cadence 0.45 s [card]) | ours/source seconds x0.89, DPS share x1.13, damage per hit x0.98, cadence x1.16 (2.6/s vs 2.2/s) | Within 15% on damage and cadence; the flags are the defender HP share (light Hunters x0.80 die sooner than the source's flat 1290). Different weapon: our tap is a shield throw/bash, the source's an Oath hammer throw (owner call, KIT_PARITY). |
| Ryzz / Joule | 112 (Jolt 90; cadence 0.8 s [F]) | ours/source seconds x0.71, DPS share x1.42, damage per hit x1.10, cadence x1.29 (1.6/s vs 1.2/s) | Cadence: ours 0.648 s against the source's 0.8 s [F, not D] and damage per hit x1.10. The owner kept 0.648 (KIT_PARITY Ryzz LMB, items 70 and 116). Light defenders (x0.80) add to the flags. |
| Kael / Brall | 215 (Caldera press 43, swings ~0.2 s apart; hold = fireblast 107; cadence 0.2 s [F]) | ours/source seconds x1.16, DPS share x0.87, damage per hit x1.63, cadence x0.53 (2.6/s vs 5.0/s) | Measured with the press combo (the source's 43-damage figure) at 2.7 m: it cannot reach 8 m, the 8 m LMB is the hold fireblast. Cadence 0.34 s against ~0.2 s [F]; damage per hit 11 against 43 [D], x1.63 after the HP scale. The two roughly cancel (DPS share x0.87), so halving the damage to match the [D] number would make Kael slower, not closer. Not changed. |
| Ravyl / Myth | none (bow, no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Nivi / Celeste | none (darts, no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Grimble / Kingpin | none (shotgun, no damage number (only a % ladder by slugs landed); cadence 0.9 s [F]) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Lumi / Elluna | none (no LMB number) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Cinder / Felix | 258 (flamethrower 258/s) | ours/source seconds x0.74, DPS share x1.35 | Our figure includes the Flashover rules (+25% on a burning foe, 1.5% max HP a second, 2% a second burn); the source's 258/s is the base stream, its Ignite bonus (a % of max HP) has no number in the data. The bare stream is 27/s = x0.87 of the source. Not fixed: no [D] number to match the bonus. |
| Tarek / Tetra | none (kit text has no damage numbers) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Motley / Void | none (Gravity Orb 263@15, no cadence) | no seconds figure | no source cadence or damage number, so nothing to flag |
| Sable / Shiv | none (Arcslinger 160@15, no cadence) | no seconds figure | no source cadence or damage number, so nothing to flag |

Defender HP shares (ours over source, from docs/KIT_PARITY.md Health): Vex x0.99, Mossy x1.09, Ryzz x0.80, Kael x1.25, Ravyl x0.94, Nivi x0.80, Grimble x1.11, Lumi x0.94, Cinder x1.25, Tarek x0.94, Motley x1.05, Sable x0.80. Armour is not a cause anywhere: both games take 20% off while it lasts and neither runs out in one life.
