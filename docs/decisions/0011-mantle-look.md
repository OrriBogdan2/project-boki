# 0011: The Mantle look (80% the Warden, 20% you) and the character creator

- **Status:** proposed (OWNER_REVIEW item 45, owner 07:31 UTC; item 44 for the lore)
- **Date:** 2026-11-03
- **Area:** save / UI / hunter models

## Problem
A player's saved look (folk, gender, Slim/Average/Sturdy body, face, colours, outfit) dressed every Hunter, so in a match nobody looked like the class's original Warden. The owner's rule: in a match a Bearer looks like the Warden (gender, silhouette, gear, signature colours), nudged by the player's own build and features; at home, with no Mantle on, the player is their own person. The creator moves to continuous sliders with a Randomise, and the look's save format changes.

## Options
1. Keep discrete picks and swap gender/folk per class: no "nudge", no continuous variety.
2. A separate "mantle look" saved per class: more data, the same person typed in 12 times.
3. One saved person (normalised sliders and picks) and one pure function that maps it onto any Warden within clamped ranges (chosen).

## Decision
- **Save (v7 -> v8).** `Save.d["look"]` keeps its picks (folk, gender, expression, skin, hair style and colour, markings, outfit, glider), gains `eyes` and `sliders` (11 values in 0..1, 0.5 neutral, saved to a 0.001 step), and drops `body`. The migration (`PlayerLook.migrate`) keeps every pick and starts every slider neutral, so an existing player's Bearer is exactly the Warden until they open the creator. A save with no look still loads (the plain Warden).
- **Mapping.** `MantleLook.apply(warden_base, player_look) -> params` is pure. Each slider moves its factor by at most the Warden's clamp (`content/rules/mantle_look.json` "sliders", per-Warden `clamp` overrides; body sizes 8-14%, face shape 5%). Colours tint the Warden's palette in HSV (`pull`, then at most `hue`/`sat`/`val`), so signature colours stay; a Warden can lock one (`dredge` skin). Gender, folk, expression, hair style and markings come from the Warden. `MantleLook.own()` is the player at home: their own picks and colours, sliders at 1.8x the range, no Warden gear, the medium class size.
- **Models.** `Models.hunter` takes the params (a few lines: build, shoulders, head and face factors, leg length, height on the root scale, colours). `HunterAnim` reads the torso's hip height from the model. The concept-pass models will read the same params; only `wardens` data and the model side change.
- **Hitboxes** are untouched: `Hunter.r` comes from `Arch.hit_r`, and the ring under the feet is compensated for every size factor.
- **Creator** (`CreatorPanel`): its own step in the new-game flow right after the Boki naming card (the name stays on that card), and the farm menu's "Change your look". Tabs Body / Face / Colours, face presets, Randomise, and a See: Yourself / In a Mantle switch.
- **Net:** none. Remote players were already built from a random look, not their saved one; they now show as their Warden with a random 20%. Showing other players' own nudges needs the 11 sliders and 4 colour picks in the join kit (about 15 bytes) and a `Net.VERSION` bump: not done, for the owner to decide.

## Consequences
- New: `scripts/core/player_look.gd`, `scripts/match/mantle_look.gd`, `scripts/ui/creator_panel.gd`, `content/rules/mantle_look.json`, `tools/mantle_look_check.gd` (`--mantle-look-check`, in `CheckRegistry`).
- Changed: `save.gd` (v8), `models.gd` (wiring; the old look helpers moved to `PlayerLook`), `hunter_anim.gd` (hip height), `hatch.gd` (the old discrete creator replaced by the step), home/interior/town call sites (`MantleLook.at_home`), bot looks (`PlayerLook.random`).
- Every Hunter now wears its class colour (the Warden's palette) instead of the player's outfit. Warden genders follow item 39 (`robot` builds on the male body). Once ext/class-titles lands, gender lives in the archetype JSON as well; `--mantle-look-check` fails if the two disagree (DEBT: keep one home).
- No voice pitch slider: the hunters have no voice lines yet.

## At the art integ (ext/art-integ, Nov 4)
Main had moved on before this landed: the saved look is now the Unmasked (`scripts/match/unmasked.gd`, its own creator in the new-game flow and Change your look), and a match builds the Warden from `Unmasked.mask_look()`. So the merge keeps main's save and creator and takes the Mantle look's model side only:
- **Save:** no new step. The v8 -> v9 slot that was kept for this stays an empty placeholder (`PlayerLook.migrate` is not run: it would drop the old `body` pick before `Unmasked.migrate` reads it). Sliders are not saved yet, so in a match every slider is neutral and a Bearer is exactly the Warden.
- **Models.hunter:** a non-Unmasked look goes through `MantleLook.params` (the Warden's likeness, the 3D model's sliders via `WardenGlb.dress`); an Unmasked look is `MantleLook.own` of `Unmasked.legacy` with the Unmasked build and colour, on main's Unmasked body and face.
- **CreatorPanel** (the slider creator) is not in any flow; `--mantle-look-check` checks it on its own. Wiring it into the Unmasked creator (and saving the sliders, with a new save step) is for the mask-look rules.
