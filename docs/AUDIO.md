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
- **Shared kinds picked per Hunter by `HeroSfx`** (falls back to the shared sound when a Hunter has none): `<arch>_dash`, `<arch>_dash_air`, `<arch>_hurt`, `<arch>_down`, `<arch>_death`, `<arch>_step_grass|stone|wood|snow`, `<arch>_pickup`. Wired at: the dash (`Hunter` and the Thief, Neve and Tenzo kits via `HeroSfx.dash_name`: `_dash_air` when the Hunter has no floor under it, positional for rivals; `tools/gen_sfx_dash.py` makes the air variants from the ground ones, and `dash_empty`, the soft tick of a Shift press with no charge, played by `PressDeny` in place of `ui_deny`; with its own dash, `Feel.dash_sound`'s shared layers are skipped), footsteps (`Juice.footstep`), loot picked up or put on (`Pack`), your own hurt (`Match` damage), downed (`Match` knock and its net event) and death (`Life.drop_box`). The voice lines are wordless.
- Glider sounds: `glider_*` (`tools/gen_sfx_glider.py`, set `content/sfx/glider.json`), played per hunter by `GliderSfx` (a snap on opening, a `glider_wind` loop pitched and levelled by speed, the Ctrl dive whoosh, a crackle and `glider_burn` loop while overheated, a fold on landing or cancel). Other players' gliders are positional and 6 dB quieter, driven by the synced glide flag, velocity and the overheat bit (hunter flag bit 19). `--match-audio-check` asserts each state plays its cue once.
- Boki sounds: `boki_*` (and the existing `kin_*` / `k_*` names); UI: `ui_*` (and the existing `click`, `hover`...).

## Sound sets (`content/sfx/<group>.json`)
```json
{"group": "gunslinger", "name": "Vex", "script": "tools/gen_sfx_vex.py",
 "sounds": {"gunslinger_dash": "dash", "gunslinger_hurt": "grunt", "vn_spin": "signature", "...": "..."},
 "signature": ["vn_spin", "gunslinger_grenade_thunk"],
 "kit_files": ["gunslinger_ult.gd"], "replaces": ["vn_rifle", "..."],
 "reach": {"gunslinger_fire": 45}, "loops": ["gunslinger_spin"]}
```
`--sfx-set-check` asserts: every listed sound has its file(s); every take is within 3 dB of its category and under the ceiling; a Hunter set has hurt/down/death, dash, steps on all four surfaces, a `fire` sound and its signature list; `HeroSfx` picks them up; every literal `m.sfx("...")` in that Hunter's kit (`<arch>_kit.gd` plus its `kit_files`) names a sound that exists. `replaces` lists old-name files the set regenerated. `reach` (metres, 5-80) sets how far a sound carries: past the usual 22 m for a heavy sound, so you hear a carry coming, or less for a call that should stay close (`scan_call`: 11 m, half of gunfire) (past 9 m it plays through the muffled bus, so the low end is what carries); `Sfx` reads it from every set at start. Each sound under `loops` must repeat seamlessly.

## Playing and buses
- Always through `Sfx.play(name, pos, vol_db)` / `m.sfx(...)` (one-shots, pooled, distance falloff, far sounds muffled) or `Sfx.loop_start(key, name, pos)` / `loop_set` / `loop_stop` (held sounds). Never a new `AudioStreamPlayer`.
- They play on the **SFX** bus (compressor, a little room, limiter; far ones via **SFXFar**). A match's sounds are torn down with the match (item 103, `Sfx.reset_scene_audio` stops keyed loops and pool voices on the match leaving the tree), so every held sound must be a keyed loop and stopped by its owner too.
- New sounds load on first play (`Sfx._lazy`, takes included); no edit to `Sfx.NAMES` is needed.

## Ultimate cast cues
You hear an ultimate before you see it. Every Hunter's X goes through `HeroUlt.press`, which calls `UltCue.cast`: the Hunter's own `<arch>_ult_cue` at its position plus a team tag, `ult_tag_ally` (bright, rising) for your team or `ult_tag_foe` (low, falling) for a rival, both at the same level (the colour tells them apart, never loudness). They carry 60 m (`reach` in `content/sfx/ult_cues.json`, falling off with distance, muffled past 9 m) and play on the match's pool voices. Kits only run in their owner's game, so the cast also sends `["fx", "ucast", nid]` and the other games play it. Sounds: `tools/gen_sfx_ult_cues.py` (own seed; re-rolls nothing else). `--sfx-set-check` asserts a cue and reach per Hunter with an ultimate; `--match-audio-check` the ally/rival tag and the range.

## Run stingers
Four short one-shots in the expedition score's key (A minor, `tools/compose.py` `STINGS`, rendered to `audio/sting_<name>.ogg`, each under 2.5 s): `extract` (you got out), `out` (taken out, or the islands fell), `last` (the last squad standing is yours) and `home` (back on the farm after a run). `Sfx.sting(name)` plays one on the Music bus, one at a time. `MusicDir` fires `extract`/`out` the moment the run is ending and `last` from `Exits.on_last_team`, and the layered stems fall away under it (to nothing at the end, to a sliver for `last`, then back). A sting still ringing when the match leaves is cut by `Sfx.reset_scene_audio`, so it never runs into the results music. `Home` plays `home` once after a run (it clears `Game.last_result`). `--sting-check` asserts one sting per outcome.

## Leaving a place: `--music-leave-check`
Music and ambience follow the screen: after each change only the new place's score is heard. The check walks Training Grounds -> duel room -> farm -> title, a match -> title, and the farm -> title, and reads every Sfx player on the Music / Ambience buses (playing and above -45 dB). What each row protects:
- **training: the layered score plays** / **match: layers and ambience beds are up**: the setup is sane (stems and abyss / ruins beds really come up), so the leave rows below are not passing on silence.
- **duel: a duel match is up** / **duel: the score is the Training Grounds's, one set of stems**: walking into the duel room keeps one set of layered stems, not a second set stacked on the first.
- **leave duel: no stem of the match score is left**: `Sfx.reset_scene_audio` stops the layered score when a match ends.
- **leave duel: only the farm's own music + ambience**: the farm starts its own track (`home*`, or a zone's) after a match.
- **leave duel: no match ambience beds**: the abyss / ruins beds `MusicDir` sets are cleared on leave, not left looping.
- **leave duel: nothing stray on the Music bus**: no player that Sfx no longer points at (an orphaned crossfade or sting) keeps playing.
- **match -> title: the score fades out rather than cutting**: the leave is a fade; right after the change the old score is still ringing out.
- **X -> title: music is the title track / no match layers, no amb layers / exactly one music player is audible** (after the duel, a match and the farm): the title never inherits a stem, a bed or a second music player from where you were.
- **all 18 rows ran**: a step that errors out (a script error ends that coroutine) can't skip its rows and still exit 0.

