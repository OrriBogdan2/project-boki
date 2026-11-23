# Geodemole: two approved forms

Owner decision 2026-11-09: Geodemole has two approved versions, both kept. Intact is art `geodemole-3-art`; broken / cracked geode is `geodemole-r-3-art`. The cracked one is a second form of the same Boki, not a redo.

## Choice: a damaged state (recommended)
The cracked form shows while the Boki is **below 40% health in a match**, and **at home while it is sick** (`Care`: starved to "sick"). It goes back to intact when healed or fed. It is a look swap only: same stats, kit and Unique.
- Why: it reuses states that already exist, needs no new progression rules, and gives players a readable "it is hurt" cue. The threshold is `damaged_below` in `content/rules/boki_forms.json`.
- Alternative (not built): an evolution, with the cracked form as a later stage. Geodemole is already the middle stage of the Glintmole line (Glintmole > Geodemole > Druzemole, `briefs/boki-art/LINE_AUDIT.md`), so a cracked stage would squeeze a fourth stage into a three-stage line. It would also need an evolution node, a trigger and a save migration, and it makes the intact art a throwaway stage. Choose it only if the owner wants a progression reward.

## Data and code
- `content/rules/boki_forms.json`: threshold, and per species `base` / `cracked` with `art` and `model`.
- `scripts/kin/kin_form.gd` (`KinForm.form_of`, `KinForm.model_of`): picks the form; a missing cracked model falls back to the base model.
- `tools/kin_form_check.gd` (`--kin-form-check`).

## Follow-ups
- No 3D model for either form is in the repo (rpc1 has no Blender or Meshy). Fill in the two `model` paths when they exist.
- Until then the fallback is the game's own: a species without a rigged model (`BokiRig.has` false) is drawn from `KinModels` primitives, so both forms look the same and nothing breaks.
- Wire the swap when the models land: where `BokiRig.build` loads `PATH` (`scripts/match/boki_rig.gd`), load `KinForm.model_of(species, KinForm.form_of(species, hp_frac, sick))` instead, and rebuild the look when the form changes (match: health crosses `damaged_below`; home: `Care` status enters or leaves "sick"). `models.gd`, `match.gd` and `home.gd` are frozen, so only a call goes there. Not wired now: with no model the call would be dead code.
- Geodemole is not in the game yet. It is the middle stage of the Glintmole line (`BOKI_NAMES.csv` #38, after Glintmole #37), not a rename of `glintmole`. The data key `geodemole` is its line name; when the stage is added, the key follows its in-game id.
