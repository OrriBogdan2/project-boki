# Boki 2D style canon (owner decision 2026-11-09, "ONE Boki 2D style")

Anchor: `style_refs/boki_style_ref_2d.png` (Vespyx + Mycroll, the website cards). Every Boki 2D image, hero card and turnaround, matches it. v2 and v3 refs are retired. This file sets size, view, framing and finish; BOKI_DESIGN_RULES.md still sets what a Boki is (one fused idea, animal not humanoid, born with its weapons).

## Style words (use in every prompt)
Soft hand-painted shading, a clean fairly thin dark outline (never thick cartoon outlines, never flat cel shading, never realistic), big glossy eyes with one bright highlight, soft pink blush on the cheeks, rounded toy-like shapes, a slightly oversized head, simplified fur and feathers (clumped shapes, no strand detail), two main colours plus one accent, a clear iconic silhouette.

## View
- Gentle three-quarter view: body turned about 25 to 35 degrees from the viewer, head turned slightly further toward the viewer so both eyes show.
- Never straight-on front, never a pure side profile, never from above or below.
- Characterful pose that shows personality (head tilt, playful lean, curious or cocky look, weight shift); feet on the floor, never stiff or straight-on (owner 11-09: straight + no personality = not good). No attack pose, no upright person-like stance, nothing held.

## Framing
- One creature, full body, nothing cropped (tail, wings, horns and blades all inside the frame).
- Centred, about 8% empty margin on every side. Hero cards are square (1:1); the creature fills the frame to that margin, so tiny and giant species read at the same size.
- Feet rest on one imaginary flat floor line.
- Background: one plain flat pale grey (#E8E8EE), no gradient, for an easy cutout. No cast shadow, no contact shadow blob, no reflection, no floor texture, no glow halo or vignette, no text, no props.

## Line, eyes, light
- Line: one thin dark outline in a darker tone of the local colour (not pure black), same weight on every Boki, a little heavier on the outer silhouette than inside.
- Eyes: large and glossy, set low on the head and well apart, one big highlight plus a small second one, a visible iris colour. Size varies with stage and archetype (below), and the face keeps its own personality (grumpy, smug, anxious, sleepy); the style never means "default chibi face".
- Light: one soft key light from the top left, shading falling to the lower right, a soft lighter belly and a gentle bounce from below. No coloured rim lights, no glow around the body. Element effects (ember cracks, spores, sparks) live on the body and stay small.

## Proportions by stage
- Baby: head about 40% of the body height, round body, short stubby limbs, big eyes, objects and weapons small and simple. Roundest shapes of the line.
- Middle: head about 30%, a bit longer limbs and a more defined silhouette, eyes still large.
- Final: head about 20 to 25%, longer limbs, bolder and bigger born-with parts (blades, horns, plates), eyes a little smaller and sharper, a stronger stance. Still cute and appealing, never realistic, never creepy gore.
- Tough archetypes stay blocky and low, fast ones lean, but the rendering is identical at every stage.

## What NOT to do
- No dark backdrop, dark circle, floor shadow, reflection or halo (the website crops have them; the canon versions do not).
- No straight-on front view. No profile.
- No realistic anatomy, fur or feather detail. No thick outlines. No flat vector fill.
- No clothes, bands, straps, hats, held items or human posture. No extra creatures, text or props.
- No redesign: identity (colours, markings, born-with parts, the fused idea) comes from the species' existing design. Only the rendering, view and framing change.
- Never name another franchise, game or artist in a prompt.

## The two examples, and what to fix in them
- Vespyx (fox with a scorpion tail, baby): the right finish, eyes, blush and outline. Fix: head and chest are almost straight-on, so turn the whole body to about 30 degrees with the head toward the viewer; drop the dark circle, the green glow around the tail and the floor shadow; keep the venom drop.
- Mycroll (hedgehog with mushrooms, baby): closest to the target view already (body turned, head toward the viewer). Fix: drop the dark backdrop, the glow outline on the mushrooms and the floor shadow, and keep the body at about 30 degrees rather than creeping toward a full side profile.

## How it is produced
Hero card = one image per species: image 1 is that species' own design (identity), image 2 is the anchor (style). Builder `C()` in `batch/build_jobs.py`, ids `<species>_card`, inputs in `card_inputs/`. SAMPLE (6 species x 2 runs: vespyx, lunowl, skidlet, glaivyx, chandelotl, teapotamus) is queued; the rest wait for the owner's verdict on it. New `B()`/`V()` turnaround jobs now use the anchor as the style ref (existing ids are unchanged).

## Glow (owner 11-09)
- Every card gets its own glow: a soft radial glow behind the creature in that Boki's signature colour, so each one stands out (as on the site Boki wall). It is added when the card is composited, NOT generated, so the generated art stays on plain grey for a clean cutout.
