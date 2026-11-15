# Spitter: design card + turnaround prompt

Renders: `renders/spitter_views.png`, `renders/match_far.png`.
Format: `TURNAROUND_SPEC.md`.

## Design card
- **Role:** ranged harasser. Slow (2.2), range 8, keeps distance and makes you dodge lines. Priority target behind fodder.
- **Telegraph:** the stalk coils back like a striking snake, the throat sac glows **#B8FF5A**, ground line 8 x 0.45 in **#FFB04A**, then one glob along the line.
- **Silhouette idea:** the only **tall and thin** mob. A teardrop pod-head on a bent, S-curved stalk rising from a squat root base with fanned leaf blades. The mouth is on the front of the pod, so where it aims is clear from any side (the pod leans toward its target).
- **Shape keywords:** teardrop, coiled, rooted.
- **Size:** 0.75 H (standard).
- **Palette:**

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| body | #4F9E6E | pod head | regional |
| dark | #1E3A2C | stalk, root base | regional |
| belly | #D8E4C0 | pod underside, lip | regional |
| leaf | #4F8A3E | 4 leaf blades | fixed |
| eyes | #FFE25A | 2 slit eyes above the mouth | fixed |
| telegraph | #B8FF5A | throat sac (charge), with ground line #FFB04A | fixed |

- **Materials:** waxy plant skin (matte), wet mouth interior (1 highlight), glowing throat sac.
- **Keep:** green pod, front maw with teeth, root base, leaf blades, spike crown (reduce to 3).
- **Weak now:** reads as a green ball at match zoom (head and body merge); mouth only visible from the front; leaves droop and add mush; no "aiming" pose.
- **Must not:** a flower-with-teeth that copies a well-known biting plant (no red head with white spots, no pipe or pot), no lips.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K. Attach: image 1 = `docs/art/mobs/renders/spitter_views.png`, image 2 = `briefs/art-refs/vex_v2/vex_v2_turnaround.jpg`, image 3 = `briefs/boki-art/style_refs/boki_style_ref_2d.png`.

**Prompt:**
```
Use image 1 only for the creature's body plan and parts; redesign it as described; ignore how it is rendered. Use image 2 only for the sheet layout and spacing; do not copy the person, her colours or her painted shading. Use image 3 only for the line and flat colouring; do not copy the creatures.
<SHEET><MOB_RENDER><MOB_LINE><MOB_RULES>
The creature: a tall, thin plant monster that spits from range. A squat, very dark green root base gripping the ground with four short thick roots, four long stiff pointed leaf blades fanning outward and upward from the base. From the base rises one thick dark stalk bent in an S-curve like a snake about to strike, leaning forward. On top, a teardrop-shaped seed pod head, round at the back and tapering to the front, with a wide mouth on its front tip showing a ring of short ivory teeth and a wet dark inside. A pale swollen throat sac under the mouth. Two narrow glowing yellow slit eyes above the mouth under a heavy ridge. Three short spikes on the back of the pod.
Its face: creepy, narrow slit eyes, mouth open in a round ring.
Palette: mid jade-green pod, very dark green stalk and roots, pale cream-green pod underside and throat sac, darker leaf green blades, warm ivory teeth, glowing warm yellow eyes.
Waxy matte plant skin; only the inside of the mouth has one wet highlight. No flower petals, no spots, no pot, no lips.
```
**Steps:** as in `skitter.md` (gate check, `specs_mobs.py`, 3 runs, post step with scale at 0.75 H, owner review).

**Checks:** spec section 8, plus: clearly taller than wide · stalk is S-curved, pod leans forward · mouth visible in front, 3/4 and side · leaves stiff and pointed, not drooping · throat sac pale (charge colour is not painted on the sheet).
