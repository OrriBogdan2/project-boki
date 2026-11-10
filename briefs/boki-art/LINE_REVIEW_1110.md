# Line review, 11-10 (art session, owner request: "review all of them, catch evolutions that look too similar or other stuff we should change")
All 235 Boki were laid out line by line (every stage side by side) and checked for: stages that look the same, stages that look unrelated, a final weaker than the stage before it, colour that breaks the family, worn or strapped parts, drips and slime, and Pokemon look-alikes.

## Fixing now (jobs queued, 4 tries each)
| Boki | Problem | Fix | Job |
|---|---|---|---|
| Forgebrock | Same badger, pose and anvil as Anvilbrock | Reared-up forge bear, twice the size, open forge chest | `on_forgebrock_big` |
| Shinobant | Green, but its final Reapant is plum-black | Dark plum armour with green leaf tips, so it bridges the two | `on_shinobant_dark` |
| Glaciatee | Smaller and cuter than Frigatee, sits on a loose ice block | Huge planted bull sea lion with long ice tusks and an iceberg ridge | `on_glaciatee_big` |
| Effigeetle (Sculptillar) | A beetle in a cocoon > moth line | Marble caterpillar with gold seams and a simple insect face | `on_effigeetle_cat` |
| Cisternmander | Blue-green; Bucketmander and Barrelmander are dark grey-brown | Family colours, keeps the cistern back | `on_cisternmander_fam` |
| Pickadactyl | Same small pterosaur and stance as Chiptero | Big planted pterosaur, huge pickaxe crest, wings half spread | `on_pickadactyl_big` |
| Sirencada | Same beetle and pose as Klaxada | Reared up, wing-cases flared like a siren horn | `on_sirencada_big` |
| Blastopuff | Olive; its baby Puffuse is charcoal with yellow cracks | Family colours | `on_blastopuff_fam` |
| Anchorbill | A crow that evolves into a sea animal | A pup of the same sea animal | `on_anchorbill` |
| Briarlynx | Thistlynx wrapped in vines | Bigger, heavier, bramble mane, thorn antlers | `on_briarlynx_big` |
Also: Glassolotl, Chandelotl and Cindermaw get straight flat-style cards (`v2c_<name>_b4`); they were waiting on a pick.

## Owner's call (not changed)
1. **Polyshroom > Starcap > Medushroom**: three unrelated bodies and palettes (glassy jelly-mushroom, white star, purple mushroom jellyfish). Suggest redrawing Starcap as Polyshroom grown up, with a star-shaped cap.
2. **Jerbolt > Dynaboa**: same body and size, only the back part changes (fur crest vs copper fins). Suggest a taller, heavier Dynaboa. Owner picked both concepts on 11-09, so left alone.
3. **Galleotter**: an otter lying in a wooden ship with oars. It breaks "born-with parts only". Owner picked this version on 11-09, so left alone.
4. **Buckleron > Bulwartoad**: same toad under a taller shell. The dex already shrinks the baby; a rounder, simpler baby would help more.
5. **Tootle > Gramofrill > Phonodrake**: tan, tan, then dark red. Works as a surprise final; flagging the colour jump only.
6. **Wickapi**: the new standing calf is plainer and more realistic than Snuffapi and Chandelapi. Could take a little more charm (bigger eyes, small flame mane).
7. **Grainspin > Sandwidow > Hourachnid**: tan, black, tan. This is the male/female line, so the colour swap is on purpose.
8. **Slime and drips** stay only on the Blight slime line (Blotlet > Slog > Sloggoth). Drips were removed from Pipewurm, Pipeworth, Quivertoad, Chainipede, Gilabacus and Cisternmander in batch 4.

