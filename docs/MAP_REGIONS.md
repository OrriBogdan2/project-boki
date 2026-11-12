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

**Terrain hazards** (`HAZARD_AREAS` in `tools/make_hollowcrown.py`; `TerrainHazards`, values in `content/rules/terrain_hazards.json`, decision 0060): ground that changes the way across a region, each with a bright edge, clear of every spot, stair foot and exit, never cutting an island off. Your active Boki's type or a hazard perk (Lava-walker, Tidewader, Iceboots: perk orbs, likelier near their field) walks it safely; a shield chip on the HUD says so, also when you are next to it. The Boki tells you when one is near and whether it can handle it, and bots go round what theirs can't.

**Big fields** (owner 11-11): a region built round a hazard is tagged `hazard` (kind) and `share` (its ground under it) in the map's `regions`, so another layout can reuse the tags. A field is an outline with `safe` shapes cut out (`lane()` causeways and fords, `stones()` islets); every spot the field reaches gets a stone islet (`carve_islets`), and `check_hazards` fails a region under its `hazard_min` or a field that cuts an island off.
- **Cinder Steps** (lava, 44%): the Forge Yard is a lava lake with causeways south from the Kilns stair, moats beside the Kilns and pools on its top. Ember Boki or Lava-walker: walk it.
- **Frostgate** (ice, 37%): the Rimefield, the strip south of the Keep and the Keep's yard are ice sheets with packed-snow lanes: no footing, you slide. Frost Boki or Iceboots: full footing.
- **Saltmere** (deep water, 41%): the river is wide channels with two fords and a sandbar for the uplink: slow, weaker hits, you drown once your breath runs out. Swimmers or Tidewader: swim fast.
- **Stormbreak**: static flats south-east of the shrine stair charge up and shock (damage, short stun) every few seconds. Storm and Tempest Boki: no shock.
- **Thornwood**: a bramble patch by the north camp slows and scratches. Bloom and Spore Boki: untouched.
