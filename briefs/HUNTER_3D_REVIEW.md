# Hunter 3D quality review (build-spec, 2026-11-06)
Source: `--warden-shots` on origin/main 7907d9afe (jobq 20261106-205337-05470, all 12, GPU), idle front_34 + closeup_front, vs `briefs/art-refs/<hero>_FINAL_sheet.png` and the FIDELITY_CHECKLIST rows. Scores are my read, 1-10, calibrated down (ORCH ran 5-15 pts under self-scores). Pass 2 (build, same jobq shots: turnaround_close, poses_game, back/side) added back/side views and the ext/imagegen KIT.md diffs (section 'Pass 2' below). Still not covered: dark scene, match-zoom x4, VFX, Pip/Sable/Grimble/Kael back and side views. Grimble = dredge, Lisette = Hem (archer).

| Hunter | Score |
|---|---|
| Pip | 8.5 |
| Ostra | 8 |
| Claire | 7.5 |
| Cinder | 7.5 |
| Hem | 6.5 |
| Tarek | 6.5 |
| Ryzz | 6.5 |
| Vex | 6.5 |
| Sable | 6.5 |
| Grimble | 6.5 |
| Breaker | 6 |
| Kael | 4.5 |

## Fix lists (ranked)
**Kael 4.5**: 1. Hair is black/white noise, not the flowing white hair; make solid white. 2. Face is fully hidden by a flat red mask; the art shows the scarf over the mouth only, with the scarred glowing eye visible and burn-hole glows. 3. Red kilt on the model; checklist says NO kilt: dark trousers + silver greaves. 4. Scarf has no long streaming tails. 5. Gold collar and belt read as bling; art has a plain leather belt and a bare chest with a strap and one pauldron. 6. Sword is a fat white slab: make it thinner, straight and jagged, hot core.
**Breaker 6**: 1. The default shot frames only a torso: check the whole body reads (stubby legs, arms, hammer chained to the wrist are not visible in front_34). 2. Hull body is good; the helmet dome is too pale and the porthole rim too thin vs the art's bronze ring. 3. Anglerfish should hang on a line from a mast, not beside the head. 4. Cyan glow seams across the hull are missing.
**Vex 6.5**: 1. Gatling arm/weapon is a thin brass horn launcher; the art's shoulder-mounted gatling + launcher is bulky, and a human right arm is still implied. 2. Pale blotchy torso skin, art has even tan with green circuit lines. 3. Face too sharp/narrow vs the art's rounder cheek. 4. Braid is thin.
**Sable 6.5**: 1. Moth antennae are flat white sheets; make slender feathery ones. 2. Skin should be grey-lilac with darker lilac eyes; she reads near-white. 3. No white braid in front/3/4 shots, and the moth-wing tails are not visible. 4. Pistols too thin and short; the runes and crystals need to be bigger. 5. Eyes closed in the close-up.
**Grimble 6.5**: 1. Stitched-shut left socket reads as a blank grey skull; add stitches and a toothy grin. 2. Hoard is too tidy and tall; bells/lanterns are fine, coins spill needed. 3. Grey skin is flat and lacks stitches. 4. Blunderbuss on the hip is good, hook arm too thin.
**Hem 7**: 1. Bow is white/silver and lacks the glowing red thread string; the arrows are not fletched. 2. Scarf is a short cape; make it long. 3. Mask stitching and the lipstick red need to pop. 4. Spool quiver is good: keep it.
**Ryzz 7**: 1. Hands hold no pink sparks in idle; the copper fingertips are not showing. 2. The rods are thick gold bars on the back; the art has thin copper rods with arcs. 3. The pigtails are heavy and spiky, whereas the art has curly loops. 4. No wires down the arms.
**Tarek 7**: 1. Left arm: huge stone arm is okay but near-white; make it grey-tan with orange cracks. 2. Eye-stones: only one shows an orange eye; the others are blank white. 3. Dreadlocks are broken black shards with no copper beads. 4. Blindfold is fine; the sash is OK.
**Cinder 7.5**: 1. Fire tank not visible from front (check back view). 2. Hair is a flat orange sheet; add flame tongue shapes. 3. Skin is plain grey; add more magma cracks. 4. Flamethrower and hose are good.
**Claire 7.5**: 1. Eyes closed/glasses-like lid line in close-up; the art has big glowing blue eyes. 2. Hood ears okay; ram horns thinner than the art. 3. Spear needs the candy-cane stripe and a heart tip. 4. Skates good; add a frost trail.
**Ostra 8**: 1. Face is a black void with a white grin but no starry sparkle. 2. Spring box is plausible, the art has more void-smoke. 3. Cards could be burning.
**Pip 8.5**: 1. Constellation markings faint; brighten. 2. Lantern needs a star glow. 3. Tail fluff is smaller than the art.

