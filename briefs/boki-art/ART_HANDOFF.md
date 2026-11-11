# Boki art session: handoff (11-09, 21:10 ET)

You are taking over the **Boki art session** for Project Boki (indie creature-collector). The owner moved this work to a second Claude account to save usage. You get everything the previous art session had: this file, the repo, the tools in `briefs/boki-art/tools/`, and the runner on the owner's Mac. Read this whole file before doing anything.

## 1. Setup (the repo is about 6 GB: never do a full checkout)
```
git clone --filter=blob:none --no-checkout --single-branch -b ext/agent-briefs https://github.com/OrriBogdan2/project-boki
cd project-boki
git sparse-checkout init --no-cone
printf '%s\n' '/briefs/*.md' '/briefs/boki-art/' '!/briefs/boki-art/batch/out/' > .git/info/sparse-checkout
git checkout ext/agent-briefs
```
- Never check out `briefs/boki-art/batch/out/` (8,000+ images), `briefs/art-refs/`, `briefs/shots/` or `art/vendor/`.
- Read any generated image with `python3 -c "import sys; sys.path.insert(0,'briefs/boki-art/tools'); import bload; bload.load('<job_id>_<run>').save('/tmp/x.jpg')"` (it does `git show origin/ext/agent-briefs:briefs/boki-art/batch/out/<stem>.jpg`). Fetch first: `git fetch origin ext/agent-briefs`.
- If git starts pulling a multi-GB pack (lazy blob fetch), stop it. Use `git write-tree --missing-ok` style commands, never `git grep` on the origin tree.
- Disk: delete your render scratch after each batch.

## 2. How images get made
- The **runner** (`batch/gen_boki.py --watch`) runs on the owner's Mac. It uses Vertex AI (Gemini 3 Pro Image, "Nano Banana Pro") on the owner's Google Cloud project. Every ~20 s it pulls the branch, renders every job in `briefs/boki-art/batch/jobs.json` that has no output yet, and pushes "Boki batch: N images" commits into `batch/out/<id>_<run>.jpg`.
- You never call the image model yourself. You **write job specs**, rebuild `jobs.json`, commit and push. Then you wait for the runner's push and read the results.
- If nothing renders for a long time, ask the owner to check the Mac. Past fixes:
  - re-login: `gcloud auth application-default login`, with `export PATH="$HOME/google-cloud-sdk/bin:$PATH"` first
  - a stuck rebase: `git rebase --abort`, then `git pull --rebase --autostash`
  - two runners at once: Ctrl+C the older window

  Give the owner terminal commands one per code block, numbered.

## 3. Job specs (`briefs/boki-art/batch/`)
- `build_jobs.py` execs every `specs_*.py` **in sorted filename order** into `SPECS`, then writes `jobs.json`. The current working spec file is **`specs_zz_wave9zzzzzzzzzzzzzzzzzzzzzz_v2.py`**: append to it. It must sort after the earlier wave files and before `specs_zzz_order.py`.
- **`specs_zzzz_locked.py` runs last.** Its `DROP` set removes jobs: old owner-locked Boki, and promoted Boki whose auto `<name>_card` / `c_<name>` jobs must not re-run. If a new job of yours goes missing, add `DROP-={'your_id'}` there. If promoting a new Boki auto-adds `<name>_card`, add `DROP|={...}`.
- Job ids are unique and **a duplicate id is silently ignored**: always give re-runs a new id.
- After every spec change, run this and check the added/removed list:

  ```
  cp jobs.json /tmp/jb.json && python3 build_jobs.py && python3 -c "import json;a={j['id'] for j in json.load(open('/tmp/jb.json'))};b={j['id'] for j in json.load(open('jobs.json'))};print('added',sorted(b-a),'removed',sorted(a-b))"
  ```

  Then commit the spec, `specs_zzzz_locked.py` and `jobs.json`, and push.
- Useful globals inside specs:
  - `_O` = `'briefs/boki-art/batch/out/'`
  - `_LM` = LIVE_MANIFEST dict (for sheet paths)
  - `_EDIT` = the "Edit image 1: keep everything... Only change this:" prefix
  - V2 helpers from `batch/style_v2.py`: `RS_CARD`, `RS_CARD_BOARD`, `RS_SHEET`, `RS_PORTRAIT`, `STYLE_V2`, `FRAME_V2`, `SRV2`, `SRB`
  - my helpers in the v2 spec file: `V2SHEET_NEW(name, card, cols, counts)` and `V2PORT_NEW(name, card, stage, arch, cols, counts, dark, furry, pose)`
