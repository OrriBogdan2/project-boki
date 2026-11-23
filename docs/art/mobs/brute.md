# Brute: design card + turnaround prompt

Renders: `renders/brute_views.png`, `renders/match_far.png`, `renders/lineup.png`.
Format: `TURNAROUND_SPEC.md`.

## Design card
- **Role:** elite bruiser (camp anchor). 170 HP, slow (3.0), heavy slam (24). Staggerable: the "hit it now" moment of a camp.
- **Telegraph:** raises both fists overhead, the cracks in its fists glow **#FF4A3A**, ground circle r 2.3 in #FF4A3A, then slams. Stagger: purple ring #C47AFF + stars.
- **Silhouette idea:** "Stonehide". A top-heavy **trapezoid**: huge boulder shoulders and forearms, tiny sunken head below the shoulder line, short bowed legs. The fists are giant rock clubs that touch the ground. Reads as "heavy" from any angle; the fists are the weapon.
- **Shape keywords:** trapezoid, slab, sunken.
- **Size:** 1.15 H (elite).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #8A5A48 | hide (arms, flanks) | regional |
| dark | #33232A | legs, face, hands | regional |
| belly | #D9C2A8 | small chest patch | regional |
| rock | #6A625E | shoulder slabs, fist stones | fixed |
| bone | #EFE4C8 | 2 short tusks | fixed |
| telegraph | #FF4A3A | crack lines in the fist stones | fixed |

Eyes #FFE25A (fixed) as on every hostile.
- **Materials:** matte hide, rough stone (no highlight), bone.
- **Keep:** knuckle-walker stance, tusks, rock on the back, warm red-brown base, yellow eyes.
- **Weak now:** generic ape/gorilla; rock slabs too small to read; the pale belly is the biggest shape on it (reads as a teddy bear from the front); black ball fists look like boxing gloves.
- **Must not:** gorilla face, chest-beating pose, clothing, a held weapon, a stone-golem made only of rocks (it is a beast wearing stone).

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/brute_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt:**
```
Use image 1 only for the creature's body plan and parts; redesign it as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a huge, top-heavy beast that walks on its knuckles. Its body is a trapezoid: enormous hunched shoulders and thick forearms, a narrow waist and short bowed legs. Big flat slabs of grey stone are grown into its hide across both shoulders and down the back like armour plates, four slabs in total. The fists are giant rough stone clubs, each as big as its head, resting on the ground, with a few thin dark crack lines across them. A small head sunk low between the shoulders, below the shoulder line, with a heavy brow, two small glowing yellow eyes and two short ivory tusks pointing up from the lower jaw. A small pale patch on the chest only, smaller than one fist. Its arms are longer than its legs, so it leans forward onto its knuckles: in every view both stone fists rest flat on the ground line in front of its feet, and both fists are stone, the same on both sides.
Its face: tough, scowling under the brow, mouth closed with the tusks showing.
Palette: warm red-brown hide, very dark brown-plum legs, hands and face, a small pale tan chest patch, cool grey stone slabs and fists, warm ivory tusks, glowing warm yellow eyes.
Matte hide and rough matte stone, no shine. Not an ape face, no clothes, nothing held.
```
**Steps:** as in `skitter.md`; scale column at 1.15 H.

**Checks:** spec section 8, plus: shoulders clearly wider than the hips (trapezoid in front view) · head below the shoulder line · fists are stone and touch the ground · the pale chest patch is smaller than one fist · 4 stone slabs readable at 40 px.
