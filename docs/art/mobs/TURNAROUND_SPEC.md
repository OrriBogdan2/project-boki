# Enemy mob turnaround sheet: the one format (owner order 11-09 ~10:40 PM EST)

Every enemy mob sheet uses exactly this format. A sheet that breaks it is redone, not patched. The prompt cards in `docs/art/mobs/<mob>.md` all build on the blocks below.

**Gate:** 2D sheet gens opened by the owner 11-10 ~12:50 PM EST (briefs/DECISIONS.md); Meshy spend per creature waits for the owner's approval of its sheet. Lair bosses use this format with the changes in `bosses/README.md`.

## 1. Canvas
- Nano Banana Pro (Gemini 3 Pro Image on Vertex, the art runner), **16:9, 4K** (about 5504 x 3072), the same as the hunter turnarounds (`briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`).
- Background: flat **#E8E8EE** pale grey, no floor, no cast shadow, no vignette (the post step re-lays it to exact #E8E8EE, as the Boki V2 pipeline does).
- Final layout after the post step (section 5), in fractions of the canvas:

| Zone | Where | Contents |
|---|---|---|
| Scale column | left 12% | the hunter scale silhouette and the mob at true scale, on one ground line |
| View row | right 88%, top 84% | four views, left to right: **front, 3/4, side, back** |
| Palette strip | right 88%, bottom 16% | the mob's swatches (section 4), left to right in the order of its card |

