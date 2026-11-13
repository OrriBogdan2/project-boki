# The Hollow Crown: regions

One line per region: landmark (what you name it by from afar) · terrain · cover · why you go · source role it stands for.
Built by `tools/make_hollowcrown.py` (purposes and loot leans in its `regions` list); checked by `--hot-zone-check`.
Each match also picks one region (not the Crown) as the **hot drop zone**: loot there rolls a rarity step better, it's ringed on the drop map and minimap, and one bot squad usually heads there (`scripts/match/hot_zone.gd`).

The drop map shows every monster camp as a campfire (1, 2 or 3 flames by size, a crown on a Chief), "N camps: to level L" under each region's name, and the hot zone as "HOT: bigger camps, better loot" (`scripts/ui/camp_map.gd`, decision 0048). Cleared camps dim for the squads that were near them. Thin smoke columns mark the camps during the drop (`scripts/match/camp_smoke.gd`). `--camp-map-check` covers it; `--region-shots` writes `drop_map.png` and `dive_smoke.png` (copies in `docs/shots/early-camps-map-ui/`).

- **The Crown** (gloom): rune ring over the vault · broken stone crown, a lv 4 terrace round the lv 8 Throne, two Gaol lair rocks · sparse gloom grass on the terrace edges · the vault, the two boss Gaols, the richest chests, the most Blight · the Heart (center vault).
- **Frostgate** (frost): hooded ice statue · the Keep's high ground (lv 6) over the Gate Span, open Rimefield below · almost bare, cover is the Keep's walls · best armor on the map (armor ×1.6) · base camp.
- **Cinder Steps** (ember): forge chimney · a lv 2 mesa with the lv 6 Kilns plateau over the Forge Yard · a few scorched clumps by the camp and stairs · gloves and weapon tunings (glove ×1.6), a camp to level on · forge / outpost.
- **Stormbreak** (storm): twisting crystal spire · the lv 6 Shrine Table over a lv 2 rock field · thin grass in the rock lee · the shrine, boots (the storm lean), Storm Halt (sky train) off its east rim · shrine.
- **Thornwood** (bloom): blossom arch · a lv 2 wood with the lv 4 Bramble Rise at its east end · the densest tall grass, thickets round the nest · the Boki nest, the Thornhive lair, tall-grass ambushes, an uplink · Boki habitat / lair.
- **Larkhollow** (meadow): giant tree on the north coast · a grassy bowl ringed by three rim mounds (lv 2) · grass on the rims, the bowl open · wild Boki grazing in the Hollow, a skiff dock out · calm landing.
- **Highwatch** (frost): stone lighthouse · a lv 4 lookout shelf over the Gaol and the Watch Road · bare frost, rocks for cover · the Lookout, boots (boots ×1.8), an uplink out · outpost.
- **Duskmoor** (storm): standing-stone ring · low moor with the raised (lv 2) ruined Moor Chapel floor and its broken walls · grass in the ruins' lee · relics (passive ×2.0), a skiff dock out · ruins / vault-lite.
- **Saltmere** (bloom): white salt obelisk · a dry salt river between two lv 2 banks · grass along both banks · salt caches (the outer ring's most chests), an uplink out · riverside landing.

## Shops

Each region lists its vendors in `regions[].shops` ([x, z, stock], `tools/make_hollowcrown.py`, written to `content/maps/hollowcrown.json`); the stocks are themes in `content/rules/shops.json`, the same every match, bought with the gems picked up this run. Re-placing a shop for a new layout is one edit of its region's list: a spot that lands off the region's open ground moves to the nearest open tile of that region within `snap_tiles` (`Shops.spot`), and `--region-shops-check` fails if a region ends with none, more than two, or a shop on someone else's land. Vendors show on the drop map, the full map (legend) and the minimap (a detail kind: on a hold, or once in view). Bots buy belt items and repairs, and upgrades (armor tier, rarer gear, perks) once they hold more than the upgrade reserve.

- **The Crown**: Crown Exchange (premium: prices ×1.5, Epic gear): Mirror, Vortex and Skyhook gloves, the Gale Cloak, Hollow and Storm Brands, Keen Edge.
- **Frostgate**: Frostgate Armory: armor tiers, repairs, the three armor pieces, Shield cell, Plating, Sure Foot (ice ward).
- **Cinder Steps**: Kiln Forge (gloves: Power, Rocket, Blink, Fissure, Hook; Shatter Charge; Emberwalk, the lava ward) and Tuning Bench (weapon tunings, Ember Brand, Tinker's Roll, Quick Hands).
- **Stormbreak**: Stormbreak Outfitters: backpack, Quickstep and Windstep boots, the movers (Spring pad, Stim, Cloud Raft, Gust Fan), Grounded (lightning ward).
- **Thornwood**: Thornwood Snares: Smoke, Thorn Wall, Blight Flask, Pilfer Pouch, Venom Brand, Spore Mask (spore ward).
- **Larkhollow**: Larkhollow Provisions: the heals (Medkit, Deep Draught, Hearth Lamp, Toss Satchel) and healing perks.
- **Highwatch**: Lookout Post: scouting (Scanner, Lookout Lantern, Hawk Whistle, Omen Draught), Skylark boots, Brass Spyglass, Featherfall.
- **Duskmoor**: Chapel Relics: the passive gloves (Focus, Cooling, Glider, Hover), Twin Gate, Warp Seed, Clear Mind, Overcharge.
- **Saltmere**: Salt Market: Lostway Scroll, Bounty Banner, Skyfall Charge, Magpie Pouch, Wayfarer's Satchel, Second Wind.

Every shop also sells Tonic and Armor kit. The ward perks only come from shops (perk orbs never drop them) and keep that biome hazard off you: Emberwalk (lava vents and pools), Sure Foot (ice patches), Grounded (storm rods), Spore Mask (spore pods). The big hazard fields of map v2 should honour the same `ward` key (`BiomeRun.warded`).
