# Warden art style: recipe

Status: **option A approved by the owner (2026-11-03 17:10 UTC)**, with a body direction: Wardens should look **epic** — Bjorn taller, muscular, heroic (see "Owner body direction" below). Final pick between the two epic Bjorn takes is pending.

Target: high-end MOBA hero art. Big readable shapes, a strong silhouette, rich painted materials, polished splash finish. Prompts describe that in plain words; they never name another game, studio, artist or character.

## Options tried (Bjorn, 2026-11-03)
Same model, settings, references and character text for every option; only the style line differs. Side-by-side: `style/bjorn_style_options.jpg`.

| Option | Style line (start of prompt) | Result |
|---|---|---|
| **A. Hand-painted 3D (recommended)** | Premium stylised fantasy hero key art, hand-painted 3D look: chunky readable shapes, exaggerated proportions, rich painted textures, soft rim light, polished game-studio splash quality. | Closest to the target bar. Design kept faithfully (prow-shield with curled stem, ice-cased oar, forked ringed beard, green crack). Two takes came out near-identical in finish and design, so it's the most consistent. Translates cleanly to S2's 3D models. |
| B. 2D painted | Premium 2D painted fantasy character illustration: confident digital painting with visible brushwork, bold shape design, strong value contrast, painterly edges, dramatic cool key light with warm bounce, polished game-studio splash quality. | Very close to A, slightly flatter. A good fallback. |
| C. Inked cel-shaded | Premium stylised fantasy character illustration with clean confident ink outlines and cel shading: flat colour blocks with two-tone painted shading, crisp graphic shapes, subtle painted texture inside the shapes, bright readable silhouette, polished game-studio splash quality. | Matches the concept sheets most literally but reads as a cartoon, below the target bar. |
| D. Semi-realistic | Premium semi-realistic fantasy character splash painting: grounded anatomy with slightly heroic proportions, richly rendered materials (...), cinematic lighting with cold moonlit key and soft volumetric mist, high-end game-studio splash quality. | Richest render, but it drifted off-design (the oar became a hammer) and is the hardest to keep consistent across 12 Wardens. |

## The recipe (option A)
- **Studio / model:** anthum.ai Studio, **Nano Banana 2.1** (Google). Licence check: Google's Gemini API terms say Google won't claim ownership of generated content and don't restrict commercial use; Anthum's terms (s. 8.1–8.2) defer output rights to the provider's terms. FLUX 2 (Pro/Flex/Max) is the backup: Black Forest Labs grants full commercial rights for all API images.
- **Settings:** 2K resolution, 1 image per run. Aspect: 4:5 for full-body frames; 16:9 splash; 1:1 portrait bust; 21:9 or 16:9 for turnarounds. No seed control is exposed in the studio, so `index.md` records the studio's image instead of a seed.
- **References (img2img/reference):** two crops of the Warden's approved concept sheet from `ext/concepts`: the full-body FRONT + 3/4 panel, and the PORTRAIT panel. Crops leave out the sheet's text so no lettering leaks in.
- **Prompt template:**
  1. Style line (option A, verbatim above).
  2. "Redesign the character from the reference images at full production quality, keeping his/her design exactly:"
  3. The Warden block: name, role, build and proportions, face, outfit, signature pieces, relic/weapon, attitude. Taken from `briefs/OWNER_REVIEW_1103.md` (items 18, 37, 39, 41) and the concept sheet's notes.
  4. Shot: framing, view, pose, background (plain gradient for frames and turnarounds; their world for splashes).
  5. "Palette: <the concept sheet's swatches in words>."
  6. "No text, no logos."
