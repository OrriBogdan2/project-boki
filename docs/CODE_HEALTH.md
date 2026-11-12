# Code health log

Each cleanup pass appends a section: what was removed or merged, and the evidence.

## Python asset scripts (branch ext/health-py-1112, 2026-11-12)

Method. All 254 tracked `.py` files were inventoried. A file was only touched when it was not changed by any
`origin/ext/*` branch with a commit in the last 3 days (2201 branches; 443 `.py` paths are in that set and were left alone).
"Unused" means: no `import`/`from` of its module name in any `.py`, no path or name in any `.gd .tscn .tres .gdshader
.cfg .json .md .sh .yml`, `project.godot`, `export_presets.cfg`, `.github/`, `tests/`, `tools/`, `docs/`; no hit in
`/home/boki/coord-refs/ext-refs.txt`; no dynamic import by string (`importlib` is used only by
`build_boki.py`/`build_fusion.py` on their own species tables and by `fit_warden.py` for recipe `scripted.module`,
none of which name these files); and no recently active branch adds a line that mentions them.

### Removed (12 files, 814 lines)

| Path | What it was | Evidence |
|---|---|---|
| `tools/art1/scipy_free.py` | nearest point on a polyline without scipy | zero references anywhere |
| `tools/art1/imgio_blender.py` | image to float array inside Blender | zero references; `tools/meshy/imgio.py` is the one in use (21 importers) |
| `tools/art1/sdf_kit.py` | numpy SDF sculpt kit (Tarek WIP) | zero importers; the kits in use are `sculpt_kit`, `hem_sdf`, `boki_sdf` |
| `tools/art1/grimble_render.py`, `hem_render.py` | copies of `art1_render.py` (turntable and clip renders) with a hero camera baked in | zero references; the docstrings even point at a path that does not exist (`tools/blender/art1_render.py`). Lost: an optional pose arg and `HEADS=1` in grimble's copy; `art1_render.py` is held by open branches, so add them there if wanted |
| `tools/art1/pip_render.py` | Pip turnaround and shape renders | zero references; covered by `art1_render.py` (turn) and `shapes_view.py` (shape looks) |
| `tools/art1/ostra_look.py`, `ostra_poseview.py`, `ostra_preview.py` | Motley preview renders and their shared helper | zero references to the first two; the helper is only imported by those two; covered by `art1_render.py` |
| `tools/art1/vex_assemble.py` | Vex stage B: pieces to flat-coloured objects and a shape pass | zero references; `vex_finish.py` (stage C) builds from the pieces itself |
| `tools/meshy/hem_crops.py`, `hem_prep.py` | Hem-only turnaround crops and padding for Meshy | zero references; generic `sheet_crops.py` and `pad_views.py` do the same and are called by `recipe.py` |

### Merged

| New | Replaces | Notes |
|---|---|---|
| `tools/art1/shapes_view.py` (argparse, `--help`) | `claire_shapes.py`, `ryzz_shapes.py`, `sable_shapes.py` | one script; the per-hero differences are options (`--res`, `--scale`, `--cz`, `--atlas`, `--closeup`). None had a caller. No ext-refs entry named them, so no wrappers were kept |

### Entry points added (`main()` + argparse + `--help`, no work at import)

`gen_hero_sfx`, `gen_key_sfx`, `gen_sfx` (body now inside `main()`), `gen_pair_sfx`, `gen_reset_sfx`, `gen_vfx_noise`,
`mkshell`, `sfx_look`, `style_lint`, `vendor_gltf`, `meshy/{recipe,sheet_crops,pad_views,flat_ground,grid_crop,
colour_sample,face_touch,look_renders}`. Arguments are unchanged. The audio generators were run before and after: the
written `.wav` files are byte-identical (hash compared; `gen_sfx` does not reproduce the committed wavs on this
machine's numpy/scipy, so it was compared against its own earlier output). `mkshell` was run on a fake web export.
`tools/py_help_check.py` runs `--help` on every tracked tool that uses argparse and does not `import bpy` at module
level; it is wired into CI through `server/matchmaker/tests/test_tool_help.py` (the existing unittest step).

### Held back, and why

- **Files in the 3-day active set** (not edited at all, to avoid merge conflicts with queued branches): the whole
  `art1/*_clips|_finish|_source|_paint` families, `boki/*_anim.py`, `boki/build_boki.py`, `gen_sfx_<group>.py`,
  `gen_wiki.py`, `make_*.py`, `health.py`, `garden_sim.py`, `udp_delay.py`, `gen_names.py`, `gen_abilities_doc.py`,
  `gen_break_sfx.py`, `gen_music.py`, `compose.py`, `.github/workflows/release.yml`. They still lack a `main()` +
  `--help` (about 50 leaf scripts). Convert them once their branches have merged.
- **Near-copy families** that should be merged into one script with options once the above are free:
  the 20 `gen_sfx_<group>.py` (each re-declares the synth primitives that `sfx_lib.py` already holds; outputs depend on
  per-script random streams, so the merge needs a before/after wav hash like the one used here), the per-hero
  `art1/<hero>_clips.py` / `_finish.py` triples, and `boki/<species>_anim.py`.
- **ext-refs.txt**: 61 `.py` paths (`tools/boki/<species>*.py`, `tools/art1/*_finish|_pieces|_source.py`, `meshy_task.py`,
  `boki3d_render.py`, ...). Not removed. Some listed paths (`tools/dashboard.py`, `usage-pacer.py`, `x.py`, ...) are not in
  this tree at all.
- `gen_sfx.py`'s `main()` is now one long function; splitting it into one function per sound section is a follow-up.
- `look_renders.py` was converted but could not be run here (no Blender on w2); it was checked by compile, `--help` and a
  undefined-name scan only.
- Zero-caller but kept as standalone generic tools: `art1/sculpt_preview.py`, `meshy/look_renders.py`
  (documented usage, no duplicate left).
