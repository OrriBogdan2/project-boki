# Audio: sound sets, loudness and buses

How the game's sound effects are made, named, levelled and played. Music and ambience are in `tools/compose.py` and `tools/gen_ambience.py`.

## Making sounds
- Sounds are **synthesised in code** (numpy/scipy, `pip install numpy scipy`), one script per group: `tools/gen_sfx_<group>.py` (e.g. `gen_sfx_vex.py`, `gen_sfx_boki.py`, `gen_sfx_ui.py`). Each one imports `tools/sfx_lib.py`, calls `S.reseed(<its own seed>)` and writes `audio/<name>.wav` (44.1 kHz mono 16-bit). Then `godot --headless --import`.
- `sfx_lib.py` re-uses the primitives in `tools/sfx_combat.py` (filters, envelopes, kick, click, crack, sub, tail, reflections, ring, grains) and adds `voice()` (wordless grunts and cries through vowel formants), `chime()`, `creak()`, `fm()`, `sweep()`, `rattle()`, `hiss()`.
- Outside sources only if **CC0**, logged in `docs/CREDITS.md` under the group's own section (source URL, author, licence, which file). No sounds from SUPERVIVE or any other game.
- Review: `python3 tools/sfx_look.py out.png audio/<names>*.wav` draws waveform + spectrogram + levels per sound (matplotlib). Use it to judge layering, clicks and harshness, and as the READY screenshot.
- Held sounds (a minigun spin, a charge hum): write them with `S.save_loop(name, x, cat)`, which cross-fades the tail into the head and skips the end fades, list them under `"loops"`, and play them with `Sfx.loop_start` / `loop_stop`.
- Variety: write takes with `S.takes_cat(name, fn, 3, cat)` (`name.wav` + `name_1..3.wav`); `Sfx` picks a different take each time.

## Loudness
Every sound is levelled to its **category** by `S.save_cat` / `S.takes_cat` (table: `content/rules/sfx_levels.json`): RMS over the audible part, peak ceiling -1 dBFS. The `vol_db` at the call site then only says intent (a quiet tell, a big ult), never fixes a file that is too loud.

| category | RMS dBFS | for |
|---|---|---|
| heavy_impact | -14.5 | a damage carry's hits (Vex, Kael, Grimble's blunderbuss, Mossy's hammer) |
| heavy_fire | -15.5 | a damage carry's weapon: a little louder than the lighter Hunters |
| impact | -16 | an ability or weapon landing |
| fire, signature | -17 | a shot or swing; a Hunter's recognisable sound |
| cast, grunt | -18 | an ability starting; hurt / downed / death voice |
| boki | -19 | Boki voices and moves |
| dash | -20 | |
| loop | -21 | held sounds |
| ui | -22 | menus and HUD |
| step | -23 | footsteps |

## Names
- A Hunter's own sounds start with its archetype id: `gunslinger_*` (Vex), `archer_*` (Lace), `juggernaut_*` (Kael), `bulwark_*` (Mossy), `ostra_*` (Motley), `ashwick_*` (Cinder), `dredge_*` (Grimble), `rimewright_*` (Neve), `tender_*` (Meeko), `thief_*` (Sable), `mage_*` (Sparkle), `dolm_*` (Tenzo). Older kit sounds keep their names (`vn_*`, `jug_*`, `rime_*`...); a branch that replaces one regenerates that file under its old name.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps and landings (`MoveSfx`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Footsteps on sand, shallow water and metal are not per Hunter: `step_<sand|water|metal>_<light|medium|heavy>` (set `steps`, `tools/gen_sfx_steps.py`, synthesised in code, no outside sound) play by the Hunter's weight class, a little louder the heavier it is, unless the Hunter has its own `<arch>_step_<surface>`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`, the surface from `StepSurface`: a map's `surfaces` tile rects (sand, water, metal), its `bridges` and the farm's opened bridges = wood, the sky train's deck = metal), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Boki sounds: `boki_*` (and the existing `kin_*` / `k_*` names); UI: `ui_*` (and the existing `click`, `hover`...).

## Sound sets (`content/sfx/<group>.json`)
```json
{"group": "gunslinger", "name": "Vex", "script": "tools/gen_sfx_vex.py",
 "sounds": {"gunslinger_dash": "dash", "gunslinger_hurt": "grunt", "vn_spin": "signature", "...": "..."},
 "signature": ["vn_spin", "gunslinger_grenade_thunk"],
 "kit_files": ["gunslinger_ult.gd"], "replaces": ["vn_rifle", "..."],
 "reach": {"gunslinger_fire": 45}, "loops": ["gunslinger_spin"]}
