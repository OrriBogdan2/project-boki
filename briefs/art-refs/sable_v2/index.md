# Sable v2 redesign (started Nov 6, 23:10 ET)

Owner asks:
- Swap the wing-shaped head pieces for fuzzy moth antennae.
- Some skin at the front.
- Earlier: her face is a bit too big; a cooler top.
- 3D review: skin reads near-white (make it grey-lilac); the pistols are too thin.

## Direction sheets
`explorations/sable_v2_directions_run1_ABC.jpg` and `_run2_ABC.jpg`. Nano Banana Pro, 16:9, 4K (ref: the main figure from sable_FINAL_sheet).
- A: open coat over a short corset, bare midriff.
- B: deep V to the sternum with a crossed strap harness.
- C: coat off the shoulders over a strapless corset.

In both runs the antennae did NOT change: the reference's wing shapes were copied. Fix: the wing antennae were painted out of the reference locally (`Sable_B_ref`, scratchpad), so the next generation follows the text.

## Master sheet: FINAL (Nov 6, 23:28 ET)
`sable_v2_master_sheet.jpg`, 3584×4800.

Chain (Nano Banana Pro, 3:4, 4K, no seed exposed):
1. A fresh generation from the antennae-free option B reference; antennae and harness came through.
2. Edit: diamond top (came out as a high-neck plate; rejected, too covered).
3. Edit on step 1: a plunge with a diamond clasp (gem too low).
4. Owner's re-run: a gem clasp at the collar plus three chains across the midriff.
5. Edit: the gem lowered to her sternum on a chain.
6. Edit: narrower, dusty-lilac antennae with dark stems.
7. Local colour fix.
8. Edit: two silver bell bolas on the key ring.
9. Local colour fix (per-channel histogram match to the first generation's palette).

Canon:
- Grey-lilac skin, dark lilac eyes, a beauty mark, pointed ears, one long white braid.
- Fuzzy moth antennae: dark lilac stems with dusty lilac fuzz.
- A long dark coat with violet trim and buckled sleeves, open in a deep plunge with nothing underneath.
- A stolen violet gem on a silver chain from the collar, resting at her sternum; three chains across her midriff link the coat edges.
- Moth-wing coat tails with eye spots.
- A belt with keys (one tiny bell on the ring); a sheath on each hip with throwing knives, their blades curved like a moth's wing with a violet sheen (the knife she throws and blinks to); fitted trousers; tall buckled boots.
- Twin enchanted flintlocks with violet runes.
- Owner wants the front showy; the X-harness was dropped because it repeats Kael's.

Notes for 3D:
- Fix the coat's front edges to the body (or constrain the cloth) so the plunge holds during runs, dashes and shooting.
- **One braid.** The two small views wrongly show a braid on each side; follow the large figure.
- The pistols are still slim; a weapon sheet will define them.

Update (23:32 ET): the owner rejected the bell bolas ("looks like bells, not a weapon"). The final is an edit on the keys version (step 7) adding throwing knives, then a local colour fix. The model put a sheath on each hip rather than one on the right thigh; accepted. For 3D, sheathe the blades (the sheet shows them poking out below the sheaths). The Bola ability can be VFX-only when thrown.

## Turnaround: FINAL (Nov 6, 23:35 ET)
`sable_v2_turnaround.jpg`, 5504×3072: front, 3/4, side and back in sculpt-render style, a pistol in each hand. Nano Banana Pro, 16:9, 4K, a fresh generation (ref: the master sheet). It passed the filter first try; no edits and no colour fix needed.

Checks:
- One braid, consistently over her right shoulder; use this, not the two braids in the master sheet's small views.
- The antennae, gem, midriff chains, hip knives, keys and moth-wing tails are all present.

Known limits:
- The side view shows the coat front closed (the plunge isn't visible in profile); use the front and 3/4 views.
- Her irises glow brighter violet than on the master sheet (dark lilac); the owner can pick.
- The knife blades still poke out below the sheaths.

## Splash: "The Rafters" (Nov 6, 23:41 ET)
`sable_v2_splash.jpg`, 5504×3072: she crouches on a ceiling rafter under a moonlit skylight, pistols crossed, grinning down at a smoky mob meeting (thugs, an orc and armoured bodyguards) around a card table with an open strongbox holding a glowing violet jewel. Nano Banana Pro, 16:9, 4K, a fresh generation (refs: the turnaround and the master sheet; owner's idea and run).

Local fix (not AI): garbled "Contracts" lettering on three papers was painted out.

`explorations/sable_v2_splash_alt.jpg`, the other run, was not chosen: it shows two braids, hides the gem behind her arms, and has a flatter pose.

Known limits: the small glowing creatures read as butterflies rather than moths; some bodyguards are armoured knights rather than mobsters.

Portrait: candidate A saved (`explorations/sable_v2_portrait_candidate_A.jpg`): wink, knife and moth on her antenna. A fix-up edit is pending: the hand appears fused to the knife, and the moth looks like a butterfly.

## Portrait: FINAL (Nov 6, 23:52 ET)
`sable_v2_portrait.jpg`: a sly wink, a moth-wing throwing knife raised beside her face, a fuzzy violet moth on the tip of one antenna, moonlit rooftops. Candidate A plus one edit: the knife grip redone, the butterfly turned into a plump fuzzy moth. Nano Banana Pro, 1:1, 4K.

Known limit: slight banding in the background fog.

**Sable v2 set complete:** master sheet, turnaround, portrait, splash.

## Weapon sheet (owner, Nov 7, 15:32 ET)
`sable_v2_weapon_sheet.jpg` is an edit of the old `sable_weapons.png` (Nano Banana Pro, 1:1, 4K). The four round silver flasks, leftovers from the rejected bolas, became her moth-wing throwing knives: side, top and back views, plus one in its hip sheath. Ref: a crop of the knives from the master sheet. Known leftover: the round silver egg and the four flask close-ups on the right; see any later fix.
Local fix (15:40 ET): the edit returned the sheet unchanged, so the round silver egg and the old ghost face were removed (seamless background fill), and the four flask close-ups were replaced with knife close-ups (blade tip, grip, pommel ring, sheath) cut from the same sheet.

## Splash v3 (owner, Nov 8, 01:01 ET)
`sable_v2_splash.jpg`, 5504×3072, replaces the crouching splash, which is kept as `explorations/sable_v2_splash_crouch_old.jpg`. She flies across the attic over the card table, firing one flintlock down at the gang while holding up a small stolen violet jewel. The open strongbox is empty, and the gang reacts: the orc lunges, a guard draws his sword, a man points. The foreground is softly out of focus and a moonlight beam falls on her, so she is the focus. How it was made: Nano Banana Pro. A fresh generation for the action pose, then one change prompt to put her face and her open chain-laced coat back on-model, then a local light vignette pass, then one change prompt for the depth of field and the moonlight. Finished with a local LAB colour match (0.5) and sharpening, upscaled to 4K.
- **Fix (Nov 8, 01:04 ET):** the first lock had a third leg (an extra boot hanging below her knee). One change prompt removed it, then the colour match and sharpen were redone. She now has two legs.
- **Fix 2 (Nov 8, 01:10 ET):** one change prompt (master sheet as ref) gave her the master's dark grey eyes and a plain plum coat with purple trim, with separate pale moth wings with eye-spots behind it. The owner disliked the smile on the best result, so two more runs were made; the owner picked the one with a single pair of narrow wings hanging behind the coat, as on the master sheet; the others had four wings (no compositing). Colour-matched (0.4) and sharpened. The antennae are still thinner than on the master sheet; accepted.

## Portrait fix (owner, Nov 8, 02:00 ET)
`sable_v2_portrait.jpg` now has the master sheet's dark grey-black eye (it was violet), the violet pendant at mid-chest, and loose chains across her stomach. Nano Banana Pro, one change prompt (ref: master sheet). Saved at 4096² with a light de-banding filter and sharpening. The old version is `explorations/sable_v2_portrait_violet_eye.jpg`.
- Alternate: `explorations/sable_v2_portrait_alt_both_eyes.jpg`, the same portrait with both dark eyes open (no wink). The owner prefers the wink.
