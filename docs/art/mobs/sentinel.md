# Sentinel: design card + turnaround prompt

Renders: `renders/sentinel_views.png`, `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md`.

**Weakest mob now (2 of 2):** a stone tower that looks the same from every side. No facing, so a player cannot tell where its volley line will go before the ground rect appears, and it reads as a prop (a chess rook) rather than a creature.

## Design card
- **Role:** stationary turret / zone denial (speed 0). Range 10, fires a volley line 10 x 1.1, staggerable. Guards camp entrances and makes you approach from an angle.
- **Telegraph:** the crystal eye turns to face its target, the three shard fins fan out and glow, ground rect 10 x 1.1 in **#6AD8FF**, then a volley. Stagger: purple ring #C47AFF + stars; fins droop.
- **Silhouette idea:** a **living rune-obelisk**: a tapering four-sided stone column on three root-claw feet, **leaning forward** toward its aim, with **one big crystal eye** set in its front face and **three shard fins** on its back that fan out like a crest. Front and back now look different and the lean shows where it aims.
- **Shape keywords:** vertical, faceted, aimed.
- **Size:** 0.85 H (standard).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #5AB0C8 | rune grooves (cool) on the column | regional |
| stone | #6E6A66 | the column | fixed |
| dark | #23272E | root-claw feet, eye socket, base | regional |
| moss | #5F8A45 | moss cap on the top and the north face | fixed |
| crystal | #8FE6FF | eye and three shard fins | fixed |
| telegraph | #6AD8FF | fins and eye in charge (not painted brighter on the sheet) | fixed |

The eye is the one hostile exception to yellow: it is a crystal, so its **core** is #FFE25A inside the cyan crystal (keeps the "hostile = yellow" read).
- **Materials:** cut stone (matte), moss (matte), crystal (1 hard highlight per crystal part, max 3), grooves flat.
- **Keep:** stone + moss + cyan runes, the crystal, it never moves, the tall shape.
- **Weak now:** rotationally symmetric (no facing read); reads as a building or a chess piece; orbiting shards are tiny and vanish at match zoom; the crystal is held in claws (prop-like).
- **Must not:** a chess rook, a lighthouse, a castle tower with crenellations, a robot, a floating eye.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/sentinel_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt:**
```
Use image 1 only for the materials (stone, moss, cyan runes, crystal); redesign the body as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a living stone obelisk monster that stays in one place and shoots. A tall four-sided stone column, wide at the bottom and tapering to a blunt point, leaning forward noticeably as if aiming. It stands on three short thick dark root-claws that grip the ground. In the upper front face, one big faceted pale cyan crystal eye with a glowing yellow core, set in a dark socket under a heavy stone ledge. On its back, three long flat cyan crystal shards stick out in a fan like a crest, pointing up and back. Simple cyan rune grooves run down the front and sides in straight lines. A cap of moss on the top and down one side.
Its face: creepy, the single crystal eye staring forward, no mouth.
Palette: warm grey stone, very dark blue-grey root-claws, base and eye socket, mossy green cap, cyan rune grooves, pale cyan crystals with a glowing warm yellow core in the eye.
Matte stone and moss; each crystal part has one hard highlight. No battlements, no windows, no floating parts, not a robot.
```
**Steps:** as in `skitter.md`; scale column at 0.85 H.

**Checks:** spec section 8, plus: front and back views clearly different · the forward lean shows in the side view · three fins visible in the side and back views · eye visible in front and 3/4 · nothing floats · fresh-eyes reviewer does not say "chess piece" or "tower".