- Push loop (other agents push to this branch constantly): `git fetch` → `git rebase origin/ext/agent-briefs` → `git push origin HEAD:ext/agent-briefs` → check with `git merge-base --is-ancestor HEAD origin/ext/agent-briefs`. Retry up to 4 times. On a `CHANNEL.md` conflict, keep both entries. Push only small appends; never commit a tree with mass deletions; never run destructive git commands (`checkout --`, `reset --hard`) on the work tree.

## 4. Making art live ("promotion")
For a Boki `<Name>` (file ID, not the display name):
1. Back up the old file to `<file>_old.jpg` (then `_old2`, ...; never overwrite a backup). Save the new **card** to `cards/<Name>.jpg`.
2. Save the new **sheet** to the path in `LIVE_MANIFEST.json[<Name>]['sheet']` (`turnarounds/` or `evolutions/`; new Boki: `turnarounds/`).
3. **Portrait:** back up `portraits/{light,dark}/<Name>.jpg` and `portraits/cutout/<Name>.png`, then `import cutout; cutout.make_all(tmp_jpg, '<Name>', 'briefs/boki-art/portraits')` (cutout.py is in `batch/`).
4. Run `python3 briefs/boki-art/tools/refresh_manifest.py` from the repo root. It rebuilds `portraits/cutout_v2` and `LIVE_MANIFEST.json/.md`, and keeps extra keys like `display_name`, `female`, `legendary_tier` and `sex_forms`. New Boki get new entries automatically. Diff the manifest before committing.
5. Post a short note in `briefs/boki-art/CHANNEL.md` (format: `### 11-09 HH:MM ET ART -> COORD`, real Toronto time from `TZ=America/Toronto date +%H:%M`).
6. **Never publish the Bokidex yourself.** The coordinator (Claude Code on the first account) publishes from `LIVE_MANIFEST.json`.

