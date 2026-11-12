# Icons and world props: inventory (2026-11-12)

What draws every in-game icon and every world interactable today, where it is defined, and how many
variants there are. Step 1 of the icons + props art pass: this is a survey only, nothing here changes
the game. Counts come from `content/` and `scripts/` on `main` at 53e2fe7f35.

## Headline

- **Icons:** about 235 named icon slots are served by **90 vector glyphs** in one file
  (`scripts/ui/icons.gd`, `Icons.draw`). There are no image icons. An unknown id draws a plain dot.
- **Hunter kits:** 52 active-ability slots share **23** glyph ids ("dash" covers 7 hunters, "quake" 5,
  "earthshatter" 4). Almost no ability has a picture of its own.
- **Weapons:** 11 of 21 have no glyph at all, and those 11 include every hunter's signature weapon.
- **Statuses and marks:** all 9 statuses and all 3 combat marks borrow an ability glyph and are drawn
  at 7 to 14 px, where the borrowed shapes stop reading.
- **World props:** almost all are built from primitives in code (`scripts/match/models.gd` and
  friends). Sculpted pieces exist for the chest and the 4 breakables. There is **no fan object** and
  **no ground source for updrafts** in the world.

## 1. Icons

### How icons are drawn

| Piece | Where | Notes |
|---|---|---|
| Glyph set | `scripts/ui/icons.gd` (`Icons.draw(c, id, at, s, col)`, `Icons.Glyph`) | 90 ids, one colour per draw, lines and polygons. Used from 26 UI scripts. |
| Slot frame | `scripts/ui/hud_style.gd` (`slot_frame`) | The frame, cooldown sweep and key cap are drawn by the HUD, so an icon is only the symbol. |
| Id aliases | `scripts/ui/kit_card.gd:20` | 4 content ids have no glyph and are mapped to another one: `earthshatter`, `bolt`, `shield`, `dash2`. |
| 3D badges | `scripts/match/models.gd` (`icon_texture`, `icon_badge`) | 4 pixel symbols baked to billboards: bless, key, egg, revive. |
| Perk orb icon | `scripts/match/perk_orbs.gd` (`_icon_tex`) | Glyph baked to a sprite above the orb. |

### Slots by group

| Group | Slots | Defined in | Drawn by now | Gap |
|---|---|---|---|---|
| Hunter active abilities (dash, RMB, E, ult) | 52 (13 hunters x 4) | `content/archetypes/*.json` (`icon`) | 23 shared glyph ids | 29 slots have no symbol of their own; 4 ids are aliases |
| Hunter passives | 13 | `scripts/ui/kit_card.gd:219` | per-hunter map onto existing glyphs | none is unique |
| Weapons | 21 | `content/weapons/*.json` (id is the glyph id) | 10 glyphs | 11 fall back to the dot or an alias, incl. all signature weapons |
| Gear | 25 | `content/gear/*.json` | 19 glyphs | 6 share a glyph |
| Utility | 9 | `content/utility/*.json` | 9 glyphs | ok at vector level |
| Hunter pickup abilities | 13 | `content/hunter_abilities/*.json` | 11 glyphs | 2 shared |
| Boki abilities | 16 | `content/abilities_v2/*.json` | no `icon` field | 16 missing |
| Boki merges | 9 | `content/merges_v2/*.json` | no `icon` field | 9 missing |
| Perks | 11 (+26 orb kinds in `content/rules/perk_orbs.json`) | `scripts/core/data.gd:117` | reuse ability glyphs | none is unique |
| Elements | 5 | `scripts/core/loot.gd` | reuse ability glyphs | none is unique |
| Status effects | 9 | `scripts/ui/hud_plate.gd` (`statuses`) | reuse ability glyphs at 14 px | all 9 borrowed; hard to tell apart |
| Combat marks | 3 + downed | `scripts/ui/combo_mark.gd`, hunter kit scripts, `downed_marks.gd` | gem, shock, concussion, knock at 7 to 11 px | all borrowed |
| Currencies and counters | 4 | HUD and menus | gem, key, seed, egg | fine as glyphs; candidates for a richer coin look |
| Toys | 5 | `content/rules/toys.json` | 5 glyphs | ok |
| Garden items | 26 | `content/rules/garden_items.json` | no `icon` field (text rows) | 26 missing |
| Backpacks | 4 tiers | loot rules | one glyph for all tiers | tiers differ by colour only |
| Menu and HUD glyphs | about 12 | `icons.gd` (heart, clock, paw, recall, ...) | glyphs | ok |

### Map and pings

| Piece | Where | Variants | Drawn by now |
|---|---|---|---|
| Pings | `scripts/match/ping_input.gd` | 3 kinds (spot, enemy, loot) | a marker and a word; no icon per kind |
| Full-map spawn markers | `scripts/ui/full_map.gd` (`icon()`) | 5 categories x 4 states | small shapes drawn in code |
| Shrines, bounty, lair fight, rivals | `scripts/ui/full_map.gd` | 4 | shapes drawn in code |
| Outposts | `scripts/ui/outpost_glyph.gd` | 1 | shape drawn in code |
| Ways out | `scripts/ui/ways_out_map.gd` | 4 seat badges | shapes drawn in code |
| Edge arrows | `scripts/ui/marker_dir.gd` | 1 | triangle |
| Minimap | `scripts/ui/hud.gd` (`_draw_minimap`) | dots, rings, arrows | drawn in code |

