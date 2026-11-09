# In-match HUD: widget files and the shared style

`scripts/ui/hud.gd` is wiring only (a frozen god file). The pieces that draw the fight-facing HUD live
in their own files and share one look, `HudStyle`. Reference study and gap list: `hero-ref/HUD.md`
(outside the repo, on the dev box).

| File | Draws |
|---|---|
| `hud_panels.gd` (`HudPanels`, one on `hud.panels`) | nothing of its own: the fixed panels (top bar, boss bar, kill feed, minimap, vitals, ability / weapon slots, gear, Boki card, squad, perks) draw on this canvas under `hud.c`, at most 20 times a second (item 94); world-anchored and mouse-following parts stay on `hud.c`, every frame. `hover_spots` fill here |
| `hud_style.gd` (`HudStyle`) | colour roles, fonts, sizes, and the primitives: `seg_bar`, `strip`, `plate_frame`, `slot_frame`, `key_pill`, `count_badge`, `text` / `ctext`, `dmg_col` |
| `hud_plate.gd` (`HudPlate`, one on `hud.plates`) | overhead plates: level coin, name or status word, health in 25-point segments, armour strip under it, shield past the end of health, chip (holds 0.4 s, then drains), hit flash, armour crack, status icons to the right, downed plate and knock burst; `chip_of()` also feeds mob, boss and squad bars |
| `hud_vitals.gd` (`HudVitals`) | bottom-left block: portrait, level coin with XP ring, big health number, thick segmented bar, armour strip, shell, resource bar |
| `hud_slot.gd` (`HudSlot`) | every ability / item slot (`hud._ab_slot`, `hud._skill_slot` delegate here): frame by state, clipped cooldown sweep, big countdown, charge pips, key pill, rank pips, lock |
| `portraits.gd` (`Portraits`) | every hunter's face, in the HUD (vitals, squad frames, ally popups) and the menus (`Portraits.Pic`, chip icons): the Warden's painted portrait from `art/portraits/<id>.jpg` (the splash, `<id>_splash.jpg`, in the bigger menu spots), cut to each frame around `content/rules/portraits.json`'s framing, with the frame and its hit, low-health, downed, dead and out states; the rendered model when a Warden has no painted art. New art: `tools/portrait_art.gd`. Check: `--portrait-check` |
| `dash_slot.gd` | the dash as a normal ability slot (Shift): a pip per charge filling as it recharges, a countdown for the next one, a flash and tick when one returns, a diamond for the air dash; one component for the match bar and `home_dash_slot.gd` at home (no dash bar on plates) |
| `outpost_glyph.gd` | an outpost on the minimap and full map: footing, mast, banner in the holder's colour, beacon filling with the charge |
| `msg_lane.gd` (`MsgLane`, one on `hud.msgs`) | every short message (`toast`, `toast_small`, `tip`, `level_up`; the farm's `UI.toast` too): cards stacked down one column under the ally alerts, never overlapping, repeats merged ("x3"), at most 3 at once, the most important first, short lives; world labels under a card fade back (`yield_label`). Check: `--msg-queue-check` |
| `hudref_demo.gd` | `--hudref-demo=plates|fight|busy` screenshot scenes |

Rules of the look:
- Colours are roles: `SELF` / `ALLY` / `FOE` for health, `LOW` as yours and allies' runs low, armour in
  its tier colour (`Hunter.armor_col()`), `SHIELD`, `CHIP`, `COOLING` for slots that aren't ready.
- Segments are a fixed amount of health (`HP_PER_SEG` = 25, doubling past `MAX_SEGS` = 12), so a bigger
  pool shows more segments.
- Bars are a handful of draws each (track, chip, fill, highlight, shield, one multiline for every gap),
  no nodes per segment, so 40 plates on screen stay cheap.
- Plate height is per hunter: `HudPlate.plate_offset(h)` reads an optional `plate_offset` (metres over the
  feet) from the hunter's `content/archetypes/<id>.json`, falling back to `HudPlate.PLATE_OFFSET` (2.35). Kit
  branches set it for taller or shorter heroes.
- Space kept free for other widgets: under each plate from `sp.y + HudStyle.PLATE_ICON_ROW` (loadout
  icons), and the right half of the bottom bar.

Check: `--hudref-check` (segments follow max health, the chip holds then drains, armour and shield are
drawn, the downed plate and status words show, cooldown text appears).

## The inventory window (I)

- `LoadoutPanel` (in `Hud._build_pack`): what you wear (two gloves with their keys Q and V, armor, boots), the four
  utility slots with keys 1 to 4, your perks, then the backpack list. Every slot names its key.
- Point at a thing for a hover card (`InvTip`, words in `InvText`). A piece of gear is compared with what you wear
  in its slot (`GearCompare`): only the numbers that change, green when better and red when worse.
- Swap by dragging a backpack piece onto a slot (or a glove onto the other glove), or point and press Enter to
  wear it (a worn piece: take it off) and Delete to drop it on the ground. The Wear and Drop buttons stay.
- Beside an open deathbox the window opens at the right edge with the box to its left, and gear rows in the box get
  the same compare card. Charms and a perk-orb cap are not in the game yet, so the window shows what exists.
- Check: `--inventory-check`; screenshots: `--inv-shots` (run with `--resolution`).

## Looting with a full inventory

- Smart loot (`LootFull.smart`) takes only what fits and reports it: "Took 1 of 3, inventory full", "Inventory full, took nothing", or "Nothing here beats what you've got".
- A box thing that doesn't fit (a backpack thing that isn't worth more than your worst, a full belt, keys, or capsule box) gets a red outline in the loot window. Clicking it moves nothing, plays a short rattle and, for a backpack thing, opens the hold window (`LootHold`) at the right edge, where your inventory was: your backpack, the clicked thing held in red, Swap (yours goes into the box) and Drop (yours goes on the ground). Belt, key and capsule rows only show "Belt full" / "Box full".
- Chests drop their loot on the ground, so chest and ground items use the older swap window (`Hud.open_swap`), now with the same red outline and rattle. Box looting is local, so there is no Net change.
- Checks: `--loot-full-check`; screenshots: `--loot-full-shots`.