```
**Movement by weight** (`content/sfx/move.json`, `tools/gen_sfx_move.py`): `jump_`, `land_` and `kick_` (wall hop) in `light`/`medium`/`heavy`, plus `glide_open_heavy`, picked by `HeroSfx.weighted` from the `weight` of `content/archetypes/<id>.json`. Landing volume follows the fall speed (`HeroSfx.land_db`); the class shifts it a few dB. The old shared `jump`/`land` stay as the fallback.

`--sfx-set-check` asserts: every listed sound has its file(s); every take is within 3 dB of its category and under the ceiling; a Hunter set has hurt/down/death, dash, steps on all four surfaces, a `fire` sound and its signature list; `HeroSfx` picks them up; every literal `m.sfx("...")` in that Hunter's kit (`<arch>_kit.gd` plus its `kit_files`) names a sound that exists. `replaces` lists old-name files the set regenerated. `reach` (metres, 22-80) makes a heavy sound carry past the usual 22 m, so you hear a carry coming (past 9 m it plays through the muffled bus, so the low end is what carries); `Sfx` reads it from every set at start. Each sound under `loops` must repeat seamlessly.

## Playing and buses
- **Positional one-shots pan.** With a position and a 3D camera, `Sfx` plays them from an `AudioStreamPlayer3D` placed at the sound, so you hear which side it is on; the level is still `Sfx`'s own falloff (Godot's attenuation is off, `Sfx.PAN` sets how hard it pans). UI sounds (no position) and keyed loops stay unpanned.
- **Movement sounds** (`MoveSfx`, numbers in `content/rules/move_sfx.json`): footsteps play on the run cycle's foot strikes (`HunterAnim.stepped`), not a timer, on the surface underfoot (`StepSurface`) and in the Hunter's weight class; jumps and landings are the class's `jump_`/`land_` with that surface's step under them. Another Hunter's footsteps carry 14 m (`step_reach_m`), landings, dashes and the glider the usual 22 m. Height sets the pitch (Kael 2.05 m about 0.89x, Neve 1.56 m about 1.01x). Enemies are 6 dB louder than you (`role_db`) so you hear them coming, and everyone is 4 dB quieter for 2.5 s after hitting, swinging or casting (`fight_db`). Footsteps are silent while crouched or unseen. `--match-audio-check` asserts an enemy's footstep plays placed at it, inside the reach and not past it, set louder than yours and quieter in a fight.
- **Water** (`WaterSfx`, set `water`, `tools/gen_sfx_water.py`, synthesised in code; levels under `"water"` in `content/rules/move_sfx.json`): on the map's shallow water (`StepSurface` "water") a Hunter's or a Boki's landing splashes in its weight class (`water_land_light|medium|heavy`; a Boki's size small, medium, large picks it), a dash on the ground (a Boki's charge) throws a spray (`water_dash`), and wading holds the `water_wade` loop (`Sfx.loop_hold`, keyed per mover) whose level and pitch follow speed, silent standing still, sneaking or past the step reach. None of them play on dry ground. Swimming exists only in the farm's ponds (`HomeWater`), whose strokes are `water_stroke`. `--match-audio-check` asserts each one on water and none on dry ground, and the farm stroke in deep water only; `--water-clip --shots-dir=<dir>` records them on the Saltmere tide pool for listening (jobq gpu, music and ambience muted). The wading loop does not pan (docs/DEBT.md).
- Always through `Sfx.play(name, pos, vol_db)` / `m.sfx(...)` (one-shots, pooled, distance falloff, far sounds muffled) or `Sfx.loop_start(key, name, pos)` / `loop_set` / `loop_stop` (held sounds). Never a new `AudioStreamPlayer`.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- New sounds load on first play (`Sfx._lazy`, takes included); no edit to `Sfx.NAMES` is needed.