## 5. The style (owner-approved 11-09 17:23): V2 flat cel
- Rules: `STYLE_CANON_V2.md`, `RERENDER_PROMPTS.md`, `REVIEW_CHECKLIST_V2.md`, `MARQUEE_HUMAN_PASS.md` (written by a Fable agent; owner has no human artist, so it's all AI).
- In short:
  - **Shading and line:** flat colour, one hard shade, an even outline in a dark shade of the local colour (never black), no glow/gradient/sparkle.
  - **Highlights:** only on eyes, gems, wet parts and glass.
  - **Blush:** only on babies and cute middle forms.
  - **Darks** stay dark.
  - **Detail:** limited to the face, the signature part and one pattern.
  - **Background:** plain #E8E8EE.
  - **Sheets** are flats.
- **Per-Boki data:** each re-render needs a row: stage (baby/mid/final), arch (cute/pretty/sleek/tough/creepy/majestic), dark, furry, colours line, counts line, optional fix. Write the rows by eye from a contact sheet of the batch's cards. Examples are in the spec file (`_PILOT`, `_B1`, `_B2`, `_B3`).
- **Pipeline per Boki:**
  1. **V2 card:** `RS_CARD` or `RS_CARD_BOARD` with image 1 = the current card, 3–4 runs.
  2. **Pick one card.**
  3. **Sheet:** `RS_SHEET` (old sheet + V2 card) for unchanged designs, or `V2SHEET_NEW` (from the V2 card) for redesigned/new ones, 3 runs.
  4. **Portrait:** `RS_PORTRAIT` (old portrait + V2 card) or `V2PORT_NEW` (from the V2 card, with a pose), 3 runs.
  5. **Pick a sheet and a portrait,** then promote all three.
- **Known failure: "bleed".** About half of all runs are contaminated.
  - **Anchor route** (`SRV2 % arch`, a whole example creature as image 2): parts of the anchor creature leak in, e.g. a white Rimink head floating next to Barostorm, Chandelotl next to Chimelop, black sludge over anglers, purple fog under cute babies. Edits to remove it mostly fail.
  - **Board route** (`SRB` = `style_refs/v2/style_board.png`, nine close-up patches): never leaks creatures, but often pastes the square patches into the corners. A remove-tiles edit (`v2x_bullpole`) is the planned fix; check if it works.
  - **What to do:** 4 runs per card, pick a clean one, and re-run the rest. Check every image for a second creature, corner tiles, floating bits, and anything added or dropped compared with the card.
- **Sheets:** reject a second row, ghost copies, missing views, or a ground line.

## 6. State right now
- **Fully V2 (card + sheet + portrait), 26 Boki:**
  - Vespyx, Coolatee, Rimink, Lockatara, Lurklet, Sarcobra, Aurostag
  - Gongrowl, Anvilbrock, Forgebrock, Furnacowary, Vaultara, Prowyak, Bastionpet, Siegephant, Chuggamus, Canvastross, Crofthollow, Pagoguana, Stormit, Sporcupine, Snapler, Bucketmander
  - new Boki Critwom, Sirencada, Citadoad

  Manifest: 230 entries.
- **In flight** (check results, pick, promote):
  - Barostorm (`v2t_barostorm_1` is clean), Maulangler (`v2t_maulangler_1` clean), Bastling (`v2t_bastling_1`/`2` or `v2x_bastling_*` clean), Barrelmander (`v2x_barrelmander_*` clean), Domeleon (`v2x_domeleon_*`: check), Chimelop (card `v2t_chimelop_3`; `v2s_chimelop`/`v2p_chimelop` queued).
    - The clean ones still need sheets + portraits (`V2SHEET_NEW`/`V2PORT_NEW`, data rows in `_B1`, poses in `_B1POSE`).
    - Bastling is new; give it `turnarounds/`.
  - **Pill bug line** (owner OK 20:39–20:41): Pinster (baby, curls into a chrome ball) → Tiltster (big pill bug with a pinball table back). Types Steel/Bug.
    - Cards live from concepts.
    - V2 picks `v2t_pinster_4`, `v2t_tiltster_4`; sheets/portraits queued as `v2s_pinster`, `v2p_pinster`, `v2s_tiltster_pb`, `v2p_tiltster_pb`.
  - **Bullpole:** chevron marks live (card `pk_bullpole_chevron_2`). V2 card runs all pasted board tiles; `v2x_bullpole` is the tile-removal edit.
  - **NEW jerboa line, Electric (owner 21:00):** **Jerbit → Jerbolt → Dynaboa**.
    - Concepts: `c_jerboa_baby_3`, `c_jerboa_final_crest_2` (middle: static-fur crest), `c_jerboa_final_vanes_2` (final: copper turbine fins).
    - V2 cards queued as `v2t_jerbit`/`v2t_jerbolt`/`v2t_dynaboa` (data in `_B3`).
    - They become new manifest entries when promoted.
  - **Effigeetle redesign** (owner: it doesn't fit its cocoon/moth line): caterpillar concepts `rd_effigeetle_a_*`/`_b_*`. Display name already Sculptillar.
- **Owner notes waiting for his pick** (Round 8d on the old A/B page):
  - Glaivyx white inner fur (`v2g_glaivyx_white_2` is my pick).
  - Cindermaw circling (`v2p_cindermaw_circle_3`).
  - Glassolotl poses (`v2p_glassolotl_rear_2`; a facing-left retry is `v2p_glassolotl_left2`).
  - Chandelotl colour schemes (`v2c_chandelotl_*`; he hasn't picked, pink is the default).
  - Ringrove stronger head tilt (`v2g_ringrove_tilt2`).

  These five pilot Boki still need their final V2 card chosen, then sheet + portrait.
- **Female looks:**
  - Card only so far: Arcestrel, Hourachnid, Pavonazar, Gongrowl, Furnacowary (`manifest[Name]['female']`). Their female sheets and V2 versions are still to do.
  - Earlier females: Voltalon, Sandwidow, Eclipsowl, Murmurling, Murmuron, Kestrike, Lunowl, Gongibbon.
  - Babies have no female look by design.
- **Names** (owner-approved, applied as `display_name`; file IDs never change):
  - Final list: `BOKI_NAMES.csv`; for main: `MAIN_PUSH_LIST.md` section 6.
  - Pokémon look-alike check: `POKEMON_CHECK.md`.
  - Not yet in the CSV: Jerbit, Jerbolt, Dynaboa, Sculptillar caterpillar. Chimelop shows as Jinglop.
- **Remaining roster:** about 200 Boki still in the old painted style. Batches of 30 in dex order. Starters and legendaries first is fine.

## 7. Owner preferences (keep these)
- **Picks:** he gave the art session **full pick control** at 19:51 ("you've been picking well, I'll review them"). Pick, promote, then show him a short before/after. Revert if he objects; old files are kept.
- **Pokémon:** no Boki may look or sound like a Pokémon. Run new names through the check: the PokeAPI CSV at `raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/pokemon_species_names.csv`, keeping difflib similarity below ~0.72.
- **Names:** blended pun names like the originals (Sabryx, Duskargot, Cubwom), never two plain words ("Bladefox" was rejected).
- **Design:** born-with parts only (nothing strapped, belted, bolted or worn), one way of moving, babies sit or bounce, finals planted. He dislikes gross/slimy looks (Glaivyx and Vespox drips were removed) and anything that reads as AI slop.
- **Communication:** short, plain answers. Terminal commands one per block. Show images as one comparison strip with clear labels.
- **Usage:** keep it light. Review images as small thumbnails in grids, never one at a time.

## 8. Other agents
- **Coordinator** = Claude Code on the first account (owns the Bokidex, game data and main). Talk to it only through `briefs/boki-art/CHANNEL.md` entries on this branch.
- **Owner's decisions log:** `briefs/DECISIONS.md` (the hunters → mobs → Boki order there is for **3D**, not this 2D work).
- The old A/B review page and Bokidex artifact belong to the first account; you can't edit them. Make your own review page if useful.

## 9. First steps for you
1. Set up the checkout (section 1). Read this file and the last 40 entries of `CHANNEL.md`.
2. `git fetch`, then look at the in-flight results in section 6 (one grid per group). Pick, promote, commit, push, and post to CHANNEL.
3. Tell the owner in one short message what went live, then continue with the in-flight items, then batch 2 of the roster.

## 10. Update 11-09 22:12 ET (second-account art session). Read this after sections 1-9; where they disagree, this wins.
- **Bleed is solved: use the text-only route.** No style image at all, the style in words: `RS_CARD_TEXT(...)` in the v2 spec file (same arguments as `RS_CARD`). 180+ images so far with no second creature and no board tiles. Do not use `SRV2` anchors or the `SRB` board any more. For new poses and design changes use `ON_POSE` (ref = the sheet; a card ref keeps the old pose) and `ON_CHANGE` (ref = the card).
- **Stage B for unchanged designs:** `RS_SHEET` (old sheet + V2 card) and `RS_PORTRAIT` (old portrait + V2 card). For new or changed designs: `V2SHEET_NEW` / `V2PORT_NEW` from the V2 card. Sheets 3 runs, portraits 2.
- **Promotion tools (run from the repo root, need `pip install opencv-python-headless scipy`):**
  - `python3 briefs/boki-art/tools/promote.py Name card_stem sheet_stem portrait_stem [dc]` (card_stem `-` keeps the card; `dc` removes floating bits from the portrait)
  - `python3 briefs/boki-art/tools/promote_card.py Name:stem[:dc] ...` (card only)
  - `python3 briefs/boki-art/tools/refresh_names.py Name ...` updates only those manifest entries and heroes. **Do not run the full `refresh_manifest.py` on a cloud machine:** a different OpenCV re-cuts all heroes and moves every hero hash.
- **Card backdrops must be flat.** Scopeleon's "bug" in the dex was a shaded backdrop that the cut-out kept. Check `portraits/cutout_v2/<Name>.png` on a dark background after promoting anything that looks shaded.
- **State (11-10 late evening):** manifest 259, all with card + sheet + portrait + hero; 14 female forms; 19 legendaries, each with the HALO CROWN mark (a ring of its own material above its head; apply `_HALO` in the spec file to any new legendary). Coolatee line kept (aurora look). Five new lines added (penguin, sawshark, kangaroo, crocodile, carousel horse), plus Barokit, Tesselamb and seven new legendaries. `LINE_REVIEW_1110.md` holds three roster reviews with ranked alternatives.
- **Open:** Calderoise sheet + portrait with the halo (`v2s_/v2p_calderoise_halo`); the owner counts five mushroom families as one too many (Fawnshroom rework was rejected as worn hats; Glomwort is the other candidate); the last ~60 sheets were chosen by `tools/autopick_sheet.py` and portraits taken as run 1, so spot-check them.
- **Tools added:** `promote_female.py`, `flat_bg.py` (shaded card backdrops; `--nofill` for open rings), `sheet_clean.py --dry`, `refresh_names.py` (never the full refresh on a cloud machine).
- **In flight:** olm line sheets + portraits (`v2s_/v2p_<olmlet|glazolm|kintsuwyrm>_wc`); post READY to the coordinator when promoted.
- **Open for the owner:** his verdict on the overnight picks; Knotwyrm sheet redo; Kestrike and Pavonazar female colours; whether Maracoil gets another round.
- **Method notes:** an edit (`_EDIT`) keeps pose and design best for recolours and small fixes; `ON_POSE` needs the SHEET as reference (a card reference keeps the card's pose); options = `OPT`/`OPTB` (3 directions x 2 runs), promote only clear winners, show the owner strips with 1st/2nd/3rd marked. The owner wants this EVERY time a choice is made or offered (11-10: "always show me your 1-3"), including picks made on his behalf.
- **Owner rules added 11-10:** (later the same day) avoid more "rocks, trees or buildings growing on a creature" designs, the roster has plenty; legendaries get the EPIC look (`EPIC()` in the spec file) except the deliberately cute ones, and he is happy to have many cute legendaries; always check a promoted card is not cut off by the frame (three epic picks were); `tools/flat_card.py` keeps backdrops on spec; `tools/autopick_sheet.py` screens sheets when there are too many to eyeball. full pick control includes design changes ("you have permission to change anything"); for anything doubtful queue several different options and keep the live one unless an option is clearly better; a middle stage should keep one thing from the baby and show one thing of the final. Poses within a line just have to differ from each other; do NOT apply a fixed ladder (baby sits / middle moves / final planted): the owner finds that predictable (11-10). The full line review is `LINE_REVIEW_1110.md`.
- **build_jobs.py quirk:** a job id that was ever in `jobs.json` can survive a rename in the spec; if a stale id shows up in the added list, put it in `DROP` in `specs_zzzz_locked.py`. Ids containing `glaivyx` or `ringrove` are dropped by an old rule unless un-dropped there.
- **Dex side:** the coordinator swaps protected or owner-approved heroes only on the owner's word in its own chat.
- **Waiting on the owner:** a name for the new sea-pup Anchorbill (proposal: Anchorpup).
- **Owner notes 11-09 evening, all handled except:** Tiltster "head not very on" (not changed; ask him about the new V2 card), Parrywhal Pokémon look-alike check (not done), Effigeetle caterpillar (the `rd_effigeetle_*` concepts have floating gold bits and a human-like face: redo with `ON_CHANGE`).
- **Roster pass:** no batches left; the work is the in-flight list above.

### Standing rule: sharing splashes and key art (owner, 11-10 evening)
Owner: "i wont ask again, always do it to the art branch and tell it to store them." Every splash or key art keeper goes, without being asked, into `briefs/boki-art/splash/` or `briefs/boki-art/og/` on `ext/agent-briefs`, is listed in `PICKS_FOR_MAIN.md` with its status, and gets a CHANNEL.md note telling main to store it in the game repo's permanent art folder. Never push to the main branch.

### State at 11-10 night (owner low on usage until Sat 11pm reset: keep check-ins rare and short)
- Full pixel sprite run queued: `px9_<id>` for all 259 (80px look). Not reviewed. Next step: run the finish step, build a contact sheet, redo the thin dark ones.
- Turnarounds behind: Kingpinguin (Pipguin), Maracoil, Pavonazar (`v2s_*_L2`, 5 tries each, queued).
- Owner picks so far: tent splash = Tenzo; Sable vault splash approved; link image not picked (options sheet sent, my order egg_A, storm_A, aurora_A).
- Still to do: Tiltster + Rimink lighter finish, independent recheck of turnarounds changed 11-10, use 3d-refs for angles in new splashes.

### START HERE for the next art session (written 11-11, supersedes the "State at 11-10 night" list above)
Everything queued has rendered. Nothing is running. To do, in order:
1. **Pixel sprites.** `batch/out/px9_<id>_1.jpg` exists for 257 Boki (80px DS-style look, prompt `_PX8` in the wave9 spec). Post-process each: flood-fill the white background from the image edges, crop to the creature, resample to 80px on the long side taking the dominant colour per cell, quantise to 14 colours, save as PNG with alpha. Build ONE contact sheet, look at it once, redo only the bad ones (thin dark Boki such as Chainipede, Aurostag, Zephyrak, Palloth go noisy; add `runs` for those). Two Boki were skipped because their card filename differs from the manifest key: find and add them. Owner's bar: "doesn't need to be perfect, just has to look good". Output folder: `briefs/boki-art/pixel/`. Then tell main in CHANNEL.md.
2. **Turnarounds behind** (`python3 briefs/boki-art/tools/sheet_audit.py`): Kingpinguin (display name Pipguin), Maracoil, Pavonazar. Five tries each are rendered as `v2s_<id>_L2_1..5`. Pick one with exactly four views, no ghost row (tools/topclean.py), no ground line, matching the card; save to the manifest sheet path; `refresh_names.py`; `sheet_audit.py mark`.
3. Tiltster and Rimink: lighter, flatter finish (first edits failed: Tiltster lost its blue shell, Rimink came back unchanged).
4. Independent recheck (subagent) of every turnaround changed on 11-10 against its card.
5. Owner still owes: Bokidex link image pick (options in `og/`, my order egg_A, storm_A, aurora_A). When he picks, tell main; main adds logo + "Meet the Boki." on the dark left side.
Owner prefs that matter most: short plain messages; always show 1st/2nd/3rd; pick and push without asking; keep a high bar; every splash/key art keeper goes to `splash/` or `og/` with a CHANNEL.md note telling main to store it; hunters must match their master sheet in `briefs/art-refs/<hero>_v2/` (Sable: solid black eyes, four moth wings; Lace: no face mask, mask on left shoulder; Albert: round plank hull body, not a knight); Boki in splashes are painted in the same 3D-looking finish as the hunters; 3D model renders are in `3d-refs/`. Never push to main.

### Update 11-11 (later the same day): the "START HERE" list above is DONE
1. Pixel sprites: all 259 in `pixel/<FileId>.png` (tool: `tools/pixel_sprite.py Name[:stem[:holes]]`, `--sheet out.jpg` for a contact sheet). Redos used `px9b_*` (chunky prompt) and `px9c_*`. Glaivyx/Ringrove were missing because of the old name DROP rule, not a filename difference.
2. Turnarounds Kingpinguin, Maracoil, Pavonazar replaced; `sheet_audit.py` shows 0 behind.
3. Tiltster and Rimink: lighter card, sheet, portrait and hero (`rv_*_light2_2`, `v2s_/v2p_*_lt_2`).
4. Recheck of 270 sheets: 260 passed. Replaced Malletary, Meteorab, Blastopuff, Voltmink, Lunowl, Barokit, Lunowl_female, Hourachnid_female. Left as is (minor): Murmuron (faint smear under the views), Murmuron_female (wings folded on the sheet, spread on the card).
5. Bokidex link image: owner says handled.
Note: `promote_female.py` re-cuts the female hero even when the portrait is `-`; restore `cutout_v2/<Name>_female.png` and its hero hash if you only changed the sheet.

### OWNER RULE 11-11 (replaces "full pick control" for design changes)
"Try a bunch of stuff, I don't want to pick until I see, as a rule. Always show me your favorites and 2nd / 3rd."
So: for any design change, queue several directions (3-4 x 2 runs), show ONE labelled strip with your 1st/2nd/3rd, and promote only after he picks.
Open from 11-11: back-scenery rework (Terrarimit, Mosstodon/Mossbastion, Vatmander/Cisternmander, Crofthollow, Briarlynx shave, Soakybara + Geyserbara water ideas; ids opt_<id>_<k>_bk, shave_briarlynx_*).
Cairnback held back (3D model in game; its ability throws its cairn stones). Kestrike female (fopt_kestrike_line_1) and Pavonazar female (fopt_pavonazar_ring_2) are proposed, not live.
Crofthorn (earlier form) and Dribbara (baby) follow whatever is picked for their finals.
