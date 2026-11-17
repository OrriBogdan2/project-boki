# The Hollow Crown: regions

One line per region: fight type · landmark (what you name it by from afar) · terrain · why you go.
The design and the reasons behind each fight type: docs/MAP_V2.md. Built by `tools/make_hollowcrown.py`
(purposes, loot leans, `fight`, `hazard` and `finals` in its `regions` list); checked by `--hot-zone-check`.
Each match also picks one region (not the Crown) as the **hot drop zone**: loot there rolls a rarity step better, it's ringed on the drop map and minimap, and one bot squad usually heads there (`scripts/match/hot_zone.gd`).

- **The Crown** (gloom) · siege · rune ring over the vault · a walled citadel on the Hollow's north rim: bailey lv 4, keep lv 8, Throne lv 12; three gates (Gate Span, Lark Span, Shard Stair) · the vault, the richest chests, the Stormcrown Eyrie on its Gaol rock off Frostgate.
- **Frostgate** (frost) · sniping · hooded ice statue · a 260 m bare ice shelf (lv 10) with the walled Keep, the Rimefield (lv 4) under it · best armor (×1.6), uplink A in the Rimefield.
- **Highwatch** (frost, slate tint) · towers · stone lighthouse · four rock towers (lv 6, 9, 11 and the Lantern at 14) over a lv 2 yard · boots (×1.8), the highest ground on the map.
- **Larkhollow** (meadow) · open plains · giant tree · lv 0 plain with low swells and boulder clusters, wide necks to Highwatch and Thornwood · wild Boki graze, the most landings, uplink B in the open.
- **Thornwood** (bloom) · forest ambush · blossom arch · a lv 2 wood packed with groves and tall grass, Bramble Rise (lv 6) · the Boki nest, the Thornhive lair.
- **Saltmere** (bloom, salt tint) · water edges · white salt obelisk · a lv 2 rim round a sunken lagoon (lv 0), one causeway, a cache islet · salt caches.
- **Stormbreak** (storm) · chokepoint bridges · twisting crystal spire · five shards over the Hollow, the Shrine Table (lv 6) · the shrine; every way across the middle.
- **Duskmoor** (storm, ash-violet tint) · close-quarters maze · standing-stone ring · a ruin maze round the raised Moor Chapel (lv 4) · relics (×2.0).
- **Cinder Steps** (ember) · cliff fights · forge chimney · four cliff tiers (lv 2, 6, 10, 14) to a sheer east rim, slag pools at the feet · gloves (×1.6), the Sunken Forge lair.

**Terrain hazards** (`HAZARD_AREAS` in `tools/make_hollowcrown.py`; `TerrainHazards`, values in `content/rules/terrain_hazards.json`, decision 0060): ground that changes the way across a region, each with a bright edge, clear of every spot, stair foot and exit, never cutting an island off. Your active Boki's type walks it safely (a shield chip on the HUD says so), it tells you when one is near and whether it can handle it, and bots go round what theirs can't.
- **Cinder Steps**: two lava fields (east of the camp, and by the west rim) burn you. Ember Boki: safe.
- **Frostgate**: an ice sheet in the yard south of the Keep's west stair: no footing, you slide. Frost Boki: full footing (ice patches too).
- **Saltmere**: the river's north reach is deep water: slow, weaker hits, and you drown once your breath runs out. Swimmers (Soakybara, Frigatee, Barrelmander, Prismander, Selenfin, Zephyrak): swim faster, no drowning.
- **Stormbreak**: static flats south-east of the shrine stair charge up and shock (damage, short stun) every few seconds. Storm and Tempest Boki: no shock.
- **Thornwood**: a bramble patch by the north camp slows and scratches. Bloom and Spore Boki: untouched.
