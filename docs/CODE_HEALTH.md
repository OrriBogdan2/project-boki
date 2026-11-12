# Code health

The code-health program (owner, 11-12): keep the codebase clean while building fast. Each job appends its
own section: what it removed or changed, and the evidence.

## Shaders (ext/health-shader-1112)

### Top offenders

The count is the number of distinct commit subjects (cherry-picked copies counted once) whose message
says fix, broke, black, compile, crash, error, stall, revert, restore, wrong or missing.

| shader | on main | unmerged ext/* | other evidence |
|---|---|---|---|
| shaders/hero_toon.gdshader | 11 (26 commits touch it) | 3 | 64 uniforms, 12 removed in one revert |
| shaders/outline.gdshader | 4 | 0 | 16 uniforms removed in one revert |
| shaders/terrain.gdshader | 4 | 2 | |
| shaders/wall.gdshader | 3 | 0 | |
| shaders/hero_vfx.gdshader | 1 | 5 | |
| shaders/care_disc.gdshader | 0 | 3 | |
| warden_card, warden_halo, vv_fx | 2 each | vv_fx 2 | warden_card: 3 uniforms removed in the same revert |
| string shaders in kit_shaders.gd, mask_beat.gd | 2 each | | |

Uniforms removed from a shader: 31 came from one commit. 6c1664fba4 reverted match-zoom v1 for v2 and took
out far_* and glow_* from hero_toon, outline and warden_card. dj_fx and ld_fx lost 8 each, because they
moved into their .gdshaderinc files. wisp_core lost 7 in a redesign.

### Why they keep breaking

1. **The uniform contract is implicit and fails silently.** hero_toon, outline, warden_card and
   warden_halo get their values from:
   - names in WardenGlb consts (PAINTED, FAR_LOOK, ICE, GLOW_SHELL);
   - keys in `content/rules/warden_look.json` (283 commits), set with `set_shader_parameter(k, ...)`;
   - about 600 literal names in scripts.

   Godot ignores a name its shader lacks, with no error and no warning (checked on 4.6.2). So a revert, a
   rename or a typo only shows up as a wrong look in review shots, and the next "fix" round follows. Most of
   hero_toon's fix commits are per-Warden look rounds on that one shared shader.
2. **Shared code is copied, and the copies drift.** The value noise in `noise.gdshaderinc` was copied
   into 6 shaders. map_paint's copy of `fbm3` has already changed (it lost the offset), and storybook's
   `hash` uses other constants.
3. **Shaders written as GDScript strings.** These are:
   - abyss_fx, farm_spotlight, blight and mask_beat;
   - 10 KitShaders kinds, put together from string pieces.

   A string shader compiles only when its effect is first built, so a typo there showed up only when the
   effect first appeared in play.

Vulkan and Compatibility were not a cause. Both use the same shader parser, and no fix in the history was
about one renderer only. The Compatibility-only problems were compile stalls, which the warm-up and
WarmStamp commits handle (733f6726d8, d5ff23c79d, da57337c16, 8614416c81, 20e788fcc6).

### What changed

| path | what | evidence |
|---|---|---|
| tools/shader_check.gd (new), `--shader-check` in tools/check_registry.gd | the guard (below) | Godot ignores bad names silently, so no other check could see the drift |
| shaders/abyss_tint.gdshader (new), scripts/match/abyss_fx.gd | the abyss tint's string shader moved to a file (same code); AbyssFx preloads it | the string was the only shader in a file no other branch touches |
| shaders/ink_wipe, pond_foam, pond_water .gdshader | their own `hash` + `vnoise` replaced by `#include "res://shaders/noise.gdshaderinc"` | same constants (127.1, 311.7, 43758.5453) and the same smoothstep as the include's `h21`/`vnoise`, so the look is unchanged |

### The guard: `--shader-check`

It fails loudly (exit 1, one `SHADER FAIL` line per problem) when:
- any `.gdshader` in the project does not compile. It is reloaded uncached headless, and its errors are
  caught by an `OS.add_logger` Logger. The dummy renderer runs the real parser.
- any `"""shader_type ..."""` string shader in `scripts/`, or any assembled KitShaders kind (both passes),
  does not compile;
- a literal `set_shader_parameter("name")` in `scripts/` names a uniform that no shader has;
- a `KitShaders.param(_, "name")` names a uniform that no KitShaders kind has;
- a key of WardenGlb.PAINTED, FAR_LOOK, ICE or GLOW_SHELL, or of a warden_look.json section, is not a
  uniform of the shader WardenGlb sets it on:
  - painted and slots: hero_toon;
  - slots.card: warden_card;
  - slots.flame-*: hero_flame;
  - ink and glow_shell: outline;
  - halos: warden_halo.

I checked that it fails on each kind of fault by planting one of each: a broken .gdshader, a broken
string shader, a broken KitShaders kind, a renamed uniform that a script still sets, and a misspelled
warden_look.json key. It passes on origin/main 53e2fe7f35, so nothing has drifted today.

Not covered: names built at run time (`set_shader_parameter(k, ...)` over other dicts, 19 sites). It also
only checks that a literal name exists in *some* shader, not in the exact one the material uses.

### Held back

Files that branches active in the last 3 days change were left alone, to avoid conflicts:
- hero_toon, outline and terrain;
- warden_glb.gd and warden_look.json: their uniform names could move into one const table;
- kit_shaders.gd, mask_beat.gd, farm_spotlight.gd and blight.gd: their string shaders could move to files;
- the noise copies in vv_fx and void_face.

map_paint keeps its own noise: its `fbm3` differs from the include's, which has the same name. storybook
keeps its own `hash`: its constants differ, so switching would change the look.

The one line added to the busy tools/check_registry.gd goes next to a line few branches edit.
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
