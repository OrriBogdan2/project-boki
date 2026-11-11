# Handoff: Cleavypus, T3 of Pocketpus > Bladypus (owner 11-11)

The game has no Pocketpus line (`content/kin` has 50 kin), so this lands in the Bokidex and the art lane, not in game data.

- **Name:** Cleavypus. Options were Cleavypus, Machetypus and Scythypus; Scythypus is too close to Scythant and Glaivypus too close to Glaivyx. No clash in BOKI_NAMES.csv or dex.json.
- **Type:** Poison (the line stays single-type). Dex #145, right after Bladypus #144 (chain_order).
- **Lore:** "Cleavypus has unfolded every blade it owns and never folds shut again. It lurks in river shallows with its saw and hook raised like reeds, and one slap of its cleaver tail splits a drifting log."
- **2D (vertex-gen):** pick `c1c`, card `briefs/boki-art/cards/Cleavypus.jpg`. The candidates sheet is `/home/boki/meshy/boki3d/cleavypus/candidates-1111.jpg` and the line sheet is `line-1111.jpg` in the same dir.
- **Art lane (uncommitted in /home/boki/briefs-wt):** card, `portraits/cutout_v2/Cleavypus.png`, LIVE_MANIFEST entry, ROSTER_200_NEW.md row 15 and a `Cleavypus (3 of 3)` section.
- **Bokidex:** `/home/boki/meshy/boki3d/cleavypus/dex-patch/apply.py` (use `--dry` first) adds the entry, alias, state and lore, links the line and renumbers. It was tested on a copy of the live dex. The worker could not write the live dex.
- **3D:** the Meshy multi-view step is done (`mv/`). The gen step stopped at the 600 credit floor. Re-run it after a top-up and after apply.py: `boki3d-batch --ids cleavypus`. Then run `dex-glb-sync --only cleavypus`, `bokidex-site-export` and site `tools/bokidex/patch.py`, and render `fix-1111.jpg`.
