# The character creator (the Empty)

Owner, 11-11: "more distinctions between male/female, more clothing options (naked with just a body outline and the
void thing ... then they can put on outfits), way more customization". The brief (11-11): the base body is a
featureless void silhouette with an outline, non-anatomical; stronger M/F frames; layered outfits where every slot can
be empty. Lore and names stay as in `docs/decisions/0105-the-unmasked.md` (player text says "the Empty").

The creator itself is the LookLocker (`scripts/ui/look_locker.gd`, opened by `hatch.gd`); this work extends it.

## What is in

| Part | Where |
|---|---|
| Look data, migration, pick rows | `scripts/match/unmasked.gd` (`Unmasked.clean` is the migration, it runs at every load) |
| Body frame: 10 sliders, per-sex ranges, stance | `scripts/match/empty_frame.gd`, `content/rules/empty_creator.json` |
| Earned clothes: pieces by slot, unlocks, worn set | `scripts/match/wardrobe.gd`, `content/rules/wardrobe.json` |
| The void body: skin-side parts in one void material with an ink line | `scripts/match/empty_void.gd`, `shaders/void_body.gdshader` |
| No cloak (the bare body shows) | `Shrouds.NONE` (`look["shroud"] = -1`): a new Empty's look |
| UI | the LookLocker's Body tab (Sex, Body tint, Outline colour, the ten sliders) and Wardrobe tab (a row per slot, then the cloth colour, trim colour, hood and trim); the farm menu's **Wardrobe** opens it on that tab |
| Check | `--empty-creator-check`, `--wardrobe-check`; shots `--empty-shots --only=wardrobe` |

**Frame.** Sex picks the frame; ten sliders (Height, Build, Shoulders, Hips, Head size, Waist, Chest, Arms, Leg
length, Muscle tone; `look["frame"]`, each 0..1) move within that sex's range (`frame` in the rules). The five added
on 11-27 are 1.0 at neutral, so an older body keeps its shape; arm thickness is set on the arm meshes (HunterAnim
sets the arm joints' whole transform, so a scale on the joint never showed). Shoulder and hip ranges do not overlap between the sexes, so a
woman always has narrower shoulders and wider hips than any man; she is shorter on average; each keeps their own
stance and idle (`warden_stance.json` "empty_f" / "empty_m").

**Wardrobe (owner 11-27: "more body customization but no clothing ... earn clothing from playing").** A new Empty
starts bare: the void body with its ink line. Clothes are pieces in six slots (head, top, bottom, feet, back,
accessory), each earned once and kept (`Save.d["wardrobe"]["owned"]`); what you wear is `look["wear"]` {slot: id}.
Feeding your Boki and playing with a toy on the first day give a tunic and trousers (a few minutes in); then
expeditions made it out of, account stats (chests, Boki brought home, monsters, knocks, revives, air hits, rings,
staggers), clan projects (`guild_perks`), garden zones open, and Hunter mastery (Vex's long scarf, Kael's neck
scarf). A newly earned piece goes on in an empty slot and a toast says so on the farm. Cosmetic only. Top, bottom
and feet are the body's own torso, arm and leg shapes in cloth (they fit every slider); a hood is a Shroud hood; back
pieces are the ten Shroud cuts, accessories the Shroud accessories plus two scarves. Room for sold sets: a new earn
kind in `Wardrobe.earned`.

**Saves.** No version bump: `Unmasked.clean` runs at every load. The wardrobe migrates on its own field
(`Wardrobe.migrate`, from `Unmasked.migrate`): a save with no `wardrobe` owns and wears the cloak and accessory it
had, owns what it has already earned without putting it on, and keeps the rest of its look. An old Short / Average / Tall height and
Slight / Average / Sturdy build become the nearest slider values; the old keys are dropped. Looks are not sent over
`Net` (remote players show a random look), so the wire is unchanged.

## Not done yet
- Gloves as a slot; per-piece dyes (top, bottom and feet pieces have one colour each, the cloak takes the cloth
  colour); sold sets.
- Remote players still show a random look (looks are not sent over `Net`).
- Starter presets, Undo, a die on each row.
