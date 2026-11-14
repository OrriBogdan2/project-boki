# tools/

Checks (`*_check.gd`, registered in `check_registry.gd`), shot tools (`*_shots.gd`), content generators (`gen_*.py`) and the repo gate.

## The gate: `tools/check.sh`

It runs `health.py --strict` (god-file budgets, the style ratchet), then `lint_gate.py`. That covers gdlint, gdformat (120 columns), ruff, ruff format, vulture, glTF validation, and Godot's unused-code and shadowing warnings, counted per file. Old debt sits in `lint_baseline.json` and may not grow, and a new file must be clean. See `check.sh`'s header for the flags. The suite and merge-candidate run `tools/check.sh --changed`: on top of the ratchet, every `.gd` a branch changes must be gdformat clean. This applies to branches cut after that rule landed.

## Formatting old files in batches

Reformatting everything at once would conflict with every open branch, so old files are cleaned about 50 at a time. A batch skips any file that an unmerged `ext/*` branch with a commit in the last 3 days touches.

```
~/.cache/boki-lint/venv/bin/python tools/format_batch.py --dry-run   # list the next batch
~/.cache/boki-lint/venv/bin/python tools/format_batch.py             # format it (--size N, --days N)
tools/check.sh --update && python3 tools/style_lint.py --update      # lock the lower counts in
```
Commit each batch on its own. Check that Godot's errors and warnings from `tools/warn_count.gd` are the same before and after. `format_batch.py --list godot-shadow` (or any other `lint_baseline.json` check) shows that check's files, each marked free or busy. Use it to pick cleanups that won't conflict.

## Python scripts

Scripts that have been given an argparse entry point answer `--help`; `python3 tools/py_help_check.py` runs it on
all of them (CI runs that through `server/matchmaker/tests/test_tool_help.py`). The rest still run straight from
their docstring usage; `docs/CODE_HEALTH.md` lists them. Scripts marked **blender** run inside Blender 4.5
(`blender -b --factory-startup --python SCRIPT -- ARGS`). The Godot checks (`tools/*_check.gd`) are not listed
here; see AGENTS.md. Pipeline detail lives in `docs/art/wardens/PIPELINE.md`, `docs/art/kin/RIGGED_BOKI.md` and
`docs/AUDIO.md`.

## Art / 3D

| Script | Purpose | Example |
|---|---|---|
| `art1/<hero>_source.py`, `_pieces.py`, `_finish.py`, `_paint.py` (blender) | The ART-1 Hunter build per hero: sculpt pieces, join, unwrap, paint, skin, export a .glb (shared kits: `meshkit`, `sculpt_kit`, `paintkit`, `posekit`) | `blender -b --factory-startup --python tools/art1/cinder_finish.py -- src.blend rig.json out.glb` |
| `art1/art1_render.py` (blender) | Review renders of a Hunter .blend: turntable or clip strip | `blender -b f.blend --python tools/art1/art1_render.py -- out turn 400` |
| `art1/shapes_view.py` | Front/side/back/top ortho looks at a stage .blend, optional close-ups (replaces the claire/ryzz/sable copies) | `blender -b --factory-startup --python tools/art1/shapes_view.py -- f.blend out --hide Cape` |
| `art1/sculpt_preview.py` (blender) | Clay contact sheet of sculpt meshes | `blender -b --factory-startup --python tools/art1/sculpt_preview.py -- out.png a.npz --head` |
| `meshy/recipe.py` | RECIPE_95 driver: one Warden from art to a shipped model, step by step | `python3 tools/meshy/recipe.py art/wardens/src/vex_recipe.json art crop` |
| `meshy/meshy_task.py` | Create and poll Meshy tasks (needs a Meshy key) | `python3 tools/meshy/meshy_task.py --help` |
| `meshy/fit_warden.py`, `warden_parts.py`, `hard_parts.py` (blender) | Fit a Meshy body to the Warden rig contract; per-Warden parts | `blender -b --factory-startup --python tools/meshy/fit_warden.py -- spec.json` |
| `meshy/look_renders.py` | Flat or lit renders of a .glb from several angles | `blender -b --factory-startup --python tools/meshy/look_renders.py -- m.glb out --lit` |
| `meshy/sheet_crops.py`, `pad_views.py`, `flat_ground.py`, `grid_crop.py`, `colour_sample.py`, `face_touch.py` | Image prep for Meshy and the face pass: crops, padding, background flattening, pixel grid, colour ramps, face touch-ups | `python3 tools/meshy/grid_crop.py img.png 0 0 200 200 4 out.png` |
| `blender/fit_rigged.py`, `warden_hull.py`, `warden_paint.py`, `decimate_warden.py` (blender) | Fit a hand-made rigged Warden, rebuild its hull, paint ageing, decimate to the triangle budget | see the docstring of each |
| `boki/build_boki.py`, `build_fusion.py` (blender) | Build every Boki species (and fusions) from `boki/<species>.py` into the game's .glb | `blender -b --factory-startup --python tools/boki/build_boki.py -- --no-export` |
| `vendor_gltf.py` | Compact a CC0 glTF pack model into `art/vendor/*.glb` | `python3 tools/vendor_gltf.py src.gltf art/vendor/x.glb --anims Idle,Run` |
| `gen_vfx_noise.py` | Bake `art/vfx/noise.png` for the hero VFX shaders | `python3 tools/gen_vfx_noise.py` |

