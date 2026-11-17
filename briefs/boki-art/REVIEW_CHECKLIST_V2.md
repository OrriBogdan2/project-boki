# Boki review checklist V2 (2 minutes per image, pass / fail)

For every re-rendered card, sheet and portrait. Rules: STYLE_CANON_V2.md (owner pick: style a, flat cel). Have the approved design open beside the new image (the current card or sheet): this is a style pass, so anything that differs in design is a fail.

**Verdict:** any HARD fail = reject and re-roll. No hard fails and 1 or 2 soft fails = edit job on that image (`X()`), naming the items. 3 or more soft fails = reject. Record failed item numbers in the ART line, e.g. `fail=4,11`.

## 0. Make the test strip (10 seconds, automatic)
Save as a scratch script and run `python3 qa_strip.py image.jpg`. It writes `image_qa.jpg` (full | 128 px thumbnail | 3-value squint | silhouette) and prints three numbers.

```python
import sys, numpy as np
from PIL import Image
p=sys.argv[1]; im=Image.open(p).convert('RGB').resize((1024,1024),Image.LANCZOS); a=np.asarray(im).astype(int)
bg=np.median(np.concatenate([a[:12,:12],a[:12,-12:],a[-12:,:12],a[-12:,-12:]]).reshape(-1,3),axis=0)
mask=np.abs(a-bg).max(axis=2)>30; g=np.asarray(im.convert('L')).astype(float)
m=np.maximum(np.abs(np.diff(g,axis=1,prepend=g[:,:1])),np.abs(np.diff(g,axis=0,prepend=g[:1,:])))[mask]
ys,xs=np.where(mask); fill=max(xs.max()-xs.min(),ys.max()-ys.min())/1024
print(f"soft={((m>1.5)&(m<=10)).mean():.2f} bg={tuple(int(v) for v in bg)} fill={fill:.2f}")
thumb=im.resize((128,128),Image.LANCZOS).resize((1024,1024),Image.NEAREST)
squint=Image.fromarray((np.digitize(g,[85,170])*127).astype('uint8')).convert('RGB')
sil=Image.fromarray(np.where(mask,0,255).astype('uint8')).convert('RGB')
out=Image.new('RGB',(4096,1024)); [out.paste(x,(i*1024,0)) for i,x in enumerate((im,thumb,squint,sil))]
out.save(p.rsplit('.',1)[0]+'_qa.jpg',quality=85)
```

