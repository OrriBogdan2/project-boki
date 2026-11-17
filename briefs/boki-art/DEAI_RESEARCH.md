# Project Boki: what makes our art read as AI, and how to fix it

Scope: 15 current hero cards, 2 turnaround/evolution sheets, the style anchor, STYLE_CANON.md and BOKI_DESIGN_RULES.md, and the a/b/c style test (560px webp, one generation each, so judge them as direction, not as finals). Web research is cited by [n] in section (e). Numbers marked (H) are my own working heuristics synthesised from the sources, not quotes; the second agent should treat them as starting values to test.

## Headline

Our art is not mainly failing on anatomy any more. It fails on a *finish* that every generator shares (glossy airbrushed gradients, equal detail everywhere, one chibi face on everything, glow and sparkle) and on *construction logic* (parts that are attached, not grown). The canon's own style words ("soft hand-painted shading", "big glossy eyes", "pink blush") ask for the tell. The anchor (Vespyx, Mycroll) is itself glossy, so it propagates the problem to 225 creatures.

## (a) AI tells in OUR art, ranked by damage

**1. No value hierarchy, uniform detail density ("everything rendered equally").** Nothing is allowed to be quiet, so the eye has no entry point and no area looks decided. Sources call this the polished-but-generic look and "greeble", detail placed without intent that gets worse the longer you look [1][2][3].
- Gongrowl: fur, armour plates, straps, scars, cymbal tail and fingers all carry the same texture weight.
- Siegephant: rivets on every plate, wood grain on every board, spikes, chain, wheels.
- Druzemole: glitter inside the geode plus pebbles on every limb. Lockatara: runes, scales, pins and spikes together.
- Glaciammoth: facet lines tile the whole body like bricks. Cindermaw: veins, spines, drips and ribs together.

**2. Plastic, airbrushed, glossy shading with an ambiguous light.** Multi-step soft gradients, scattered specular spots, bounce light and haze. Artists name "exaggeratedly airbrushed", "injection-moulded plastic" and "vague lighting with no visible source" [1][4].
- Vespyx's tail segments read as balloons with window highlights. Chandelotl's stripes and body are wet-looking.
- Anchorhorn, Pipwom and Siegephant carry dozens of random highlights that do not agree on a light direction (the canon says top-left).
- Spanglin and Chandelotl use iridescent rainbow glints: the generic "magic crystal" look.

**3. The same face template on everything.** Round glossy eyes with double highlights, pink blush, closed little smile. Blush appears on Gongrowl mid-roar, the rusted Anchorhorn, the skull-faced Cindermaw, Siegephant's helmet, Pipwom, Glaciammoth and Druzemole. It contradicts our own rule 4 (own personality per face). It also creates a *style mismatch*: semi-realistic bodies (Gongrowl, Lockatara, Cindermaw, Pipwom, Siegephant) under an anime-chibi face, which reads as a collage of two models.

**4. Construction and attachment logic breaks.** Parts look draped, strapped or fused without a joint (the "one thing tied to another" the owner hates).
- Gongrowl: armour straps cross the chest with no buckle logic, a back disc floats on a strap, arm cuffs end abruptly.
- Siegephant: tower, mask, wheels *and* feet blocks all present, so the body has two locomotion systems; it reads as a vehicle with eyes.
- Anchorhorn: the chain lies on the back like a prop, the harpoon skewers the beak, the hind limb count is ambiguous. Pipwom: a die sitting on a wombat (backpack syndrome).
- Rimink: floating pose with ice-spike hooves off the floor, a paintbrush-like ferrule joining ice tail to fur tail tip. Glaciammoth: the raised trunk tip reads as a pig-snout foot.
- Chandelotl: chevron and stripe patterns do not wrap with the neck and body curvature, so they look like decals. Druzemole: a muscular humanoid torso and pecs on an "animal" (against rule 6).

**5. Shading and light effects that fight the canon.** Glow halos and sparkle stars return despite "no glow": Aurostag (halo on antlers, stars scattered over a galaxy body), Cindermaw (glowing rib window), Druzemole (glittering geode), Vespyx's glowing slime drop. Effects spread to the whole body instead of staying "small".

**6. Flat, low-contrast value range and a milky cast.** Gongrowl, Anchorhorn, Pipwom and Cindermaw are mostly mid-values (purple on purple, grey-teal on grey-teal), so the shadow test is weak at thumbnail size. A lilac haze tints shadows and the background. Chandelotl and Aurostag exceed "2 colours plus an accent" (red, white, green, pink, rainbow). Rimink is the restrained exception and the strongest piece.

