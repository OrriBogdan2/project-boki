# Sound-effect library (Sonniss GDC bundles)

A private library of real recordings for choosing better game sounds. **No library file, raw or edited, goes into this repo.**

## Licence (Sonniss GDC Game Audio Bundle licence v2.0, effective 2026-08-27)
- Allowed: use and edit the sounds in a game we ship, sell or share; no attribution; unlimited projects; sharing inside the team.
- Not allowed: supplying them "as sound effects" (raw, edited or re-designed) in a library, asset pack, template or SDK; claiming we recorded them; using them to train AI or build SFX generators.
- So: the **built game** may contain them. The **public GPL-3.0 repo may not**, and the GPL cannot cover them. Keep the library and any clips cut from it private; a swap job must pull the chosen clips into the export from a private asset pack (a private repo or bucket), not commit them to `audio/`.
- AI use: choosing is done from file names, folders and measured clip shape. Audio is never uploaded to an AI service.
- The yearly PDFs on the mirror are older licence versions; the version in force on the download date governs (we downloaded 2026-11-13, so v2.0).

## Tools (`tools/sfx_library/`, run with `python3 -I`; sheets and packs need numpy and ffmpeg)
| Script | Does |
|---|---|
| `sonniss_remote.py list OUT` / `get PICK DEST CAP_GB` | Lists every member of the free your.org mirror zips by HTTP range, then extracts only the picked files. |
| `sonniss_pick.py MEMBERS PICK MAX_MB` | Keyword filter: weapons, whooshes, impacts, UI, magic, creatures, footsteps, stingers; no ambience or long files. |
| `sfx_index.py LIB OUT.jsonl` | Index: path, bundle, pack, category, duration, channels, rate, tags. |
| `sfx_sheet.py GAME LIB INDEX slots.json OUT [MANIFEST]` | Decodes every library file, cuts it into its sounds, measures each (length, onset, decay, spectrum, noise floor) and ranks them against the slot's `fit` profile, with whole-word name matches as a prior. Writes `choices.html` (live sound plus A-D as mp3 players, A the default; a slot with `"picks": 6` in slots.json keeps up to 8), `mapping.json` and every candidate as `MANIFEST` (pick A unless the manifest already holds a pick). |
| `sfx_pack.py build/tester/apply/restore/check` | `build` cuts each slot's pick into the private pack, `tester` cuts every candidate of the tester slots into `PACK/audio/sfxtest/`, `apply` copies both over `audio/` for an export and `restore` puts the tree back (and deletes `audio/sfxtest`, which is also in `.gitignore`). |

`slots.json` maps each slot to the game cue (`audio/<cue>.wav`, takes `<cue>_1..`), its `fit` profile and name words. To add a slot, add an entry and rerun `sfx_sheet.py`.

## Private pack (how a pick reaches the build)
`content/rules/sfx_pack.json` lists the picked cuts as pointers into the library (file name, start, end), never audio. `sfx_pack.py build` cuts them, levels each to the live sound's loudness and writes `<cue>.wav` plus re-pitched takes to the pack, `/home/boki/sfxpack-private/audio` (outside git; override with `BOKI_SFX_PACK`). `tools/build_web.sh` applies the pack over `audio/` just before the Godot export and restores the tree on exit, so the built game plays the library sounds and git never holds one. A machine without the pack exports the generated sounds. To change a pick: edit the manifest (or rerun `sfx_sheet.py ... MANIFEST`), rebuild the pack. `sfx_pack.py check MANIFEST . PACK` confirms every cue has its file.

## Picks and the sound tester (11-15 owner verdicts)
`content/rules/sfx_pack.json` has one entry per slot: the cue, its candidates (file, start, end) and `pick`, the letter the built game plays ("" = the generated sound stays). Picks now: ghost_shot A, ghost_reload B, take_damage B, hit_confirm D, knockout B, scan_capture A, ui_click A, level_up A. glide_start, glide_loop, extract and the dash keep the generated sounds. `sfx_pack.py build` deletes stale pack files first, so a dropped pick leaves the build.

Slots with `"tester": true` (glide_loop, glide_start, dash_ground, dash_air, ghost_shot, ghost_reload) are also in the game: **Settings > Audio > Sound tester** (also from the pause menu) lists each slot's letters (the build's pick starred). A letter plays at once and replaces that cue until Default is pressed, so the owner can glide, dash or shoot with it; **Lock in** writes `user://sfx_picks.json` (`{slot: letter}`), shows it under "Your picks", and plays it again at every start (`SfxPicks`, `SfxTesterPage`). The clips are `audio/sfxtest/<slot>_<letter>.wav` from the private pack, so only an export with `BOKI_SFX_PACK` has them; a dev checkout says so. To find the letters on a pack machine: `sfx_pack.py tester content/rules/sfx_pack.json LIB PACK` after `build`.

The dash is chosen by the floor under it (`HeroSfx.dash_name`): in the air `<arch>_dash_air` else `dash_air`, on the ground `<arch>_dash` else `dash_ground` (both made by `tools/gen_sfx_dash.py`). A tester pick for `dash_air` or `dash_ground` beats every Hunter's own. A glider skin plays its own `glide_start` / `glide_loop` cues (`Gliders`, default `glider_snap` / `glider_wind`; `glider_wind_*` loops from `tools/gen_sfx_glider.py`). A tester pick for `glider_wind` or `glider_snap` replaces the default cues, so a skin with its own loop keeps it.
