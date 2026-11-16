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
