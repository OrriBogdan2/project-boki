# UI style (owner-approved reference, 2026-11-05)

Reference: `briefs/art-refs/ui/ui_style_ref_boki_card.png`. Its text and names are placeholders ("Stinger Fox", "Tail Whip"); use real data.

## Look
- **Panels:**
  - Deep navy body (~#252e4a) with a lighter navy header bar (~#364464).
  - Soft inner bevel and drop shadow; slightly rounded corners.
  - Thin warm-gold double trim with filigree corner flourishes (gold ~#d9a85a to #f1dd8c highlight).
- **Content rows:** parchment cards (~#e5c9a2) with a torn/soft edge and a subtle paper texture. Dark brown text (~#483224); bold names.
- **Header/title text:** a chunky rounded display font with a gold gradient fill, a dark brown outline and a soft drop shadow.
- **Icon tiles:**
  - Square, gold-framed, dark inner bevel, the icon centred.
  - A small label baked under it (e.g. "Ability", "Passive").
  - Element-coloured backgrounds (green venom, etc.).
- **Portrait:** a framed square tab breaking out of the panel's top edge, on a navy backdrop.
- **Primary button:**
  - A dark brown-plum fill (~#483d3e), a gold rim and an outer warm glow on hover.
  - Cream bold label.
  - One primary button per screen.
- **Backgrounds:** behind modal screens, the world/sky blurred (no flat dim).

## Rules
- Only interactive things get hover/press states (glow, scale 1.03). Info rows (Ability/Passive) are static.
- Spacing: generous padding (~24 px panel, ~16 px between rows) on the UI.T_* type scale.
- Text diet (OWNER_REVIEW item 155): labels, not paragraphs.
- Build it as reusable theme pieces (a StyleBox panel with nine-patch gold trim, a parchment row, an icon tile, a primary button, a portrait tab) in the UI helpers, so every screen uses the same parts.
- Rollout order: the hatch flow (item 157), the Boki list/sheet (174), the Black Market (170), the home panels, then everything else.
