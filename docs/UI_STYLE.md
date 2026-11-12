# UI style: the house look and the pop-up budget

Owner, 11-11 after 0.24.4: "the ui needs to be cleaned up / made to look more professional. it looks like an
amateur version of supervive", and earlier the same day: "i want LESS of the random pop up ui stuff, not more".
This file is the rule book every screen follows. The helper API is in [UI_DESIGN.md](UI_DESIGN.md) section 4,
the in-match HUD widgets in [HUD.md](HUD.md). Check: `--uipolish-check` (house look, pop-up budget, every
screen's boxes come from the theme). Shots: `--ui-screens-shots --shots-dir=<dir> [--size=1920x1080]`.

## 1. Audit (11-11, 0.24.5, 1920x1080)

Before/after sheets: [`docs/shots/ui-pro-1111/`](shots/ui-pro-1111) (one image per screen, before left, after right).

**Across every menu (the main cause of the "Supervive" read).** Every panel, button, tab, tag and tooltip was the
same torn outline with a teal-to-magenta neon glow, speckle and scratched runes in the border, a parchment title tab
with nails, a magenta "ticket" primary button with notches, tilted rubber-stamp tags and pink section headers. Neon
magenta and teal on torn violet is that game's palette; the busy edges made every box shout, so nothing had
hierarchy. HUD and menus used different violets and inks.

| Screen | Problems found | This pass |
|---|---|---|
| Title | version shown twice (corner and playtest chip); the menu column ran into the bottom 5% (Quit at y 1050); neon ticket | one version (on the chip); column fits the safe area; solid teal Continue |
| Home | 8 counters in the top bar, four of them "0 wood / 0 stone / 0 fibre / 0 coals" with a placeholder chevron icon; hub bar and key-hint bar both bottom; neon edges on hub and Goals card | edges calm; the four material chips are one Materials chip (`TopChips`: the hammer icon, the total, a row per material in its tooltip; each still shows from the first time you have some) |
| Hunter pick (Relics) | title "Relics" vs subtitle "Who you play... Every Hunter"; locked tiles wrap names over two lines ("The Barnacle / Knight"), uneven; a lone lowercase "challenge" over a bar; the detail card runs past the panel and scrolls | tile names on one line (the title without "The", 14 shrinking to 12 to fit), no empty bar on a tile that hasn't started; the lone "challenge" and the subtitle are `ext/ui-simplify-1111`'s |
| L page (Training Grounds loadout) | glove names cut ("Barrier Glo"), Boki grid runs off the bottom, every option a heavy torn slab | owned by `ext/lpage-fit-1111`; gets the new theme for free |
| Match HUD | a 14 s "Your kit" card pops up over the right of the fight after every landing; the first-match guide banner overlaps the top ways-out strip; bottom-left labels overlap at 8-10 px ("THE HIRED GU..MEDIUM" under the portrait cut by the screen edge, "CARRY OFF" over "FOLLOW", "from Boki", "FEVER" over "UNLOCK"); empty slots are grey dots | kit card only in Training; guide line under the strip; portrait caption, "from Boki" and the CARRY ON/OFF word gone (carry shows as the order word's colour); the last 8-9 size labels (the Boki slot's FOLLOW / DOWN / FUSED, RESTING, the grip's PASSIVE) at the 10 minimum |
| Combat floating text | up to 24 words and numbers in the air; STUNNED / ROOTED / SLOWED / DAZED / GROUNDED floated over targets although the plate's status row already shows them | those five words gone; at most 2 words in the air (`Fx.WORD_MAX`), damage numbers aside |
| Full map | place labels overprint each other ("STORMCROWN GAOL" over "Sealed Gate"); the HUD's top strip and guide line show through above the title | one label pass (`FullMap.label`): place names move a line up or down, or a little sideways, never off their island, to clear the markers, the Ways Out seats with their words and the hot zone's caption (at the opening zoom 10 of the 11 region names sat under a marker; now only Stormcrown Gaol can, a name wider than its crowded island); a halt or gate name that would print over another is left off (the hover card names it); countdowns step to a free line (`--map-names-check`); the darker backdrop is `ext/map-clear-1111`'s |
| Results | neon frame; the Boki card cuts a line at the scroll edge | look only |
| Settings | neon tabs and slabs; pink eyebrows | look only (calm tabs with an accent underline, teal switches) |
| Tutorial | its card is a third style (black box, mint 2 px edge, all-bold Lilita body text) | main's `TutorialStrip` (one strip, mint accent, the plain-words detail in the message lane) now draws the step line and the first-match guide line; the earlier house-look card was dropped for it |

## 2. Type

Two fonts, no others: **Lilita One** (display: titles, names, big numbers) and **Rubik** (everything you read,
with `UI.semi` 560 and `UI.caps` 700 spaced variants). Sizes are layout units (the UI lays out at 1280x720 and
scales 1.5x at 1080p):

| Token | Size | Font | Use |
|---|---|---|---|
| `T_TITLE` | 30 | Lilita | one per panel |
| `T_HEAD` | 19 | Lilita | card and item names |
| `T_BODY` | 15 | Rubik | everything you read |
| `T_SMALL` | 13 | Rubik | secondary lines, hints |
| `T_CAPS` | 12 | Rubik caps | section eyebrows |
| HUD | 10 minimum | Lilita for numbers and keys, Rubik for sentences | nothing smaller than 10 (15 px at 1080p) |

Lilita is never used for a sentence; Rubik is never used for a big number. A one-line tutorial step or what-next
line is a headline (Lilita, cream); anything explaining it is Rubik.

## 3. Colour tokens (`UI`, shared by `HudStyle`)

- Surfaces: `BG` #0c0e16, `SURFACE` ink navy #171a26, `CARD` #1f2333, `RAISED` #272c3f, `NIGHT`/`GLASS` for
  things over the world. Edges are a 1 px hairline (`LINE`, white at 8-10%), never a glow.
- Text: `INK` warm cream #f1ece0, `MUTED` #a3a9b8, `FAINT`.
- **One accent:** `ACCENT` Boki teal #45d3bf (the logo egg's cracks): the primary button's fill, focus rings,
  the picked tab's underline, switches and sliders. Text on it is `DARK_INK`.
- Roles: `GOLD` rewards and gems, `GOOD` owned/ready, `BAD` danger/loss, `INFO` blue, `EYEBROW` warm caps for
  section headers. Rarity colours only on items.
- Magenta and neon gradients are retired. A Hunter's own colour may tint its name and portrait ring only.

## 4. Spacing, shapes, components

- **4 px grid**: 4, 8, 12 (`GAP`), 16, 20 (`GAP_BIG`), 24 (`PAD`, inside a panel). Radii: `R_PANEL` 12,
  `R_CARD` 8, `R_CTRL` 8, `R_SMALL` 4, `R_PILL`.
- **Panel**: `SURFACE`, hairline rim, deep soft shadow, title in Lilita at top left (no tab, no ornament), close X
  top right, footer actions bottom right.
- **Buttons**: primary = solid accent, dark text, one per screen; secondary = `RAISED` slab, hairline, accent edge
  on hover; ghost = text; danger = red outline behind a confirm. Picked option ("Chosen") = accent-tinted slab
  with an accent edge. Tabs = segments in a recessed track, the picked one raised with an accent underline.
- **Tooltip / popup menu**: `SURFACE` a step lighter, hairline rim, `T_SMALL`.
- **Tags**: small caps in a thin coloured outline, straight (no tilt).
- **Icons**: drawn vector icons (`Icons`, `UI.draw_icon`) or painted portraits; one stroke weight per screen,
  sized 16/20/24 units; never a text glyph (», ‹) as an icon, never an empty grey dot for "no icon" (show the slot
  empty instead).

## 5. Motion

Panels fade and rise 140-220 ms; hover grows a button 3% and lights its edge; toasts drop in 240 ms; nothing bounces
or pulses unless it needs you now (a downed teammate's row, a recast window). Full-screen washes stay under 0.3 s.

## 6. Pop-up budget (in a fight)

"In a fight" = hit in the last `Hud.MSG_FIGHT_S` (4 s). What may appear, where, for how long:

| What | Where | How long, how many |
|---|---|---|
| Damage numbers | on the target | merged per target, ~0.8 s; Settings can turn them off |
| Floating words (combo, ult name, PARRIED...) | over the hunter | 0.75 s, **at most 2 in the air** (`Fx.WORD_MAX`); never a status the plate already shows |
| Status (stun, root, Ground, Daze, Slow) | the plate's status row | as long as it lasts; no floating word |
| Message lane (pickups, warnings) | top centre column | 2 at once, 2 s each (`MsgLane.FIGHT_SHOWN`, `FIGHT_LIFE`) |
| What-next line (first-match guide, tutorial) | one banner under the top strip | one at a time |
| Kill feed | top right | 5 lines, 6 s |
| Teammate down / up | their squad row | 1.5 s faint line |
| Help cards ("Your kit") | Training Grounds only | expeditions never pop one up; K opens the kit card |

Anything new that wants screen time in a fight takes a row of this table in the same change, or merges into an
existing one.

## 7. Left for later

- Hunter pick: "Relics" is the game's word for the screen (hub button, unlock texts); renaming it is a naming call,
  not a style one.
- L page layout: `ext/lpage-fit-1111`.
- Full map: at the opening zoom Stormcrown Gaol's name is wider than its crowded island and can still touch its
  seat word; moving markers (deathboxes, pings, the ship) are not obstacles for names.
- Menus keep a few one-off sizes (11, 14) between the tokens; fold them in as screens are touched.