**7. Line has no hierarchy and no consistent colour.** One thin, even stroke everywhere. The canon says "darker tone of the local colour", but Pipwom, Chandelotl, Spanglin and Lockatara use the same dark plum, while Glaciammoth and Rimink use pale blue that vanishes. Fur-edge hairlines and doubled lines (Rimink tail, Gongrowl fur) add noise. Line weight reads as a filter, not a hand decision [5].

**8. Set inconsistency.** Glaciammoth is painterly with visible brush texture and almost no outline. Vespyx and Mycroll are clean stickers. Lockatara and Anchorhorn are semi-realistic. Gongrowl is muddy-painterly. A real roster shares a rendering recipe [6][7].

**9. Sameness of staging.** Every hero: centred, eye-level three-quarter, head turned to camera, same scale. The canon enforces it. Real rosters vary pose and silhouette rhythm. Kisser also lists "eye-level, straight-on framing" as an AI habit [4].

**10. Multi-view drift and non-orthographic sheets (turnarounds, evolutions).**
- Chandelotl sheet: crystal count and placement change between views, hood facets differ, stripe phase shifts, glint stars appear only in some views.
- Anchorhorn sheet: chain path changes per view, water droplets appear that the card lacks, hind limb count varies.
- The views are perspective three-quarter drawings at small scale, not orthographic model-sheet views with construction lines, head-unit height or a colour sheet [8].

**11. Artefacts.** Blocky patches in the Pipwom background top-right, a horizontal seam in Spanglin's background, and upscaler halos and mush at small detail. Viewers who zoom see them instantly.

## (b) Professional principles that fix each tell (rule-ready)