## Animation

| Script | Purpose | Example |
|---|---|---|
| `art1/<hero>_clips.py` (blender) | The hero's animation clips on the rig, exported into the .glb | `blender -b --python tools/art1/cinder_clips.py -- cinder.blend out.glb idle,run` |
| `art1/anim_kit.py`, `crouchkit.py`, `fistkit.py`, `gardenkit.py` | Shared clip helpers (imported, not run) | |
| `art1/glb_add_clips.py` | Copy clips from one .glb into another | `python3 tools/art1/glb_add_clips.py target.glb source.glb run_,idle out.glb` |
| `boki/<species>_anim.py`, `boki_clips.py` (blender) | A Boki species' clips | built by `build_boki.py` |

## Audio

| Script | Purpose | Example |
|---|---|---|
| `gen_sfx.py` | The base sound palette into `audio/*.wav` (numpy, scipy) | `python3 tools/gen_sfx.py` |
| `gen_sfx_<group>.py` (one per hero or system), `gen_hero_sfx.py`, `gen_key_sfx.py`, `gen_pair_sfx.py`, `gen_reset_sfx.py`, `gen_break_sfx.py`, `gen_train_sfx.py`, `gen_wisp_sfx.py` | One sound set each, with its own random stream so no other set moves | `python3 tools/gen_sfx_vex.py` |
| `sfx_lib.py`, `sfx_combat.py` | Shared synth blocks and the combat layer (imported) | |
| `gen_music.py`, `compose.py`, `gen_ambience.py`, `gen_garden_ambience.py` | Music and ambience loops into `audio/*.ogg` | `python3 tools/gen_music.py` |
| `sfx_stats.py` | Loudness and spectrum numbers for a mix pass | `python3 tools/sfx_stats.py audio --json now.json` |
| `sfx_look.py` | Waveform and spectrogram review sheet | `python3 tools/sfx_look.py out.png audio/vn_*.wav` |

After any generator: `godot --headless --import`.

## Build / CI

| Script | Purpose | Example |
|---|---|---|
| `health.py` | God-file line budgets and duplicate-content checks (`--strict` fails the ship) | `python3 tools/health.py --strict` |
| `style_lint.py` | Style ratchet for `.gd` (docs/STYLE.md) | `python3 tools/style_lint.py --file scripts/x.gd` |
| `py_help_check.py` | Every Python tool answers `--help` | `python3 tools/py_help_check.py` |
| `mkshell.py` | The page around a Godot web export (gzipped wasm and pck) | `python3 tools/mkshell.py ../build/web ../build/site` |
| `udp_delay.py` | UDP delay proxy for online-feel runs | `python3 tools/udp_delay.py 9000 9001 60` |
| `rebrand.py` | Player-facing text rename pass | `python3 tools/rebrand.py --help` |
| `../server/matchmaker/matchmaker.py` | The matchmaker service (tests: `python3 -m unittest discover -s server/matchmaker/tests`) | `python3 server/matchmaker/matchmaker.py --help` |

## Data

| Script | Purpose | Example |
|---|---|---|
| `gen_wiki.py` | Data-driven wiki pages in `docs/wiki/` | `python3 tools/gen_wiki.py` |
| `gen_abilities_doc.py` | The abilities doc from `content/` | `python3 tools/gen_abilities_doc.py` |
| `gen_names.py` | `scripts/core/names.gd` from the name lists | `python3 tools/gen_names.py` |
| `make_hollowcrown.py`, `make_skyreach.py` | Hand-made expedition maps into `content/maps/` | `python3 tools/make_hollowcrown.py` |
| `garden_sim.py` | Headless garden balance sim | `python3 tools/garden_sim.py` |
| `ways_out_sites.py` | Map rule for the Limited Ways Out mode (imported) | |