The check opens screens the way the game does (`Game.goto`). With a display (xvfb too) the old screen stays current until the 0.3 s ink fade has covered it, so it waits for a new current screen rather than a fixed frame count. Settles run at `Engine.time_scale` 4: the fades are game-time tweens.

## Capture sounds (`content/sfx/capture.json`, `tools/gen_sfx_capture.py`)
All wired in `scripts/match/capture.gd`, so a rival's game plays them from the same net events (`scan_start`, `scan_stop`, `scan_done`) as the local one:
- **Scan hum**: the looping `revive_hum` on `Sfx.loop_start`, pitch rising from `rise_pitch[0]` to `[1]` with the scan fill, heard `hear_range` (26 m).
- **Success chime** by the Boki's rarity (`Capture.rarity_tier`, rules `pop_sounds`): `scan_pop` common, `scan_pop_fine` mutated, `scan_pop_rare` shimmer or a rare species. The music ducks (`duck_s`, `duck_db`) for a catch within hearing.
- **`scan_fail`**: a scan cancelled by a dash or crowd control, a box that filled mid-scan, or a rival's scan that broke off.
- **`scan_call`**: the Boki's own short call at the catch, positional with a reach of 11 m.
- Voice limits are `Sfx.MIN_GAP` (a crowd of scans cannot stack one cue) and the pool's stacking cap.
