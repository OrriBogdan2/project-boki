# Shared docs: how to add to them without clashing

Six docs were in most PRs and made green PRs conflict (11-21, 57 open PRs): `docs/wiki/Rules.md` (13 PRs),
`docs/DEBT.md` (13), `docs/HUD.md` (10), `docs/AUDIO.md` (10), `docs/KIT_PARITY.md` (7), `docs/MOVEMENT_FEEL.md` (6).
Each got the form that fits it:

| Doc | Form | Why |
|---|---|---|
| `docs/DEBT.md` | `merge=union` (`.gitattributes`) | A flat list of one-line entries, order means nothing. Two PRs adding at the end keep both lines. A duplicated line is harmless: a human reads it, deletes one. |
| `docs/wiki/Rules.md` and the other pages `tools/gen_wiki.py` writes whole | `merge=ours`, then regenerate | Never edit by hand. A clash is two renderings of the same data, so keep ours and run `python3 tools/gen_wiki.py` (CI's `gen_wiki --check` is red until you do). Needs `git config merge.ours.driver true`; without it git falls back to a normal merge. Union would keep both versions of a changed row. |
| `docs/HUD.md`, `docs/AUDIO.md`, `docs/KIT_PARITY.md`, `docs/MOVEMENT_FEEL.md` | one fragment file per change in `docs/<NAME>.d/` | Prose and tables where a row's meaning depends on its neighbours: union would keep a stale row next to its fix. |

## Merge trains and regate-bot

`ops/merge-rush-1113/merge_batch.sh` is the conflict policy of regate-bot, merge-train and train-batch. It unions
hand-written `docs/*.md` (DEBT.md included) and keeps ours for `docs/wiki/*` (regenerated after the batch). HUD, AUDIO,
KIT_PARITY and MOVEMENT_FEEL are unioned only when both sides just added lines; when both changed the same row the merge
is a real conflict (`ops/merge-rush-1113/merge_batch_test.sh`). Blind union had left four copies of the `hud_plate.gd` row
in `docs/HUD.md` by 11-21; they stay until the open PRs that edit that row have merged.

## Fragments

- New section, table or note for HUD, AUDIO, KIT_PARITY or MOVEMENT_FEEL: write it as `docs/<NAME>.d/<MMDD>-<topic>.md`
  (for example `docs/HUD.d/1121-steal-reel.md`), starting with its own `## heading`. Name order is date order.
  The directory listing is the index; do not keep a hand-written list (it would clash again).
- Fixing or retiring an existing line still edits the legacy file in place. Two PRs on the same line is a real
  conflict and stays one.
- Do not move old text out of the legacy docs: open PRs edit it. Move it once they have merged.
