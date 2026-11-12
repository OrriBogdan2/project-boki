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
