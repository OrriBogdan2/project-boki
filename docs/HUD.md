# In-match HUD: widget files and the shared style

`scripts/ui/hud.gd` is wiring only (a frozen god file). The pieces that draw the fight-facing HUD live
in their own files and share one look, `HudStyle`. Reference study and gap list: `hero-ref/HUD.md`
(outside the repo, on the dev box).

| File | Draws |
|---|---|
| `hud_style.gd` (`HudStyle`) | colour roles, fonts, sizes, and the primitives: `seg_bar`, `strip`, `plate_frame`, `slot_frame`, `key_pill`, `count_badge`, `text` / `ctext`, `dmg_col` |
| `hud_plate.gd` (`HudPlate`, one on `hud.plates`) | overhead plates: level coin, name or status word, health in 25-point segments, armour strip under it, shield past the end of health, chip (holds 0.4 s, then drains), hit flash, armour crack, status icons to the right, dash pips, downed plate and knock burst; `chip_of()` also feeds mob, boss and squad bars |
| `hud_vitals.gd` (`HudVitals`) | bottom-left block: portrait, level coin with XP ring, big health number, thick segmented bar, armour strip, shell, resource bar |
| `hud_slot.gd` (`HudSlot`) | every ability / item slot (`hud._ab_slot`, `hud._skill_slot` delegate here): frame by state, clipped cooldown sweep, big countdown, charge pips, key pill, rank pips, lock |
| `stamina_bar.gd` | the dash bar: segments per charge that refill, flash, tick; overhead, bottom-left and squad frames |
| `hudref_demo.gd` | `--hudref-demo=plates|fight` screenshot scenes |

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
