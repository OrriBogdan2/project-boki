# Character customizer (spec only: building waits for the owner's OK)

Priority: "a better character customizer". Branch ext/customizer-spec. No code changes.

## 1. The rule (owner: DECISIONS "Identity and Masks")
- **Farm and town: you are yourself, the Empty**, fully customisable.
- **Match: the Mask makes you 90-100% the Hunter.** Close-ups (hero card, loadout, victory) 60-70%.
- Layers: **Locked** (the Hunter's silhouette, gear, weapon, signature colours: never yours),
  **Personal** (the small part of you that survives the Mask), **Cosmetic** (unlockable extras on top).
- Note: the DECISIONS text itself is not in this repo; the numbers above come from the owner's brief. If the
  owner's text differs, it wins.

## 2. What exists today
| Piece | File | State |
|---|---|---|
| The look (the Empty) | `scripts/match/unmasked.gd` (321 lines) | keys gender, height, build, shroud, colour, hollow, glow, ghost, aura, marks, features, glider |
| Creator UI | `scripts/ui/look_locker.gd` (587), `look_set.gd`, `look_thumbs.gd`; opened by `hatch.gd` stage "create" and Settings > Change your look (`--creator`) | tabs Body / Hollow / Shroud / Glider; turntable, hover-try, thumbnails, one **Random** button |
| Slider creator | `scripts/ui/creator_panel.gd` (219) | 11 sliders, presets, Random; **in no flow** (decision 0011); `--mantle-look-check` only |
| Mapping onto a Hunter | `scripts/match/mantle_look.gd` + `content/rules/mantle_look.json` | pure `apply(base, look)`, per-Hunter clamps and locks |
| Match look | `Unmasked.mask_look()` returns the old detailed look (a plain Warden); `Unmasked.blend()` mixes in `SHOW = 0.1` colour, height and build | this is the Personal layer today: 10%, colour + proportions only |
| Save | `Save.d["look"]`, `Save.VERSION` 21, `Unmasked.migrate` runs on load (idempotent) | old looks map to the closest Empty |
| Net | remote players are built from a random look, not their saved one | `Net.VERSION` 0.24.18 |

Gaps against a modern creator:
- **No presets** (only a full Random): nothing to start from.
- **No undo/redo and no revert**: a Random click or a mis-click loses the look.
- **No saved slots**: one look only.
- **Few body controls**: 2 sexes, 3 heights, 3 builds. No sliders (the slider panel is unused).
- **No colour freedom**: 12 shroud swatches, 6 glows; no per-part colour (trim, hood, hands).
- **Hair is absent by lore** (the Empty has none). "Hair" players ask for becomes Cosmetic headwear/hollow styles, see 5.
- **Randomise** ignores locks; cannot reroll one tab only.
- **The Personal layer is almost invisible** in a match (10% colour tint), and bears no marks or glow.
- **Others never see your look** online (random look).

## 3. What players expect (and our answer)
| Expectation | Answer in the Empty |
|---|---|
| Body: size, build, proportions | Height and build as continuous sliders on the Empty (keep 3 named snaps as presets); shoulder, torso, leg length within the figure's limits |
| Face | The Empty has a hollow, not a face: shape, glow, ghost marks (12), stare, with a ghost intensity slider (decision 0016 "not built yet") |
| Hair | Not in the Empty; Cosmetic "crowns" (horns, wisps, halo, hood shapes) as unlocks |
| Colours | Shroud main + trim + glow, each from a wheel or 24 swatches; recent colours; matching-set suggestions |
| Presets | 12 authored starting looks, plus "start from your Hunter's Mask" |
| Randomise | Whole look, per tab, and per row; lock icon on rows to keep; reroll history |
| Undo | Undo/redo (20 steps), Revert to opened, Reset tab |
| Save slots | 3 looks, name them, swap on the farm |
| Preview | Turntable (exists); add "see in a Mask" toggle: pick any owned Hunter and see the 90% / 65% result |
| Copy/share | Look code (short string) to paste; no network needed |

## 4. The Personal layer (what carries into a match)
Two strengths from one function (`MantleLook`, one place, no second system):
- **Match, in play: 8%** (cap 10%): shroud colour tints trim only, height and build +-8% within the Hunter's clamp,
  hollow glow shows as the Mask's eye-light and ability-glow tint. Hit ring and hitbox are never changed.
- **Close-up: 35%** (cap 40%): the same, wider, plus your ghost mark on the Mask's brow and your aura specks.
- **Locked, never carried:** silhouette, outfit cut, weapon, kit colours that identify the class (Warden can lock any
  slot, e.g. dredge skin), anything gameplay-readable. A Hunter's JSON lists which Personal keys it accepts.
- **Cosmetic layer:** unlockable items (crowns, shroud trims, glow shapes, aura types) stored as owned ids; equipped ids
  ride the look. Cosmetics change only visuals and are listed per slot.
- Sync: later, the join kit carries 6 look picks + 4 colours (~10 bytes), with a `Net.VERSION` bump (own decision note).
  Until then remote players stay at the Warden with a random 10%.

## 5. Save fields and migration
`Save.d["look"]` keeps every current key. New keys (all optional, defaults = today's behaviour):
- `sliders` (dict of floats 0..1, 0.5 neutral, step 0.001): height, build, shoulder, torso, legs, head, jaw.
- `colours` (dict: main, trim, glow as 0..11/0..23 index or `#rrggbb`).
- `cosmetics` (dict slot -> id) and `owned_cosmetics` (array of ids).
- `slots` (array of up to 3 {name, look}); `slot` (active index).
- `ghost_a` (0..1 intensity).
- Undo history is **not saved** (session only).
Migration: **Save v21 -> v22**, one step in `Save.migrate`, then `Unmasked.clean` fills missing keys: `sliders` from
the old 3-value height/build (0.5 neutral, snaps map to 0.25/0.5/0.75), `colours` from `colour`/`glow`, `cosmetics`
empty, `slots` = [current look]. Golden file for v21 added to the save-compat check (`docs/SAVES.md`).
Needs a short decision note in `docs/decisions/` first (save format is a core system).

## 6. Build list (2-hour tasks, priority order)
1. **Undo / redo / revert** in LookLocker: history stack of looks (20), Ctrl+Z / Ctrl+Y, buttons. No save change.
   Check: `--look-undo-check`. IMPACT 7/10.
2. **Randomise per tab + row locks**: extend `_random` and `Unmasked.random_look` with a key mask. Check extended.
3. **12 presets**: `content/rules/look_presets.json` (data), a Presets strip in the Body tab, hover-try already works.
4. **Save v22 migration + keys** (section 5), decision note, golden file, `--save-compat-check`.
5. **Sliders in the Empty**: wire the existing `CreatorPanel` sliders into LookLocker as a "Fine" tab (reuse, do not
   rebuild); `Unmasked.height/build` read sliders with the 3 snaps kept. Check: unmasked-check 2 cm sole rule at extremes.
6. **Colours**: main/trim/glow pickers, recent colours; shader params only; check every palette is readable on the void.
7. **Save slots** (3) and the farm swap.
8. **Personal layer v2**: `Unmasked.mask_look` -> `MantleLook` with the two strengths and per-Hunter accepted keys;
   replace `Unmasked.blend` (delete it). "See in a Mask" toggle in the locker. Check: `--mantle-look-check` limits
   (<=10% in play, <=40% close-up), hitbox unchanged.
9. **Cosmetic slots** (crowns, trims, glow shapes) and the unlock hook into existing mastery/market rewards.
10. **Look code** copy/paste; **ghost intensity** slider.
11. **Net**: join kit carries the Personal picks, `Net.VERSION` bump, remote players wear them (decision note first).

Order logic: 1-3 are save-free, quick and the most felt; 4 unlocks 5-7; 8 is what makes the customizer matter in
matches; 9-11 are polish and online.

## 7. Open questions (decided, owner may flip)
- Hair: chosen **Cosmetic crowns, not hair** (lore: the Empty has none). Alternative: hair as a Personal key.
- Personal 8% / 35%: chosen inside the owner's 90-100% / 60-70% bands (i.e. 0-10% and 30-40%).
- Slots: 3, not unlimited, to keep the save small.