## 2. Views
- **Front** (faces the viewer), **3/4** (turned 45 degrees to its left, so we see its right side), **side** (true profile, facing left), **back**. Same order as the hunter sheets.
- Same scale and the same ground line in all four views. The largest view fills 70% of the view-row height; small mobs are drawn at that size too (the scale column, not the views, shows how small they are).
- **Neutral readable pose**, not an attack pose: legs planted, the signature part fully visible, mouths closed unless the mouth is the signature part (spitter). The telegraph state is described in words on the card, never drawn on the sheet.
- Every part that matters for gameplay is visible in at least two views (the brute's fists, the sentinel's crystal eye, the bomber's sac).
- Flat even light from the top left (about 45 degrees), no rim light, no coloured light, no environment.

## 3. Line and shade (the approved flat-cel rules)
The hunter turnarounds are painted sheets with soft 3D-like shading; the owner picked flat cel (style a) "as the base for everything" on 11-09 (`briefs/boki-art/STYLE_CANON_V2.md`). Mob sheets use that canon from day one so they sit between hunters and Boki and never need a restyle pass. If the owner wants mobs in the painted hunter finish instead, only the `MOB_RENDER` block changes.
- **Line:** three even weights, ratio **5 : 2 : 1** (the "finals" weight: mobs are threats and need the heavier silhouette). Outer silhouette line about 8 px at 4K on the largest view. Each line is the neighbouring fill darkened to about 25% lightness and shifted 15 to 20 degrees cooler. **Never pure black.** The silhouette line is closed.
- **Shade:** two tones per colour: flat base plus one hard-edged shade shape on the lower right (light from the top left), covering 25 to 35% of each form. Shade = base 15 to 25% darker, 10 to 20 degrees cooler. No gradients, airbrush, rim light, bounce light or texture.
- **Darks stay dark:** a fill under 30% lightness keeps a base of 15 to 25% and gets one lighter lit plane on its upper left instead of a shade (STYLE_CANON_V2 section 3).
- **Highlights by material only:** glowing eyes get none (they are the brightest flat colour, with a lighter flat core); wet surfaces and crystals 1 hard highlight shape per part, max 3 per mob; metal 1 flat lighter band; fur, hide, stone, bone, wood, plant: none.
- **Detail budget:** three zones: the face, the signature part, one pattern. At least 40% of the body is plain. At most 16 countable parts (spines, plates, rivets, gems) in at most 3 sizes. Nothing smaller than the eye.

## 4. Mob world rules (what makes a mob read as a mob)
- **Hostile eyes:** every hostile mob has glowing eyes in **#FFE25A** (warm yellow, flat with a paler core, no pupil, no highlight dot) under a heavy brow. Boki have big glossy eyes with a white highlight; hunters have human eyes. The glow is how a player tells "it will hurt me" from "it is a pet" at a glance. The only exception is the Glimmerkin (treasure, harmless): big dark glossy eyes.
- **No blush, no cute face template.** Face templates from STYLE_CANON_V2 section 6: **tough** (brute, Watcher, bomber) or **creepy** (skitter, spitter, sentinel). Glimmerkin uses **cute**.
- **Not humanoid:** no clothes, no held weapons, no human posing (the same rule as the Boki edgier update). A mob's weapon is part of its body.
- **Regional body colour:** in game, `BiomeRun` repaints each mob's body / dark / belly materials per region. So a mob must read by **silhouette and value first**, and by its fixed accents second. The sheet shows the base (meadow) palette. Fixed accents (eyes, glow parts, bone, gold, crystal) never change per region and are marked "fixed" on the card.
- **Telegraph colour is reserved:** each mob's ground telegraph colour (from `scripts/match/mob.gd`) appears on the body only on the part that charges before the attack (the brute's fist cracks, the spitter's throat). It is the 6th swatch, set apart on the strip.
- **Value against the floor:** match floors are mid-light (meadow #7A9A5A in the gallery; snow and sand are lighter). Every mob needs at least one large mass darker than 30% lightness touching its silhouette, so it never melts into the floor at match zoom.
- **Size tiers** (H = hunter height; est. from the gallery lineup, re-measure before modelling): fodder 0.4 to 0.55 H (skitter, bomber, Glimmerkin), standard 0.7 to 0.9 H (spitter, sentinel), elite 1.15 to 1.3 H (brute), champion 1.7 H and up (the Watcher). A mob never shares a size tier **and** a silhouette family with another mob.
- **Originality:** our own creatures. No franchise IP lookalikes: no designs, names or art from other games. Never name another game or franchise in a prompt.

## 5. Post step (art session, local, after the gen)
1. Cut the four views out of the generated image and re-lay them on exact #E8E8EE in the view row, same scale, one ground line (the Boki V2 recrop step does the same).
2. **Scale column:** a flat #B9B9C4 hunter silhouette, the hunter scale figure (front A-pose, no features, height = H, the same figure on every mob sheet), and next to it the mob's front view as a flat #8A8A96 silhouette at true scale from its card's height. A thin vertical ruler with ticks at 0.25 H. No text.
3. **Palette strip:** flat rectangles, equal width, in the card's order: up to 5 base swatches, a gap, then the telegraph swatch. No text (hex values live in the card).
4. Save as `briefs/art-refs/mobs/<mob>_turnaround.jpg` (quality 92) once the owner approves the mobs gate; drafts go wherever the runner writes them.

Steps 2 and 3 are drawn locally, never by the image model: models garble swatches and ignore empty zones.

## 6. Prompt blocks (every mob prompt = SHEET + MOB_RENDER + MOB_LINE + MOB_RULES + its own design paragraph)
```
SHEET = "Character turnaround sheet for a 3D modeller: the same creature four times in one row, left to right: front view, three-quarter view turned to its left, side view in true profile facing left, back view. Same scale and the same ground line in every view, neutral planted pose, whole body in frame with even spacing, flat even light from the top left, plain flat pale grey background (#E8E8EE), no floor, no shadow on the ground, no text, no labels, no scenery. "
MOB_RENDER = "Rendering: flat cel-shaded 2D game art, like a hand-inked model sheet coloured with flat fills. Every colour area is one flat fill plus exactly one hard-edged shade shape in a darker, slightly cooler tone, on the lower right of each form. Very dark areas stay near black and get one lighter flat plane on the upper left instead. Matte everywhere; the only highlights are one hard shape on wet or crystal parts and one flat band on metal. No gradients, no airbrush, no rim light, no surface texture, no sparkles, no glow halo. "
MOB_LINE = "Line: a bold, clean inked outline in three even weights: a very heavy outer silhouette line, lines between body parts less than half as thick, small detail lines thinner still. Every line is a very dark, slightly cooler shade of the colour it borders, never pure black. "
MOB_RULES = "This is a hostile wild monster from the same world as stylised hunter heroes and cute companion creatures, drawn in the same game style but clearly a threat: its eyes are flat glowing warm yellow with a paler core, no pupils and no shine, under a heavy brow. No blush, no clothes, no human pose, nothing held in its hands. Simple bold shapes that read from far away, detail only on the face, one signature part and one pattern. "
```
The Glimmerkin swaps MOB_RULES for its own line (see its card).

## 7. Attachments (same for every mob; paths on `origin/ext/agent-briefs` unless marked)
1. **Image 1, the design:** the mob's current render strip, `docs/art/mobs/renders/<mob>_views.png` (on `ext/mob-design-1109`, later main). Prompt says: "Use image 1 only for the creature's body plan and parts; redesign it as described; ignore how it is rendered."
2. **Image 2, the sheet format and world:** `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`. Prompt says: "Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading."
3. **Image 3, the finish:** `briefs/boki-art/style_refs/boki_style_ref_2d.png` (or the first approved V2 flat-cel anchor if one exists by then). Prompt says: "Use image 3 only for the line and flat colouring; do not copy the creatures."

## 8. Checks (every sheet, before it goes to the owner)
- [ ] Four views in order front, 3/4, side, back; same scale, one ground line; no text.
- [ ] Silhouette test: fill the front and side views solid black at 64 px tall. The mob is still nameable and does not match any other mob's silhouette.
- [ ] Match-zoom test: the 3/4 view scaled to 40 px tall on a #7A9A5A square: the signature part and the glowing eyes still read.
- [ ] Value: a mass darker than 30% lightness touches the silhouette; a 40-point lightness split between the darkest and lightest large fills.
- [ ] Palette matches the card's hexes within about 8% lightness and 10 degrees hue; no extra hue.
- [ ] Line never pure black; detail count within budget; no gradients.
- [ ] Hostile eyes are glowing #FFE25A (Glimmerkin: dark glossy eyes).
- [ ] Every "must keep" item on the card is present; every "must not" item is absent.
- [ ] Originality: a fresh-eyes reviewer cannot name a franchise creature it resembles.
