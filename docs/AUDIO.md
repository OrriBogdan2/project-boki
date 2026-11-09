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

## Mix pass: loudness across all cues and ducking
The files above are levelled by RMS at generation; cues added one branch at a time still drifted (a 12 dB spread inside "move"). `python3 tools/loudness_report.py` measures every cue in `audio/` (ITU-R BS.1770 integrated loudness, 400 ms gated blocks, K-weighted; sample peak; takes as one cue; standard library only, about 2 s) and groups them: weapon, ability, impact, boki, voice, move, ui, ambience. Targets, tolerance (+-2 LU) and the name patterns per category are in `content/rules/sfx_mix.json`. An outlier is brought in **through the cue table** `content/rules/sfx_cues.json` (dB added in `Sfx.play` and `loop_start`; files are untouched), at most 12 dB down / 3 dB up, boosts never past -1 dBFS peak. Ambience beds are measured but not trimmed (they play at -14 dB in `play_ambience`).
- `--write` rebuilds the table, `--check` fails when it is stale (run after adding or regenerating a sound), `--outliers` lists the cues outside tolerance, `--md` prints the table below, `--tails NAME..` gives a cue's length, end level and decay time.
- What is left outside tolerance after the table is peak-limited (a sound whose file peak is already -1 dBFS but whose body is quiet, e.g. `jug_meteor`, `vv_sky_strike`) or capped; fixing those means regenerating the sound with more body.

Before and after (integrated LUFS; "outliers" = cues more than 2 LU from the target; 476 cues, 186 with a cue gain):

| category | cues | target LUFS | median before | spread before (sd) | outliers before | median after | spread after (sd) | outliers after | trimmed | loudest peak dBFS |
|---|---|---|---|---|---|---|---|---|---|---|
| weapon | 23 | -19.5 | -20.3 | 3.2 | 12 | -19.7 | 2.3 | 7 | 9 | -1.0 |
| ability | 186 | -19.5 | -19.4 | 2.2 | 70 | -19.5 | 1.3 | 15 | 64 | -0.9 |
| impact | 55 | -20.0 | -21.3 | 1.9 | 24 | -20.8 | 1.2 | 10 | 20 | -1.0 |
| boki | 25 | -20.0 | -20.2 | 1.6 | 4 | -20.0 | 0.9 | 0 | 4 | -1.1 |
| voice | 66 | -21.0 | -21.4 | 2.1 | 23 | -21.1 | 0.8 | 0 | 23 | -1.1 |
| move | 95 | -25.5 | -25.6 | 3.5 | 58 | -25.6 | 0.7 | 0 | 58 | -1.4 |
| ui | 21 | -23.5 | -23.3 | 2.4 | 8 | -23.5 | 0.7 | 0 | 8 | -3.4 |
| ambience | 5 | -20.5 | -20.5 | 1.7 | 2 | -20.5 | 1.7 | 2 | 0 | -4.4 |

Ducking: `Sfx.duck` now dips the Music **and** Ambience buses (a bus effect, so it works for one track, the stems and the beds). A rival's ult (wind-up, cast, or an X ult; `MusicDir._ult_duck`) within 45 m dips them 9 dB, a knock call within 45 m (`Juice.knock`) 6 dB; both ease in in 0.12 s, hold 0.7 s / 0.35 s and come back in 1.0 s (`duck` in `sfx_mix.json`). Your own knock keeps its dip in `Match.knock`. `--match-audio-check` fires them and measures the buses.

SFX_AUDIT row 18 (Tenzo's and Neve's ult tails): by ear is not done. By measurement (`--tails`): Tenzo `br_spine` (1.6 s, ends -48 dB under its loudest 50 ms) and `br_crumble` decay cleanly; **`br_rumble` (0.42 s) is cut off at -23 dB, an audible stop**, and `br_crack` ends at -33 dB; Neve `rime_crash` (2.1 s), `rime_burst`, `rime_lock` and `rime_freeze` end under -45 dB, `rime_creak` takes end at -28 to -36 dB (a short blip). Not regenerated here (sound files untouched): `br_rumble` needs a longer fade in its generator.

## Names
- A Hunter's own sounds start with its archetype id: `gunslinger_*` (Vex), `archer_*` (Lace), `juggernaut_*` (Kael), `bulwark_*` (Mossy), `ostra_*` (Motley), `ashwick_*` (Cinder), `dredge_*` (Grimble), `rimewright_*` (Neve), `tender_*` (Meeko), `thief_*` (Sable), `mage_*` (Sparkle), `dolm_*` (Tenzo). Older kit sounds keep their names (`vn_*`, `jug_*`, `rime_*`...); a branch that replaces one regenerates that file under its old name.
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Boki sounds: `boki_*` (and the existing `kin_*` / `k_*` names); UI: `ui_*` (and the existing `click`, `hover`...).

## Sound sets (`content/sfx/<group>.json`)
```json
{"group": "gunslinger", "name": "Vex", "script": "tools/gen_sfx_vex.py",
 "sounds": {"gunslinger_dash": "dash", "gunslinger_hurt": "grunt", "vn_spin": "signature", "...": "..."},
 "signature": ["vn_spin", "gunslinger_grenade_thunk"],
 "kit_files": ["gunslinger_ult.gd"], "replaces": ["vn_rifle", "..."],
 "reach": {"gunslinger_fire": 45}, "loops": ["gunslinger_spin"]}
```
`--sfx-set-check` asserts: every listed sound has its file(s); every take is within 3 dB of its category and under the ceiling; a Hunter set has hurt/down/death, dash, steps on all four surfaces, a `fire` sound and its signature list; `HeroSfx` picks them up; every literal `m.sfx("...")` in that Hunter's kit (`<arch>_kit.gd` plus its `kit_files`) names a sound that exists. `replaces` lists old-name files the set regenerated. `reach` (metres, 22-80) makes a heavy sound carry past the usual 22 m, so you hear a carry coming (past 9 m it plays through the muffled bus, so the low end is what carries); `Sfx` reads it from every set at start. Each sound under `loops` must repeat seamlessly.

## Playing and buses
- Always through `Sfx.play(name, pos, vol_db)` / `m.sfx(...)` (one-shots, pooled, distance falloff, far sounds muffled) or `Sfx.loop_start(key, name, pos)` / `loop_set` / `loop_stop` (held sounds). Never a new `AudioStreamPlayer`.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- New sounds load on first play (`Sfx._lazy`, takes included); no edit to `Sfx.NAMES` is needed.
