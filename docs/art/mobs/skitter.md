# Skitter: design card + turnaround prompt

Renders: `renders/skitter_views.png` (front | 3/4 | side | back), `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md` (this card fills in its blocks).

## Design card
- **Role:** fodder swarmer. Fast (5.2), low HP (34), comes in packs and punishes standing still.
- **Telegraph:** stops, rears its front half up, horn tip flashes; ground rect 2.6 x 0.8 in **#FF6A4A**, then a straight lunge.
- **Silhouette idea:** "Thornback". A low arrowhead pointing at you: a flat wedge carapace that is wider at the back, six splayed short legs, and one forward ram horn. It is the only mob whose silhouette is wider than tall and pointed. Reads as an arrow at match zoom, which is what it does.
- **Shape keywords:** wedge, splayed, barbed.
- **Size:** 0.45 H (fodder).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #7B5EA8 | carapace | regional |
| dark | #2E233E | legs, underside, carapace rim | regional |
| belly | #C9B9C8 | 2 pale plates under the head | regional |
| bone | #EFE4C8 | ram horn, 3 back barbs | fixed |
| eyes | #FFE25A | 4 small glowing eyes in a row | fixed |
| telegraph | #FF6A4A | horn tip only | fixed |

- **Materials:** matte chitin (no highlight), bone, glowing eyes. No gloss.
- **Keep:** six dark legs (strong dark mass on the floor), bone horn, yellow eyes, purple base, small size.
- **Weak now:** glossy plastic finish; reads as a generic spider; the horn points up instead of at the target, so the lunge has no silhouette cue; legs are long and thin and vanish at match zoom.
- **Must not:** spider abdomen ball, eight legs, web, fangs on a human-like face, mandible pincers like a well-known bug-type creature.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/skitter_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt** (SHEET + MOB_RENDER + MOB_LINE + MOB_RULES from the spec, then):
```
Use image 1 only for the creature's body plan and parts; redesign it as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a small, fast, low beetle-like swarm monster shaped like an arrowhead pointing forward. A flat wedge-shaped carapace, narrow at the front and wide at the back, low to the ground, much wider than it is tall. One thick bone-coloured ram horn juts straight forward from the front like a spear point. Three short bone barbs stand along the back ridge. Six short, thick, splayed legs in very dark purple-black, bent outward like a crouching crab, feet planted wide. A small head tucked under the horn with four small glowing yellow eyes in a row and no visible mouth. Two pale plates under the head.
Its face: creepy, eyes only, no mouth, no expression lines.
Palette: dusty violet carapace, very dark purple-black legs and carapace rim, pale lilac-grey under-plates, warm ivory bone horn and barbs, glowing warm yellow eyes. Only the very tip of the horn is a hot coral red.
Matte chitin, no shine on the shell. No spider body, not eight legs, no web, no pincers.
```
**Steps:**
1. Check the gate is open (owner approved hunters and opened mobs in DECISIONS.md). If not, stop.
2. Add a job to `briefs/boki-art/batch/specs_mobs.py` with the prompt above and the three refs; build `jobs.json`; let `gen_boki.py --watch` run it. Three runs.
3. Pick the best run against the checks; run the spec section 5 post step (re-lay on #E8E8EE, scale column at 0.45 H, palette strip).
4. Post the pick plus the other two to the owner; save the final per spec section 5.

**Checks:** spec section 8, plus: the horn points forward (side view) · six legs, not eight · the side view is clearly wider than tall · no gloss on the carapace · horn tip is the only coral area.
