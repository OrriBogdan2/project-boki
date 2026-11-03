# Project Boki menu design

How Kinfall's menus look and behave, and the helpers in `scripts/ui/ui.gd` that build them. The
in-match HUD (`scripts/ui/hud.gd`) has its own Supervive-style layout and isn't covered here; it
shares the colours and fonts.

## 1. The look: a hunter's field kit

The first pass (October 2026) made the menus clean and consistent but quiet: one dark sheet, thin
type, nothing that said *this* game. The second pass gives them an identity of their own.

**Tooled leather, stitched seams and brass hardware**, like the satchel, journal and kit a hunter
carries out to the islands. Why this and not paper or wood:
- It *is* the game's world: you pack a kit, carry a Field Book, bring your Boki home in a satchel.
  Leather and brass say "gear you trust", warm and hand-made, not sci-fi chrome or fantasy gold.
- It stays dark, so light text reads at AA on every panel and the bright, playful world behind a
  menu still pops. Parchment would have flipped every text colour and fought the world.
- It scales from a big panel (grain, burnished edge, seam, brass corner guards) down to a chip
  (just a brass trim) without changing material, so every box reads as one set.

Where each piece goes:
- **Panels and modals** (`UiTheme.panel_frame`): saddle leather with a fine grain, a burnished
  darker edge, a stitched seam 8 px in, brass corner guards with rivets, a long soft shadow, and
  light along the top tinted with the panel's **section colour**.
- **Cards and tiles**: lighter leather with a faint seam; tiles light their brass trim on hover, and
  the picked one wears an edge in its colour with a glow inside.
- **Buttons**: tan leather slabs with a brass trim on a darker lip (secondary), the amber primary
  stitched in dark thread, a red danger, a brass-edged "chosen". Round icon buttons are brass rings.
- **Wells** (tab tracks, inputs, bars, the results strip): recessed, lit from below, brass rim.
- **Bone keycaps** with dark ink, always from `Settings.key_cap` for rebindable actions.
- **Smoked leather** (`glass`) for things over the world: the hub, prompts, hover cards, toasts.

## 2. Rules

1. **One strong title per panel**, pressed into the leather (a dark drop under it), after the
   panel's **section emblem** (a brass-rimmed medallion in the section colour), with at most one
   short subtitle line under it. A stitched rule separates the header from the body.
2. **A type scale.** Display `T_DISPLAY` 46 (a screen's one headline: results, loading), title
   `T_TITLE` 30, head `T_HEAD` 19 (all Lilita One), label `T_LABEL` 15 (Rubik 560, buttons and row
   labels), body `T_BODY` 15, hint `T_SMALL` 13 (Rubik), caps `T_CAPS` 12 (Rubik 700, tight, no
   extra letter-spacing). Numbers that count or line up use `UI.num` (tabular figures); big stats
   use `T_STAT` 30 Lilita (`UiSkin.stat`). Section eyebrows are `section()`: a brass diamond, the
   caps words, a hairline to the end of the row.
3. **Fewer boxes, one frame.** Every box is a `UiFrame` (`scripts/ui/ui_frame.gd`): drop and
   contact shadows, a dark rim, the fill, grain, light from the top (tinted), a bevel line and a
   bottom shade, a burnished edge, a brass trim, the stitched seam, brass corner guards, an inner
   glow and an edge, each optional. `leather(thread)` turns on grain, burnish and seam together.
   Wells and tracks are the same frame reversed (`UiFrame.sunk`).
   Radii come from `R_PANEL` 18, `R_CARD` 12, `R_CTRL` 10, `R_SMALL` 6, `R_PILL`. Cards have no
   outline unless they are *selected*. Group with spacing and eyebrows before reaching for a card.
4. **Three button tiers.** `primary()` (filled accent, dark text): the one thing the screen is for,
   at most one per screen, usually in the footer. `button()` (outline): normal actions.
   `ghost()` (text only): rare or small actions. `danger()` (red outline) for things that can't be
   undone, always behind `confirm()`.
5. **Colour roles.** `ACCENT` (amber) means "act here" and focus. `GOLD` means gems and rewards.
   `GOOD` owned/ready/success, `BAD` danger/loss/locked, `TEAL` info and extraction. `BRASS` is
   hardware and decoration only (trims, guards, emblem rims, eyebrows). Item rarity uses
   `rarity_col(r)`. **Section colours** (`UiSkin`: expedition teal, kin rose, gear blue, market gold,
   farm green, system lavender) mark where you are: the emblem, the picked tab's underline and the
   light along the panel's top. `UiSkin.section_of(title)` picks one from the panel title.
6. **Same shell everywhere.** Title (+subtitle) top left, extras (chips, tags) and a close X top
   right, tabs under the title, body, footer actions bottom right with the primary last and an Enter
   keycap on it. Esc always closes or goes back.
7. **Tabs, not long lists.** Group options into tabs (`shell_tabs`) and groups (`section`). Tabs are a
   segmented control, visibly different from buttons.
8. **Sensible defaults.** The panel opens with the primary focused (or the first control), the last
   tab you used, and the current choice highlighted.
9. **Confirm only what can't be undone** (delete a save, leave a match, sell or salvage an Epic or
   Legendary, reset all settings). Everything else happens immediately.
