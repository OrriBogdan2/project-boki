# Size budget

`tools/size_budget.py` runs `godot --headless --export-pack` for every preset in `export_presets.cfg` (a dry run:
no export templates needed, a temporary `.pck` only), reads the pack's file table, and compares each platform's pack
with `tests/size_budget.json`. It fails (exit 1) when any platform is more than 5% over its baseline, and prints
which asset categories grew most (textures, models, audio, scripts, data, fonts, shaders, scenes, other) and the
biggest packed file. `tests/*` is not exported, so fixtures cost nothing.

- Check: `python3 tools/size_budget.py` (also `tools/check.sh` and the suite flag `--size-budget-check`). About 40 s.
- A growth you mean to ship (new art, audio, a new hero): run `python3 tools/size_budget.py --update` and commit
  `tests/size_budget.json` **in the same PR**, so the baseline bump is reviewed with the growth. Shrinking is fine;
  bump the baseline down too so the budget stays tight.
- The dry run measures the pack, not the engine binary the platform adds on top (about the same on every release).
- The baseline lists the categories too, so a diff of the json shows where the weight went.
