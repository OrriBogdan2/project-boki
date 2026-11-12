# In-match HUD: widget files and the shared style

`scripts/ui/hud.gd` is wiring only (a frozen god file). The pieces that draw the fight-facing HUD live
in their own files and share one look, `HudStyle`. Reference study and gap list: `hero-ref/HUD.md`
(outside the repo, on the dev box).

| File | Draws |
|---|---|
| `hud_panels.gd` (`HudPanels`, one on `hud.panels`) | nothing of its own: the fixed panels (top bar, boss bar, kill feed, minimap, vitals, ability / weapon slots, gear, Boki card, squad, perks) draw on this canvas under `hud.c`, at most 20 times a second (item 94); world-anchored and mouse-following parts stay on `hud.c`, every frame. `hover_spots` fill here |
| `hud_style.gd` (`HudStyle`) | colour roles, fonts, sizes, and the primitives: `seg_bar`, `strip`, `plate_frame`, `slot_frame`, `key_pill`, `count_badge`, `text` / `ctext`, `dmg_col` |
| `hud_plate.gd` (`HudPlate`, one on `hud.plates`) | overhead plates: level coin, name or status word, health in 25-point segments, armour strip under it, shield past the end of health, chip (holds 0.4 s, then drains), hit flash, armour crack, status icons to the right, downed plate and knock burst; `chip_of()` also feeds mob, boss and squad bars |
| `team_boki.gd` (`TeamBoki`, drawn by `hud_panels.gd` right after `Hud._draw_squad`) | the squad rows' extras: a level chip on the portrait's lower-left (gold once the ultimate is open, the plate's own chip), and the teammate's small Boki icon with a thin health bar, tinted when it is down, resting or its owner is a wisp. The rest of a row (portrait, name, armour strip over segmented health, status icons, distance, KNOCKED / DEAD / EXTRACTED states) is `Hud._draw_squad`. A teammate's ult cooldown is not synced, so there is no ready marker. Check: `--hudref-check` |
| `hud_vitals.gd` (`HudVitals`) | bottom-left block: portrait, level coin with XP ring, big health number, thick segmented bar, armour strip, shell, resource bar |
| `hud_slot.gd` (`HudSlot`) | every ability / item slot (`hud._ab_slot`, `hud._skill_slot` delegate here): frame by state, clipped cooldown sweep, big countdown, charge pips, key pill, rank pips, lock |
| `portraits.gd` (`Portraits`) | every hunter's face, in the HUD (vitals, squad frames, ally popups) and the menus (`Portraits.Pic`, chip icons): the Warden's painted portrait from `art/portraits/<id>.jpg` (the splash, `<id>_splash.jpg`, in the bigger menu spots), cut to each frame around `content/rules/portraits.json`'s framing, with the frame and its hit, low-health, downed, dead and out states; the rendered model when a Warden has no painted art. New art: `tools/portrait_art.gd`. Check: `--portrait-check` |
| `dash_slot.gd` | the dash as a normal ability slot (Shift): a pip per charge filling as it recharges, a countdown for the next one, a flash and tick when one returns, a diamond for the air dash; one component for the match bar and `home_dash_slot.gd` at home (no dash bar on plates) |
| `recast_cue.gd` (`RecastCue`) | two-step abilities, one language for every hunter (see below) |
| `map_detail.gd` (`MapDetail`) | what the minimap draws: six default kinds (you, squad, Boki, nearest exit, Blight, pings); the rest (places, train, the hot zone ring, far exits, lairs, caches, beacons, rivals' boxes, ships, bounties, allies) show while Tab or the map key is held, while riding in, or once they matter (awake lair, scouted cache, lit beacon). One icon radius (`ICON_R`). The full map shows everything. `--minimap-check` counts the kinds; `--minimap-shots` takes 720p before/after crops |
| `train_map.gd` (`TrainMap`, one on `hud.train_map`) | the sky train on both maps, one draw path (`draw`): the loop as a thin gold line, a small square per halt (named on the full map), the train as a chevron with its cars, and 'Next train: 0:24' at the halt nearest you (`SkyTrain.halt_eta`). On the minimap it is the `train` detail kind and shows by itself only while the loop is within 34 m of you. `--train-map-check` asserts halts, marker and countdown; `--train-map-shots` takes the shots (docs/train_map_shots/, on the 2x Hollow Crown) |
| `outpost_glyph.gd` | an outpost on the minimap and full map: footing, mast, banner in the holder's colour, beacon filling with the charge |
| `msg_lane.gd` (`MsgLane`, one on `hud.msgs`) | every short message (`toast`, `toast_small`, `tip`, `level_up`; the farm's `UI.toast` too): cards stacked down one column under the timer, never overlapping, repeats merged ("x3"), at most 3 at once (2 in a fight), the most important first, short lives (2 s at most in a fight); world labels under a card fade back (`yield_label`). Check: `--msg-queue-check` |
| `combo_mark.gd` (`ComboMark`) | the tag over a rival's plate that carries your combo state: icon, stack pips and a shrinking time ring in your ability colour, shown only to the hunter whose kit applied it (Sable's Marks, Vex's Daze, Sparkle's Static). It reads `ArchKit.combo_read(foe)` from the kit's own status timers; a kit calls `ComboMark.payoff()` when its payoff lands (white body flash, tag flash, sound). Checks: each kit's combo check (`tools/combo_mark_check.gd`); shots: `--combo-mark-shots` |
| `mate_alerts.gd` (`MateAlerts`, one on `hud.mates`) | a teammate down, back up, eliminated or their soul lost: a knocked mark on their squad row's portrait, one faint line beside the row (1.5 s), a sound. Check: `--hudref-check` |
| Solos (`Life.has_mates` false) | no squad on the left (no rows, Boki icons or level chips), no base-to-a-teammate badge, no "YOUR SQUAD" panel, ping or lead keys on the full map (`FullMap._side`), no "Click to ping" hint, no squad words on the wisp and uplink lines. Checks: `--hudref-check` section 9 (runs a solos match, then adds a squadmate to prove each piece comes back); shots: `--solo-hud-shots` (1280x720, trios beside solos) |
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

- Crowd control on the plate: one status row (`HudPlate.statuses`, drawn by `icon_row` on hunter plates and
  `Hud._status_row` on monsters) with one icon per kind, in order: stun, root, Ground, Daze, Slow, then burn,
  weakened, shield, guard. Stun/root/slow read `Ent.stun_t/root_t/slow_t`; Ground and Daze read `KitStatus`
  (`grounded_left`, `rattled_left`). Each shows its time left, shrinking, in the icon's colour; no icons, no row.
  A remote body keeps the Net `kst` time (`KitStatus._note_remote`). Check: `--clarity-check` section 4.

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

## Pop-up budget

Owner playtest 11-09: "ally knocked is way too in your face". The rule now: nothing that pops up during
a fight covers the middle of the screen or stays more than 2 s; edge-anchored, small, merged, few. "In a
fight" is the player hit in the last `Hud.MSG_FIGHT_S` (4 s). Tutorial hints are owned elsewhere
(`ext/tutorial-visibility`) and not covered here.

| Pop-up | Where, size | How long | Now |
|---|---|---|---|
| Ally knocked | was a 300x70 card top centre, pulsing red, portrait, timer, arrow | was all the time they were down | **gone.** Knocked mark on their squad row (left, under the minimap), row outlined steadily (pulses only while stomped), one faint 13 px line beside the row ("down", 60% opacity), the edge arrow toward them (`_draw_squad_markers`, only while they're off screen), "Revive Nm" only within 9 m (`DownedMarks`) |
| Ally revived / eliminated / soul lost | was a 236x44 card top centre | was 2.6 s | **gone.** The same faint line by their row, 1.5 s |
| "DOWN" knock burst over a downed hunter | 22-35 px word and rays over the plate | 1.1 s | rivals only now; a teammate's fall is the row's job |
| Message lane (`toast`, `toast_small`, `level_up`: pickups, armour, combos, objectives, warnings) | top centre column from y 84, cards up to 45% wide, 15/17/20 px | 1.8 / 2.4 / 3.2 s, 3 at once | in a fight: 2 at once, 2 s each (a hint's own life aside); repeats already merge ("x3") |
| Kill feed | top right, 13 px plates | 6 s, 5 lines | unchanged: edge-anchored |
| Stomp line ("Standing on X") | was a boxed 15 px sentence under the crosshair | while standing on a wisp | a short 13 px line, no box |
| Level-up gold wash | full screen at 16% | ~0.3 s | unchanged (brief; `--level-hud-check` holds it); the line goes through the lane |
| Kill / knock flashes (`Juice.kill`, you knocked) | full screen, 14-30% | 0.2-0.3 s | unchanged: brief, and about you |
| "You're down" panel, killcam line | centre, 34 px | while you're down | unchanged: you can't fight then |
| Abyss warning ("HOLD GLIDE TO LIFT") | centre, 26 px | while over the void | unchanged: it is the danger |
| Exit / lair progress, interact prompts | centre-top 24 px, under the crosshair 16 px | while channelling or in reach | unchanged: only while you act on them |
| Hurt direction arcs | round the middle | 1.2 s | unchanged: they are the combat read |

## Looting with a full inventory

- Smart loot (`LootFull.smart`) takes only what fits and reports it: "Took 1 of 3, inventory full", "Inventory full, took nothing", or "Nothing here beats what you've got".
- A box thing that doesn't fit (a backpack thing that isn't worth more than your worst, a full belt, keys, or capsule box) gets a red outline in the loot window. Clicking it moves nothing, plays a short rattle and, for a backpack thing, opens the hold window (`LootHold`) at the right edge, where your inventory was: your backpack, the clicked thing held in red, Swap (yours goes into the box) and Drop (yours goes on the ground). Belt, key and capsule rows only show "Belt full" / "Box full".
- Chests drop their loot on the ground, so chest and ground items use the older swap window (`Hud.open_swap`), now with the same red outline and rattle. Box looting is local, so there is no Net change.
- Checks: `--loot-full-check`; screenshots: `--loot-full-shots`.

## Two-step abilities (RecastCue)

DECISIONS 2026-11-08 "two-step abilities must be obvious and in your face". Kits report and `RecastCue` draws;
no kit draws its own recast HUD.

- **Reporting (pull).** `ArchKit.recast_window()` returns `RecastCue.window(slot, left, total, at, armed, auto)`
  while a recast is open: `slot` is `e`, `x`, `dash` or `lmb`; `at` is what the recast triggers (the seed, the
  knife, the hammer, the landing spot); `armed` false shows WAIT (a minimum hold); `auto` means the window fires by
  itself at the end (no EXPIRED). `ArchKit.combo_marks(out)` appends `RecastCue.mark(foe, n, left, total, label,
  ready)` for every foe carrying the kit's mark, stack or Daze. `_tick_recast` runs `RecastCue.track` for the
  local hunter only.
- **Slot.** The slot pulses in the ability colour (`slot_col`), a timer ring empties (red under `WARN` = 0.6 s),
  and a big "<KEY> AGAIN" sits over it on a dark pill; the key is `Settings.key_cap` of the live InputMap action.
  A window that ran out (not used, not `auto`) shows EXPIRED for 0.9 s.
- **World.** A marker with the key and a ring over `at`. A badge over each marked foe (count, ring for the time
  left, name and seconds, gold when the payoff is ready), and a white burst on the foe when the payoff lands
  (`RecastCue.payoff`, called from `ArchKit.payoff_fx` and the payoffs that bypass it).
- **Sound.** A chime when the window opens, ticks at 0.6/0.4/0.2 s left, a low click on EXPIRED.
- **Buffer.** A press up to `ArchKit.RECAST_BUFFER` (0.15 s) before the recast is allowed is kept in `recast_buf`
  and replayed through `recast_now(slot)` (Ostra's seed, Rimewright's wall, Bulwark's recall, the E lead).

Kits reporting: Thief knife (E), Tender hearth (E), Ostra seed (E), Rimewright wall (E) and Rimelock (X),
Juggernaut chain (E), Mage Kitefall (X), Ashwick flight (X), Bulwark hammer (LMB), Dolm hops (Shift). Badges:
Thief Marks, Mage Sparks, Gunslinger Daze, Rimewright Chill/Fan, Ashwick Char, Juggernaut slam.

Checks: `--recast-cue-check` (each kit reports its window and the cue carries it, EXPIRED, the buffer, the
badges); `--recast-cue-shots --shots-dir=<dir>` (screenshots, run on a GPU through jobq).

## Tutorial objective strip (one banner for both tutorials)
- `TutorialStrip` (scripts/ui/tutorial_strip.gd) is the only objective banner: one line, top-centre, inside the
  title-safe margin (4% of the height, 24 px least), at most 6% of the height and 42% of the width. It glows and
  pulses for 1.6 s whenever the objective changes, then keeps a steady rim. The message lane starts at 72% of the
  width, so the strip never touches it. In the match tutorial the Ways Out strip, the match clock and the ship's
  planning countdown are off; in a real match (`FirstMatchGuide`) the strip drops under `WaysOutHud.bottom()`
  (the zone clocks and their line, 8 px gap) and under the ship's countdown line while the drop is planned.
- The match draws it on the HUD canvas (`TutorialHud`, also `FirstMatchGuide`); the farm adds a `StripView`
  Control (`FarmGuide.hint_box`). Both call `TutorialStrip.paint`. The match step's plain-words detail is a
  message-lane tip when the step opens, not a second line. The farm's Skip sits just under the strip's right end.
- Checks: `--tutorial-hud-check` (strip geometry at 1280x720, 1920x1080, 3440x1440), `--tutorial-strip-shots`.