## 2. World interactables and props

| Prop | Where | Variants | Built from | Gap |
|---|---|---|---|---|
| Jump pad ("Spring pad") | `Models.jump_pad` (`models.gd`), `content/utility/jump_pad.json` | 1 | 2 cylinders + 3 chevron boxes | placeholder shape |
| Gust | `content/gear/gust_fan.json` (worn gear), launch in `match.gd` | 1 | particle burst only | **no world fan exists** |
| Updraft | `World.updraft_visual` (`world.gd`), `shaders/updraft.gdshader` | 1 column + motes | shader column | **nothing on the ground marks the source** |
| Wind road, air ring | `world.gd` (`winds`), `Models.air_ring` | 1 each | ribbons, torus | effect only |
| Chest | `Models.chest`, `scripts/match/props_sculpt.gd`, `key_chest.gd` | 1 (locked) | sculpted in code; an imported kit chest also exists | one tier only; no rarity read |
| Padlock and key | `scripts/match/key_models.gd` | 1 each | primitives | |
| Breakables | `props_sculpt.gd` (`breakable`), `content/rules/breakables.json` | 4 (crate, pot, barrel, keg) | sculpted in code | ok |
| Shrine | `Models.shrine` + bless badge | 1 | primitives | one look for every blessing |
| Revive beacon | `Models.revive_beacon`, `beacons.gd` | 1 | primitives | |
| Exits | `exit_models.gd` (uplink mast, lift, palisade), `Models.portal`, `seat_beacon.gd` | 4 | primitives | |
| Lair gates | `lairs.gd` | 1 | primitives | |
| Deployables | `Models` gear pad, platform, smoke | 3 | primitives | |
| Pickups | `Models.gear_drop`, `gear_models.gd`, gem, armour shard, tonic, key, perk orb, deathbox, backpack, rare egg, relic mask, wisp | about 12 | primitives, sprites | gear drops share one body |
| Landmarks | `landmarks.gd` | 1 per region | primitives | |
| Set dressing | `art/vendor/*` via `scripts/core/assets.gd` | 68 kit models, repainted by our toon shader | imported kits | not interactable |
| Camps, ruin walls, sky train, skyship, nest | `props_sculpt.gd`, `ruin_walls.gd`, `train_lamp.gd` | 1 each | code | |
| Spawn markers | none in the world | 0 | map only | |

## 3. Worst gaps, in order

1. Ability icons: 52 slots on 23 shared glyphs. Two hunters with the same "dash" tile look the same on
   the HUD and in the kit card.
2. Signature weapons: 11 weapons with no glyph.
3. Statuses and marks: 12 borrowed glyphs at 7 to 14 px. These need single-shape designs made for
   that size, not shrunk ability art.
4. Boki abilities, merges and garden items: 51 rows with no icon at all.
5. Traversal props: the jump pad is a placeholder, and gusts and updrafts have no object that tells a
   player where the lift comes from before they step in.

## 4. Proposed art direction (for approval)

- **Icons:** one bold symbol per slot, two tones of the slot's own colour plus a thin pale rim,
  no frame (the HUD draws the frame), readable at 32 to 48 px. Statuses and marks get simpler
  single-shape versions for 14 to 20 px. The vector glyphs stay as the fallback.
- **Props:** same cel-shaded toy look as the hunters: chunky proportions, soft bevels, two or three
  flat colours, one glowing accent that shows what the prop does.

Samples and the full-pass plan were made outside the repo for review.

## 5. Painted icons, full set (wired in 2026-11-12)

The owner approved the style samples on 11-12. 126 painted icons now live in `art/icons/<id>.png`
(128 px, imported with mipmaps so they stay smooth at 14-20 px). `Icons.draw` draws the painted icon when
one exists, in its own colours (`col` gives the alpha; a near-black `col` gives the silhouette that
unowned Field Book items use), and the vector glyph otherwise. `--icon-art-check` keeps the set complete.
Contact sheet: `docs/shots/icons-full-1112/full_set.jpg`.

| Group | Icon ids | Wired through |
|---|---|---|
| Hunter ability slots (52) | `<hunter>_<dash/rmb/e/x>` | `icon` in `content/archetypes/*.json`; the kit card's alias map is gone |
| Weapons with no glyph (11) | the weapon id | weapon ids already were icon ids; the other 10 weapons keep their glyphs |
| Statuses (9) | `status_<kind>` | `HudPlate.statuses` |
| Combat marks (3) | `mark_static`, `mark_thief`, `mark_daze` | each kit's `combo_read` |
| Boki abilities (16) | `boki_<ability id>` | `KinText.icon` (shape glyph stays as the fallback) |
| Fusions (9) | `merge_<merge id>` | `KinText.merge_icon` (HUD Fusion slot, Boki moves list) |
| Shaping items (26) | `garden_<item id>` | `ItemPages.icon_of` |

Made with Meshy image-to-image (nano-banana-pro) and the approved Storm Rod and Burning samples as style
references, since the 2D generator from the plan was not on the worker. Still open from the plan: hunter
passives, gear, utility, pickup abilities, perks, elements, map pings, and the world props.
