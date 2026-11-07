# Vex v2 redesign (owner-approved 2026-11-06)

| File | Model | Settings | Notes |
|---|---|---|---|
| vex_v2_master_sheet.jpg | Nano Banana Pro (no seed exposed) | 16:9, 4K | Final master sheet: front (cocky crossed-leg pose, coin flip), side, back, 3 expression heads, minigun detail. |

Design (locked):
- Tall, elongated figure: long legs, narrow waist, full bust, curved hips.
- Face: green hair with bangs and one braid (cartridge beads), goggles, prominent freckles, wine-plum lips, sly smirk.
- Eyes: both amber-gold. The mechanical eye is marked by the brass wire to the temple; no glow.
- Arms: right forearm is a brass six-barrel minigun (stickers, charm, bullet keychain); left arm is slender brass/steel, flipping a gold coin.
- Outfit: lime cropped jacket off one shoulder (patches, hazard stripe), narrow black bandeau with a brass ammo strap, choker with a gold coin, tally-mark tattoos on her bare shoulder, charcoal cargo trousers (green tally marks, splatters), gold coin hip chain, combat boots.
- No hip strap, no glowing skin lines, no name text.

Prompt chain (Nano Banana Pro; 2K for exploration, 4K for finals):
1. Directions A/B/C were rejected (too grounded); restarted from the v1 sheet.
2. Minigun-arm exploration, then a merge, then the cargo outfit.
3. Eye edit (mechanical eye), then the necklace (bullet → coin choker).
4. Expression and face-shape tests; kept the original face.
5. Master sheet; then figure variations (B picked).
6. Proportions failed with the full-sheet reference. Fixed by generating from head and minigun crops only (tall figure + outfit details).
7. New master sheet; edits for the eye colour, tattoo, strap and top.
8. A 4K pass, the strap/tattoo edit and a gold robot-eye edit.
9. Local pass (Python/PIL): tally tattoos redrawn, neutral white balance, magenta desaturated.
10. A clean 4K redraw from that sheet (narrower top, non-glowing eye, wine-plum lips). Run 2 was kept.

Rejected:
- Underboob tops.
- A glowing eye, and a green-ring eye (edits rendered it as fire or as alien black-rimmed eyes).
- A hip underwear strap.

## Update (Nov 6, 15:46 ET): composited final sheet
`vex_v2_master_sheet.jpg` was replaced. Base: redraw run 2, with three views regenerated as single figures (Nano Banana Pro, 3:4, 4K) and pasted in locally (scaled to the old figure's height, background-matched):
- Front: a fuller bust in the original bandeau with the ammo strap (edit on the front crop).
- Side: a moderately fuller bust to match the front (edit on the side crop, text-only bust description; using the front as a second reference made it copy the front pose).
- Back: the jacket slipped off the bare-shoulder side, showing the tally tattoos (fresh single-figure gen).

Local pass: neutral white balance; low-saturation magenta reduced 45%.

Rejected tops: the V-ring bandeau, the twist-knot, and the sweetheart cups (the owner preferred the original bandeau).

## Turnaround: FINAL (Nov 6, 15:51 ET)
`vex_v2_turnaround.jpg`: 3D-modelling reference (front, 3/4, side, back), approved by the owner.
- Model: Nano Banana Pro, 16:9, 4K. Single reference: the master sheet.
- The prompt asked for a colour-painted 3D model (not grey clay), a true A-pose and the minigun in every view.
- First attempt rejected: grey-blue skin, arms down, no minigun in the back view (that attempt also used Kael's turnaround as a style reference).

## Portrait and splash: FINAL (Nov 6, 16:02 ET)
All Nano Banana Pro. References: the master sheet plus the smirk close-up only. Kael's images were dropped as style refs because they made her static.

- `vex_v2_portrait.jpg` ("Over the Shoulder", 1:1, 4K). She looks back over her bare freckled shoulder with tally tattoos, a sly smirk and the minigun on her shoulder, under a warm rim light. Matches the framing of the other heroes' portraits.
- `vex_v2_splash.jpg` ("Power Slide", 16:9, 4K). A rooftop power-slide while firing, laughing, with a coin flip. The generation came out mirrored (minigun on the left arm); the whole image was flipped locally, so all details are consistent.

Alternates kept for marketing/loading screens:
- `vex_v2_alt_tavern.jpg` (tavern bounty portrait). Known issue: two mechanical hands plus a detached minigun, and garbled poster text. Needs an arm-fix edit before use.
- `vex_v2_alt_joyride.jpg` (mine-cart splash).

Rejected:
- Static rooftop splash and portrait (accurate but no personality).
- Coin-bite portrait (owner: not sly or hot enough).
- Bubblegum, kiss-for-luck (off-model / held gun).
- Freefall splash.
- **Portrait updated (05:08 ET):** `vex_v2_portrait.jpg` = barrels to camera + robotic V-sign (natural green eye + glowing cyber-eye, gun reads as her right arm). Alts: firing, reloading in explorations/.
- **Portrait FINAL (05:18 ET):** `vex_v2_portrait.jpg` = the belly laugh, wiping a tear (owner pick). Pout and embarrassed moved to emotes/.

## Weapon sheet (owner, Nov 7, 15:38 ET)
`vex_v2_weapon_sheet.jpg` is the current minigun prop sheet and replaces the old `vex_weapons.png`. It shows the brass and gold six-barrel rotary gun with sticker badges (a green ghost face, a purple flame), the looping brass shell belt and the chain with a bullet charm, in four views, three close-ups and a scale silhouette. Nano Banana Pro, new generation, 16:9, 4K. Refs: the minigun close-up from the master sheet and the splash.

Full 4096px original of the belly-laugh portrait swapped in (15:58 ET).
