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

## Looting with a full inventory

- Smart loot (`LootFull.smart`) takes only what fits and reports it: "Took 1 of 3, inventory full", "Inventory full, took nothing", or "Nothing here beats what you've got".
- A box thing that doesn't fit (a backpack thing that isn't worth more than your worst, a full belt, keys, or capsule box) gets a red outline in the loot window. Clicking it moves nothing, plays a short rattle and, for a backpack thing, opens the hold window (`LootHold`) left of the box: your backpack, the clicked thing held in red, Swap (yours goes into the box) and Drop (yours goes on the ground). Belt, key and capsule rows only show "Belt full" / "Box full".
- Chests drop their loot on the ground, so chest and ground items use the older swap window (`Hud.open_swap`), now with the same red outline and rattle. Box looting is local, so there is no Net change.
- Checks: `--loot-full-check`; screenshots: `--loot-full-shots`.

## Hit feedback (OWNER_REVIEW_1103 item 96.4)
One path for every Hunter: `Match.on_damage` plays the hit, `Juice.number` picks the damage number's look
(`Fx.NUM_SMALL / PLAIN / HEAVY / CRIT`, colours in `HudStyle.dmg_col`), `Juice.hit` adds the impact and the
sound layers, `Feel.hitstop` holds the bodies, `Ent.flash_t` flashes the body (the toon shaders' `flash`).
A kit marks an empowered hit with `"heavy": true` in its hit options (a shot's `x["heavy"]`, a stage's
`hit_extra`); a payoff (`"payoff"`) reads the same. No screen shake from any of it (Shake: big hits on you only).

- **Numbers**: yours are the base (cream); an empowered hit is orange, a size up, deep red outline; a crit gold,
  two sizes up, ember outline; your Boki's hits are dimmer and a size down; the hits you take red and a size down.
  Only hits that involve you show numbers.
- **Sound**: each Hunter's weapon has its own hit, `<arch>_hit` (`HeroSfx.hit_sound`, `tools/gen_sfx_hits.py`;
  Neve's is her dart hit), in place of the shared tick; a crit plays the crit tick; an empowered or 28+ hit
  adds `hit_heavy`, armour `armor_hit`. A Hunter without its own falls back to `slash_hit` (melee) or `hit`.
- **Hit-stop**: an empowered hit is at least Feel tier 3 (target 0.065 s; your ranged shots never freeze you),
  a further hit on the same pair inside 0.25 s no longer cuts it to a third, and a small hit no longer cuts a
  running hold short (`Ent.damage` keeps the larger). A shotgun volley with 70% of its slugs on one body
  (`Feel.POINT_BLANK`) is an empowered hit.
- Check: `--hit-feedback-check` (also inside `--hero-combo-check`): each Hunter's LMB at 2.2 m / 6 m (flash,
  number, its own sound, no shake), Grimble's point-blank and Sable's empowered bolt, and the number looks.

| Hunter | LMB hit sound before -> after | Heavy hit | Number before -> after | Hold before -> after |
|---|---|---|---|---|
| Lace | shared `hit` (+`hit_heavy` 28+) -> `archer_hit` | wall pin | already `heavy`; plain -> orange | 0.05 / pin stun tier 4 (unchanged) |
| Cinder | shared `hit` -> `ashwick_hit` | - | plain | unchanged |
| Albert | `hit` (on_damage and the swing's own) + `slash_hit` -> `bulwark_hit` + `hit_heavy` | perfect swing | charged swing already `heavy`; plain -> orange | perfect: payoff (unchanged) |
| Tenzo | `hit` + `slash_hit` -> `dolm_hit` | - | his `heavy` fist hits now orange | unchanged |
| Grimble | shared `hit` -> `dredge_hit` | point-blank | not marked -> orange at 70% of a volley | 0.03 (pellets cut it to a third) -> 0.065 |
| Vex | shared `hit` -> `gunslinger_hit` | - | plain | unchanged |
| Kael | `hit` + `slash_hit` -> `juggernaut_hit` | finishing slam | not marked -> orange (execute stays crit gold) | by damage -> at least tier 3; sweet spot payoff unchanged |
| Sparkle | shared `hit` -> `mage_hit` | - | plain | unchanged |
| Motley | shared `hit` -> `ostra_hit` | - | plain | unchanged |
| Neve | `hit` + kit's `rimewright_dart_hit` (2 sounds) -> `rimewright_hit` once | - | plain | unchanged |
| Meeko | shared `hit` -> `tender_hit` | - | plain | unchanged |
| Sable | shared `hit` -> `thief_hit` | empowered bolt | not marked (looked plain) -> orange + `hit_heavy` | 0.05 -> 0.065 |

Every Hunter already had the body flash (0.12 s, Lace's heavy 0.2 s) and no shake from a plain hit. Your Boki's
numbers looked like yours and the hits you took were the same size; now both are a size down.
