# Relic art order (2D first), for the art session after the Boki run
Source spec: docs/art/relics/RELIC_ART_SPEC.md on origin/ext/relic-art-adds (copied below with current names). Owner order 2026-11-09: start only after the Boki batch is finished.

## What to make per relic
- One 2D relic sheet: the object alone, 3/4 view big, plus a front and side view and a close-up of the worn detail. Transparent or flat neutral grey background. No text, logos, hands or characters.
- Then one 512x512 transparent 3/4 icon crop.
- Grade it like the Boki batches (bar 8/10). Post one ART line per relic in briefs/EXT_TO_MAIN.md: `ART relic <hero_id> <file> grade X/10`.
- Save to briefs/art-refs/relics/<hero_id>_sheet.png and <hero_id>_icon.png on ext/agent-briefs. The coordinator then runs Meshy image-to-3D from the sheet (props under 1.5k tris, pivot bottom centre, ~0.35 m).

## Hero references (for palette and motif only; never put the hero in the image)
briefs/art-refs/<file>_FINAL_sheet.png (and <file>_v2/): Vex=vex, Albert (Mossy)=mossy_v2/, Neve=claire, Kael=kael, Cinder=cinder, Tenzo=tarek, Sparkle=ryzz, Grimble=grimble, Meeko=pip, Sable=sable, Lace=ravel_v2/ (and hem_FINAL_sheet.png), Motley=ostra (and motley_v2/).

## Shared spec
- **Per relic:** one 3D pickup prop (GLB, under 1.5k tris, one 512 px albedo, no rig) and one 2D icon (PNG 512x512, transparent, 3/4 view, soft rim light). The 2D can be a render of the 3D.
- **Scale:** the prop is about 0.35 m across and sits at origin on its base. The pivot is the bottom centre.
- **Look:** chunky toy-like shapes matching the heroes; worn, dug-up surfaces (grime, chips, faint cracks); one saturated hero colour plus a warm gold filigree accent (the Mask/Wyrmheart motif). Each relic carries a faint porcelain-white face-glow hint at the edges (the put-on beat).
- **Glow:** emissive only where listed. No text, logos or hands in the image.
- **Files:** `assets/relics/<hero>_relic.glb`, `assets/relics/<hero>_relic.png`.
- **Status tags:** LOCKED = owner-approved. PROPOSED = table default; swap if the owner objects.

## Relics
| Hero | Relic | Status | Key shapes | Palette | Glow |
|---|---|---|---|---|---|
| Vex | her first coin | LOCKED r3 | thick worn coin on a short scratched bounty tally edge; stamped crude eye, one nick; shown mid-flip on a small dust puff base | dull brass, teal tarnish | none |
| Kael | broken chain | LOCKED | two heavy shackle cuffs joined by 4 links, last link snapped open; wall-mortar chips | dark iron, rust | none |
| Cinder | empty Wyrm's-blood vial | LOCKED r3 | stoppered glass vial, dried dark residue streaks, cracked lip; ember glowing at the bottom | smoked glass, black, red-orange | ember, bottom only |
| Meeko | glass globe: sun and raincloud | LOCKED r3 | palm-size sphere on a small wood base; tiny faced sun and a puffy raincloud inside (cloud drips a few drops) | warm yellow, soft grey-blue | sun inside |
| Tenzo | one seeing-stone | PROPOSED | smooth river-stone with a carved open eye ring, moss in the groove | slate, green | faint eye ring |
| Lace | stitched porcelain mask | PROPOSED | cracked white porcelain half-face, red thread stitching across the cracks; hollow eyes | white, red thread | none |
| Grimble | brass monocle | LOCKED | thick brass monocle, round lens, short chain, tiny loot-price tick marks engraved on the rim | brass, pale-blue lens | none |
| Neve | ice skates | PROPOSED | pair of old figure skates tied by laces, blades frosted, one lace frayed | pale ice-blue, tan leather | frost shimmer |
| Sparkle | lightning rod | PROPOSED | short fused-glass-scarred iron rod, spire-top finial, a scorch spiral where the bolt hit | iron, electric yellow | small arc on tip |
| Albert (Mossy) | ship's compass | PROPOSED | brass ship's compass, cracked glass, needle pointing to a single fixed heading, barnacle crust | brass, sea-green | none |
| Sable | moth-wing knife | LOCKED | slim dagger, blade shaped like a moth wing with dusty scale pattern; hook-cross guard | charcoal, muted lilac | none |
| Motley | jack-in-the-box | LOCKED | small painted box with crank, lid popped, spring jester head on a coil; chipped paint | faded purple, gold | none |

## Prompt list
Common suffix for every prompt: "stylized chunky game prop, hand-painted texture, worn and dug up from ruins, single object centred, transparent or flat neutral grey background, soft rim light, no text, no hands, no characters".

1. Vex: "A thick worn brass coin, crude eye stamped on its face, one nick on the rim, shown mid-flip above a small dust puff, teal tarnish."
2. Kael: "A pair of heavy rusted iron shackle cuffs joined by four chain links, the last link snapped open, flecks of wall mortar clinging."
3. Cinder: "An empty glass vial of dried dark blood with a cracked lip and a cork stopper, a single bright red-orange ember glowing at the bottom."
4. Meeko: "A small glass globe on a wooden base holding a tiny smiling sun and a puffy raincloud with a few raindrops, warm glow inside."
5. Tenzo: "A smooth slate river-stone with a carved open-eye ring, moss in the groove, faint green glow in the eye."
6. Lace: "A cracked white porcelain half-face mask, red thread stitched across the cracks, hollow eyes."
7. Grimble: "A thick brass monocle with a pale-blue lens, a short chain and tiny tick marks engraved on the rim."
8. Neve: "A pair of old figure skates tied together by laces, frosted blades, one lace frayed, pale ice-blue and tan leather."
9. Sparkle: "A short iron lightning rod from a spire top, a scorch spiral around it, a small yellow electric arc on the tip."
10. Albert (Mossy): "A brass ship's compass with cracked glass, needle fixed on one heading, barnacles crusting the case."
11. Sable: "A slim dagger whose blade is shaped like a moth wing with a dusty scale pattern, charcoal with muted lilac, hooked guard."
12. Motley: "A small faded-purple jack-in-the-box with a crank, lid open and a spring-mounted jester head popped up, chipped gold paint."

## Open notes
- Vex's table entry (gatling arm) was superseded by the round-3 coin lock; Vex's coin is "flipped to pick jobs", so the pickup spins on a loop.
- Cinder's old shard crown and Meeko's old sun are retired by the round-3 locks; Tenzo, Lace, Neve, Sparkle and Mossy stay as the table says (PROPOSED here only because they were never re-confirmed after the Nov 7 review).
- Dawn/Dusk Meeko globe variants are a later season idea: not specced.
