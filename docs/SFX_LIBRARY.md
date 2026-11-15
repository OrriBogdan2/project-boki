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
| `sfx_sheet.py GAME LIB INDEX slots.json OUT [MANIFEST]` | Decodes every library file, cuts it into its sounds, measures each (length, onset, decay, spectrum, noise floor) and ranks them against the slot's `fit` profile, with whole-word name matches as a prior. Writes `choices.html` (live sound plus A-D as mp3 players, A the default), `mapping.json` and the A picks as `MANIFEST`. |
| `sfx_pack.py build/apply/restore/check` | Turns the manifest into the private pack, copies it over `audio/` for an export and puts the tree back. |

`slots.json` maps each slot to the game cue (`audio/<cue>.wav`, takes `<cue>_1..`), its `fit` profile and name words. To add a slot, add an entry and rerun `sfx_sheet.py`.

## Private pack (how a pick reaches the build)
`content/rules/sfx_pack.json` lists the picked cuts as pointers into the library (file name, start, end), never audio. `sfx_pack.py build` cuts them, levels each to the live sound's loudness and writes `<cue>.wav` plus re-pitched takes to the pack, `/home/boki/sfxpack-private/audio` (outside git; override with `BOKI_SFX_PACK`). `tools/build_web.sh` applies the pack over `audio/` just before the Godot export and restores the tree on exit, so the built game plays the library sounds and git never holds one. A machine without the pack exports the generated sounds. To change a pick: edit the manifest (or rerun `sfx_sheet.py ... MANIFEST`), rebuild the pack. `sfx_pack.py check MANIFEST . PACK` confirms every cue has its file.
