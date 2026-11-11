# The Hollow Crown: regions

One line per region: landmark (what you name it by from afar) · terrain · cover · why you go · source role it stands for.
Built by `tools/make_hollowcrown.py` (purposes and loot leans in its `regions` list); checked by `--hot-zone-check`.
Each match also picks one region (not the Crown) as the **hot drop zone**: loot there rolls a rarity step better, it's ringed on the drop map and minimap, and one bot squad usually heads there (`scripts/match/hot_zone.gd`).

- **The Crown** (gloom): rune ring over the vault · broken stone crown, a lv 4 terrace round the lv 8 Throne, two Gaol lair rocks · sparse gloom grass on the terrace edges · the vault, the two boss Gaols, the richest chests, the most Blight · the Heart (center vault).
- **Frostgate** (frost): hooded ice statue · the Keep's high ground (lv 6) over the Gate Span, open Rimefield below · almost bare, cover is the Keep's walls · best armor on the map (armor ×1.6) · base camp.
- **Cinder Steps** (ember): forge chimney · a lv 2 mesa with the lv 6 Kilns plateau over the Forge Yard · a few scorched clumps by the camp and stairs · gloves and weapon tunings (glove ×1.6), a camp to level on · forge / outpost.
- **Stormbreak** (storm): twisting crystal spire · the lv 6 Shrine Table over a lv 2 rock field · thin grass in the rock lee · the shrine, boots (the storm lean), Storm Halt (sky train) off its east rim · shrine.
- **Thornwood** (bloom): blossom arch · a lv 2 wood with the lv 4 Bramble Rise at its east end · the densest tall grass, thickets round the nest · the Boki nest, the Thornhive lair, tall-grass ambushes, an uplink · Boki habitat / lair.
- **Larkhollow** (meadow): giant tree on the north coast · a grassy bowl ringed by three rim mounds (lv 2) · grass on the rims, the bowl open · wild Boki grazing in the Hollow, a skiff dock out · calm landing.
- **Highwatch** (frost): stone lighthouse · a lv 4 lookout shelf over the Gaol and the Watch Road · bare frost, rocks for cover · the Lookout, boots (boots ×1.8), an uplink out · outpost.
- **Duskmoor** (storm): standing-stone ring · low moor with the raised (lv 2) ruined Moor Chapel floor and its broken walls · grass in the ruins' lee · relics (passive ×2.0), a skiff dock out · ruins / vault-lite.
- **Saltmere** (bloom): white salt obelisk · a dry salt river between two lv 2 banks · grass along both banks · salt caches (the outer ring's most chests), an uplink out · riverside landing.

**Terrain hazards** (`HAZARD_AREAS` in `tools/make_hollowcrown.py`; `TerrainHazards`, values in `content/rules/terrain_hazards.json`, decision 0060): ground that changes the way across a region, each with a bright edge, clear of every spot, stair foot and exit, never cutting an island off. Your active Boki's type walks it safely (a shield chip on the HUD says so), it tells you when one is near and whether it can handle it, and bots go round what theirs can't.
- **Cinder Steps**: two lava fields (east of the camp, and by the west rim) burn you. Ember Boki: safe.
- **Frostgate**: an ice sheet in the yard south of the Keep's west stair: no footing, you slide. Frost Boki: full footing (ice patches too).
- **Saltmere**: the river's north reach is deep water: slow, weaker hits, and you drown once your breath runs out. Swimmers (Soakybara, Frigatee, Barrelmander, Prismander, Selenfin, Zephyrak): swim faster, no drowning.
- **Stormbreak**: static flats south-east of the shrine stair charge up and shock (damage, short stun) every few seconds. Storm and Tempest Boki: no shock.
- **Thornwood**: a bramble patch by the north camp slows and scratches. Bloom and Spore Boki: untouched.