## Cross-cutting
- Fix first: Kael, Breaker framing, Sable and Vex colour/skin.
- Faces: several close-ups (Claire, Sable) show eyes closed in idle; a shared eye/blink default is worth checking.
- Re-shoot with `--arena-demo=pose_clear` for match zoom before scoring again.

## Pass 2 (build, 2026-11-06): back/side views and kit diffs
**Canon conflict (owner decides, one line):** the 3D models match `briefs/art-refs/*_FINAL_sheet.png` (main) for Breaker (barrel hull + porthole), Claire (hood, ram horns, light-blue wings) and Ostra (jack-in-the-box, black starry face). The ext/imagegen kits say otherwise: Breaker r3 = sea-ogre (1.5x, bald, three icy braids, hammer on right shoulder, no anglerfish or lantern); Claire r2 = demoness (dark horns/wings, dark wavy hair, ice-crystal costume); Ostra r2 = white porcelain mask, no legs, crescent halo, no box. Scores above stand against the FINAL sheets; if the kits are canon, Breaker drops to about 2 and Claire/Ostra to 4-5 (new models needed, not fixes). Breaker item 3 (anglerfish) is FINAL-sheet only: the kit says no lantern.
Kits agree with the model on Pip, Sable, Tarek, Vex, Cinder, Hem, Ryzz as listed below.
- **Ryzz 7 -> 6.5:** back view shows 4-5 copper rods fanned out plus a round copper ring. Kit: exactly 3, the middle one scorched and bent (relic); no ring. Fix first. One coil tie per pigtail base only.
- **Hem 7 -> 6.5:** (kit) head has a black ponytail; kit has a sleek bun pierced with silver needles. Bow is white/silver; kit is a black recurve with a glowing red thread string and spool. Body is a black bodysuit with red lines; kit is a crimson high-collar coat, open over a black corset, plus tape measure, shears, needle bandolier. Face covering reads as a red scarf; kit is a cracked porcelain half-mask with red stitches. The long red tail is the asymmetric coat tail: keep, but attach it to a coat. Quiver on back is good.
- **Vex 6.5:** back view confirms a bulky launcher/backpack on the right shoulder with hoses (ok), but the right forearm must END in the six-barrel rotary gun with no hand; check the gold forearm piece. Green seams on the legs are good. Add the green braids' copper wire and bolts.
- **Tarek 7 -> 6.5:** (kit) both arms are huge white-grey stone gauntlets, shoulder to fist; kit is a lean runner with bracers on the forearms only and open hands. Shirtless with tiger-stripe tattoos; kit has an open slate vest, harness with pitons and a chalk pouch. Terracotta sash and wrapped feet are good. Stones orbit correctly.
- **Cinder 7.5:** back view shows the copper tank and hose, tail with fin and magma spots: the earlier "tank not visible" note is resolved (tank is there, good). Kit wants a thin translucent fin-crest with a glowing orange edge instead of the long flame-hair sheet, goggles cracked on the crest (goggles present), a flame in the lance chamber, glowing skull vials on the bandolier.
- **Breaker (framing):** the default turnaround shows the hull from the front; poses_game shows a top-down tub with the hammer as a flat pole. The hammer is not a capstan wheel chained to the wrist. Fix with the FINAL sheet: capstan wheel head with spike, chain to the wrist.
- **Claire (back):** bow and wings read well, tail has no heart tip. Spear has the candy stripe (the earlier "needs stripe" note was wrong); it still needs a heart tip.
- **Ostra (back):** spring box reads well from all sides, cards orbit; no crescent halo or starfield anywhere (kit and FINAL sheet both show the starry void body).
