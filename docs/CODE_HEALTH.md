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

## GDScript and scenes (branch ext/health-gd-1112, 2026-11-12)

Method. The skip list holds every path changed by an `origin/ext/*` branch with a commit in the last 3 days (2201
branches). 916 of the 1038 tracked `.gd`/`.tscn` files are on it and were only read. Of the 122 left, 94 are named in
`/home/boki/coord-refs/ext-refs.txt`, so none of those files was deleted (only unused symbols inside them were removed).
- **Files.** A reference graph covered every tracked `.gd`/`.tscn`. A file counts as used when another file names its
  path, file name, uid (`.uid` file or scene header) or `class_name`. The search covered `.gd .tscn .tres .gdshader
  .cfg .json .py .sh .yml .txt`, `project.godot`, `export_presets.cfg` and `.github/`. Paths built from strings were
  added by hand (`hero_vfx_reel.gd` loads `tools/vfx_reel/<hero>.gd`). Reachability started from `project.godot`,
  export presets, content JSON, tool scripts and coord refs, and was run a second time with GDScript comments
  stripped. Every one of the 20 unreachable files is an entry point run by hand: F6 galleries, `godot -s` tools, a
  `--script` tool. **No file is provably dead, so none was deleted.**
- **Symbols.** Every top-level `func`, `signal`, `@export var`, `var` and `const` in the 122 free files was counted
  across all text. A name with no use outside its definition was then searched with `git grep` on all 2201 active
  branch tips.
- **Commented-out code.** None in the free files. Repo-wide, the only hit, `tools/boki_follow_check.gd:273`
  (`# return`), labels the next step and is not dead code.

### Removed

| Path | What it was | Evidence |
|---|---|---|
| `scripts/core/mutations.gd` `inherit_odds()` | getter for the parent-inherit odds | no caller on main or in any active branch tip; `_inherit` is still read by the roll |
| `scripts/core/mutations.gd` `SHIMMER_WILD`, `SHIMMER_EGG` | aliases of Shiny's odds "kept for older callers" | no caller on main or in any active branch tip; the odds live in `Shiny` |
| `scripts/match/gloves.gd` `wear_pair()` | puts two gloves on at once | no caller on main or in any active branch tip; bots use `Gloves.bot_fill` |

Kept: `KinRules.DEFAULT_SLOW` is unused on main, but `scripts/match/ent.gd` reads it on 6 active branches.

### Merged

| Path | Was | Now |
|---|---|---|
| `scripts/match/key_bonus.gd` `rules()` | its own JSON read and cache of `content/rules/chest_keys.json` (`RULES_PATH`, `_rules`) | `Content.rules("chest_keys")`, the shared cached loader; same dict, same `{}` on a missing file; `KeyBonus.rules()` callers unchanged |

### Guard: `--unref-check`

`tools/unref_check.gd` fails on any `.gd`/`.tscn` that no other file names by path, file name, uid or `class_name`.
Comments count as names; `.md` docs don't. It takes about 1.7 s headless. Intentional entry points go in
`tools/unref_allow.txt` with a reason, and a listed file that is gone also fails. The check is not transitive: a file
named only by another dead file still passes. It is registered with one line in `tools/check_registry.gd`, placed
where a trial `git merge-tree` against all 1078 active branches that change that file showed 0 new conflicts.

### Found, not changed

- **`--unstable-mix-check` is orphaned and red.** `tools/unstable_mix_check.gd` had an inline hook in `main.gd`
  (4e7fd6a893), and a later merge dropped it. `docs/wiki/Checks.md` still lists the check. Run on main, it fails:
  "20 of 20 clashing pairs get the Nook line and the card tag (0)". Registering it here would add a red, so it is
  allowlisted instead. Fix (Nook lane): repair `UnstableMix` tagging, then register the flag and drop the allowlist line.
- **Entry points nobody names** (allowlisted): `tests/feel_sim.gd`, `tests/glider_gallery.tscn`,
  `tests/portrait_gallery.tscn`, `tests/net/match_probe.gd`, `tests/net/net_probe.gd`, `tools/vfx_reel/*.gd` (4).

### Duplicate systems to merge later

All of these touch skip-list files (and most are in coord refs), so none was merged in this pass.
1. **Movement and camera prototype vs the game's.** `scripts/feel/` holds its own controller and camera:
   `HunterController` (560 lines), `TopDownCameraRig`, `FeelConfig`, `JumpPad`, `KinfallInput`, `feel_test_world`.
   It is reached by `--feel-lab` (`tests/feel_test.tscn`) and `tests/feel_sim.gd`. The game uses `Hunter` +
   `HunterMove` + `CamRig`; `hunter.gd` and `move_feel_check.gd` only name `FeelConfig` in comments and labels.
   Plan: once `move_feel_check`'s targets are in `content/rules`, delete `scripts/feel/`, `tests/feel_test.tscn`,
   `tests/feel_sim.gd` and the `--feel-lab` hook.
2. **Ruin walls twice.** `scripts/match/ruin_walls_v1.gd` (226 lines) is kept for the `--art1` before/after view
   next to `ruin_walls.gd`, and `_init` and `_exposed` are identical in both. Plan: drop the `Flora.v2()` false
   branch in `world.gd`, then delete v1. Both files are in coord refs, so the coordinator decides.
3. **Rules loaders.** 19 files read their own `content/rules/*.json` with a private cache instead of
   `Content.rules(id)`: `arch_kit`, `boki_lines`, `class_unlock`, `garden_xp`, `box_revive`, `breakables`, `cam`,
   `equal`, `gear_drops`, `heart`, `hunter_move`, `key_run`, `level_growth`, `mantle_look`, `perk_orbs`,
   `weapon_path`, `wisp_look`, `hunter_viewer`, `portraits`. Plan: the same swap as `KeyBonus` for each file as it
   comes off the skip list. Check that none of them writes into its cached dict (Content shares one).
4. **Kit FX mesh helpers.** `dj_fx.gd`, `ld_fx.gd` and `vv_fx.gd` each copy `_mi()`. `dj_fx` and `ld_fx` also copy
   `_quad_mesh()`, `_ribbon_mesh()` (20 identical lines) and `unplace()`. `KitMeshes.inst()` and `KitMeshes.quad()`
   already do this job. Plan: callers use `KitMeshes`, and `_ribbon_mesh` moves into `KitMeshes`.
5. **Model finishing.** `MobModels._finish` and `PropSculpt._finish` are identical (merge statics, bake part y).
   Plan: one `Models.finish(root)`.
