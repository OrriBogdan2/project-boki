# Boki design rules (owner + art direction, Nov 8)
This is the bar every Boki has to clear. It works alongside the judging rubric in BOKI_50_DESIGNS.md (hook, mix, silhouette, personality, buildability, originality).

## What makes a Boki (and not generic AI creature art)
1. **One idea, fused into the body.** A real animal plus one object or element, where the object becomes a body part: Lockatara's padlock shackle and key tail, Chuggamus's boiler belly. It is never worn, carried or strapped on (mount saddles are the only gear).
2. **Shadow test.** Recognisable as a solid black silhouette, and different from every other Boki's silhouette.
3. **Two main colours and one accent.** Generic AI creatures have every colour plus glowing filigree. Restraint is the signature.
4. **A face with its own personality.** Each species gets its own eye shape and expression (grumpy, smug, sleepy, anxious, fierce). No default big-eyed chibi face on everything.
5. **Born with a weapon.** The edge comes from teeth, claws, spikes, or real weapons (sword, axe, spear, mace) grown out of the body. Never held, never strapped on.
6. **Clearly an animal.** No clothes, no standing or posing like a person, nothing held in its hands. The heroes are the humanoids.
7. **The element shows at a glance.** Every Boki has a theme in the game data, and the art must show it (table below).
8. **The archetype sets the shape language** (table below). The roster needs a spread, not 50 round creatures with things on their backs.
9. **The design explains the ability.** Soakybara's pool heals, Zippelith's seam lets it tunnel, Chuggamus's cowcatcher rams.
10. **Buildable and readable in game.** Models are about 5k triangles, seen from a distance. Use chunky parts and no thin floating bits (ropes, wires, ribbons, lace).
11. **One render style.** Soft hand-painted shading with a thin clean outline, matching style_refs (the website's Vespyx and Mycroll). No thick cartoon outlines or flat cel shading.
13. **The idea runs through the whole body (owner, Nov 8).** If the object shows up in one place, its material and shapes must repeat everywhere else: the same bone, metal or stone in the claws, spine, tail and face. A design should never read as one thing tied to another. Example: Umbrathere's umbrella ribs are its arm and finger bones, not a canopy bolted to its back.
12. **Things to avoid:** more than one idea, a realistic animal with a prop on it, backpack syndrome (an object sat on its back with no change to the animal), accessories, particles and glow everywhere, and any franchise name in a prompt.

## Elements: how each theme must read
| Theme | Visual signature |
|---|---|
| ember | glowing orange-red ember cracks, a few rising sparks |
| frost | pale ice-blue crystal growths, frosted tips |
| storm | crackling yellow sparks, zig-zag lightning markings |
| bloom | living leaves, petals or moss growing from the body, fresh green |
| spore | mushrooms, soft drifting spore puffs, teal glow |
| venom | toxic green markings, glossy venom on fangs or stingers |
| stone | rough rock plates, crystal or marble surfaces |
| shadow | inky black edges fading into smoke, violet glow |
| prism | glass, mirror or crystal facets throwing rainbow glints |
| lunar | pale silver crescent-moon markings, soft moonlight glow |
| echo | sound-wave rings and ridges, bell, horn or pipe shapes |
| gravity | heavy dark iron, small pebbles orbiting it, deep indigo |
| swarm | honeycomb patterns, many small repeated parts or tiny companions, amber gold |
| titan | huge heavy armour plates engraved with ancient gold runes |
| tempest | wind-swept streamers, swirl markings, sky blue and white |

## Archetypes: shape language
| Archetype | Shapes |
|---|---|
| cute | round soft shapes, big head, short limbs |
| sleek / cool | long tapering lines, pointed shapes, narrow eyes |
| pretty / elegant | graceful curves, long flowing parts, delicate patterns (still buildable) |
| fast | lean body leaning forward, swept-back shapes |
| tough | blocky, wide, heavy, low stance, small eyes |
| creepy / weird | odd proportions, unsettling calm |
| majestic | big, upright, crown-like features, calm power |

**Roster target (50):** about 10 cute, 8 sleek, 6 pretty, 6 fast, 8 tough, 6 creepy, 6 majestic.

## Audit of the 29 new designs
- **Elements:** Batch 1 mostly reads its theme already (Chuggamus ember, Lockatara titan, Umbrathere shadow, Mirrolin prism, Mycroll spore). From now on it is written into every prompt.
- **Archetype gaps:** sleek/cool (only Skateron) and pretty (Bubblisk, Snuffapi). Heavy/round/tough and back-mounted designs are overrepresented: about 10 of 29 have the object on their back. Batch 3 (Kindlewren, Zephyrak, Lunowl, Selenfin, Vespyx) helps sleek and pretty. Any future redesign slot should go to sleek, pretty or fast.

## Evolutions and uniqueness (owner question, Nov 8, 15:15 ET): not in this art pass
Already in the game:
- Evolution paths by affinity. Shared nodes fierce, curious, steadfast and swift unlock at level 4 and shift stats; their cosmetic is generic, e.g. fierce adds "horns" and a red tint. Paths are picked per Boki and tied to its personality, with evolved names ("Cind" + "fang").
- Personality weights per species: bravery, loyalty, temper, curiosity.
- Mutations: patches, glow marks, twin tail, crystals, stars, and the rare "shimmer".
- A unique id and lineage per Boki, plus the hunter Fusion form.

Art implication if the owner wants evolution trees that look different: the current turnarounds are the **base form**. Each affinity branch then exaggerates the same design along its own axis, so it stays one model with grown or swapped parts:
- **Fierce:** bigger born-with weapon, teeth and spikes.
- **Steadfast:** more armour, a bigger fused object.
- **Swift:** leaner, longer limbs, swept shapes.
- **Curious:** more element signature, like glow and growths.

Mutations, defects and personality marks layer on top per individual (scars, a chipped horn, an oversized part, odd colours), which gives near-endless variety cheaply. True cross-species transformations (Digimon-style "becomes a different creature") each need a new model, so keep them for rare or legendary paths. This needs an owner decision and a spec with main before any art.
