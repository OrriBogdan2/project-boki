# The character creator (the Empty)

Owner, 11-11: "more distinctions between male/female, more clothing options (naked with just a body outline and the
void thing ... then they can put on outfits), way more customization". Briefs rule (DECISIONS, 11-11): the base body
is a featureless void silhouette with an outline, non-anatomical; stronger M/F frames; layered outfits where every
slot can be empty. Lore and names stay as in docs/decisions/0016-the-unmasked.md (player text says "the Empty").

## How it is built

| Part | Where |
|---|---|
| Look data, migration, pick rows | `scripts/match/unmasked.gd` (`Unmasked.clean` is the migration; it runs at every load) |
| Body frame: 5 sliders, per-sex ranges, stance | `scripts/match/empty_frame.gd`, `content/rules/empty_creator.json` "frame" |
| The void body, outfit slots, colours | `scripts/match/empty_wear.gd`, `content/rules/empty_creator.json` "slots" |
| Drawing the items | `scripts/match/empty_wear_kit.gd` (shells fitted by `scripts/match/empty_fit.gd`) |
| Cloak and accessory | the existing `Shrouds` cuts and `ShroudExtras` (a Scarf added) |
| Void body shader | `shaders/void_body.gdshader` (stars fixed to the screen, lit edge) + `outline.gdshader` ink line |
| UI | `scripts/ui/creator_panel.gd` (in the new-game step and Change your look, `scripts/ui/hatch.gd`) |
| Check | `--empty-creator-check` (`tools/empty_creator_check.gd`) |

**Base body.** Every skin-side part of the hunter rig (torso, hips, limbs, neck, hands, feet) is drawn in the void
material: a deep fill with drifting stars seen "through" the body, a soft rim and a clean outline in the outline
colour. The hunter's boot soles, cuffs and knee pads are removed, so the bare body is a smooth mannequin. The head
stays the existing void head (`void_face.gdshader`) with its hollow. A new save starts bare: nothing worn.

**Frame.** Sex picks the frame; five sliders (Height, Build, Shoulders, Hips, Head size) move within that sex's range
(`frame` in the rules). Shoulder and hip ranges do not overlap between the sexes, so a woman always has narrower
shoulders and wider hips than any man; she is shorter on average; her arms and legs are slimmer; each keeps their
own stance and idle (`warden_stance.json` "empty_f" / "empty_m"). The ranges are clamped, so no slider leaves the
shapes the outfits are fitted to.

**Outfits as layers.** Top, Bottom, Shoes, Gloves, Headwear (`look["wear"]`: `[item, colour, colour, colour]`), Cloak
(the 10 shroud cuts) and Accessory (6). Every slot can be empty. Clothes are shells drawn over the reach of what is
already on the body (EmptyFit samples the body's own meshes after the sliders, then each layer as it goes on:
bottom, top, shoes, gloves, headwear), so they fit every slider setting by construction. Each item takes 2 or 3
colours from one 18-colour palette (`Unmasked.COLOURS`, append only).

**Creator options.** Body tab: name, sex, the five sliders, body (void) tint, outline colour, Start from (4 presets).
Outfit tab: one row per slot (press the name to open its colours, the arrows step through None and every item);
the open slot's colour slots show below on the palette (and Hood / Trim for a cloak). Face tab: hair style and
colour, eyes (the hollow's shape), eye glow, face marks (the ghost features), aura. Footer: Undo, Randomize, Looks
good. Gamepad: d-pad / stick moves focus, A presses, left / right moves a slider, LB / RB change tab, X undoes, Y
randomizes, the right stick turns the turntable (A / D and mouse drag too). Focus stays on the same control when the
panel redraws.

**Saves.** No version bump (as 0016): `Unmasked.clean` runs at every load. Old Short / Average / Tall and Slight /
Average / Sturdy become the nearest slider values; an old shroud becomes the cloak layer with its colours, trim and
accessory, and the new layers start empty, so an existing player looks as before. Saves are per slot file, so per
profile.

## Done
- Bare void body with outline; stronger M/F frame; clamped sliders; stance per sex.
- 7 slots, all can be empty: Top 7, Bottom 6, Shoes 6, Gloves 6, Headwear 6, Cloak 10, Accessory 6; 2-3 colour
  slots each, one palette picker.
- Body tint, outline colour, hair (13 styles + none) and colour, eyes, eye glow, face marks, aura, 4 presets,
  Randomize, Undo; mouse and gamepad; turntable preview.
- Migration of old looks; `--empty-creator-check`: save/load round trip per slot, old-save migration, every slot
  empty and every item alone, no clipping at the shape corners, the M/F frame, the panel.

## Checks and media
- `--empty-creator-check`: save/load round trip per slot, old-save migration (twice), every slot empty and every item
  alone, no shape corner (2 sexes x 8 slider corners x 7 outfits) clips through an outfit (3 mm), triangle budget,
  the M/F frame, the panel. `--unmasked-check` (the older Empty check) now reads the frame sliders.
- Clip and sheet: `--gameplay-media --media-clip=9` (void body, Female / Male frames, then dressing up) and
  `--media-clip=10` (six example Empties). Made on rpc4: `/home/boki/meshy/char-creator-1111.mp4` (1280x720, 26 s) and
  `/home/boki/meshy/char-creator-1111-sheet.png`.
- Fit notes from the clipping sweep: boots and sandal straps are thin (a thick shell folds in at the ankle crease),
  the hood and helm are fitted to the void head (the Hunter's own hood and helm poke through it), a glove's thumb
  is grown whole, hand wraps cover palm and thumb under two bands.

## Missing / not done
- **Voice:** the Empty has no voice lines anywhere yet, so there is no voice pick.
- **Clipping in motion:** the check covers the rest pose. Skirts hang from the "Skirt" pivot (it sways), not the
  cloth bones, so a long stride can push a knee through a long skirt. Hands at the sides can touch a wide skirt.
- **Cloak over tops:** the shroud cuts were drawn for the bare frame; a cut over a bulky top (Hoodie) may touch it
  at the shoulders. The check does not measure the cloak layer.
- **Others' looks online:** remote players still show a random look (no `Net` change was made); sending the frame,
  wear and colours needs a join-kit field and a `Net.VERSION` bump (owner call, as in 0011).
- **Materials budget:** a fully dressed Empty in many different colours can use more than the Hunters' 8 materials
  (one per distinct colour); fine for the farm and the creator, worth a vertex-colour pass if many Empties share a
  screen.
- The accessory's accent is shared with the cloak's accent (one look key).

## Art gaps (for generated or Meshy art later)
Everything here is procedural from existing kits (HeroKit shells, HeroGear hood/helm/brim, HeroHair, Shrouds). Gaps:
- Hand-made garment meshes with real seams, folds and fastenings (jackets with collars and buttons, layered skirts,
  laced boots) in place of the fitted shells.
- Patterned cloth (checks, stripes, embroidery) as textures; today every colour slot is a flat painted colour.
- Headwear with character: a witch-style hat, a crown or circlet with gems, ear muffs, a mask-shaped visor that reads
  as "a Relic waiting".
- Gloves with real fingers (the rig has mitten hands).
- Back items that are not cloaks: wings of light, a pack, a quiver; a tail ornament.
- Icons for each item in the Outfit tab (now text names).
