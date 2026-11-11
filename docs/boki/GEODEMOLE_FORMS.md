# Geodemole: two approved forms

Owner decision 2026-11-09: Geodemole has two approved versions, both kept. Intact is art `geodemole-3-art`; broken / cracked geode is `geodemole-r-3-art`. The cracked one is a second form of the same Boki, not a redo.

## Choice: a damaged state (recommended)
The cracked form shows while the Boki is **below 40% health in a match**, and **at home while it is sick** (`Care`: starved to "sick"). It goes back to intact when healed or fed. It is a look swap only: same stats, kit and Unique.
- Why: it reuses states that already exist, needs no new progression rules, and gives players a readable "it is hurt" cue. The threshold is `damaged_below` in `content/rules/boki_forms.json`.
- Alternative (not built): an evolution, with the cracked form as a later stage. It would need an evolution node, a trigger and a migration for saves, and it makes the intact art a throwaway stage. Choose it only if the owner wants a progression reward.

## Data and code
- `content/rules/boki_forms.json`: threshold, and per species `base` / `cracked` with `art` and `model`.
- `scripts/kin/kin_form.gd` (`KinForm.form_of`, `KinForm.model_of`): picks the form; a missing cracked model falls back to the base model.
- `tools/kin_form_check.gd` (`--kin-form-check`).

## Follow-ups
- No 3D model for either form is in the repo (rpc1 has no Blender or Meshy). Fill in the two `model` paths when they exist.
- Wire `KinForm.form_of` into the Boki look (match and home) once a model exists; `models.gd`, `match.gd` and `home.gd` are frozen, so call it from a focused module.
- The data key is `geodemole`. The species is not in `content/kin_v2` yet (the nearest is `glintmole`, a star-nosed mole with a split quartz geode, which may be the same Boki renamed). The owner should say which; then the key follows that id.
