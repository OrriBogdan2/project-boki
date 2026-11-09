# Armour parity (audit 2026-11-09)

How hunter armour works against the source, row by row. Order of trust: owner > data
(docs/SUPERVIVE_DATA.md §3) > wiki ([Armor](https://supervive.wiki.gg/wiki/Armor),
[Kingpin](https://supervive.wiki.gg/wiki/Kingpin)) > footage (briefs/hero-ref/HUD.md). `[?]` = no
source found: ours is kept as is and marked. Code: `Hunter._mitigate` and `Hunter.ARMOR_TIERS`
(scripts/match/hunter.gd), `Match.on_damage` (progress), `Life.bring_back`. Asserted by
`--armor-parity-check` (tools/armor_parity_check.gd) and `--equal-check`.

| Row | Source | Ours (before) | Verdict | Evidence |
|---|---|---|---|---|
| What armour does to a hit | reduction comes off first, then the rest hits both health and durability; 0 durability = no reduction | same | match | data §3, wiki Armor |
| Reduction by tier | 20 / 25 / 30 / 35 / 35% (Common .. Exotic) | flat 20% at every tier | **fixed**: per tier, our five tiers in order | data §3, wiki table; check `tier N hit cut` |
| Durability by tier | 2,500 / 2,500 / 2,500 / 3,000 / 3,500 | +15% of base per tier | **fixed**: x1 / 1 / 1 / 1.2 / 1.4 of our Common piece (2.2x max health, the source's ~2.4x) | data §3, wiki table; check `tier N plates` |
| Progress to the next tier | 2k / 3.6k / 12k / 20k damage (1.04) | 220 / 560 / 1,000 / 1,600 | **fixed**: same ratios at our damage scale, 220 / 396 / 1,320 / 2,200 (wiki's newer 2k/5k/15k/20k loses to the data file) | data §3; check `2k/3.6k/12k/20k ratios` |
| What fills progress | damage dealt **and taken** from enemy hunters | dealt only (+ monsters a third, + 140 per knock) | **fixed**: damage taken from a rival counts too. Monsters a third and the knock chunk are kept `[?]` (see notes) | wiki Armor "Armor can upgrade..."; checks `damage taken ... fills` (both) |
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
| Grimble: bonus armour damage without spread | Scattergun "deals 66% increased damage to Armor when fired without spread" | not built | **fixed**: a shot fired at 0 bloom wears durability 1.66x, health unchanged (`clean_armor_k` in content/weapons/shotgun.json) | wiki Kingpin; check `no-bloom slug` |

## Notes for the owner (not built)
- Monsters count a third and a knock adds 140: the wiki names only hunter damage. Removing them is
  the strict reading but slows PvE-heavy runs; kept until you call it.
- Kill-dropped repairs and base repairs would be the next parity rows if wanted.
- Our tier names stay ours (Epic / Legendary for the source's top two).
