# Stormcoil, the Sky Serpent: design card + turnaround prompt

Format: `../TURNAROUND_SPEC.md` with the boss changes in `README.md`. Lair: Stormcrown Eyrie. Egg: Zephyrak (a moray eel's body with a swift's swept wings, crackling with static).

## Design card
- **Role:** lair boss, the "keep moving" fight. 1250 HP, fast (5.2), 22 per hit, staggerable. Circles you and lunges along a telegraphed line, calls lightning on marked circles, coils up and discharges (r 4.8); a lightning storm on each phase change.
- **Telegraph:** before a lunge it draws its head back into an S and the three crest fins on its skull crackle **#7FE8FF** (lane telegraph in #7FE8FF); before the discharge the same fins and the static lines along its back light. Lightning circles #BFF4FF. Stagger: purple ring #C47AFF + stars.
- **Silhouette idea:** "Eel of the storm". A long, legless, flying eel-serpent. A moray's head: long, heavy-jawed, a deep closed mouth line, a low ridge over the eyes; three tall jagged crest fins along the top of the skull; a pair of long, narrow, scythe-shaped swift's wings sweeping back from the neck. The body is one long smooth tube that tapers to a thin tail with a forked fin. Neutral pose on the sheet: the body rests in a loose upright S-coil, the lowest loop on the ground line, the head raised at the top, wings half open. Reads as "fast and electric" from any angle.
- **Shape keywords:** coiled, swept, crackling.
- **Size:** about 2.2 H tall coiled, about 7 H long stretched (boss). Re-measure before modelling.
- **Palette** (all fixed):

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #2F6F9A | storm-blue back and sides | fixed |
| dark | #1D3E5C | the back stripe, wing leading edges, tail fork, jaw line | fixed |
| belly | #D6F4FF | pale belly band and lower jaw | fixed |
| wing | #BFE8FF | the wing membranes and the tail fin | fixed |
| lair glow | #9FF4FF | thin zigzag static lines along the back (6 short marks), the crest fin edges | fixed |
| telegraph | #7FE8FF | the three crest fins on the skull | fixed |

Eyes #FFE25A (fixed) as on every hostile.
- **Materials:** smooth matte eel skin, thin matte wing membranes (flat, not see-through on the sheet), glow parts flat with a paler core, no halo, no sparks drawn around it.
- **Keep from the current boss:** storm-blue coils with a pale belly, the glowing crest fins, swept swift's wings just behind the head, the forked tail fin, the name.
- **Weak now:** eyes glow cyan, not the hostile yellow; the body is a chain of separate balls; whisker horns and glow rings make it busy; reads as a generic sky dragon.
- **Must not:** legs, arms or claws, horns, whiskers or a beard, a mane, feathers, scales drawn one by one, a four-legged winged dragon (that is the villain's family), anything crimson or gold, rings or bands around the body, a fish with fins only.
- **Modelling note:** in game the head is the body node and 16 coil segments follow its path (`BossModels.serpent`). The modeller cuts the sheet into the head with wings, one coil segment (repeated, scaled down along the tail) and the tail fin; the sheet must show the body as one continuous even tube so a segment can be taken from it.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K, 3 runs. Attach: image 1 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 2 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt:**
```
Use image 1 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 2 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><BOSS_RULES>
The creature: a huge, legless flying storm serpent with the head of a moray eel. Its body is one long, smooth, even tube that tapers to a thin tail ending in a forked fin; it rests in a loose upright S-coil with the lowest loop touching the ground and the head raised high at the top of the coil, looking ahead. The head is long and heavy-jawed like a moray eel's, mouth closed, with a low ridge over two small glowing yellow eyes and three tall, jagged crest fins standing along the top of the skull. Just behind the head, a pair of long, narrow, scythe-shaped wings like a swift's sweep back from the neck, half open. A dark stripe runs along the whole back, with a few short pale zigzag lines of static along it; the belly is a pale band from the lower jaw to the tail.
Its face: creepy and alert, cold, mouth shut in a long hard line.
Palette: deep storm-blue back and sides, very dark navy back stripe, wing edges, jaw line and tail fork, pale icy belly and lower jaw, pale sky-blue wing membranes and tail fin, bright pale cyan crest fins and static lines, glowing warm yellow eyes.
Smooth matte skin, no scales drawn, no shine. No legs, no arms, no claws, no horns, no whiskers, no mane, no feathers, no rings around the body, not a dragon.
```
**Steps:** as in `../skitter.md`; scale column at 2.2 H (coiled height).

**Checks:** spec section 8, plus: no legs or arms in any view · the coil touches the ground line once and the head is the highest point · wings attach at the neck, not mid-body · crest fins visible in front, 3/4 and side · the body tube has an even, unbroken outline (a segment can be cut from it) · eyes are yellow, not cyan · a fresh-eyes reviewer says "eel" or "serpent", not "dragon".