10. **Motion is quick and purposeful, and nothing grows** (`UiMotion`). Hover lights a trim and a
    glow, never resizes (every tier's states have equal margins; the check enforces it). Panels fade
    and slide up 18 px (200 ms); a pressed button dips to 95% and springs back with a small overshoot
    (240 ms, scaled about its centre); the picked tab's underline glides to the new tab (220 ms);
    switch knobs ease across (180 ms); toasts slide down in and lift away. Modals blur the screen
    behind them (160 ms). With **Fewer flashes** on, all of it becomes plain fades and snaps.
11. **Icons next to labels** where they help scanning (tabs, hub, pause menu, footers, empty states),
    from one original set (`UiIcons`, drawn with lines and shapes so they stay crisp at any interface
    size): tabs (compass, pad, camera, speaker, monitor, access, film, shield, boot, glove, kit, chest,
    bowl, hat, sprout, coin), sections, currencies and buttons. Known tab names get theirs
    automatically (`UiSkin.TAB_ICONS`).
12. **Keyboard and pad.** Every panel has something focused; arrows, Enter and Esc work; focus rings
    show for keyboard and pad only (`gui/common/show_focus_state_on_pointer_event=false`).
13. **Contrast.** Text colours meet WCAG AA (4.5:1) on panels, cards, button faces and smoked glass
    over a bright world; `--uipolish-check` computes it from the tokens.

## 3. Home flow

- **Hub bar** (bottom left): Expedition, Kin, Bag, Market, (Build), Settings, on number keys 1-6.
  Pressing the same number again closes that panel. Hidden while a panel is open and when visiting.
- **Prompts**: walking up to anything shows a glass pill with keycaps for what you can do (F use; for
  a kin, F pet, V fetch, T talk, C details).
- **Panels** open over a blurred, dimmed farm; clicking the dimmed area or pressing Esc closes them;
  Enter presses the panel's primary when nothing else has focus.

## 4. Helper API (`scripts/ui/ui.gd`, class `UI`)

Everything is static. The Theme is built by `UiTheme` (`scripts/ui/ui_theme.gd`) and `UI.install()`
(called once by Game) merges it into the engine's default theme, so every Control, popup and tooltip
gets the look. Screens never set a theme themselves; `--uipolish-check` fails if one does, or if a
script outside the style module builds its own `StyleBoxFlat`.

### Colours and sizes
`INK MUTED FAINT BG SURFACE CARD RAISED RIM WELL LINE BRASS BRASS_HI STITCH ACCENT ACCENT_HI GOOD BAD
GOLD TEAL INFO DARK_INK`, `R_PANEL R_CARD R_CTRL R_SMALL R_PILL`,
`T_DISPLAY T_TITLE T_STAT T_HEAD T_LABEL T_BODY T_SMALL T_CAPS`, `GAP GAP_BIG PAD`, `rarity_col(r)`.
Fonts: `UI.big` (Lilita One), `UI.body` (Rubik), `UI.semi` (Rubik 560), `UI.caps` (Rubik 700),
`UI.num` (Rubik 560, tabular figures). Section colours and tab icons live in `UiSkin`.

**The in-match HUD** keeps its own widgets (`HudStyle`, ext/hudref) and matches the menus through
shared tokens: the same INK and the two fonts, and for frames the field-kit tokens `UI.BRASS`
(slot and plate trims), `UI.STITCH` and `UI.SURFACE`/`UI.RIM` (frame backing and outline).
HudStyle should read these rather than copy them, the way it already shares INK (see §5).

### Text
- `title(text, size=34, col=INK)` - Lilita One, one line.
- `label(text, size=16, col=INK, font=null)` - wraps only past 48 characters.
- `para(text, size=T_SMALL, col=MUTED)` - always wraps.
- `section(text, col)` - a spaced caps eyebrow over a group (pages keep it with what follows).
- `kv(key, value, col)` - a muted key on the left, the value on the right.

### Buttons
- `primary(text, cb, minw=0, icon="")`, `button(...)`, `ghost(...)`, `danger(...)` - the tiers.
- `choice(text, chosen, cb, minw, icon)` - an option in a row; the chosen one is lit (Chosen).
- `icon_button(icon, cb, tip, px=16)` - round, icon only (close, back, arrows).
- `set_icon(button, icon, px=16)` - adds a drawn icon to any button's left.
- `with_key(button, "Enter")` - shows a keycap at the button's right end (it doesn't bind the key).
- Theme variations you can set directly: `Primary`, `Ghost`, `Danger`, `Chosen`, `IconBtn`, `Seg`,
  `SegOn`, `Tile`, `TileOn`, `MenuItem`, `MenuMain`.