Fix for 1 (hierarchy, detail budget):
- Design 3 value groups (light / mid / dark) before rendering; limit to 3-4 values, merge unimportant areas into one quiet value, put the strongest contrast on the face [9][10]. Squint rule: the eye reduces to about 3 values anyway [10].
- Silhouette carries about 70% of impact, details 30% [11]. Pokémon: fill it in black and it must still be recognisable [12]; test small, large and in motion [12].
- Detail budget (H): at most 3 detail zones (face, signature born-with part, one pattern). Everything else is flat colour. One texture motif, drawn large: no mark smaller than the eye highlight. Pass test: at 128px it still reads; posterised to 3 grey levels it still reads.
- One defining trait per design; "give one defining trait" (Psyduck) [12]. Sugimori deliberately adds one "not cool" quirk (Oshawott's freckles) to stay memorable [13]. Add one intended imperfection per Boki (chipped horn, droopy ear), not noise.

Fix for 2 and 5 (shading):
- Shading = value family, not gradient. Anime colouring uses base, one shadow layer, one highlight layer, and few layers overall [14]. Rule (H): 1 base + 1 hard-edged shadow shape + at most 1 small highlight per material; one key light (top-left, as in canon), one shadow direction; shadow tone is hue-shifted (cooler, not black or grey).
- Specular only where the material is glossy (eyes, gems, slime). None on fur, scales, cloth.
- Effects: one effect, one place, max about 5% of area, nothing outside the silhouette. Glow belongs in the display layer (as the canon already says).

Fix for 3 (faces):
- Pokémon Gen 1 got cohesion from a *limited eye set* and shared motifs (identical bird feet), not one face [6]. Define 5-6 eye/brow templates by archetype (cute round, sleek narrow, tough small, creepy off-centre, majestic calm). Blush only on cute and baby stages. Face spec per species (brow angle, pupil shape, mouth).
- Body and face must share one realism level: pick chibi-simple or semi-real for all, not both.

Fix for 4 (construction, solid drawing):
- Solid drawing = volume, weight, balance; avoid "twins" (mirrored limbs); posture expressive [15]. One continuous line of action through spine, neck and tail; pose asymmetric.
- Rule (H): every born-with part has (a) an attach point that grows from a body landmark, (b) the same material repeated in at least two other places (rule 13), (c) no strap, band, buckle or chain wrapping the body. Pattern follows form: stripes are drawn as cross-contour curves.
- One locomotion system (legs *or* wheels). Hind and fore limb count stated in the prompt and checked.
- Primitive shapes: circles friendly, squares heavy, triangles aggressive; one dominant primitive plus one contrast; archetype shape language per our table [11].

Fix for 6 (colour and value):
- Keep "2 main + 1 accent" and make it measurable (H): max 5 base swatches, each with exactly 1 shadow swatch; accent at most 10% of area and the most saturated; check in greyscale that the face and signature part separate from the body [10]. Colour supports shape, never replaces it [11]. Pokémon Gen 1: single main colour with a lighter or darker accent, contrast doing the work [6].

Fix for 7 (line):
- Line weight is hierarchy: heaviest on the outer silhouette, focal point, shadow side and where forms touch; thinnest on interior detail; tapered ends; uniform weight carries no hierarchy [5].
- Numbers (H) on a 2048px card: outer 6px, interior 3px, detail 1.5px (about 4:2:1); line colour = local colour at about 25% lightness and hue-shifted, never one global plum; never lighter than the fill beside it.

Fix for 8 (consistency):
- Style guide plus model sheets: front (reference), side, back, three-quarter, head turnaround, construction sheet in head units, colour sheet with swatches, about 6 expressions, 4-5 poses [8].
- Rosters stay coherent by repeating a small vocabulary (eye set, claw style, ear shape) per family [6]. Lock a one-page "recipe card" (line, tones, effect rules) rather than relying on one image anchor.

Fix for 9 (staging, appeal): pose and exaggeration express personality; push one trait past realistic while keeping it believable; staging uses silhouette and contrast to point at the key idea [15]. Allow per-archetype poses (tough: low, wide; fast: forward lean; majestic: upright) instead of one pose [11].

Evolution design: I found no strong sourced studio doctrine. Practical synthesis: keep 2 anchors constant (colour pair, eye shape or marking), change the *primary shape* by stage (round, then mixed, then angular or heavy), per the canon's head-ratio table and shape language [11].

## (c) The three test styles versus current

Caveat: all three are restyles of the *current* cards, so they inherit current poses and construction errors (Gongrowl's straps, Rimink's hooves). They cure finish, not logic. Viewed at 560px only.

| | Tells fixed | Tells remaining or new | Verdict |
|---|---|---|---|
| **cur_** | none | tells 1-11 | baseline |
| **a flat cel** (Gongrowl, Chandelotl, Vespyx, Glaciammoth, Rimink) | Removes gloss, airbrush, rainbow glitter (Chandelotl hood becomes plain pale blue), most surface noise; shadow becomes one shape; coloured outline; easiest to hold consistent over 225 and to hand to a 3D modeller | Face template and blush stay; eyes shrink (Vespyx loses appeal); generic "vector clip-art" risk; shadow shapes are model-chosen, not designed; line weight still uniform | **Best base.** |
| **b hand-ink and wash** (Chandelotl, Vespyx, Glaciammoth) | Most visible trace of a hand: variable line, pigment edges, restrained palette | Wash texture is uniform (a filter look [16]); paper-coloured background fights the #E8E8EE clean cutout; Glaciammoth desaturates; drift risk across 225 | Best for marketing or hero shots only if a human finishes; weak as a pipeline default |
| **c chunky simple** (Gongrowl, Glaciammoth, Mycroll, Rimink, Chandelotl) | Smallest detail budget, strongest silhouettes, nothing for a model to hallucinate; hardest to flag | Heavy black uniform outline (banned by the canon); eyes become dots or closed lids (Glaciammoth looks asleep), so personality is lost; adds floor shadow ellipse (Chandelotl, Glaciammoth); looks like stock sticker art | Borrow its *simplification*, not its outline or eyes |

Recommendation: a's rendering (flat, 1 shadow shape) plus b's line behaviour (tapered, hue-shifted, heavier outer line) plus c's detail budget, keeping the current eyes and face quality. This also suits 3D buildability (flat zones). Candid risk: flatter art makes anatomy and construction errors *more* visible, because gloss no longer hides them, so the construction fixes in (b) become mandatory.

## (d) Prompting versus a human pass

**Can be fixed by prompting and pipeline:**
- Tone count, line weight ratios, line colour, palette cap, "no glow, no gradients, no specular on fur", detail budget, no blush on non-cute, face template per species, one locomotion, no straps.
- Enforce the finish mechanically: after generation, posterise to N colours and vectorise (my suggestion), then re-apply line. This hard-limits tone count where prompts only nudge.
- Generate the silhouette or flat-shape version first, then fill. Per-view consistency: build the existing 3D greybox or clay render and feed it as a depth or line reference, plus a written feature-count list ("5 hood crystals, 4 legs").
- Replace the anchor: a style anchor with the glossy finish bakes the tells into everything.

**Needs a human (honest limits):**
- Real design decisions: which parts are quiet, where the one quirk goes, designed shadow shapes. Models average; "painted light is a choice, generated light is often an average" [16].
- Construction logic of fused parts and attachment points, anatomy of unusual species, view-to-view identity (stripe phase, crystal count). Prompts reduce but do not remove these.
- Imperfection that looks purposeful: filters read as filters [16]. A full-AI workflow is slop by definition to many viewers [2][17].
- Practical triage (H): human paint-over or redraw for about 20 marquee Boki (starters, legendaries, site and store art, key promo); prompt-fixed pipeline plus a 2-minute QA checklist for the rest. Studio use of AI is typically as a controlled layer under human paint-over [18].

**Audience and legal reality (not fixable by style):**
- Many dislike AI for labour and "ripped-off" reasons, not just look; some will not buy a suspected-AI game; big-studio "slop" criticism spills onto indies [19]. GameDiscoverCo poll (3,800 Steam players): 31% negative on AI disclosures, 8% would refuse to buy, only 17% trust developers to disclose all AI use [20].
- Identical images were rated lower when labelled AI (small student study) [21]; discrimination ability is described as poor in prior work [21]. So a better finish lowers "looks AI" flags but not "is AI" objections.
- Steam requires disclosure of AI-generated content shipped in the game or used in marketing (rewritten 16 Jan 2026) [22]. Fully AI-generated images are not copyrightable in the US; prompts and selecting an output are not authorship, but human modification and arrangement are [23]. For "our own IP", hand-drawn design sheets and paint-overs matter legally as well as optically.
- Human art also gets accused: Abandoned Sheep changed capsule art after viewers assumed AI; devs advise process videos and being open [19]. Plan to show WIP and human passes.

## (e) Sources

1. Creative Bloq, how to spot AI images: https://creativebloq.com/ai/ai-art/how-to-spot-ai-images
2. Venngage, AI slop in design: https://venngage.com/blog/ai-slop-in-design/
3. IIT Tech News, AI in artistic non-realism: https://technews.iit.edu/2025/03/06/the-uncomfortable-tension-caused-by-ai-in-artistic-non-realism
4. Kisser, Why does all AI art look like that: https://medium.com/@keithkisser/why-does-all-ai-art-look-like-that-f74e2a9e1c87
5. Proko, line weight notes: https://proko.com/course-lesson/how-to-draw-with-line-weight/notes
6. Game Developer, Evolution of Pokémon designs (Gen 1): https://www.gamedeveloper.com/design/evolution-of-pokemon-designs-gen-1
7. Rocketbrush, shape language and consistency: https://rocketbrush.com/blog/shape-language-in-game-character-design-how-to-make-characters-readable-and-consistent
8. Clip Studio, model sheets for character designers: https://www.clipstudio.net/how-to-draw/archives/164740
9. Brooks, Design your values, don't just shade: https://brooks-newsletter-359c19.beehiiv.com/p/design-your-values-don-t-just-shade
10. Gurney Journey, How many values: https://gurneyjourney.blogspot.com/2018/01/how-many-values.html
11. Rocketbrush (as 7), 70/30 silhouette rule and primitives
12. Creative Bloq, lessons from 30 years of Pokémon design: https://www.creativebloq.com/art/digital-art/what-artists-can-learn-from-30-years-of-pokemon-character-design
13. Nintendo Life, Sugimori on memorable designs: https://www.nintendolife.com/news/2018/07/ken_sugimori_wants_pokemon_designs_to_be_as_memorable_as_possible
14. Clip Studio, simple anime-style colouring: https://www.clipstudio.net/how-to-draw/archives/162911
15. Netguru, 12 principles from an illustrator's eye: https://www.netguru.com/blog/illustrators-eye-12-principles-of-animation (animation principles applied to stills is an extrapolation)
16. Imagera, making AI art look hand-made: https://imagera.ai/blog/make-ai-art-look-hand-made-2026
17. Creative Bloq, AI was supposed to make artists' work easier: https://www.creativebloq.com/3d/video-game-design/ai-was-supposed-to-make-artists-work-easier-its-doing-the-opposite
18. Kevuru, AI-assisted key art pipeline (self-reported 40% speed-up, no methodology): https://kevurugames.com/blog/inside-the-ai-assisted-pipeline-behind-the-ballbuds-kickstarter-key-art/
19. Creative Bloq, responding to AI art accusations: https://www.creativebloq.com/3d/video-game-design/how-should-game-developers-respond-to-ai-art-accusations
20. PC Guide, GameDiscoverCo poll on Steam AI disclosures: https://www.pcguide.com/news/pc-gamers-remain-skeptical-of-steams-ai-disclaimers-poll-shows-many-believe-game-devs-are-hiding-it/
21. Frontiers in Psychology 2025, AI art attribution study: https://www.frontiersin.org/articles/10.3389/fpsyg.2025.1509974/full
22. PC Gamer, Steam AI disclosure form update: https://www.pcgamer.com/software/ai/steam-updates-ai-disclosure-form-to-specify-that-its-focused-on-ai-generated-content-that-is-consumed-by-players-not-efficiency-tools-used-behind-the-scenes/
23. Jones Day on the US Copyright Office Part 2 report: https://www.jonesday.com/en/insights/2025/02/copyrightability-of-ai-outputs-us-copyright-office-analyzes-human-authorship-requirement
