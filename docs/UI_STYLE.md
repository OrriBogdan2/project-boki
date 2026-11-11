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
| Home | 8 counters in the top bar, four of them "0 wood / 0 stone / 0 fibre / 0 coals" with a placeholder chevron icon; hub bar and key-hint bar both bottom; neon edges on hub and Goals card | edges calm; counters unchanged (their "stays once seen" rule is pinned by `--arrival-check`; see 5) |
| Hunter pick (Relics) | title "Relics" vs subtitle "Who you play... Every Hunter"; locked tiles wrap names over two lines ("The Barnacle / Knight"), uneven; a lone lowercase "challenge" over a bar; the detail card runs past the panel and scrolls | look only; names and layout left (see 5) |
| L page (Training Grounds loadout) | glove names cut ("Barrier Glo"), Boki grid runs off the bottom, every option a heavy torn slab | owned by `ext/lpage-fit-1111`; gets the new theme for free |
| Match HUD | a 14 s "Your kit" card pops up over the right of the fight after every landing; the first-match guide banner overlaps the top ways-out strip; bottom-left labels overlap at 8-10 px ("THE HIRED GU..MEDIUM" under the portrait cut by the screen edge, "CARRY OFF" over "FOLLOW", "from Boki", "FEVER" over "UNLOCK"); empty slots are grey dots | kit card only in Training; guide line under the strip; portrait caption, "from Boki" and the CARRY ON/OFF word gone (carry shows as the order word's colour) |
| Combat floating text | up to 24 words and numbers in the air; STUNNED / ROOTED / SLOWED / DAZED / GROUNDED floated over targets although the plate's status row already shows them | those five words gone; at most 2 words in the air (`Fx.WORD_MAX`), damage numbers aside |
| Full map | place labels overprint each other ("STORMCROWN GAOL" over "Sealed Gate"); the HUD's top strip and guide line show through above the title | not changed (see 5) |
| Results | neon frame; the Boki card cuts a line at the scroll edge | look only |
| Settings | neon tabs and slabs; pink eyebrows | look only (calm tabs with an accent underline, teal switches) |
| Tutorial | its card is a third style (black box, mint 2 px edge, all-bold Lilita body text) | not changed (owned by the tutorial jobs) |

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

Lilita is never used for a sentence; Rubik is never used for a big number.

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

## 7. Words (owner, 11-11: "super simplified and easy to understand/use")

The audit and its numbers: [UI_SIMPLIFY_1111.md](UI_SIMPLIFY_1111.md). Check: `--ui-words-check`.

- **Subtitle**: one short sentence (about 10 words) or none. Don't restate the tabs or the title.
- **Tooltip**: one line (`TIP_WORDS`, 14 words). It adds what the control doesn't show; never repeat its label or the
  card it sits on, never a list of stats or ability names (the detail view or K kit card has those).
- **No help walls**: a side panel's "how it works" is at most two short lines. Rules live in the wiki.
- **Hide what you can't act on**: counters at 0, rows nobody can use yet (one faint "N more..." line instead),
  a hint that the next line already gives.
- **Why it's greyed out**: a disabled button gets its reason on a line under it (`HomeEcon._gated`), not only on hover.
- **Wrapping text**: `UI.label` (over 48 letters) and `UI.para` wrap and take the row's free width (`UI.wrap_text`). A
  wrapping label set up by hand in an HBox needs `SIZE_EXPAND_FILL`, or it shows one letter per line.

## 8. Left for later (not in this pass)

- Hunter pick: one-line tile names (shorter names or a two-column list), the title naming (Relics vs Hunters).
- Full map: label collision (place names over halt and gate names), hide the HUD strip and guide line while it is open.
- Tutorial card: move it onto the house look (`TutorialHud`), Rubik body text.
- Home top bar: one Materials chip instead of four (needs the `--arrival-check` "stays once seen" rule revisited).
- HUD bottom left: the remaining 8 px labels (rank "UNLOCK", "LV 6", "AUTO") to the 10-unit minimum; empty item
  slots without the grey dot.
