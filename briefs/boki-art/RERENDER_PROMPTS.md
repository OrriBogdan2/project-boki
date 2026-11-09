# Re-render prompts for the V2 style (flat cel, owner pick 16:32 ET 11-09)

Text blocks for `batch/build_jobs.py` and the specs. Rules: STYLE_CANON_V2.md. QA: REVIEW_CHECKLIST_V2.md. Nothing here is wired in yet: this file is the copy to paste once the owner approves.

Three wording rules used throughout, all learned from the tests:
- **"Shade" is on the body, "shadow" is on the floor.** Test c said "one soft shadow" and got floor shadows. The blocks never use "shadow" for body shading.
- **Say what to draw, not what to leave out.** Naming an unwanted thing often adds it (owner taste notes). Plain cheeks are "the same flat colour as the face", not "no blush".
- **Colours and counts are written in words in every prompt.** Eye or body colour changed on 8 of the 26 Boki in the style-a tests.

## 1. Order of work
1. **Hold list first** (section 7): about 20 Boki get a construction redesign and an owner OK before any style render.
2. **Anchors** (section 6): six human-finished cards. Until they exist, use the interim anchors listed there.
3. **Pilot**: 12 Boki, 2 per face template, mixed stages, at least 3 dark and 2 furry (suggested: Vespyx, Coolatee, Chandelotl, Glassolotl, Rimink, Glaivyx, Lockatara, Ringrove, Lurklet, Cindermaw, Sarcobra, Aurostag). Owner approves the pilot before the other 200.
4. **Per Boki: card, then sheet, then portrait.** The card is made from the approved card. The sheet and portrait are made from their old versions plus the new V2 card, so each Boki's three assets agree. 3 runs each; pick by checklist.
5. **Post, every image**: cut out and re-lay on exact #E8E8EE (the model lands near 220, 218, 231), `recrop.py` to a fill of 0.84, then the QA strip.
6. Heroes and cutouts are rebuilt from the V2 cards. Old files stay as `*_v1.jpg`.

Per-Boki data the jobs need (one small table, built once by an agent reading each approved sheet, then spot-checked): `arch` (face template: cute, pretty, sleek, fast, tough, creepy, majestic; many Boki have none on record), `cols` (main colours and eye colour in words; most specs already have "Main colours"), `counts` (legs, wings, tails, heads, horns, and the count of the signature part), `dark` and `furry` flags, and `fix` (one sentence, only for small construction cleanups).

