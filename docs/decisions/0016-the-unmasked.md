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
a look with `"unmasked": true` (a few lines of wiring). Look keys: gender, height (scale), build (body width),
eyes, brows, blush, outfit (5), colour (1 of 12), marks (kept mask features, empty for now).
Farm, town and house wear `Unmasked.worn()`; a match, hero cards and portraits wear `Unmasked.mask_look()`
(a plain Warden until mask-look lands). Walk style is not built.

## Save
No version bump: `Save.load_game` runs `Unmasked.migrate` (idempotent), turning an old look into the closest
Unmasked (gender, build, height from race size, eyes from face, colour from skin). `Unmasked.clean` also covers
anything read later, so odd old data never crashes.

## Affects
Models.hunter, the creator (hatch.gd), Gliders (keeps look["glider"]), every caller that passed Save.d["look"].
Old race/hair/detail code stays for bots' looks and the galleries until warden-models decides.
