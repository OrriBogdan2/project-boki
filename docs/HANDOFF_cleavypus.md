# Handoff: Cleavypus, T3 of Pocketpus > Bladypus (owner 11-11)

The game has no Pocketpus line (`content/kin` has 50 kin), so this lands in the Bokidex and the art lane, not in game data.

- **Name:** Cleavypus. Options were Cleavypus, Machetypus and Scythypus; Scythypus is too close to Scythant and Glaivypus too close to Glaivyx. No clash in BOKI_NAMES.csv or dex.json.
- **Type:** Poison (the line stays single-type). Dex #145, right after Bladypus #144 (chain_order).
- **Lore:** "Cleavypus has unfolded every blade it owns and never folds shut again. It lurks in river shallows with its saw and hook raised like reeds, and one slap of its cleaver tail splits a drifting log."
- **2D (vertex-gen):** pick `c1c`, card `briefs/boki-art/cards/Cleavypus.jpg`. The candidates sheet is `/home/boki/meshy/boki3d/cleavypus/candidates-1111.jpg` and the line sheet is `line-1111.jpg` in the same dir.
- **Art lane (uncommitted in /home/boki/briefs-wt):** card, `portraits/cutout_v2/Cleavypus.png`, LIVE_MANIFEST entry, ROSTER_200_NEW.md row 15 and a `Cleavypus (3 of 3)` section.
- **Bokidex:** applied 11-12 (`dex-patch/apply.py`, backups `.bak-cleavypus-11120136`): Cleavypus #145 after Bladypus #144, prev/next linked, lore in. `bokidex-site-export` (runs site `tools/bokidex/patch.py`) rebuilt `/home/boki/site-repo/bokidex`; that tree is left uncommitted for the site owner/coord.
- **3D:** done 11-12. `boki3d-batch --ids cleavypus` (Meshy mv image-to-image + multi-image-to-3d meshy-7.1, judge 82, 44 cr), `dex-glb-sync --only cleavypus` (Bokidex 3D viewer and Model Room read the dex glb). There was no earlier model, so there is no model_prev_1111.glb. Sheets: `/home/boki/meshy/boki3d/cleavypus/fix-1111.jpg` (BEFORE no model | AFTER front/3-4/side/dex, light+dark) and `line-1111.jpg` (Pocketpus | Bladypus | Cleavypus 2D+3D, plus the 3 candidates).
- **Game data:** none. The game has no Pocketpus line yet; when the line is ported to `content/kin`, Cleavypus is its stage 3.
