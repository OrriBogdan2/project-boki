# Which mode each Boki is found in

Owner core principle 2 (DECISIONS 2026-11-11, 7:20 PM EST): every Boki type is found in exactly one game or
mode. Each mode has a spawn table with COMMON, RARE and VERY RARE tiers, and the rarer tiers sit behind the
mode's harder difficulties.

- **Data:** `content/rules/mode_boki.json`. Each mode has three tiers, and each tier has a `gate` (the lowest
  difficulty it spawns at; the mode's `gate_doc` says what that number counts) and its species. Expedition also
  has a `legendary` block for its separate per-match roll.
- **Loader:** `ModeBoki` (`scripts/core/mode_boki.gd`). `mode_of(species)` and `tier(species)` give `""` for a
  species that no mode lists.
- **Check:** `--mode-boki-check`. Every species in `Data.KIN` is listed exactly once. Every mode has all three
  tiers with species in each, and each tier's gate is above the one before it. The legendaries are the rare kin
  (`Data.is_rare`), and their roll is under 30%.

## This is a seed, not live yet

No spawn reads the table yet, so nothing in the game changes:
- Expedition still spawns every non-legendary species at every difficulty (`Data.common_kin`).
- Garden visitors still come from every common species that has a rigged model.
- Each boss still drops its own egg when it is killed.

Wiring the table into spawning is a separate task, once the owner approves the split below.

## How it was seeded

Nothing in today's data says which Boki is rarer, so the seed follows four rules:

| Mode | Species | How the tiers were picked | What the gate counts |
|---|---|---|---|
| Expedition: Hollow Crown | 29 | The 6 starters plus the unrigged species. Tier by adult size (`content/kin/*.json` `size.kg`): 9 kg or less is COMMON, 30 kg is RARE, 60 kg is VERY RARE. | `Data.TIERS` index: 0 The Meadow, 1 Dusk Isles, 2 The Hollow. Dusk Isles already promises "rarer Boki". |
| Heart Raid (prototype) | 5 | A dark set that fits the Heart and the Blight: the unrigged shadow, lunar, tempest and one venom species. Tier by the same size rule. | The raid's difficulty level. The mode has no levels yet. |
| Garden visitors | 13 | Today's visitor pool (rigged, non-starter, non-legendary). Tier by the zone the species' theme belongs to: Bramblebank (open from the start) is COMMON, Glasswater and Cinderstep are RARE, Hushwood and Ridge are VERY RARE. | Garden zones open: 1, 2 and 3. |
| Legendaries | 3 | Cairnback, Hivara and Zephyrak, listed under Expedition with a 20% chance per match (DECISIONS 2026-11-09). This is not a tier. | n/a |

## Open questions for the owner

1. **The split.** Once this is live, Expedition loses 18 species it spawns today: 13 go to garden visitors and 5 to
   Heart Raid. Expedition's wild Boki would then be the starters plus species that have no rigged model yet. Is
   that the split you want? The alternative is that a species moves to its mode only when that mode ships, and
   until then Expedition keeps it.
2. **Starters.** The 6 starters are your first Boki, and they also spawn in the wild. They are seeded as
   Expedition COMMON. Should they be in no mode at all, or have a "starter" entry of their own?
3. **Tiers by size.** Big Boki are rarer in the seed. Would you rather pick the tiers by hand, or by some other
   rule (look, lore, type)?
4. **Spawn odds.** Each tier has a gate but no weight. What share of spawns should each tier get (for example
   70/25/5), and does a harder difficulty also raise the rare share, or only unlock it?
5. **Heart Raid's Boki.** Which Boki belong to Heart Raid, and what are its difficulty levels called?
6. **The legendary roll.** Today a legendary egg comes from killing its boss, every time. Should the 20% roll
   decide whether a legendary appears on the map at all (and so whether its lair wakes), or be a second way to
   find one?
7. **The garden's difficulty.** The garden has no difficulty, so zones open stands in for one. Is that right, or
   should visitors' rarity follow something else (garden level, trust)?
8. **The Bokidex.** Principle 2 says the dex shows where each Boki is found and its rarity. `ModeBoki` can
   answer both. Should the dex show this now, from the seed, or wait for your approval?
