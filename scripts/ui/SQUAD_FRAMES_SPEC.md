# Squad frames: measured spec

`squad_frames.gd` (SquadFrames) and the ally ping in `downed_marks.gd` (DownedMarks.ally_ping) copy the
owner's reference capture (a private still, not in the repo). Measured 2026-11-12.

## How the numbers were taken
- Capture: 2000x1299 px, with browser/player chrome. Black bar on top: rows 0-43. The game area is
  2000x1255 (x 0-1999, y 44-1298; the player controls overlay its bottom, the game runs under them).
- Normalise: game px -> 1920x1080 by height, `k = 1080 / 1255 = 0.8606` (left-anchored, so x uses the same k).
- Our HUD is laid out in 1280x720 units and scaled by the window (Settings._apply_ui_scale), so at
  1920x1080 one unit = 1.5 px: `unit = game px x 0.8606 / 1.5 = game px x 0.5737`.

## Rows
| What | Ref (game px) | 1920x1080 px | HUD units (const) |
|---|---|---|---|
| Portrait centre x | 60.5 | 52 | 35 (`X`) |
| Portrait radius (with its thin dark rim) | 23 | 19.8 | 13.2 (`R`) |
| Row pitch (centre to centre) | 80 | 68.8 | 46 (`PITCH`) |
| First row centre below the minimap block (timer bar bottom) | 68 | 58.5 | 39 (`FIRST_DROP`) |
| Text column start, right of portrait centre | 30.5 | 26 | 17.5 (`LABEL_X`) |
| State label caps (KNOCKED/DEAD), top / baseline from centre | -22 / -11 | -19 / -9.5 | baseline -6.6 (`LABEL_Y`), 10 px font, condensed 0.82, lean 0.22 |
| Name caps height / baseline from centre | 10 / +6 | 8.6 / +5 | baseline 3.4 (`NAME_Y`), 8 px body sans at weight 600 (`name_font`; the ref's name is a plain medium sans, not the display face) |
| Level number (lower-left of portrait, no chip) height | 10.5 | 9 | 11 px font (`LVL_PX`; Lilita digits run small), centre (-8.9, +6.9) |
| Bar frame top from centre | +11.5 | 9.9 | 6.6 (`BAR_Y`) |
| Bar frame height | 16 | 13.8 | 9.2 (`BAR_H`) |
| Bar frame width along the top | 76 | 65.4 | 43.6 (`BAR_W`) |
| Slant: bottom edge left of top edge | 8 | 6.9 | 4.6 (`BAR_SKEW`) |
| Armour row height (top) | 4 | 3.4 | 2.3 (`ARMOR_H`) |
| Gap, then health row height | 2, 6 | 1.7, 5.2 | 1.1, 3.5 (`HP_H`) |
| Knocked marker centre, right of portrait centre | 184 | 158 | 106 (`MARK_DX`) |
| Knocked marker size (body + tail) | 75 x 45 | 65 x 39 | body r 13 (`MARK_R`), long point 2 r toward the ally, three short points 1.3 r |

No segment ticks: both bars are solid fills in one black slanted frame; the empty part stays black.
Each fill is two-tone: the lower half darker (health f4f01b over 8f9a2e, armour 306fd7 over 1f5a9f), so `_fill` shades
the lower half with 38% black (`SHADE`).

## Colours (sampled)
| What | Ref | Ours |
|---|---|---|
| Health (self) | #f2ef10 top half, #8f9a2e lower half | `HP_COL` f2ef10, lower half under `SHADE` |
| Armour | #2d71d5 | `ARMOR_COL` 2d71d5 |
| Knocked bleed-out (in the health row, armour row empty) | #23a5f4 | `BLEED_COL` 23a5f4 |
| Frame | #020204 | `FRAME` near black, 92% |
| KNOCKED label | hot pink with a pale inner | `KNOCK_COL` ff6fb4 |
| DEAD label | #bbc0c6 | `DEAD_COL` bbc0c6 |
| Name | near white | `NAME_COL` eef4f2 |
| Knocked portrait tint | portrait averages #b57d8b | `TINT_KNOCK` (0.95, 0.2, 0.32) at 50% |
| Dead portrait | light grey #cac9ca with a soft white 4-ray burst past the rim and a dark crack | grey cut under `TINT_DEAD` (60% light grey), `_burst`: four diagonal rays to 1.3 r (a soft wide one under a bright thin one), a dark crack line |
| Killer disc (dead row, at the marker's spot) | red disc with a white emblem, ~23 px across, centre 188 px right of the portrait | `KILL_R` 11.5 units, `KILL_COL` e8304a; the finisher's face in it inside a `KILL_RIM` 2.5 ring (the ref's emblem is a class icon, ours is the Hunter portrait) |
| Marker body / X | #e2faeb / #e84b5b | `MARK_FILL` / `MARK_X` |

## Ally ping (world)
| What | Ref (game px) | 1920x1080 px | HUD units |
|---|---|---|---|
| Face circle radius | 45 | 38.7 | 25.8 (`PING_R`) |
| Spiked ring | cyan #3cb8f0, flames up-left and up-right, red X on top | | `PING_RING`, 3.5 rim |
| "ALLY KNOCKED" caps height / width | 17 / 117 | 14.6 / 100 | 14 px font, condensed 0.9, leaning, blue outline |
| Name plate under it | 70 x 20 | 60 x 17 | not drawn: the ally's own overhead plate sits right under the ping |

## States and timing
- Alive: armour over health, live from the match each draw (HUD panels redraw rate).
- Knocked: label, red tint, armour row empty, bleed-out drains in the health row (flashes white while
  stomped); marker beside the row, its tail turned toward the ally on screen. The ping pops in over
  0.25 s (`PING_POP`, overshoot 1.3x, fades in over 0.08 s) from the knock (MateAlerts.since); its white
  inner arc drains with the bleed-out.
- Dead: label (with the deathbox soul timer while they can still be brought back), grey cracked portrait,
  no bars. The level number stays, as in the ref. A killer disc at `MARK_DX` when a Hunter (or a Hunter's Boki) landed the last hit
  (`MateAlerts.killer`, set on the ALIVE/WISP -> DEAD change, cleared on revive); a deathbox row (DEAD with the timer) carries it too.
- Order: teammates, then you last. 2 or 3 rows; none in solo.
- Timing of the ref's own transitions is not visible in a still: the pop and fades are ours.

Not copied: the voice/mute icons left of each portrait and the unmute hint (we have no voice chat).
