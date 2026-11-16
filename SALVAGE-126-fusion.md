# SALVAGE-126-fusion: the fusion-states revival dropped from PR #126

Saved on `ext/salvage-126-fusion-backup` (head 31888b32fe2 = PR #126 head before the split, everything intact).
Main reverted the same revival on 11-14 (b3b837bdf48: 39 reds in `--fusion-states-check`).

## What it was
- `scripts/match/merge_moves.gd`: per-form ultimates `mf_ult_<form>` (stormwing, tidal_shell, titan), `mf_release`, `ult_move()`, `playing()`
- `scripts/kin/merge_kit.gd`: `anim_state` shows the release; `releasing()`; `press_ult` plays the form's ult
- `scripts/match/merge_xform.gd`: `OUT_AT` meta on separate; `scripts/match/kin_net.gd`: release pose id in hunter_extra
- `scripts/arch/kits/{ashwick,juggernaut,thief,dredge}_kit.gd`: `KinMerge.active` -> `KinMerge.transforming` (a merged Hunter keeps its own attack), ashwick `repress`
- `tools/fusion_states_check.gd`, `tools/fusion_strips.gd` (+ .uid), 2 registry lines, `tools/merge_form_check.gd` (`arch` option), `tools/remote_anim_check.gd` (release rows), `docs/art/FUSION_STATES.md`, 3 DEBT.md lines

## Commits (on the backup branch)
85943f63815 (anim-fusion-states-rebased-rebased merged), 09fd494acce (fusion-states-fix merged), 3986103ebb4 (chip flinch counts), b29b2e8efb9 (registry dedupe), afc3c9676e1, 863bf9b94c7 (merge fix-ups), 31888b32fe2 (head).
Source branches: ext/anim-fusion-states-rebased (df3fa047922), ext/fusion-states-fix (098c4cf258c).

## Why it stays out
`--fusion-states-check` was red on the integrated tree: a merged Hem hit shows the form clip (hit is now the flinch layer), Gil's merged keyed moves differ (9 failures left of 36).
To revive: re-key merged hit rows against WardenFlinch, fix the Gil rows, then bring the files above back.
