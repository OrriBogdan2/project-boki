# Match HUD: measured layout (owner reference, 11-12)

The owner asked (11-12) for the match HUD to follow a reference still as closely as possible: layout,
sizes, proportions, bar thickness and segmenting, colours, type weight. The still itself is private and
stays off the repo; these are the numbers measured from it. Everything drawn is our own (shapes, our
icons, our portraits, our fonts).

## How the numbers were taken
- The still is 2000x1299 with browser and player chrome; the game picture is x 0..2000, y 108..1234
  (2000x1126, 16:9). To 1080p: x * 0.96, (y - 108) * 0.96.
- Our HUD is laid out in a 1280x720 frame that `Settings._apply_ui_scale` scales to the window
  (x1.5 at 1080p). So layout px = x * 0.64, (y - 108) * 0.64. All numbers below are layout px.
- Bottom-left items are anchored to the bottom edge: drawn at `sz.y - 720 + y`.

## Self frame, bottom-left (`hud_vitals.gd`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Portrait | bust ~163x182, pale disc behind | ~109x122 | round, r 50 at (66, 596), pale disc in class colour |
| Armour badge (round icon right of portrait) | dia 52 at (248, 919) | dia 35 at (165, 613) | `ArmorHud.RADIUS` 17.5 at `BADGE_C` |
| Leaning plate | x 50..246, y 958..1010, lean 0.56 px/px | x 33..164, y 638..673 | `PLATE_*`, lean `HudStyle.LEAN_K` 0.5 (shared with squad rows) |
| Armour bar (over health) | h 7, segmented ~32 px | y 639.5, h 4.5 | `AR_Y` / `AR_H`, segments `seg_step(max_armor)` |
| Armour number | tab over plate, ~10 px caps | font 10 | tab at the plate's top-left |
| Health bar | w 162, h 23, segments ~26 px | y 645, w ~108, h 15, segments ~17 | `HP_Y` / `HP_H` / `BAR_W` 104, `seg_step(max_hp)` (25 hp, about 18 px at 145 hp) |
| Strip under health (+ value tab) | h 5, value on a tab at its right | y 662, h 3 | shield, or the merged form's shell |
| Health number | caps ~23 px, heavy, leaning | font 21, baseline 683 | `NUM_FS`, `lean_text` |
| "/ max" | caps ~10 px, muted | font 10 | `MAX_FS` |
| Level badge + XP bar | badge dia 17; bar x 39..216, h 13 | badge r 7.5; bar x 30..146, y 687, h 9 | `XP_*` |
| Second bar (gold) | x 34..211, h 11 | y 699, h 8 | the class resource (`_res_bar`) |

Colours sampled: health `#a8f26e` (`HudStyle.SELF`), armour `#1974f7` (we keep the armour tier colour),
strip `#7edaf0` (`SHIELD_BAR`), plate `#050f19` (`FRAME`), XP `#d33efd` (`XP`), gold `#ffb729` (`RES`).

## Ability row (`hud_slot.gd`, `rank_marks.gd`, `Hud._draw_abilities`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Slots | 55 square, pitch 66, first at x 391, top y 978 | 36, pitch 44, x 260, y 652 | `HudVitals.SLOT*` |
| Corner radius | ~5 | ~4 | `HudStyle.SLOT_RAD` 4 |
| Rank badge | pink tab ~21x12 on the top edge, numeral | ~14x8 | `RankMarks.pips`: numeral tab, gold when maxed |
| Key label | dark tab h 19 under the slot, white caps ~10 px | h 13, font 10, centre 14 below the slot | `HudStyle.key_pill`, `KEY_DROP` |
| Cooling | dark slot, pink-red edge, big pink-red number | | `CD_TEXT` `#ff3d6e` |

## Minimap and phase line (`Hud._draw_minimap`, `_draw_clock_bar`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Disc | dia 252, centre (138, 159), thin pale rim | dia 168, top-left (8, 22) | `MM_D`, `MM_AT`, rim 1.5 px |
| Clock tab | 59x15, centred on the disc's top, grey | 40x13 | match time left; red under 30 s |
| Phase line | words y ~316, bar h 6, x 19..257 | words + 3 px bar, x 7..177 | raid condition, phase word, `LV. n`; bar `#0863d4` on `#242f3e` |

## Weapon (`weapon_hud.gd`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Silhouette | pale white side-on gun, x 256..374, y 974..1022 | x 171..250, y 650..682 | `AT` (210, 666), `Icons` at scale 42 (~76 px wide), `SIL` `#eef6fb`, element tints it 35 % |
| Ammo | none shown (its gun has no magazine) | | leaning count, font 15, "/ mag" font 10, baseline 700 under the silhouette; reload dims it and fills a 3 px strip |

Every weapon has its own drawn silhouette in `icons.gd` (the 11 that had none got one).

## Bottom-right row (`belt_hud.gd` `row`, `grip_hud.gd`) and gear column (`gear_panel.gd`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Consumable slots | 39 square, pitch 43, foot y 1044 | 26, pitch 29, foot 696 | the belt (`BeltHud.SLOT`, `GAP`, `BOTTOM`); Boki throw left of it |
| Count over a slot | "2/8", caps ~11 px, in the item colour | font 11, 4 px over the slot | "left/max" (replaces the old corner badge) |
| Item cards | 53x62, pitch 60, rarity-coloured foot ~19 px | 36x42, pitch 40, foot 12 | gloves (rarity foot) and the Boki (foot = bond meter, gold) (`GripHud.W/H/BASE_H`) |
| Gap consumables to cards | 48 | 32 | `TO_GRIPS` |
| Item column, right edge | round icons dia ~34, pitch ~38 | 26, pitch 30, 14 from the edge | `GearPanel` (gloves, armour, boots), rarity rim |

The weapon card that used to sit bottom-right is gone: weapon → silhouette above, gems → currency
top right, seeds / box / backpack → the line under it.

## Top right (`score_row.gd`)
| Part | Reference (1080p px) | Layout px | Ours |
|---|---|---|---|
| Counter icons | ~15 px, pitch 43, centre y 26 | scale 6.5, pitch 28, y 17 | squads left, kills, knocks |
| Rule | 1 px `#9cb8ce`, diamond ends, y 44 | y 29.5 | `RULE_*` |
| Counts | caps ~12 px, white, under each icon | font 12, baseline 44 | |
| Currency | caps ~21 px `#e8f8d0`, coin dia 26 at the right | font 20, baseline 23 | gems + gem icon (`CUR_*`, `COIN_R`) |
| Carry line | (a stat list in the ref) | font 10-11, baseline 60 | seeds · box, backpack used/max |

## Left for later (not in this pass)
- Squad rows and the ALLY KNOCKED world marker: `ext/squad-frames` (same reference, same `LEAN_K`
  and frame colour; its private `_slant` / `_lean_text` can switch to `HudStyle.slant` / `lean_text`).
- The ref's cut-out portrait bust (our portrait art has no transparency: round portrait).
