# Armour parity (audit 2026-11-09, progress rules 2026-11-11)

How hunter armour works against the source, row by row. Order of trust: owner > data
(docs/SUPERVIVE_DATA.md §3) > wiki ([Armor](https://supervive.wiki.gg/wiki/Armor),
[Kingpin](https://supervive.wiki.gg/wiki/Kingpin)) > footage (briefs/hero-ref/HUD.md). `[?]` = no
source found: ours is kept as is and marked. Code: `Hunter._mitigate` and `Hunter.ARMOR_TIERS`
(scripts/match/hunter.gd), `Match.on_damage` (progress), `Life.bring_back`. Asserted by
`--armor-parity-check` (tools/armor_parity_check.gd) and `--equal-check`. Progress rules: `ArmorXp`
(scripts/match/armor_xp.gd) over content/rules/armor_xp.json; see "Progress" below.

| Row | Source | Ours (before) | Verdict | Evidence |
|---|---|---|---|---|
| What armour does to a hit | reduction comes off first, then the rest hits both health and durability; 0 durability = no reduction | same | match | data §3, wiki Armor |
| Reduction by tier | 20 / 25 / 30 / 35 / 35% (Common .. Exotic) | flat 20% at every tier | **fixed**: per tier, our five tiers in order | data §3, wiki table; check `tier N hit cut` |
| Durability by tier | 2,500 / 2,500 / 2,500 / 3,000 / 3,500 | +15% of base per tier | **fixed**: x1 / 1 / 1 / 1.2 / 1.4 of our Common piece (2.2x max health, the source's ~2.4x) | data §3, wiki table; check `tier N plates` |
| Progress to the next tier | 2k / 3.6k / 12k / 20k damage (1.04) | 220 / 560 / 1,000 / 1,600 | **fixed**: the source's numbers in content/rules/armor_xp.json, scaled by base health to 282 / 507 / 1,689 / 2,816 (wiki's newer 2k/5k/15k/20k loses to the data file) | data §3; check `at our health scale` |
| What fills progress | damage dealt **and taken** from enemy hunters | dealt only (+ monsters a third, + 140 per knock) | **fixed**: damage taken from a rival counts too; monsters and Boki build none; the knock chunk stays `[?]` (see Progress) | wiki Armor "Armor can upgrade..."; checks `dealt ... taken`, `builds none` |
| Order against other layers | not published | merged-form shell, then shield, then armour, then the Boki's owner shield | `[?]` kept | none |
| Damage over time (burn ticks) | not published | ticks hit health directly, armour untouched | `[?]` kept | none |
| Anti-Heal | 70% healing cut; no armour rule published | Blight venom / Anti-Heal only cuts healing; its slugs hit armour like any shot | `[?]` kept | data §3 Healing |
| Storm / closing circle | storm ignores armour | we have no closing circle (the Blight is monsters, which hit armour like any hit) | n/a | data §3 |
| Falls and glider heat | not published | bypass armour (`src` fall / heat) | `[?]` kept | none |
| Armour shred | damages durability only | Pin's ult strips durability only | match | data §3, docs/heroes/archer.md |
| Break moment | footage: the strip empties (dark track stays), white crack | burst, crack sound, "ARMOR BROKEN" for the attacker, empty strip; no invulnerability | match (HUD side on ext/hudref) | briefs/hero-ref/HUD.md |
| Refill out of combat | none listed (only repairs) | none (a dead `armor_wait` timer removed) | match | wiki Armor; check `does not refill` |
| Repairs | Basecamps, the Forge, repairs dropped by kills, powers, Armor Soul | armor kit on the belt (+20), breakable drops | `[?]` partial: no kill drops / base repair yet | wiki Armor |
| Revived from death | "damaged Common Armor in most instances" | kept the tier, durability 0 | **fixed**: back on a broken Common piece, progress reset (amount of "damaged" not published, so 0) | wiki Armor; check `broken Common piece` |
| Death box keeps the armour | your armour goes in your box, lootable | no armour items in matches (Equal) | n/a (design) | wiki Armor |
| Grimble: bonus armour damage without spread | Scattergun "deals 66% increased damage to Armor when fired without spread" | not built | **fixed**: a zero-bloom volley wears the foe's durability 1.66x, health unchanged (`gun.armor_k` in content/archetypes/dredge.json, `DredgeKit._shred_armor`, tier-aware) | wiki Kingpin; `--dredge-combo-check` |

## Progress (content/rules/armor_xp.json, 2026-11-11)

DECISIONS 2026-11-10: hitting players gives no level XP, only progress toward armour upgrades. The
rates and thresholds moved out of `Hunter.ARMOR_TIERS` into the rules file, set to the source. Our
damage points differ from the source's by base health, so the file holds the source's thresholds and
the two health figures, and `ArmorXp` scales: ours = round(source x 145 / 1,030), the Medium class's
base health (scripts/core/data.gd) over the source's median base health (docs/SUPERVIVE_DATA.md §5).

| Row | Source | Ours | Evidence |
|---|---|---|---|
| Damage to reach Uncommon / Rare / Epic / Legendary | 2,000 / 3,600 / 12,000 / 20,000 (cumulative) | 282 / 507 / 1,689 / 2,816 (same at the health scale) | data §3; check `at our health scale` |
| Damage dealt to a rival hunter | counts, point for point | `dealt` 1.0 | wiki Armor |
| Damage taken from a rival hunter | counts | `taken` 1.0 | wiki Armor |
| Damage to monsters | not named (only hunters are) | `monster` 0.0 (was a third) | wiki Armor; check `monster builds none` |
| Damage to a rival's Boki | no Boki in the source | `boki` 0.0 (was a third) | n/a; check `Boki builds none` |
| Damage to a downed rival | not published | none (unchanged) | check `downed rival builds none` |
| A knock | counts (old patch notes), amount unpublished | `knock_source_damage` 1,000 -> 141 `[?]` (was 140) | patch notes via wiki search |
| Shared with the squad | not published | per hunter `[?]` | none |
| Level XP from any of this | none | none | DECISIONS 2026-11-10; check `none of it is level XP` |
| Duel at the TTK matrix's damage | 2 x 1,030 points a mutual down | 2 x 145 (Medium dummy, docs/TTK_MATRIX.md): Uncommon after duel 1, Rare after 2, Epic after 6, Legendary after 10, as the source | check `duel N` |

## Notes for the owner (not built)
- The knock chunk: the source counts knocks but publishes no amount, so ours stays a rules number
  (1,000 source points, about one down's worth). Set it to 0 for the strict reading.
- The health scale is one number; if class health or the source's median moves, the thresholds follow.
- Kill-dropped repairs and base repairs would be the next parity rows if wanted.
- Our tier names stay ours (Epic / Legendary for the source's top two).
