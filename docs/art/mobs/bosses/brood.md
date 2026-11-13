# The Brood Mother: design card + turnaround prompt

Format: `../TURNAROUND_SPEC.md` with the boss changes in `README.md`. Lair: The Thornhive. Egg: Hivara (a honeybee with a mantis's folded blades and a crown of wax).

## Design card
- **Role:** lair boss, the "kill the adds, dodge the acid" fight. 1350 HP, slow (2.3), 18 per hit, staggerable. Spits fans of acid, lobs acid that leaves burning puddles, lays egg sacs that hatch into adds, burrows and bursts up under you; a brood of adds on each phase change.
- **Telegraph:** before spitting it rears its front up and the throat pouch under its jaws swells and glows **#B6FF6A** (fan lanes and lob circles in #B6FF6A); egg sacs it lays are gold #E0B040 with a #FFE680 circle; the burrow exit is a #FF4A3A circle. Stagger: purple ring #C47AFF + stars.
- **Silhouette idea:** "Hive Queen". A low, wide, armoured mantis-wasp queen. Front: a narrow armoured thorax and a wedge head with folded mantis scythe forearms tucked under the chin. Behind it rises its signature: a **huge swollen abdomen that is a living honeycomb**, built of big hexagonal wax cells, a few cells glowing gold with eggs inside. Four long jointed walking legs splay out wide and low around it; with the two folded scythe forearms that makes six limbs, as on an insect (six legs plus forearms read as a spider in the first pass). A crown of five short hexagonal wax spires on the head. Reads as "queen of a nest, and the nest is her body" from any angle.
- **Shape keywords:** splayed, swollen, crowned.
- **Size:** 1.7 H tall at the top of the abdomen, 3.5 H long, legs spanning about 4 H wide (boss). Re-measure before modelling.
- **Palette** (all fixed):

| Swatch | Hex | Use | Fixed? |
|---|---|---|---|
| shell | #3F4A22 | olive armour plates of head, thorax and legs | fixed |
| dark | #22281A | joints, underside, lower legs, gaps between wax cells | fixed |
| wax | #E0B040 | the honeycomb abdomen cells and the wax crown | fixed |
| bone | #E8DCC0 | the scythe blades, 5 thorns along the thorax ridge | fixed |
| egg glow | #FFE680 | 5 glowing egg cells in the honeycomb | fixed |
| telegraph | #B6FF6A | the throat pouch under the jaws | fixed |

Eyes #FFE25A (fixed) as on every hostile: six small eyes in two rows of three.
- **Materials:** matte chitin, matte wax (the glowing cells are flat glow colour with a paler core, no halo), bone blades with no highlight.
- **Keep from the current boss:** dark olive armour, a swollen amber sac with glowing eggs at the back, six long jointed legs, a thorn ridge, a crown on the head, a cluster of six eyes, the name.
- **Weak now:** reads as a spider (round body, splayed legs, a sac like a spider's abdomen); the eyes are orange, not the hostile yellow; the sac is a smooth ball with dots; nothing ties it to its egg (Hivara).
- **Must not:** a spider (no eight legs, no spinnerets, no web, no round spider body), a realistic bee or wasp, a stinger aimed forward, see-through wings on the back, slime or gore, an alien queen from any film, anything held.
- **Modelling note:** hexapod rig; the throat pouch (spit), the abdomen (egg lay, pulses in game) and the forearms (burrow/strike) are the moving parts. The honeycomb cells stay big (about 20 across the visible side) so they survive the Meshy bake.

## Prompt card
**Run:** Nano Banana Pro, new generation, 16:9, 4K, 3 runs. Attach: image 1 = `briefs/boki-art/style_refs/boki_style_ref_2d.png` only (regen 2, 11-10: the layout ref bled a ghost of its person into two first-pass sheets, so it is dropped; the layout is in SHEET). Regen 3: regen 2 fixed the spider read but stood the abdomen straight up like a balloon on stilt legs with every cell glowing, so the abdomen tilt, bent legs and the five glowing cells are spelled out; a dark band along the bottom is ruled out in the prompt.

**Prompt:**
```
Use image 1 only for the line and flat colouring; do not copy the creatures. Exactly four views of this one creature in one row and nothing else on the sheet: no person, no extra small views, no second row.
<SHEET><MOB_RENDER><MOB_LINE><BOSS_RULES>
The creature: a huge, low, wide insect queen, half mantis and half wasp, much longer than it is tall. Its whole body is held low and level, never upright: at the front, a narrow armoured thorax held horizontal and a wedge-shaped head, carried lower than the top of the abdomen, with short mandibles, six small glowing yellow eyes in two rows of three, a small rounded throat pouch under the jaws, and a crown of five short hexagonal wax spires on top of the head. Two big mantis scythe forearms are folded under its chin, blades tucked in. Five short pale thorns run along the ridge of the thorax. Behind it, its huge, swollen abdomen, long and egg-shaped like a wasp's, tilts back and up at about 45 degrees, its tip higher than the head but never standing straight up, never a round ball; the abdomen is a living honeycomb: big hexagonal wax cells, about twenty across the side, and only five of them glow warm gold with an egg inside; all the other cells are flat matte wax, not glowing. Four jointed walking legs splay out wide and low around the body, knees bent, the belly close to the ground, feet planted; in the side view it is clearly longer than tall; with the two scythe forearms it has six limbs in total, like an insect.
Its face: creepy and regal, calm, mandibles closed.
Palette: dark olive armour plates, very dark green-black joints, underside and lower legs, warm golden wax honeycomb and crown, pale bone scythe blades and thorns, glowing pale gold egg cells, glowing warm yellow eyes. Only the throat pouch is acid lime green.
Matte chitin and matte wax, no shine. Not a spider: only four walking legs, no web, no spinnerets, no round spider body. No wings, no stinger, no slime. Plain flat light background across the whole sheet, no dark band or strip along the bottom.
```
**Steps:** as in `../skitter.md`; scale column at 1.7 H.

**Checks:** spec section 8, plus: six limbs in total (four walking legs + two folded forearms), never eight · the body is low and level, the head below the top of the abdomen · the abdomen is honeycomb (hex cells readable at 40 px) and is the biggest shape · scythe forearms folded, visible in front, 3/4 and side · the wax crown has five spires · only the throat pouch is lime · a fresh-eyes reviewer says "insect queen" or "hive", not "spider".
