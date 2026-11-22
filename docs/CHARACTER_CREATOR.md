# The character creator (the Empty)

Owner, 11-11: "more distinctions between male/female, more clothing options (naked with just a body outline and the
void thing ... then they can put on outfits), way more customization". The brief (11-11): the base body is a
featureless void silhouette with an outline, non-anatomical; stronger M/F frames; layered outfits where every slot can
be empty. Lore and names stay as in `docs/decisions/0016-the-unmasked.md` (player text says "the Empty").

The creator itself is the LookLocker (`scripts/ui/look_locker.gd`, opened by `hatch.gd`); this work extends it.

## What is in

| Part | Where |
|---|---|
| Look data, migration, pick rows | `scripts/match/unmasked.gd` (`Unmasked.clean` is the migration, it runs at every load) |
| Body frame: 5 sliders, per-sex ranges, stance | `scripts/match/empty_frame.gd`, `content/rules/empty_creator.json` |
| The void body: skin-side parts in one void material with an ink line | `scripts/match/empty_void.gd`, `shaders/void_body.gdshader` |
| No cloak (the bare body shows) | `Shrouds.NONE` (`look["shroud"] = -1`), the first Shroud tile |
| UI | the Body tab of the LookLocker: Sex, Body tint, Outline colour, the five sliders |
| Check | `--empty-creator-check` (`tools/empty_creator_check.gd`) |

**Frame.** Sex picks the frame; five sliders (Height, Build, Shoulders, Hips, Head size, `look["frame"]`, each 0..1)
move within that sex's range (`frame` in the rules). Shoulder and hip ranges do not overlap between the sexes, so a
woman always has narrower shoulders and wider hips than any man; she is shorter on average; each keeps their own
stance and idle (`warden_stance.json` "empty_f" / "empty_m").

**Saves.** No version bump: `Unmasked.clean` runs at every load. An old Short / Average / Tall height and
Slight / Average / Sturdy build become the nearest slider values; the old keys are dropped. Looks are not sent over
`Net` (remote players show a random look), so the wire is unchanged.

## Not done yet (the rest of the 11-11 brief, from `ext/char-creator-v2-1111`)
- Layered outfits: Top, Bottom, Shoes, Gloves, Headwear as slots that can be empty (a new save starts bare), their
  fitted shells and colours; hair style and colour. About 750 lines of old code (empty_wear, empty_wear_kit,
  empty_fit): its own PR.
- Starter presets, Undo, a die on each row.
