# UI style: "Void & Masks" (OWNER-APPROVED 2026-11-05 18:35 UTC: "make all the ui like this - including title screen / everywhere")

**References:**
- **Base:** `briefs/art-refs/ui/ui_style_void_A2_base.png`.
- **Borrow from:** `ui_style_void_A1_alt.png`.
- The old `ui_style_ref_boki_card.png` is REJECTED (too "basic adventure").
- All the text in the refs is placeholder (names, abilities, "DoT"); use real data and plain words.

## Look
- **Panels:**
  - Black-violet (~#1e1430 to #2a1c40), with rough torn/asymmetric edges and faint scratched runes + speckle/ink spatter texture.
  - A neon edge glow running teal (~#3fe0d0) → magenta (~#ff3fd0) around the outline.
- **Portrait:** a cracked-mask/void window: the creature over a deep starfield, with teal crack lines through the frame.
- **Title:** a torn parchment tab pinned/taped at the top (A2) or at an angle (A1), with a bold hand-cut black display font.
- **Info rows:** torn parchment strips pinned with nails, a bold name + one short line in dark ink. Icons sit in jagged mask/bat-shaped black badges (A2's solid black glyph badges; A1's outlined mask badges also OK).
- **Primary button:** a torn ticket-stub shape, magenta neon rim, pink caps label. One per screen.
- **Accents** (used sparingly): rubber stamps ("LOGGED", "EXPEDITION", "VOID-TOUCHED" style, for state badges like captured/rare); chalk tally marks; scratched runes.
- **Backgrounds:** the world blurred behind modals (dusk broken-isle palette); floating void specks drift around the panel.

## Rules
- Only interactive things glow on hover (the neon edge brightens, a scale of 1.03). Info strips are static.
- Readability first: the parchment strips carry the text; never put body text directly on the noisy texture. Min body size at 720p as UI.T_BODY.
- Keep the chaos in the frame and decoration, not in the content layout. One clear hierarchy per screen: title → portrait → rows → button.
- Build reusable pieces:
  - a torn panel (nine-patch + an edge-glow shader with a gradient param),
  - a parchment strip,
  - a mask badge,
  - a ticket button,
  - a void portrait window (a starfield shader + a crack overlay),
  - a stamp label.
- Rollout: the hatch flow (157) → the Boki list/sheet (174) → the Black Market (170) → home panels → everything else. The HUD in matches stays clean and minimal (only borrow colours/edges).

## Scope (owner-approved): EVERYTHING
- The title screen / main menu: the logo over a blurred broken-isle dusk with drifting void specks; the menu items as stacked torn parchment strips or ticket stubs with the neon edge on hover; no subtext (item 155).
- Loading screens, settings, the pause menu, the creator, hatch/naming, the Boki list/sheet, the Black Market, Market, Build menu, Hob dialogue box, tutorial prompts/keycaps, results/extract screens, the Masks screen, toasts.
- The match HUD: the same palette, edges and fonts, but kept minimal and readable (no parchment clutter over gameplay).
