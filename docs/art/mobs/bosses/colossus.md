# The Stone Colossus: design card + turnaround prompt

Format: `../TURNAROUND_SPEC.md` with the boss changes in `README.md`. Lair: The Sunken Forge. Egg: Cairnback (a tortoise with ibex horns and a rune cairn on its shell).

## Design card
- **Role:** lair boss, the "stand your ground" fight. 1500 HP, slow (2.5), slam 26, slam ring r 3.8, staggerable. Slams send shockwave rings you jump; thrown boulders; ground fissures from phase 2; rockfall on each phase change.
- **Telegraph:** rears up on its hind legs, the cracks in both forefeet glow **#FF4A3A** (ground circle r 3.8 in #FF4A3A), then drops them: the shockwave rings go out in amber. Boulder throw: a horn toss flings a stone off the cairn on its back (target circle #FF6A3A). Stagger: purple ring #C47AFF + stars.
- **Silhouette idea:** "Cairn Titan". A colossal four-legged stone beast: a huge low **dome** of shell built like a stepped cairn of flat stacked stones, on four short **pillar** legs; a thick neck and a heavy blocky head carried low and forward; two enormous ridged horns that sweep back and down along the sides of the dome like an ibex's. At the top of the cairn a dark vent with a molten amber glow (the forge of its lair) breathes out. Reads as "a walking hill that will crush you" from any angle.
- **Shape keywords:** domed, pillared, horned.
- **Size:** 2.5 H tall at the top of the cairn, 3.5 H long (boss). Current model is 4.3 m tall; re-measure before modelling.
- **Palette** (lairs are not repainted per region, so every swatch is fixed):

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| stone | #9C968A | cairn stones of the shell, head top | fixed |
| dark | #3A3632 | legs, underside, face, neck skin | fixed |
| moss | #6F9A4A | moss caps on the top stones and the brow | fixed |
| horn | #E6D9B8 | the two horns, 4 short toe claws per foot | fixed |
| lair glow | #FFB04A | the vent at the top of the cairn, 3 rune lines on the shell front | fixed |
| telegraph | #FF4A3A | crack lines in the forefeet | fixed |

Eyes #FFE25A (fixed) as on every hostile.
- **Materials:** matte rough stone (no highlight), thick dry hide, bone horn; the vent and runes are flat glow colour with a paler core, no halo.
- **Keep from the current boss:** grey weathered stone, moss caps, gold-amber rune glow, the rune ring at its feet in game (an effect, not on the sheet), the name.
- **Weak now:** a recoloured humanoid skeleton warrior with an axe; reads as a big hunter, not a boss; boulder pauldrons are small spheres; nothing ties it to its egg (Cairnback).
- **Must not:** humanoid, standing upright, arms, a held weapon or axe, armour plates, a crown or ring of standing stones (the Watcher's), spikes on the shell, a realistic tortoise, a turtle with a spiked shell from any franchise, a golem made only of loose rocks (it is a beast whose shell is a cairn).
- **Modelling note:** quadruped rig (not Meshy's humanoid rig); the forefeet and horns are the attack parts. The current clips (2H chop, spellcast throw) become rear-and-stomp and horn-toss in the boss animation job.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K, 3 runs. Attach: image 1 = `briefs/boki-art/style_refs/boki_style_ref_2d.png` only (regen 2, 11-10: the layout ref bled a ghost of its person into two first-pass sheets, so it is dropped; the layout is in SHEET). Regen 3: "ibex" still came back as ram curls in all three regen-2 runs, so the horns are described as one shallow backward arc along the dome; a dark band along the bottom (from the finish ref) is ruled out in the prompt.

**Prompt:**
```
Use image 1 only for the line and flat colouring; do not copy the creatures. Exactly four views of this one creature in one row and nothing else on the sheet: no person, no extra small views, no second row.
<SHEET><MOB_RENDER><MOB_LINE><BOSS_RULES>
The creature: a colossal, ancient four-legged stone beast, much longer than it is tall; in the side view it is clearly longer than tall. Its back is one huge low dome of shell built like a stepped cairn: big flat grey stones stacked in four rough rings, each ring smaller than the one below, with thick moss caps on the top stones. At the very top of the cairn a dark round vent glows with molten amber light from inside, and three short amber rune lines are carved into the front stones of the shell. It stands on four short, thick pillar legs of very dark hide, each foot a flat round stomp with four short ivory toe claws, and a few thin cracks across the front feet. A thick neck and a heavy, blocky, low-carried head with a deep jaw and a heavy mossy brow over two small glowing yellow eyes. Two long, thick, ridged ivory horns grow from the top of its head, rise backwards in one shallow arc and lie along the top of the dome, tips pointing backwards past the vent, like a wild goat's scimitar horns seen from the side; each horn is one gentle curve with no spiral and no curl, nothing around the ears or cheeks. A short thick tail.
Its face: tough, calm and ancient, mouth closed, looking down at you.
Palette: weathered warm grey stone, very dark grey-brown legs, neck, face and underside, mossy green caps, warm ivory horns and claws, molten amber vent and runes, glowing warm yellow eyes. Only the cracks in the front feet are a hot red.
Matte stone and hide, no shine. Not standing upright, no arms, no weapon, no armour, no spikes on the shell, not a realistic tortoise, no ram's horns. Plain flat light background across the whole sheet, no dark band or strip along the bottom.
```
**Steps:** as in `../skitter.md`; scale column at 2.5 H (the hunter figure is small next to it).

**Checks:** spec section 8, plus: four pillar legs on the ground in every view · the dome is the biggest shape and is clearly a stacked cairn, not a smooth shell · horns sweep back along the dome (side view) · the vent glows at the top and is visible in 3/4, side and back · only the forefoot cracks are red · no humanoid read in the front view.