- **Negative prompt:** none (Nano Banana takes no negative field). Unwanted things go in the positive prompt as short "no ..." clauses.
- **Owner body direction (17:10 UTC):** the first option-A Bjorn felt too short. The concept sheets' squat, small-head proportions are a guide for the design, not the body. In the Warden block, ask for the body you want explicitly and say it overrides the reference: e.g. "keeping his outfit, face, shield and weapon design exactly, but make his body much taller, more muscular and more epic than the reference ... a true giant about eight heads tall. Heroic proportions: long powerful legs, massive shoulders, a deep powerful chest, thick muscular arms ...". Without the explicit override and head-count, the reference pulls the figure back to short legs. Apply the same idea per Warden to their own build (item 37: distinct heights and builds; Moosh Moosh stays small and cute).
- **Name each signature prop's shape plainly** ("clearly an oar with a long shaft and a flat paddle blade"), or the model drifts toward a generic weapon (the ice oar became a hammer when only "oar encased in ice, used as a maul" was given).
- **Give scale as hard relations, not adjectives.** "Much bigger shield" did nothing; what worked was "its top edge is higher than the top of his head, the curled stem post rises another full head-height above that, its bottom edge rests on the ground, and it is about twice as wide as his torso, big enough to hide his entire body."
- **Don't feed a generated image back as a reference to change it.** Nano Banana copies it almost pixel for pixel (two runs with the previous take as a third reference came back with the same small shield). For a change, use only the concept-sheet crops and put the approved changes in the text.
- **Owner picks on Bjorn (17:20 UTC):** sleeveless coat (bare muscular arms) and a much, much bigger prow-shield. Current approved frame: `style/bjorn_optA_epic_bigshield.png`.
- **Owner direction (17:25 UTC): not too many regular humans.** Wardens should feel interesting: give each human-based Warden a clear non-human or otherworldly twist (e.g. part stone, storm-touched, frost-sprite, half-giant, part machine, undead hint) that reads at a glance. Propose each Warden's twist to the owner before generating their set; keep the item 39 originality guard.
- **Style anchor (owner, 2026-11-03: all art styles must match).** Every Warden prompt attaches the approved Bjorn frame `style/bjorn_optA_epic_bigshield.png` as a third reference, after the two concept crops, with the line "Match the art style, rendering finish, brushwork, shading and colour handling of the third reference image exactly; it shows a different character, so use it for art style only and copy nothing else from it (no shield, oar, beard, fur, or frost)." Without it the first Zedran splash drifted to a flatter 2D-cartoon look. This is not the "reuse a generated image to change it" case: Bjorn is a different character, used only for finish.
- **Count and side anything that must stay consistent.** Nano Banana duplicates features freely (four horns, two demon faces on one blade, both eyes glowing). Say "exactly two horns", "exactly one eye and one mouth on the blade", "only the right eye glows". For turnarounds, tie asymmetric details to each other, not to left/right ("the possessed arm is the SAME arm that holds the cleaver"), because the model flips sides between views. For a portrait of a Warden with one-sided details, crop tight with "no hands in frame" so a held weapon can't drag the detail to the wrong side.
- **Turnaround recipe:** 21:9, "front, side, back, same scale, one ground line, neutral A-pose, flat even studio light, plain light grey background, no text or labels"; hang big weapons point-down beside the leg so they don't hide the body, and ask for them in every view.
- **Not generic (owner):** every Warden gets something specific in body, attitude and story that reads at a glance (Zedran: very dark skin, scars worn like trophies, a showman's ego, a demon in the sword spreading lava cracks up his sword arm).
- **Originality checks per image:** reject anything that resembles an existing character (owner's list in item 39 and Bjorn's mood-reference note in item 41).

## Open questions for the owner
1. Approve the big-shield Bjorn (`style/bjorn_bigshield_revision.jpg`) as his look for the splash/portrait/turnaround.
2. For the files we keep, download the full-resolution 2K originals from the studio into this branch? The previews committed now are captures from the studio's viewer (772x959).
3. Anthum's terms (s. 10.4, 8A) give Anthum a licence to show uploads and outputs as platform examples and to train its internal systems on Platform activity. That covers the concept sheets we upload as references and the art we generate. OK for unreleased game art?