### Containers and pieces
- `card(col=CARD, pad=14, rad=R_CARD)` - a raised card (shadow and top light when opaque).
- `frame(bg, rad, edge, edge_w, pad_h, pad_v, lit)` - a `UiFrame` for a control that styles itself
  (a tile, a chip, a colour swatch). Never build a `StyleBoxFlat` in a screen.
- `badge(icon, col, px=44, rad=R_PILL)` - a tinted round (or rounded) badge with an icon.
- `toast(host, text, col=GOLD, y=100)` - a one-line note that drops in at the top and fades.
- `draw_bar(canvas_item, rect, frac, col, track, rad)`, `bar_box(col, rad)` - cached bars for things
  drawn every frame.
- `set_card_border(card, col, w)` - only for the selected or the warning card.
- `tile_card(on, cb, pad=12, col=ACCENT)` - a selectable card (hover, focus, click, Enter); add your
  content to it. For tiers, skins, items.
- `glass(pad, rad)` - dark glass for things over the world (prompts, hint rows, hover cards, hub).
- `sheet(width)` - a plain panel without the shell.
- `chip(icon, text, col, tip, size=14)` - a pill with an icon and a value (gems, scrap, counts).
- `tag(text, col)` - a small coloured caps tag (Partner, Equipped, Kin at risk).
- `tabs(names, cur, cb(name), counts={}, minw=0)` - a segmented control.
- `empty_state(icon, head, sub)` - what an empty list shows.
- `bar(frac, col, w, h)` (a Control using `draw_bar`), `keycap(key, size)`, `key_hints([[key, what], ...])`, `spacer(h)`,
  `fill()`, `vbox(sep)`, `hbox(sep)`.
- `draw_icon(canvas_item, id, at, half_size, col)` and `IconDot.new(id, col, px)` - any `Icons` id
  plus the menu's own: close, back, next, check, plus, lock, gear, home, bag, shop, portal, hammer,
  info.

### The panel shell
```gdscript
var pb := UI.scroll_panel("Market stall", 800, close_cb)   # or (title, width, close_cb, "Back", true) to scroll
var panel: PanelContainer = pb[0]
var v: VBoxContainer = pb[1]                     # the body: add your content here
UI.subtitle(v, "Seeds, food and things for the farm")
UI.head_extra(v).add_child(UI.chip("gem", "120", UI.GOLD, "Your gems"))
UI.shell_tabs(v, ["Seeds", "Food", "Sell"], cur_tab, func(t): cur_tab = t; reopen())
UI.footer_left(v).add_child(UI.ghost("Hear it", play_sound))
UI.footer(v).add_child(UI.button("Brush", brush))
UI.footer_primary(v, "Buy", buy, 160, "gem")      # primary + Enter keycap; UI.press_primary(host) presses it
```
- The body pages (or scrolls, with `scroll = true`) whenever it's taller than the window.
- At home use `_new_panel(title, width, scroll)` in `home.gd`: it builds this shell, blurs the farm,
  hides the hub, pops the panel in, and Esc / Enter / clicking outside work.
- In overlay menus use `_page(name, title, width, scroll)` in `overlay.gd` (it keeps a back stack:
  on a sub-page the X becomes a back arrow before the title).
- Prefer `scroll = true` for panels whose content is mostly cards or previews (it only scrolls when
  the window is too short); the paged body suits lists of rows.
- `confirm(host, head, text, yes_text, on_yes, dangerous=true)` - a small modal over `host` with a
  warning badge, Cancel and a danger (or primary) button; Esc cancels it.
- `backdrop()` + `show_backdrop(rect, on)` - the blurred, dimmed layer behind modals
  (`shaders/ui_backdrop.gdshader`).
- `pop_in(control, delay)` - the open animation. `focus_first(control)` - focus the first button.

### Hooks for other systems
- **Hub entries** come from `home.gd`'s `hub_items()`: `[id, label, icon, Callable]`. If the home
  screen has `open_build()` a Build entry appears; if it has `open_kin_box()` the Kin entry opens it
  instead of the partner's card. Hide the bar with `hub.visible = false` while a mode (build mode)
  owns the bottom of the screen.
- New home panels: `var v := _new_panel("Kin Box", 900)` then fill `v` with the helpers above.

## 5. Hand-off: HudStyle (ext/hudref)

ext/hudref isn't merged yet, so this pass doesn't touch its widgets. When it lands, extend its
tokens to point at the menu's (no widget restyling):
```gdscript
const INK := UI.INK
const TRIM := Color(UI.BRASS, 0.55)      # new: a 1 px brass line inside slot_frame and plate_frame
const KEY_BG := Color(UI.SURFACE, 0.95)  # keycap pills on the leather tone
```
and draw `TRIM` one pixel inside the existing `slot_frame` and `plate_frame` edges. MUTED stays
HUD-cool (it reads over the world, not on leather).