## 2. Text blocks
```python
RENDER_V2=("Rendering: flat cel-shaded 2D game art, like a hand-inked model sheet coloured with flat fills. "
 "Every colour area is one flat fill plus exactly one hard-edged shade shape in a darker, slightly cooler tone of the same colour. The shade shapes are large, simple and connected, and sit on the lower right of each form, because the single light comes from the top left. "
 "Matte finish everywhere. The only crisp highlights are one white highlight in each eye and one highlight shape on anything truly wet or glassy (slime, venom, polished gems, glass); metal shows one flat lighter band. ")
LINE_V2=("Line: a bold, clean inked outline in three weights: the outer silhouette line is the heaviest, the lines between body parts are half as thick, and small detail lines are a quarter as thick. Each line keeps an even thickness along its length. "
 "Every line is a very dark shade of the colour it borders (deep plum round purple, dark umber round brown and gold, deep slate blue round white and ice), always clearly darker than the fill beside it. One clean line. ")
LINE_FINAL=LINE_V2.replace("the outer silhouette line is the heaviest,","the outer silhouette line is very heavy and bold,")  # finals and legendaries (5:2:1)
BUDGET_V2=("Detail budget: detail lives in three places only: the face, the signature part and one pattern. Every other area is a quiet, plain flat shape. Repeated things are drawn few and large: fur as a few big clumps along its edges, and scales, facets, rivets, spots and crystals as a handful of big shapes. Nothing is drawn smaller than the highlight in its eye. ")
FX_V2=("Effects: at most one small effect, attached to the body and drawn as flat hard-edged shapes. Anything that glows is simply the brightest flat colour on the creature with a lighter flat shape inside it; the air around the creature is empty. ")
DARK_V2=("This creature is dark, and it must stay dark: its dark areas stay near black, as dark as in image 1. On the dark areas the second tone is a lighter one: one hard-edged lit shape on the upper left, a little lighter than the dark base, and the inner lines on dark areas are drawn in that lighter tone so they show. Keep a strong split between its dark, middle and light areas. ")
FUR_V2=("Its fur is drawn as big clumps: the edge between the two fur tones is a row of large pointed clumps, with a few more clump shapes at the mane, shoulders, elbows, haunches and tail, and plain flat fur between them. ")
FACE_V2={
 'cute':"Face: big round eyes set low and wide apart, each with a coloured iris, a dark pupil, one large crisp white highlight and one small one; tiny brows or none; a small mouth. ",
 'pretty':"Face: large almond eyes with one to three lash flicks, a coloured iris, one large and one small crisp white highlight; a soft arched brow; a small, poised mouth. ",
 'sleek':"Face: narrow almond eyes tilted up at the outer corners, a coloured iris and one crisp white highlight; the flat upper lid works as the brow; a cool, knowing smirk. ",
 'tough':"Face: small eyes set deep under a heavy, straight brow ridge, a coloured iris and one small crisp white highlight; a wide jaw with an underbite, tusks or bared teeth. ",
 'creepy':"Face: round staring eyes with pinpoint pupils and at most one tiny highlight, no brows; a flat, unreadable mouth; unsettlingly calm. ",
 'majestic':"Face: calm, level, half-lidded eyes with a coloured iris and one crisp white highlight; a long straight brow; a closed, composed mouth; quiet power. "}
FACE_V2['fast']=FACE_V2['sleek']
FACE_KEEP="Keep this species' own expression from image 1. The eyes are the most finished, most contrasty spot in the image, and the face is drawn as flat and simplified as the body. "
def CHEEKS_V2(stage,arch):
    if stage=='baby' or (stage=='mid' and arch=='cute'): return "Cheeks: two small flat pink ovals with hard edges. "
    return "Cheeks: plain, the same flat colour as the rest of the face. "
FRAME_V2=("Framing: exactly one creature, whole body in frame, centred, with about 8 percent empty margin on every side. "
 "Background: one perfectly flat pale grey (#E8E8EE) from edge to edge and nothing else: no gradient, no floor, no cast shadow, no contact shadow, no reflection, no halo, no text. Crisp clean edges all round so it can be cut out. ")
def STYLE_V2(stage,arch,dark=False,furry=False):
    return (RENDER_V2+(LINE_FINAL if stage=='final' else LINE_V2)+BUDGET_V2+(DARK_V2 if dark else "")+(FUR_V2 if furry else "")
            +FACE_V2[arch]+FACE_KEEP+CHEEKS_V2(stage,arch)+FX_V2)
SRV2='briefs/boki-art/style_refs/v2/anchor_%s.png'   # % face template; 'fast' uses the sleek anchor
```

