# 0016: The Unmasked (the player's own character)

- **Status:** accepted (heroes in a match wait for the owner's warden-models / mask-look sign-off)
- **Date:** 2026-11-04
- **Area:** save / farm / UI

## Problem
The creator (race, face, details, skin, hair rows) makes a detailed person, but the owner's story says you are
a smooth, near-faceless person and masks fill you in (briefs/DECISIONS.md, "Player character: the Unmasked").

## Options
1. A new Meshy model: needs a rig that HunterAnim can drive, and the art pass is not ready.
2. The existing hunter rig with no hunter gear, no hair, no ears and no nose: every animation already works.

## Choice
Option 2. `Unmasked` (scripts/match/unmasked.gd) holds the look and builds the extras; `Models.hunter` takes
a look with `"unmasked": true` (a few lines of wiring). Look keys: gender (Female / Male), height (scale
0.9 / 1.0 / 1.1), build (body width and bulk), hollow (the face socket's shape), glow (its colour), ghost (faint
outlines of the missing features), motes, outfit (5), colour (1 of 12), marks (kept mask features, empty for now).
Farm, town and house wear `Unmasked.worn()`; a match, hero cards and portraits wear `Unmasked.mask_look()`
(a plain Warden until mask-look lands). Walk style is not built.

## Save
No version bump: `Save.load_game` runs `Unmasked.migrate` (idempotent), turning an old look into the closest
Unmasked (gender, build, height from race size, eyes from face, colour from skin). `Unmasked.clean` also covers
anything read later, so odd old data never crashes.

## Affects
Models.hunter, the creator (hatch.gd), Gliders (keeps look["glider"]), every caller that passed Save.d["look"].
Old race/hair/detail code stays for bots' looks and the galleries until warden-models decides.

## Update: the Empty (owner, Nov 4)
The lore names you **the Empty**: the Wyrm took everyone's essence, so the face is an absence, not a blank. The
face marks (eyes, brows, blush) are replaced by a hollow: a shell of the head drawn by `shaders/void_face.gdshader`
(a socket with a glowing rim, a starfield seen with parallax, ghost features floating in it), a small glowing void
on the chest where the heart is, and motes round the head. A woman's body is drawn into an hourglass with a
flared tunic, narrower shoulders and her own stance (warden_stance.json "empty_f"); a man's is broad and square
("empty_m"). Height scales the whole model (the hit ring keeps its size). Old face-marks looks migrate in
`Unmasked.clean` (eyes -> hollow, brows -> ghost, blush -> a rose glow). The first Mask is no longer a pick
before the egg: after you name your Boki, Vex's Mask drifts to you and you put it on (`MaskMoment`, staged by
`MaskBeat`: build-up, the Mask rising, black and silence, memory frames of the fallen Hunter, the snap back
with the name and title; content/rules/mask_moment.json). The second Mask comes from Hob on the farm after
the first expedition (`HobTalk`, `HobOffer`: a pick of Kael, Pip or Cinder in conversation, then a short
Mask moment).

## Update: the shroud, the void head, the aura, the soles (owner, Nov 4, items 77-81)
- The whole head is the void (`void_face.gdshader`: a dim starfield all round with a lit edge); the hollow's socket
  and ghost features float on it. The heart on the chest is gone: the body is wrapped in a **shroud** (collar,
  mantle, drape to the ankles, a cowl), in three styles (Cloak, Wrap, Tatters), and head, neck and hands are the
  void colour: no skin shows, so there is no skin colour. `look["colour"]` is now the **shroud colour** (an old
  skin colour keeps its slot index), `look["shroud"]` the style (from the old outfit), `look["aura"]` (from the
  old motes). `Unmasked.clean` migrates all three; old saves load.
- **Aura** (None / Faint / Strong, tooltip "Glowing specks that drift around you"): big bright specks that swirl
  round the head, shoulders and shroud.
- **Soles**: `FootPlant.reach` gives HunterAnim the real lowest boot point so the hips drop or lift until the sole
  meets the ground, standing and walking, at every height, build and sex (`--unmasked-check` asserts 2 cm).
- Prologue captions wrap inside 86% of the width and grow upward from the bottom, never off screen.
