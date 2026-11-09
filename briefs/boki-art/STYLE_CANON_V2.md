# Boki 2D style canon V2 (proposal for owner approval, 2026-11-09)

Replaces the finish rules of STYLE_CANON.md. Designs do not change: same creature, body plan, colours and signature parts. Only rendering, line, face treatment and construction cleanup change. Prompts: RERENDER_PROMPTS.md. QA: REVIEW_CHECKLIST_V2.md.

**Owner pick (16:32 ET 11-09): style a, flat cel, as the base for everything; it does not work on Gongrowl.** So V2 is style a plus four things the tests show a does not fix by itself: a line with hierarchy, a detail budget, face and blush rules, and rules for big, dark or furry finals (section 3). Evidence: DEAI_RESEARCH.md, the round-6 test (6 Boki x 3 styles) and the round-7 test (style a on 20 more Boki, 40 images, all viewed).

What round 7 showed. Style a holds up on simple, light or mid-value designs: `style_aurostag_a_1` (halo and stars gone, aurora as flat bands), `style_druzemole_a_1` (geode glitter gone), `style_lurklet_a_1`, `style_lockatara_a_1`, `style_soakybara_a_1`, `style_vespyx_a_2`, `style_chandelotl_a_1`. It does not fix these, so the rules below do:
- **Dark bodies get lifted to a muddy mid tone** (Gongrowl, Sarcobra a_1, Seamwyrm, Cindermaw). Section 3.
- **Colours drift between runs**: eye colour changed on Mycroll, Glazolm, Arcestrel and Hydrangor; body colour on Coolatee (white to cream), Chuggamus (purple to grey), Sarcobra a_2 (black to navy). Section 4.
- **The outline turns pure black in about 1 run in 8** (Spanglin a_2, Kitlet a_1, Zipling a_2, Hydrangor a_1, Maulangler a_1). Section 1.
- **Blush, mist, steam, drips and inner glow survive** (Siegephant, Druzemole, Coolatee, Chuggamus, Quivertoad, Cindermaw's ribs). Sections 6 and 8.
- **Busy or strapped designs barely change** (Siegephant, Shinobant, Chuggamus). A style pass cannot fix a design: see the hold list in RERENDER_PROMPTS.md section 7.

## The recipe in one line
Flat fills, one hard shade shape per colour, a bold three-weight line in a dark shade of the local colour, darks kept dark, shine only on truly glossy materials, detail in three zones, a face template per archetype, blush on babies only.

## 1. Line
Style a's bold clean line, with a hierarchy added (a's even weight is the one tell it left in place).
- **Three weights, ratio 4 : 2 : 1.** Outer silhouette : lines between body parts : small detail. On a 2048 px card that is about 6 / 3 / 1.5 px (outer line is about 0.35% of the creature's longest side, so sheets scale down with the view size). Finals and legendaries use 5 : 2 : 1 (outer about 8 px).
- **Taper.** Strokes that end inside the body end in a point. The outer line gets up to 1.5x heavier on the shade side (lower right) and under overlaps. The silhouette line stays closed, for the cutout. If the owner prefers a's even line exactly, drop the taper and keep the three weights (`LINE_V2_EVEN` in the prompts file).
- **Colour.** Each line is the neighbouring fill darkened to about 25% lightness and shifted 15 to 20 degrees cooler: deep plum round purple (Vespyx), dark umber round gold and brown (Gongrowl, Mycroll), deep slate blue round white and ice (Rimink, Glaciammoth). Never pure black (test c), never one plum for every Boki, never lighter than the fill beside it, never above 35% lightness on pale Boki.
- One line only: no doubled lines, no sketch hairlines, no fur strands. A fur edge is 3 to 7 clump points per edge run.

## 2. Shading
- **Two tones per colour: base + one shade.** The shade is one hard-edged, connected shape per form, on the lower right (one key light, top left, about 45 degrees). It covers 25 to 35% of the creature.
- Shade colour: the base 15 to 25% darker, 10 to 20 degrees cooler, slightly more saturated. Never grey, never black, never a lilac wash.
- No gradients, airbrush, bounce light, rim light, soft belly glow or ambient smudges. A lighter belly is its own flat swatch.
- **Highlights by material only:**

| Material | Highlight |
|---|---|
| Eyes | 1 hard white highlight (cute and pretty: plus 1 small second) |
| Slime, venom, wet surfaces, polished gems, glass | 1 hard-edged highlight shape per part, max 3 per creature outside the eyes (Vespyx's venom bead: 1) |
| Metal | 1 flat lighter band, no dots, no gradient (Gongrowl's gong, Glaciammoth's tusks) |
| Ice, crystal | 2 or 3 flat planes per crystal. Rainbow only on prism types: max 3 flat pastel planes, on the signature part only (Chandelotl's hood) |
| Fur, feathers, skin, scales, stone, wood, bone, moss | none |

## 3. Big, dark or furry finals (the Gongrowl problem)
Flat cel failed on Gongrowl for two rendering reasons and one design reason. Rendering: the model lifted the dark fur to mid grey so the line would show, which put fur, shade and bronze into one value band; and fur as one flat fill has no form. Design: strapped armour on a semi-realistic gorilla, which no finish can hide (hold list, RERENDER_PROMPTS.md section 7).
- **Darks stay dark.** A fill that is below 30% lightness in the approved card keeps a base of 15 to 25% lightness and may not be lifted by more than 5 points. Applies to about 35 Boki, among them Gongrowl, Sarcobra, Seamwyrm, Cindermaw, Sphinxblight, Maulangler, Snapler, Zippelith, Zipling, Blotlet, Slog, Sloggoth, Lodestaff, Reapant, Eclipsowl, Meteorab, Gravitank, Murmuron, Howlop, Dreadmonite, Pyrraven, Anchorbill, Chainipede, Umbrathere.
- **On a dark fill the second tone is a light shape, not a shade.** One hard-edged lit plane on the upper left, 10 to 15 points lighter than the base, covering 20 to 30% of the dark area. Interior lines on dark fills are drawn in that lighter tone, because a darker line cannot show. The outer line stays the darkest thing in the image.
- **Value split.** At least 40 points of lightness between the darkest and the lightest large fill, each value group one connected mass (Gongrowl: fur about 20%, bronze about 60%, belly about 70%). Check it in the squint panel.
- **Fur is clumps, not a flat fill.** The edge between the two tones is a clump edge (3 to 7 big points per run), plus up to 5 separate clump shapes at mane, shoulder, elbow, haunch and tail. No clump smaller than the eye, no strand lines, no third tone. Applies to furry finals such as Gongrowl, Ringrove, Glaivyx, Rimefang, Dreadnoyak, Prowyak, Sphinxblight, Howlop.
- **Heavier silhouette.** 5 : 2 : 1 line (section 1).
- **Boki proportions.** Finals keep a head of 20 to 25% of body height. A realistic small head on a big body (Gongrowl, Cindermaw, Glaivyx, Ringrove) reads as a different art style from the babies.

## 4. Palette and value
- **Max 5 base swatches**: 2 mains, 1 accent, up to 2 neutrals (teeth, claws and eye whites share one). Each has exactly 1 shade swatch.
- Area: mains together at least 75%; the accent at most 10% and the most saturated colour on the creature.
- Three value groups (light, mid, dark). The face and the signature part sit in a different group from the body behind them. Somewhere there is a fill darker than 25% lightness and one lighter than 85% (fixes the purple-on-purple of Cindermaw and Gongrowl).
- Colours come from the approved design and are written into every prompt in words (main colours and eye colour). A shifted colour is a fail: eye colour changed on 4 of the 26 Boki tested in style a, body colour on 4 more.

## 5. Detail budget
- **Three detail zones: the face, the signature part, one pattern.** Everything else is a quiet flat shape. At least 40% of the body has no interior mark.
- No mark smaller than the eye highlight.
- Countable parts (crystals, mushrooms, spikes, rivets, eye-spots, facets, stars): at most 12 on a baby or middle form, 16 on a final or legendary, in at most 3 sizes. Drips: max 3. Cut repeats, never a kind of part.
- Bands and stripes: none narrower than the pupil.
- Named targets: Glaciammoth about 12 body facets (now about 80); Siegephant max 3 rivets per plate, on the head tower only; Pavonazar 3 crest eyes + 7 tail eyes (now about 35); Aurostag max 7 stars, on the flank only; Mycroll 3 big + 4 small caps.
- One intended quirk per species (a chipped horn, a bent ear, one odd tooth), the same on its card, sheet and portrait.

## 6. Faces
The eyes keep their current quality: coloured iris (2 tones max), dark pupil, hard highlight. They are the most finished spot in the image. Never dots or closed lids (test c), never shrunk (test a_1 Vespyx). The face is drawn at the same simplification as the body: no realistic muzzle, wrinkles or fur under cartoon eyes (Ringrove, Gongrowl, Cindermaw, Sphinxblight). The species' own expression (grumpy, smug, anxious) always wins over the template's default mouth.

| Template | Eye shape | Eye height / head height | Highlights | Brow | Mouth | Blush |
|---|---|---|---|---|---|---|
| cute | round, set low and wide | 30 to 35% | 1 big + 1 small | none or a dot | small, own expression | yes |
| pretty | large almond, 1 to 3 lash flicks | about 25% | 1 big + 1 small | soft arch | small, poised | baby only |
| sleek / fast | narrow almond, outer corner up 10 to 15 degrees | 15 to 20% | 1 | flat upper lid | smirk | no |
| tough | small, deep under a heavy straight ridge | 10 to 15% | 1 small | heavy ridge | wide jaw, underbite or tusk | no |
| creepy | round stare, pinpoint or uneven pupils | 20 to 30% | none or 1 tiny | none | flat, or slightly too wide | no |
| majestic | level, half-lidded | 15 to 20% | 1 | long, straight | closed, composed | no |

**Blush rule:** two small flat ovals, no gradient, on every baby and on cute middle forms. Nowhere else: no finals, no legendaries (Glaciammoth, Hydrangor, Cetorgan, Wayshell, Pavonazar, Sphinxblight and the skull of Cindermaw all carry blush today).

## 7. Construction
- Every born-with part grows from a named landmark (skull, spine, shoulder, tail root) through a thick fused base. No seam, ferrule, band, strap, buckle, chain, bolt or plate lying on top.
- The part's material appears in at least 2 other places (claws, brow, tail tip).
- One locomotion system. Limb, wing, tail and head counts are written in the prompt and equal on every asset.
- Patterns wrap the form: stripes are cross-contour curves, spots foreshorten at the edges (Chandelotl's chevrons are decals today).
- An animal, not a person: no pecs, abs or shoulders-back stance (Druzemole).
- One line of action through spine, neck and tail. No mirrored limbs. Creepy Boki may be symmetrical on purpose.
- Feet of walking species sit on one floor line (Rimink's ice hooves float today). Flyers and swimmers may float.
- Small cleanups (a band, a cuff, a chain) go in the `fix` field of the re-render job. Whole-design problems (strapped armour, an animal wearing a machine) are redesigned first: hold list in RERENDER_PROMPTS.md section 7.

## 8. Effects
- One effect, one place, at most 5% of the creature's area, attached to the body, drawn as flat hard-edged shapes (a flame is 2 flat tones).
- "Glow" in the art is the brightest flat swatch with a lighter inner shape. No halo, bloom, sparkle stars, glints, mist, smoke trails or drifting particles. Real glow is added at display time (the CSS type glow in STYLE_CANON.md stays).
- Detached pieces (gravity pebbles, spores): max 3, each bigger than the eye, close to the body.

## 9. Staging
A style re-render keeps each approved pose and facing. These rules apply when a pose is redone.

| Stage | Stance | Camera |
|---|---|---|
| Baby | sits, bounces or tumbles; round and compact | level or up to 15 degrees above |
| Middle | in motion: prowl, stride, dash, glide or coil; body on a diagonal | level |
| Final | planted: rearing, looming, towering or braced wide | level, or up to 10 degrees below for majestic and boss or ultra legendaries |

| Template | Pose | Gaze |
|---|---|---|
| cute | head tilt, weight on the rump | at the viewer |
| pretty | S-curve, looks back over a shoulder | past the viewer |
| sleek / fast | forward lean of 15 degrees or more, long diagonal | along its path |
| tough | low and wide, head down | along its path, or a glare at the viewer |
| creepy | very still, head tilted | straight at the viewer |
| majestic | upright, head high | over the viewer |

Body turned 20 to 60 degrees, both eyes visible, never flat front or pure profile. Kept from V1: one creature, full body, centred, about 8% margin, flat #E8E8EE, no ground, no cast shadow, no halo, no text, head ratios by stage (40 / 30 / 20 to 25%).

## 10. Sheets and portraits
- **Sheets are flats:** line plus flat fills, no shade shapes, highlights in the eyes only. Fewer things can drift between views, and the sheets feed image-to-3D, where painted shading bakes into the texture. Four views in one row (front, three-quarter, side, back), same height, same counts, same eyes as the card.
- **Portraits** use the full card recipe on #E8E8EE (not white), so one cutout pipeline serves both.

## 11. Overrides of the old canon
| # | Old rule (source) | V2 | Why |
|---|---|---|---|
| 1 | "Soft hand-painted shading" (STYLE_CANON style words, DESIGN_RULES 11, RENDER, CARD, P, TA, CONCEPT_CORE) | flat fill + 1 hard shade shape | the airbrushed finish is tell 2 |
| 2 | "Never flat cel shading", "no flat vector fill" (STYLE_CANON, DESIGN_RULES 11) | flat cel is the base | the owner's pick |
| 3 | "One thin dark outline, same weight on every Boki" | bold line, 3 weights 4:2:1 (5:2:1 on finals), hue-shifted per local colour | uniform line reads as a filter (tell 7) |
| 4 | "Big glossy eyes" for all; "rounded toy-like shapes" for all | 6 face templates; shapes follow the archetype table already in DESIGN_RULES | one chibi face on everything (tell 3) |
| 5 | "Soft pink blush on the cheeks" at every stage (STYLE_CANON, PANEL_BRIEF "Blush") | flat blush on babies and cute middles only | blush on bosses and skulls (tell 3). Restores the older GRADES auto-fail "blush on non-babies", with cute middles allowed |
| 6 | "Soft key light, a soft lighter belly and a gentle bounce from below" | one key light, hard shade, no bounce | ambiguous light (tell 2) |
| 7 | "Never from above or below"; body fixed at 25 to 35 degrees; head always toward the viewer | 20 to 60 degrees, small camera tilt and gaze by stage and template | every hero staged the same (tell 9) |
| 8 | Finals "still cute and appealing" (CARD_STAGE) | finals are appealing; cute is not required | the owner wants bold finals; cute finals forced the baby face onto them |
| 9 | Element wording with "glowing", "glow", "glossy shine", "mist", "rainbow glints", "shimmer" (DESIGN_RULES table, ELEM) | flat-shape wording, RERENDER_PROMPTS.md section 5 | the words ask for glow and sparkle (tell 5) |
| 10 | Anchor `boki_style_ref_2d.png` | 6 archetype anchors, RERENDER_PROMPTS.md section 6 | it is glossy, and two cute babies pull every face to chibi |
| 11 | Sheets "in the same soft hand-painted style"; portraits on plain white | sheets are flats; portraits on #E8E8EE | section 10 |
| 12 | PANEL_BRIEF "STYLE_CANON" paragraph (thin outline, big glossy eyes, soft blush) | critics judge with REVIEW_CHECKLIST_V2.md | follows from 1 to 5 |

Not overridden: every BOKI_DESIGN_RULES design rule (1 to 10, 12 to 14), the stance ladder, framing and background, no shadow or halo, display-time glow, never naming another franchise.