| Number | Pass | What it means |
|---|---|---|
| `soft` | above 0.30 = HARD fail; 0.25 or less = go on to item 7 | share of creature pixels on a soft ramp. Measured on the 26 Boki tested: current cards 0.20 to 0.52 (mean 0.36), style-a runs 0.11 to 0.30 (mean 0.21). It catches painterly and textured renders. It does not see slow gradients on big smooth shapes (the glossy Coolatee, Zipling and Hydrangor cards already score 0.25 or less), so a low number is not a pass: item 7 by eye decides. Cards and portraits only (sheets: run it on one cropped view) |
| `bg` | each channel within 8 of 232, 232, 238 | the model does not hit the hex: every round-6 image came out near 220, 218, 231, a lilac tint. Fix in post (cut out, re-lay on #E8E8EE), not by re-rolling |
| `fill` | 0.80 to 0.88 | 8% margin. Current cards run 0.92 to 0.95. Fix with `recrop.py`, not by re-rolling |

## A. Thumbnail, 128 px (15 seconds)
1. HARD. You can name the animal and the fused object.
2. HARD. Two eyes (or the species' eye count) read as separate marks; the face is the first thing you see.
3. The silhouette panel is one clear shape, unlike any other Boki's, and the signature part sticks out of it.

## B. Squint, 3 values (15 seconds)
4. HARD. The creature separates from the background all the way round (no pale line or pale part melting into the grey).
5. The face and the signature part are a different value from the body behind them.
6. All three values are present on the creature, and no value is shattered into confetti (many small patches = too much detail).
6b. HARD for dark designs. Darks stayed dark: a body that is near black in the approved card is still black in the squint panel, with one lighter lit shape on it. A dark body lifted to mid grey fails (Gongrowl, Sarcobra a_1, Seamwyrm and Cindermaw in the style tests).

## C. Finish, full size (40 seconds)
7. HARD. Flat fills: no gradient, airbrush, soft glow, paper or brush texture. Each colour has one base and one hard-edged shade, on the lower right.
8. HARD. No halo, bloom, sparkle stars, glints, mist or drifting particles. No floor shadow, ground or reflection. No text or letters anywhere.
9. Highlights only on eyes, slime or wet parts, gems, glass. Metal has one flat band. Fur, skin, scales, stone, wood and bone have none.
10. Line: outer line clearly heaviest, a dark shade of the local colour. Fail if pure black (about 1 style-a run in 8), pale, one colour everywhere, doubled, or the same weight inside and out.
10b. Fur on furry finals is a few big clumps along the tone edge, not one flat fill and not strands.
11. Palette: 5 base colours or fewer, accent 10% or less, no rainbow (prism types: max 3 pastel planes on the signature part).
12. Detail budget: detail only on the face, the signature part and one pattern; about 40% of the body is plain; no mark smaller than the eye highlight; countable parts 12 or fewer (16 on finals and legendaries); drips 3 or fewer.
13. No artefacts: blocky patches, seams or bands in the background, mushy small detail, halos along the outline.

## D. Face (15 seconds)
14. HARD. Eyes are full eyes (iris, pupil, hard highlight) in the template of its archetype. Fail on dot eyes, closed lids, or cute round eyes on a tough, creepy or majestic Boki.
15. HARD. Blush only on babies and cute middle forms, and flat. Any blush on a final or a legendary fails.
16. The face is as simplified as the body (no realistic muzzle under cartoon eyes), and it has the species' own expression.

## E. Construction (25 seconds)
17. HARD. Limb count: count legs, wings, tails, heads, horns. They match the counts line in the prompt, and no limb is ambiguous or merged.
18. HARD. Nothing strapped, belted, banded, chained, bolted, worn or held. Every part grows from the body with a fused base. Accepted exceptions, as approved by the owner: Scoopsy's cone, Shinobant's mask and scarf, Reapant's hood, Galleotter's collar, hoops, oars and mast.
19. HARD. One locomotion system (legs or wheels or a coil, not two).
20. Patterns wrap the form (stripes curve like rings round a tube). The part's material repeats in 2 other places.
21. Stance matches the stage: baby sits or bounces, middle moves, final is planted. Walking species have every supporting foot on one floor line. No base under it (ice block, stump, puddle).
21b. If the Boki is on the hold list (RERENDER_PROMPTS.md section 7), stop: it needs its construction redesign approved before any style render is judged.

## F. Identity against the approved design (15 seconds)
22. HARD. Same creature: body plan, proportions, signature parts, markings. Nothing added, dropped or moved.
23. HARD. Same colours. Check eye colour first, then the main body colour, then the accent. Eye colour changed on Mycroll, Glazolm, Arcestrel and Hydrangor in the style tests; body colour on Coolatee, Chuggamus, Sarcobra and Lurklet.
24. Same pose and facing as the approved card, unless the job was a re-pose.

## G. Sheets only (add 30 seconds)
25. HARD. Exactly four views in one row: front, three-quarter, side, back. No ghost or duplicate copies, no second row.
26. HARD. Counts agree in all four views: limbs, horns, crystals, spikes, stripes on the same body part. Count one feature across the row (Chandelotl: hood crystals; Anchorhorn: hind limbs).
27. HARD. Same eyes and face in every view that shows them, and the same as the card (Chandelotl's old sheet has narrow eyes, its card round ones; the card's face is the one to keep).
28. Same height and scale in all four views, feet on one baseline, same stance in each.
29. Flats only: line and flat fills, no shade shapes, no highlights except the eyes. Colours match the card's base swatches.
30. The side and back views are real side and back views (not a second three-quarter), and the back shows how the signature part attaches.

## H. Portraits only (add 10 seconds)
31. Same design, counts and colours as the V2 card; the pose differs from the card.
32. No effects at all (no sparks, petals, embers, motion lines).

## Roster check (every 20 approved)
33. Lay the approved V2 cards out as one contact sheet at 128 px. Fail any card whose line weight, shade depth or eye finish stands out from the set, and any two with the same pose and facing next to each other in a line.
