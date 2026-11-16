# Armour parity: ours against the source (2026-11-09)

PARITY FIRST (briefs/DECISIONS.md 2026-11-07). Source: `docs/SUPERVIVE_DATA.md` section 3 (wiki, May 2025) and
section 10 on `origin/ext/agent-briefs`; supervive_kits.md and supervive_physics.md say nothing about armour.
Ours: `content/rules/armor.json` (tiers), `ArmorRules`, `Hunter._mitigate` (the split), `Hunter.armor_gain`,
`Match.on_armor_break`, `Juice.armor_break`, `content/utility/armor_kit.json`. Checked by `--armour-check`.

**Scale.** The source's numbers are in its health units. Ours are 0.14 of them (our Medium 145 HP against the
source's medium ~1,040; Light 124/930 and Heavy 193/1,400 give 0.13 and 0.14). Durability and level-up damage
are the source's times 0.14.

**Evidence:** [D] source data (SUPERVIVE_DATA.md, wiki-sourced), [gap] the source data doesn't say.

| Topic | Source | Ours (before this change) | Ours now | Verdict |
|---|---|---|---|---|
| Tiers | 5: Common, Uncommon, Rare, Legendary, Exotic [D] | 5: Common .. Legendary | same | match in count; names and top colour differ (owner call 1) |
| Block per tier | 20 / 25 / 30 / 35 / 35% [D] | a flat 20% at every tier | 20 / 25 / 30 / 35 / 35% | **fixed** |
| Durability per tier | 2,500 / 2,500 / 2,500 / 3,000 / 3,500, the same for every hunter [D] | 2.2x the class's health, +15% of that per tier (Medium: 319 .. 510) | 350 / 350 / 350 / 420 / 490 for every class | **fixed** |
| How a hit splits | the block comes off first; the rest hurts health and wears durability by the same amount; 0 durability blocks nothing [D] | same | same | match |
| A hit bigger than the durability left | [gap] | the tier's full block applies to the whole hit, durability goes to 0 | same | unknown; kept |
| Levelling | by dealing damage: 2,000 / 3,600 / 12,000 / 20,000 [D] | 220 / 560 / 1,000 / 1,600 damage dealt to hunters | 280 / 504 / 1,680 / 2,800 | **fixed** (read as running totals, owner call 2) |
| Monster damage, knocks | [gap] (only "by dealing damage") | monsters count a third; a knock adds 140 | same | ours; kept (owner call 3) |
| New durability on a level-up | [gap] | arrives full | same | kept |
| Storm damage | ignores armour [D] | no storm; fall, burn and glider heat skip armour | same | match in spirit |
| Armour shred | wears durability only [D] | Pin's ult `shred` takes durability only | same | match |
| Break feedback | [gap] | burst, ring, glassy crack sound, 0.045 s freeze for the breaker, "ARMOR BROKEN" toast, white crack on the strip | same | no source to compare; kept |
| Repair | Armor Shards, the Forge, base camp, shop "Armor Repair" 400 gold (Vive Brew 200) [D] | the armour kit (belt): full repair, 1.6 s channel, open to hits (x1.2), spilt by a hit; price 40 vs tonic 30 | same | differ (owner call 4) |
| Repair time | [gap] | 1.6 s | same | unknown; kept |
| Wear slowed by your Boki (`owner_armor`, Crystal kin), +20 from the Plating perk, armour gear | not in the source | built | same | ours; kept (owner call 5) |
| Deathbox armour | an enemy's box armour comes at full durability [D] | armour is not looted from boxes | same | missing; out of scope |

## Owner calls (not built)
1. Tier names and colours: the source's fourth and fifth tiers are Legendary (gold) and Exotic (red); ours are
   Epic (purple) and Legendary (gold), matching our item rarities. Renaming would split the two rarity ladders.
2. Level-up damage: the data lists 2k / 3.6k / 12k / 20k without saying whether they are running totals or per
   level. Built as running totals. Per level would be 280 / 784 / 2,464 / 5,264.
3. Monsters counting a third and a knock adding 140: ours, the source data doesn't say. Keep or drop?
4. Repair: the source repairs with shards, at a Forge or a base camp, and sells a repair at twice a heal. Ours is a
   belt kit (40 vs a 30 tonic). Price ratio 2:1 would make it 60.
5. The armour extras (Boki wear reduction, Plating perk, armour gear stat) aren't in the source.