## Pokemon look-alikes (by eye, not a pixel check)
- **Coolatee**: a white seal pup. Closest to Seel/Spheal. The ice crystals on its back and no horn keep it apart, but it is the nearest call on the roster.
- **Pebblamb**: a round woolly lamb. Same niche as Wooloo/Mareep; the bubble-pebble wool is its own idea.
- **Glacione (Clionice)**: a pale blue sea angel. Same real animal as Phione/Manaphy's inspiration; its ice wings and white body differ.
- **Jerbit**: small electric rodent. No yellow, no cheek marks, spring legs; fine, but it sits in Pikachu's niche.
- **Parrywhal**: no narwhal Pokemon exists; clear. **Narfoil**: a round white whale calf with a horn; clear.

## Lines that read well as they are
Vespyx, Mycroll, Zipling, Kayak, Glintmole, Skidlet, the nine Ermink branches, Kestrike, Kindlewren, Dribbara (after tonight's fix), Marchleaf > Scythant > Harvantis, Latchling, Kerchick, Kitlet, Jarmit's three branches, Bathilus, Cubbat, Lensling, Olmlet, Gravigrub, Lurklet, Morelkin, Pawnfry, Mumblet > Klaxada, Pagodito, Pinster, and the legendaries.

## Overnight decisions, 11-10 (owner asleep: "rank your own choices and try to finish for morning")
Everything below is live; old files are kept as `*_old*`, so any of it can be put back. Job ids are in `batch/out/` for looking at the alternatives.

| Boki | Made live (1st) | 2nd | 3rd | Why |
|---|---|---|---|---|
| Mossbastion | `opt_mossbastion_a_1`: water-bear carrying a little landscape | `b_1`: mossy stone-plated | `c_2`: reared up, moss cloak | Only A is clearly Mossgrade grown up (same snout, legs, fuzz). |
| Blastopuff | `opt_blastopuff_c_2`: spike burst, Puffuse's colours | `b_1`: torpedo-shaped | live olive one | Same fish and colours as the baby, new silhouette. B is striking but stops being a puffer. |
| Maracoil | kept the live card | `opt_maracoil_b_2` | none | Every option read as Rattlebub again. `a_1` drew a feathered war-bonnet: do not use. |
| Ringrove | `opt_ringrove_u1_1`: rearing, quill mane, cap tail | `u3_2`: seated guardian | `u1_2` | Its tail matches the new Sporcupine's, so the line connects. |
| Checkmare | `fix_checkmare_1` | 2, 3 (near identical) | | Clean-up the owner agreed to, beak needle removed. |
| Knotwyrm | `fix_knotwyrm_2` | `fix_knotwyrm_4` (lighter rope) | | Owner asked for contrast after the wood was removed. Its SHEET is the weakest tonight (views disagree): redo. |
| Glaciammoth | `fix_glaciammoth_2`: ice musk-ox, one blade horn | 4 | 3 (kept curled horns too) | The merge the owner asked for. |
| Pangolith portrait | `v2p_terrasloth_new_a_2`: ring lying on its side | `new_b_1`: walking in profile | | Card-as-reference kept the old pose 6 of 6; the sheet as reference worked. |
| Olm line (Water/Crystal) | `wc_olmlet_2`, `wc_glazolm_2`, `wc_kintsuwyrm_2` | Glazolm 3 (bigger fan tail) | | Fins and clear crystals, more at each stage, per the coordinator's owner order. |
| Lunowl female | `fv4_lunowl_2` | 1, 3 | | Male's palette one step lighter, silver for gold. |
| Murmuron female | `fv4_murmuron_4` | 3 | | Darkest of the four, so she stays the same dark bird with a bronze sheen. |
| Poses (22) | see CHANNEL 03:38 and `tools/../batch` ids `pose_*`, `on_*` | | | Latchling kept its old pose (the sitting ones lost its latch). |

Not done, for the owner: Parrywhal/Coolatee-type Pokemon checks are by eye only; Kestrike and Pavonazar females still use their own colour scheme (flagged, not changed); Stormit's sheet needs a manual look; the 20 re-posed Boki keep their old portraits (portrait pose differs from the card on purpose).