## 3. Style re-render that keeps each design
**Card.** refs: `[cards/<Name>.jpg, SRV2 % arch]`, 1:1, 2K, 3 runs.
```python
def RS_CARD(name,stage,arch,cols,counts,dark=False,furry=False,fix=''):
    return ("Redraw the creature in image 1 as one single character illustration: "+name+". "
     "Image 1 is the design and the pose: keep exactly the same creature, body plan, proportions, pose, view, facing direction, face, markings and signature parts. Add nothing, remove nothing, move nothing. "
     "Its colours must not change: "+cols+". Its parts, counted, must match image 1: "+counts+". "
     "Image 2 is the style guide only: match its line, flat shading, eye finish and amount of detail exactly, but never copy its creature, face, colours or pose. "
     "Change ONLY how it is drawn. "+STYLE_V2(stage,arch,dark,furry)
     +(("One construction cleanup is allowed, and nothing else about the design changes: "+fix+" ") if fix else "")+FRAME_V2)
```
**Sheet.** refs: `[<old sheet>, <new V2 card>]`, 16:9, 2K, 2 runs. Sheets are flats (canon section 10).
```python
def RS_SHEET(name,cols,counts):
    return ("Redraw the turnaround sheet in image 1 as a clean flat model sheet of "+name+". "
     "Image 1 is the layout and the design: keep exactly its four views in one single row (front, three-quarter, side, back), their order, poses, scale and spacing, and every part of the creature. "
     "Image 2 is the same creature in the final art style, and it is the truth for colours, eyes, face and part counts: every view must agree with image 2 and with the other views. "
     "Colours: "+cols+". Parts, the same in every view: "+counts+". "
     "Model-sheet finish: "+LINE_V2+"Flat colour fills only, using the base colours of image 2, with no shading at all, in even neutral light. The only highlight is one crisp white highlight in each eye. "
     "All four views are the same height with the feet on one invisible baseline; the front, side and back are true front, side and back views. "
     "Background: one perfectly flat pale grey (#E8E8EE) and nothing else: no floor, no cast shadow, no text, no extra or faded copies of the creature.")
```
**Portrait.** refs: `[<old portrait>, <new V2 card>]`, 1:1, 2K, 3 runs.
```python
def RS_PORTRAIT(name,stage,arch,cols,counts,dark=False,furry=False):
    return ("Redraw the creature portrait in image 1: "+name+". Image 1 is the pose: keep its pose, view and framing. "
     "Image 2 is the same creature in the final art style, and it is the truth for design, colours, eyes, face, part counts and finish: draw image 1's pose exactly the way image 2 is drawn. "
     "Colours: "+cols+". Parts: "+counts+". "+STYLE_V2(stage,arch,dark,furry).replace(FX_V2,"The air around the creature is empty: nothing drifts, sparks or trails. ")+FRAME_V2)
```
**Re-pose** (only when a card's pose must change): use `CARD()` with the section 4 wording and the Boki's **sheet** as image 1. A card as image 1 keeps the old pose.

## 4. New art: replacements in build_jobs.py and the specs
| Where | Old text | New text |
|---|---|---|
| `RENDER`, `RENDER_A`, last sentence of `evo()` | "Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, ... not flat cel shading, not realistic." | `"Render it in the style of the style-guide image. "+RENDER_V2+LINE_V2+BUDGET_V2+FX_V2` |
| `STYLE_A`, `STYLE2`, the image-2 sentence in `evo()` and `CARD()` | "...match the finish, line weight, soft hand-painted shading, eye treatment and colour treatment..." (and "two example creatures; ignore their dark backdrop and glow") | "Image N is the style guide only (one example creature on plain grey): match its line, flat shading, eye finish and amount of detail exactly, but never copy its design, face or colours. " |
| `CARD()` lighting sentence | "Lighting: one soft key light from the top left, light shading falling to the lower right, no coloured rim light." | delete (RENDER_V2 sets the light) and insert `STYLE_V2(stage,arch,dark,furry)` |
| `CARD()` opening and last sentence | "a stylised, cute, endearing but slightly dangerous"; "the face is the focal point, big, glossy, expressive" | "a stylised, endearing but dangerous"; "the face is the focal point, big and expressive" |
| `CARD_STAGE['final']` | "...and a stronger stance, but still cute and appealing, never realistic." | "...and a stronger stance: bold and appealing, never realistic, with the head still about a fifth to a quarter of its height." |
| `SHEET` | "flat even light, plain pale grey background" | "a flat model sheet: line and flat colour fills only, no shading, even neutral light, plain flat pale grey (#E8E8EE) background" |
| `TA()` | "in the same soft hand-painted style" | "as a flat model sheet: the same line, flat colour fills only, no shading" |
| `P()` | "Render it exactly like image 1: soft hand-painted shading with a clean, fairly thin dark outline, not realistic. Plain flat white background" | `STYLE_V2(...)` + "Plain flat pale grey (#E8E8EE) background" |
| `CONCEPT_CORE` | "painted in exactly the soft hand-painted style of image 1 (clean, fairly thin dark outline, painterly shading, stylised and appealing)" | "drawn in exactly the flat cel style of image 1 (bold clean outline in a dark shade of each colour, flat fills with one hard-edged shade, stylised and appealing)" |
| `SRA` | `style_refs/boki_style_ref_2d.png` | `SRV2 % arch` (section 6) |

**New LESSONS.txt lines** (add; keep the existing eight):
```
Flat fills only: each colour area is one flat colour plus one hard-edged darker shade shape, in a matte finish.
Shine only on eyes, wet slime, gems and glass; fur, skin, scales, stone, wood and bone stay matte.
Bold outline in a very dark shade of the neighbouring colour, heaviest round the outside, lighter inside.
Dark creatures stay dark: near-black areas stay near black, with one lighter lit shape on the upper left.
Few, large details: detail only on the face, the signature part and one pattern; the rest of the body is plain.
Patterns wrap round the body: stripes and bands curve with the form like rings round a tube.
Every grown part rises out of the body through a thick fused base, like a horn from a skull, and its material shows again in the claws, brow or tail.
It moves one way only (legs, or wheels, or wings, or a coil), with the same number of limbs in every view.
Anything that glows is drawn as a flat bright colour; the game adds the glow later.
```

## 5. ELEM: element wording without glow
```python
ELEM_V2={
'ember':'ember, shown by bright orange cracks drawn as flat shapes and one or two small flat flames',
'bloom':'bloom, shown by living leaves, petals or moss growing from its body, fresh green',
'storm':'storm, shown by a few bold yellow zig-zag markings and one small flat lightning fork',
'frost':'frost, shown by a few big pale ice-blue crystals drawn as flat facets and frosted white tips',
'venom':'venom, shown by lime-green markings and one glossy venom bead with a single crisp highlight',
'swarm':'swarm, shown by a honeycomb pattern and insect-like segments, amber gold',
'tempest':'tempest, shown by wind-swept streamer shapes and sky-blue swirl markings',
'stone':'stone, shown by a few big rough rock plates with one or two bold cracks',
'shadow':'shadow, shown by inky black edges ending in a few solid flat wisp shapes, with a violet accent',
'spore':'spore, the type the Blight touches: appealing and healthy-looking, with the Blight palette only as a small accent (purple-black gills or vein lines on its caps, a few small bone-spur quills)',
'prism':'prism, shown by a few big glassy facets, with two or three flat pastel planes on its signature part only',
'lunar':'lunar, shown by pale silver crescent markings',
'echo':'echo, shown by ridges and ring shapes on its body, with bell, horn or pipe forms',
'gravity':'gravity, shown by heavy dark iron shapes and at most three chunky pebbles floating close to its body, deep indigo',
'titan':'titan, shown by a few massive plates grown from its hide and a powerful, grounded build',
'tide':'tide, shown by flowing fin shapes, wave-curl crests and foam-white tips, sea blue-green',
'wyrm':'wyrm, shown by small horns, a few big scale plates and a ridge of spines, old gold and deep crimson',
'wild':'wild, shown by natural earthy colours and a plain, honest animal look'}
```

## 6. New style anchor
**Recommendation: six anchors, one per face template, each a single creature on #E8E8EE, 1:1, 2K, each finished by a human.** Replace `boki_style_ref_2d.png`: it is glossy, on a dark backdrop, and its two cute babies pull every face toward the chibi template (style_refs/README.md already noted this). Each job passes the anchor that matches its own face template, so image 2 pulls the face the right way.

| File | Boki | Why this one | Start from |
|---|---|---|---|
| `v2/anchor_cute.png` | Vespyx (baby) | the face of the game; fur, flat cheek ovals, and the one licensed highlight (venom bead) | `style_vespyx_a_2` |
| `v2/anchor_pretty.png` | Chandelotl (final) | patterns that wrap the form, the prism rule (hood in 3 flat pastel planes), crystal count | `style_chandelotl_a_1` |
| `v2/anchor_sleek.png` | Rimink (final) | white fur on pale grey: shows the dark slate line and a restrained palette | `style_rimink_a_1` |
| `v2/anchor_tough.png` | Lockatara | mid values, scales as a few big shapes, metal as a flat band | `style_lockatara_a_1` |
| `v2/anchor_creepy.png` | Cindermaw (legendary) | dark body kept dark, glow drawn flat (the rib furnace), no cheeks on a skull | `style_cindermaw_a_2`, darkened |
| `v2/anchor_majestic.png` | Sarcobra (legendary) | black coils kept black with a lit shape, gold in base + shade + band | `style_sarcobra_a_1`, coils back to black |

How to make them: render each with `RS_CARD` using the interim anchor as image 2, pick the best run, then the artist paints over it to the canon's numbers (MARQUEE_HUMAN_PASS.md, first six). Owner approves all six side by side before the pilot. Interim anchors until then: the "start from" files above. After Gongrowl's redesign is approved and painted, add it as `v2/anchor_furry.png` for dark furry finals. Also save the six side by side as `v2/recipe_strip.png` for human reviewers; do not use the strip as a job reference (six creatures in one image get copied into results).

## 7. Hold list: construction redesign before any style render
From a pass over all 226 cards (most at 400 px, so confirm each at full size). A style pass leaves these designs as they are (Siegephant, Chuggamus and Shinobant barely changed in the style-a test), and flat rendering makes the straps easier to see. Each needs a concept round (`c_<name>`), an owner pick, then its set.

| Boki | Problem | Redesign direction |
|---|---|---|
| **Gongrowl** | chest plate on straps, shoulder strap, cuffs, back disc; semi-realistic gorilla with a small head | the gong is a bronze disc grown in the chest like a breastbone plate, the same bronze in the knuckles and skull crest; head about 22% of its height; near-black fur with a lit shape, bronze as the light value |
| Anvilbrock, Forgebrock | bolted plates on shoulders and legs, anvil and furnace sat on the back | the back is one grown anvil slab rising from the spine; plates become dark iron hide patches without rivets or raised edges |
| Barostorm | upright, with bracers, greaves and a crown | low stance; the gold becomes horn growth at brow and tail; the dial is a belly marking |
| Furnacowary | banded furnace armour, anvil feet | the firebox is its open ribcage, the ribs its own dark bone; the chimney is its casque |
| Vaultara | vault door plus riveted leg armour with gold trim | the door is its shell, the hinge its spine ridge; legs get thick plain scale plates |
| Prowyak | riveted steel plate bolted over the face | the prow is its own keeled skull boss growing between the horns |
| Bastionpet | riveted bands round the claws and legs | bands become ridges of the shell itself |
| Siegephant (legendary) | tower, face mask, wheels and feet, chain and mace tail, rivets on every plate | legs only; the tower is a grown crest, the portcullis its teeth, the tail a thick tail with a mace knob; 3 rivets per plate at most |
| Chuggamus | hippo wearing a locomotive: wheels and legs, riveted boiler shell | boiler belly is its own copper hide, the stack a horn, piston-shaped legs only, the cowcatcher its lower jaw |
| Tiltster | hamster in a pinball machine with chrome arms and leg frames | the table is its flat back shell, bumpers are knobs grown from it, flippers are its own forepaws |
| Canvastross | bird wearing a ship's hull, masts and rigging | the hull is its keeled chest, the sails are its wings, the mast a crest feather |
| Barrelmander, Bucketmander | salamander wearing a hooped barrel; sitting in a bucket | the cask is its own stave-patterned back, hoops are skin ridges |
| Crofthollow | a cottage (walls, window, chimney smoke) on a yak | the hump is shaped like a thatched roof made of its own fur, one chimney horn |
| Pagoguana | a pagoda building on its back; upright | tiers are stacked dorsal plates along the spine; tail planted, forelegs down |
| Domeleon | riveted dome and telescope carried on the back | the dome is its casque, the telescope one tube-shaped eye turret |
| Stormit | crab carrying a glass case, spring legs | the case is its own translucent shell |
| Maulangler, Snapler | bolted trap jaw, strap band, hanging chain | the trap is its own toothed jaw with a knuckle joint; the hook grows from the lure stalk |

**Accepted exceptions (owner, 11-09).** Four approved designs bend the born-with rule and stay as approved: Scoopsy (sits in a cone), Shinobant (mask and scarf), Reapant (hood) and Galleotter (collar, hoops, oars, mast). Give them no `fix` line, and do not fail them on checklist item 18 for these parts.

**Galleotter: one edit before its style re-render (owner, 11-09).** The ship sits over its lower belly with the mast rising between its hind legs, which reads badly. Move it; change nothing else. Edit job on the card (`X()`), then the sheet and portrait follow from the new card:
> Move the ship deck and the mast up onto its chest and upper belly, so the deck lies between its front paws and its waist and the mast rises from the middle of its chest. Its lower belly, hips and hind legs are plain brown fur with nothing on or between them. The otter, its pose on its back, its face, the tail prow, the oars, the sail and every colour stay exactly the same.

**Small fixes inside the re-render** (`fix` field, no hold): gold belts on Parrywhal and Gambitfin; ankle cuffs on Snuffapi; pan-pipe collar on Murmuron; chain on Anchorhorn (make it a raised chain-link ridge along the spine); copper leg and neck coils on Arcestrel, Boltstrich and Kestrike; leg rings on Lanternlong; latch and toe caps on Frigatee; tail band on Lockatara; loose gears and compass letters on Wayshell (letters become plain tick marks); bow on Ribbonwyrm. Example `fix`: "the gold bands round its body become raised ridges of its own skin in the same gold, fused to the body with no edge standing proud".

**Other flags from the same pass:** person-like stance on Druzemole, Voltalon and Barokat; a base or ground under Glaciatee (ice block), Knotwyrm (stump), Glomworth, Slog, Quivertoad and Cisternmander (puddles); Effigoon's rope is cut by the frame.
