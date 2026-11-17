# Tarek v2: planned changes (not started)

Current art: `../tarek_FINAL_sheet.png`, `../tarek_turnaround_apose.png`, `../tarek_portrait.png`, `../tarek_splash.png`.

To change when his pass starts (owner, Nov 6):
- **The arms overlap with Cinder.** Both have dark rock/obsidian plates with glowing orange cracks. Cinder keeps hers (her design was hard to get through the image filter); Tarek's arms change instead. The orange-fire glow belongs to Cinder now.
- **Optional:** small stones worked into his hair.

Direction options to put to the owner (not yet chosen):
- **A. Jade runes:** matte grey stone arms with carved prayer-script runes glowing soft jade green, the floating eye stones glowing jade to match.
- **B. Crystal:** rough stone with amber or quartz crystal growing from the knuckles and forearms, no glow.
- **C. Pure earth:** no glow at all; cracks filled with dust and moss, sand trickling from the joints.

## Direction chosen: A, jade runes (Nov 6, 22:34 ET)
`explorations/tarek_v2_directions_ABC.jpg` shows the three directions: A jade runes, B amber crystal, C sandstone. The owner picked A.
- B was dropped because its amber put him back in Cinder's orange range.
- C was dropped because its tan stone was too close to his skin tone.

## Master sheet: FINAL (Nov 6, 22:45 ET)
`tarek_v2_master_sheet.jpg`, 3584×4800.

Chain (Nano Banana Pro, 3:4, 4K, no seed exposed):
1. A fresh generation (ref: direction A cropped).
2. Edit: dark, non-glowing seams; the runes became simple glyphs (main figure only took it).
3. Edit: the small front and back views matched to the main figure.
4. Hair jewellery edit, rejected: about a dozen big glowing cubes with letters.
5. Local colour fix (below), then a subtle hair edit: small matte stone beads and a jade bead near the face.
6. Local colour fix again.

Local colour pass (Python, not AI): per-channel histogram match to the first generation's palette, removing the magenta drift from the edits.

Canon:
- A plain cream blindfold (no glow).
- Three floating rough-grey eye stones with jade-teal eyes.
- A huge stone left arm onto his chest; a stone gauntlet on his right forearm.
- Matte grey stone with **dark seams that never glow**; only the carved glyphs glow (spirals, crescents, bars, dots, never letters), jade with a slight teal tint.
- Dreadlocks with copper rings, small carved grey stone beads and a jade bead near his face.
- Prayer beads, a cream waist wrap, a burnt-orange sash, dark brown trousers, wrapped bare feet.
- His molten abilities (Volcano Crusher, Molten Guard) can flare in their VFX; at rest he has no orange glow, which keeps him distinct from Cinder.

## Turnaround: FINAL (Nov 6, 22:49 ET)
`tarek_v2_turnaround.jpg`, 5504×3072: front, 3/4, side (his right side) and back, with the eye stones shown once beside the side view. Nano Banana Pro, 16:9, 4K, a fresh generation (ref: the master sheet); no edits and no colour pass needed.
- The arm sides check out in every view: the stone arm is on his left, the gauntlet on his right.
- His hair jewellery is lighter than on the master sheet: a few copper rings mixed with grey stone beads, plus the short strand with a jade bead. Treat the turnaround as the reference for the amount.

Known limits:
- He is slightly bulkier than on the master sheet; use the master sheet's leaner build.
- One or two glyphs on the gauntlet look letter-like ("F"); the modeller should use the simple set (spirals, crescents, bars, dots).

## Portrait: FINAL (Nov 6, 22:51 ET)
`tarek_v2_portrait.jpg`, 4096×4096. He listens with a half smile in a misty mountain shrine at dusk. One eye stone floats in front of him, staring at the viewer; two drift behind. His stone arm is folded across his chest, glyphs glowing; no orange light.

Nano Banana Pro, 1:1, 4K, a fresh generation (ref: the master sheet). The model drew four eye stones, so the fourth (right side) was painted out locally (OpenCV inpaint plus a soft blend, not AI). The original is `explorations/tarek_v2_portrait_4stones.jpg`.

## Portrait swapped (Nov 6, 22:55 ET)
`tarek_v2_portrait.jpg` is now the owner's own run from a slightly different prompt: no eye stone in front, three stones framing his head (canon count, no fix needed). The face is larger and higher, so it reads better at select-screen size.

The front-stone version (fourth stone painted out) moves to `explorations/tarek_v2_portrait_front_stone.jpg`.

`explorations/tarek_v2_portrait_wide.jpg` (16:9, the owner's run): a waist-up shot in a misty canyon, his right stone gauntlet across his chest and the huge stone left arm hanging, three eye stones. It is the clearest read of which arm is which, and could serve as a website or banner image.

## Splash: "Nothing Hidden" (Nov 6, 22:59 ET)
`tarek_v2_splash.jpg`, 5504×3072: four hooded assassins close in through moonlit shrine ruins. Tarek stands calm on a rock pillar bursting from the ground, one foot raised, with dust swirling and three eye stones around his head. Nano Banana Pro, 16:9, 4K, a fresh generation (refs: the turnaround and the master sheet; the owner's run).

Local fix (not AI): the two background assassins had glowing teal eyes, which clashes with Tarek's jade colour language. They were darkened to normal eyes.

`explorations/tarek_v2_splash_alt.jpg` is the second run: a squarer pose with stronger spotlight. Not chosen because all four assassins have glowing green eyes, his stone arm is washed teal, and the composition is more static.

Not achieved: the eye stones turning toward the attackers. All three face the viewer.

## Splash: FINAL, action version (Nov 6, 23:05 ET)
The owner wanted Tarek fighting back, not posing. `tarek_v2_splash.jpg` (5504×3072) shows him leaping off a rock pillar. His huge stone left fist smashes a boulder that flies at an assassin in a jade-teal burst; pillars erupt under two more assassins, throwing them into the air; flung rocks are mid-flight; he grins. Nano Banana Pro, 16:9, 4K, a fresh generation (refs: the turnaround and the master sheet; the old splash was deliberately not used as a ref, to avoid copying its standing pose). Owner's pick: his foot is clearly on the rock, and the punch reads well in 3D.

Local fix (not AI): the hit assassin's glowing teal eyes were darkened to normal eyes.

Alternates in `explorations/`:
- `tarek_v2_splash_action_pose_alt.jpg`: the second action run, which the owner likes for its pose. His back leg merges into the rock pillar, and the punch lands straight on the assassin.
- `tarek_v2_splash_standing.jpg` and `tarek_v2_splash_standing_alt.jpg`: the earlier "surrounded but calm" runs, which had no action.

## Renamed: Kibo, "the Stone Seer" (owner, Nov 7, 00:17 ET)
Tarek is renamed **Kibo** ("Kibo the Stone Seer"). Display name only; ids and files stay (`dolm`, `tarek_*`). Passed to the coordinator via the owner.

## Renamed: Tenzo, "the Stone Seer" (owner, Nov 7, 05:04 ET)
Replaces "Kibo" (clashed with Kael). Display name only; ids and files stay (`dolm`, `tarek_*`, `tarek_v2/`).
