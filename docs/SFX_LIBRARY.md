# Sound-effect library (Sonniss GDC bundles)

A private library of real recordings for choosing better game sounds. **No library file, raw or edited, goes into this repo.**

## Licence (Sonniss GDC Game Audio Bundle licence v2.0, effective 2026-08-27)
- Allowed: use and edit the sounds in a game we ship, sell or share; no attribution; unlimited projects; sharing inside the team.
- Not allowed: supplying them "as sound effects" (raw, edited or re-designed) in a library, asset pack, template or SDK; claiming we recorded them; using them to train AI or build SFX generators.
- So: the **built game** may contain them. The **public GPL-3.0 repo may not**, and the GPL cannot cover them. Keep the library and any clips cut from it private; a swap job must pull the chosen clips into the export from a private asset pack (a private repo or bucket), not commit them to `audio/`.
- AI use: choosing is done from file names, folders and measured clip shape. Audio is never uploaded to an AI service.
- The yearly PDFs on the mirror are older licence versions; the version in force on the download date governs (we downloaded 2026-11-13, so v2.0).

## Tools (`tools/sfx_library/`, run with `python3 -I`; sheets need numpy and ffmpeg)
| Script | Does |
|---|---|
| `sonniss_remote.py list OUT` / `get PICK DEST CAP_GB` | Lists every member of the free your.org mirror zips by HTTP range, then extracts only the picked files. |
| `sonniss_pick.py MEMBERS PICK MAX_MB` | Keyword filter: weapons, whooshes, impacts, UI, magic, creatures, footsteps, stingers; no ambience or long files. |
| `sfx_index.py LIB OUT.jsonl` | Index: path, bundle, pack, category, duration, channels, rate, tags. |
| `sfx_sheet.py GAME LIB INDEX slots.json OUT` | Per slot: 4 trimmed, levelled (`content/rules/sfx_levels.json`) .ogg candidates, the grey "now" row, `sheet.html`, `mapping.json`. |

`slots.json` maps each slot to the game cue (`audio/<cue>.wav`, takes `<cue>_1..`) and holds the search words. To add a slot, add an entry and rerun `sfx_sheet.py`.

## Swapping a pick in
`mapping.json` lists, per slot, the cue, the "now" file and candidates A-D (library path, clip, length). A swap job reads the owner's letter per slot, converts the clip to `audio/<cue>.wav` (44.1 kHz mono 16-bit, already levelled), keeps take counts, and runs `--sfx-set-check`. The clips are private (see above).
