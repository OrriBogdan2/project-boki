## Map marks: what is what (owner 11-26)

`map_marks.gd` (`MapMarks`) is the one registry and drawer for the things you walk up to: monster camps, shops,
chests, shrines, jump pads. One badge (dark disc, ring in the category colour, icon) on the minimap, the full map
and the key; on the ground near you (16 m, fading over the last 6) a ring and a short name over the thing
(shops and pads already carry their own sign; a name never sits within 70 px of the hunter).
Colours by category (`MapMarks.ENEMY/LOOT/TRAVEL/OBJECTIVE`): enemy red (camps, boss lairs), loot gold (shops,
chests, vaults, item caches), travel cyan (extraction, jump pads), objective white (shrines, rare Boki).
Minimap: a thing within 45 m shows by itself, all of them while Tab/M is held (MapDetail kind `thing`).
Full map: chests only once zoomed in (a map holds ~46); the key grows a second column past 8 rows.
Check: `--minimap-check` (registry, colours, key rows); shots: `--map-clarity-shots` (GPU; one frame per kind,
minimap, M map). Perf: the per-frame loop over the 77 rows costs ~17 us (headless timing).
