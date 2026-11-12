# tools/

Checks (`*_check.gd`, registered in `check_registry.gd`), shot tools (`*_shots.gd`), content generators (`gen_*.py`) and the repo gate.

## The gate: `tools/check.sh`

It runs `health.py --strict` (god-file budgets, the style ratchet), then `lint_gate.py`. That covers gdlint, gdformat (120 columns), ruff, ruff format, vulture, glTF validation, Godot's unused-code and shadowing warnings, and `private-ref` (no outside game's name in any tracked text file or file name; the old code comments are baselined and go down when you touch a file), counted per file. Old debt sits in `lint_baseline.json` and may not grow, and a new file must be clean. See `check.sh`'s header for the flags. The suite and merge-candidate run `tools/check.sh --changed`: on top of the ratchet, every `.gd` a branch changes must be gdformat clean. This applies to branches cut after that rule landed.

## Formatting old files in batches

Reformatting everything at once would conflict with every open branch, so old files are cleaned about 50 at a time. A batch skips any file that an unmerged `ext/*` branch with a commit in the last 3 days touches.

```
~/.cache/boki-lint/venv/bin/python tools/format_batch.py --dry-run   # list the next batch
~/.cache/boki-lint/venv/bin/python tools/format_batch.py             # format it (--size N, --days N)
tools/check.sh --update && python3 tools/style_lint.py --update      # lock the lower counts in
```
Commit each batch on its own. Check that Godot's errors and warnings from `tools/warn_count.gd` are the same before and after. `format_batch.py --list godot-shadow` (or any other `lint_baseline.json` check) shows that check's files, each marked free or busy. Use it to pick cleanups that won't conflict.
