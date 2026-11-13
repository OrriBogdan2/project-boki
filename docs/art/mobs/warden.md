# The Watcher (warden): design card + turnaround prompt

Renders: `renders/warden_views.png`, `renders/lineup.png`, `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md`.

**Weakest mob now (1 of 2):** it is the brute model recoloured navy with a gold crown. Same silhouette, so the champion of the area reads as "a blue brute". Full redesign.

## Design card
- **Role:** champion / area guardian. 820 HP, slam r 3.3 (30 dmg), staggerable, drops 30 gems. A fight you choose to take, seen from far away.
- **Telegraph:** the single great eye shifts from yellow to **#FF4A3A** red, the standing stones on its back lift, ground circle r 3.3, then a two-handed slam. Stagger: purple ring #C47AFF + stars; the eye dims during stagger (the "now" cue).
- **Silhouette idea:** a walking **gate**. Tall, upright, monolithic: a slab-like torso of dark stone bound with roots, long arms ending in flat stone palms, and a **crown-ring of 5 standing stones** rising behind its shoulders like a halo of menhirs, gold-banded. One huge eye in the chest (no separate head). Taller than anything else on the map; the crown-ring is visible over walls and trees.
- **Shape keywords:** monolithic, crowned, gate.
- **Size:** 1.7 H (champion).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #5A4A7A | stone torso and arms | regional |
| dark | #241C2E | root bindings, legs, eye socket | regional |
| belly | #B8AECB | lit face of the chest slab | regional |
| gold | #F2C84A | bands on the standing stones, eye rim | fixed |
| heart | #C9A0FF | small rune cuts on the stones | fixed |
| telegraph | #FF4A3A | eye in charge (not painted on the sheet) | fixed |

Eye #FFE25A (fixed), one large eye with a paler core.
- **Materials:** cut stone (matte), roots (matte), gold bands (one flat band highlight each), rune cuts (flat, no glow halo).
- **Keep:** the name and "watcher" idea, gold crown read, the purple heart-gem colour (moves to the rune cuts), navy-violet base, slam.
- **Weak now:** identical silhouette to the brute; the crown is a tiny hat at match zoom; nothing says "watcher".
- **Must not:** a humanoid knight or king, a robe, a sword; a single-eye floating ball; a stone face with a human nose.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/warden_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

Note for image 1: the current model is the old brute body; the prompt says to keep only the colours and the crown idea.

**Prompt:**
```
Use image 1 only for the colours and the gold crown idea; the body plan is new and described below; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a giant ancient guardian monster made of standing stone bound together with thick dark roots, like a living stone gateway. Tall and upright, much taller than wide. Its torso is one big flat slab of dark violet stone, slightly wider at the top. It has no separate head: one huge round glowing yellow eye sits in the upper middle of the chest slab, set deep in a dark socket with a gold rim, under a heavy stone ledge. Two long heavy arms of stacked stone blocks hang to its knees and end in broad flat stone palms. Two short thick stone legs wrapped in roots. Behind its shoulders rises a ring of five tall standing stones fanned in a half circle like a crown, each with one gold band around it and a few small lilac rune cuts. Dark roots wrap the joints and run down the back.
Its face: the single eye, stern and watchful, no mouth.
Palette: dusty navy-violet stone, very dark plum roots, legs and eye socket, a pale lilac-grey lit face on the chest slab, gold bands and eye rim, small lilac rune cuts, glowing warm yellow eye.
Matte stone and roots; gold bands get one flat lighter band each; no glow halo. Not a knight, no armour, no clothes, no weapon, no human face.
```
**Steps:** as in `skitter.md`; scale column at 1.7 H. Then tell the model/Meshy session (after the gate) that `mob_models.gd` needs a new warden body; the brute body is no longer shared.

**Checks:** spec section 8, plus: silhouette is nothing like the brute (upright, tall, no hunch) · crown-ring of 5 stones visible in all four views · one eye, in the chest · the back view shows the stones and roots clearly · at 40 px the crown-ring still reads.
