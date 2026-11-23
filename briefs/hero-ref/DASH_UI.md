# Dash charge UI in the reference footage (items 147 / 188)

Source: `ext/hero-ref-footage`, folder `juggernaut` (Brall, Quick Dash, 3 charges, 0.4 s between uses,
frames 0371-0420; frame N = video second 360 + (N-1)/5), bottom bar cropped 4x. Frames are 720 px wide,
so only shapes and colour roles are readable, not numerals. Not checked: Myth (`pin`) has no multi-charge
dash in this footage version (Spirit Walk), so Brall is the only multi-charge sample.

## What the frames show
- **Charge pips are a row of small round discs on the Shift slot's top edge**, one per charge (f0376, f0388):
  3 for Quick Dash. Spent = dark disc with a light ring; ready = bright teal fill (f0376 lit, f0388 mostly dark).
- **The slot shows a short countdown in tenths** (0.5, 0.3, 0.2 across f0376-f0388) in pink over the icon
  while a charge is coming back. The slot is not greyed out while a charge is ready.
- **Recharge is one charge at a time** (the countdown restarts per charge); 0.4 s between uses.
- **Right of the slots** is a round gauge ring (f0376, f0400): the glider/air gauge, not a charge count.
- **Nothing at the character's feet or on any overhead plate** (f0376, f0388, f0400: plates show name,
  health and level chip only). Rivals' charges are never shown.

## What we copy (our look, our colours)
1. Charge pips are round discs, one per charge, at least 8 px across, lit in the dash colour when ready,
   a dark disc with a light ring when spent.
2. The recharging charge fills as a ring around its disc.
3. The countdown in tenths stays on the slot; a returning charge flashes the slot and ticks (already in `DashSlot`).
4. No dash display on rival/ally plates (already true; asserted by `--dash-slot-check`).

Pip placement: kept at the slot's bottom (our rank pips already use the top edge); the alternative is the top edge.
Recharge rules (one at a time, reset refills) live in `Hunter`/kits and are unchanged.
