# Handoff: Sorbeast, T3 of Scoopsy > Sundormouse (owner 11-11)

The game has no Scoopsy line (`content/kin` has 50 kin), so this lands in the Bokidex and the art lane, not in game data.

- **Name:** Sorbeast. Options were Sorbeast, Glaciermouse and Conequake; Glaciermouse is too close to Glaciatee and Glaciammoth. No clash in BOKI_NAMES.csv or dex.json.
- **Type:** Ice/Normal (same as Sundormouse). Dex #205, right after Sundormouse #204 (chain_order). Line heroScale 0.72 / 0.8 / 1.0.
- **Lore:** "Sorbeast is what a Sundormouse becomes once it stops sleeping through the cold. It prowls glacier edges at dusk, and its two ice fangs freeze whatever they bite; one swing of its spiked cone tail shatters a frozen pond."
- **2D (vertex-gen):** picked `c3_sorbet` (sabre ice fangs, swirl mane, spiked cone-club tail). Card `briefs/boki-art/cards/Sorbeast.jpg`. Sheets in `/home/boki/meshy/boki3d/sorbeast/`: `candidates-1111.jpg`, `line-1111.jpg`, `fix-1111.jpg`.
- **Art lane (uncommitted in /home/boki/briefs-wt):** card, `portraits/cutout_v2/Sorbeast.png`, `portraits/light/Sorbeast.jpg`, LIVE_MANIFEST (json+md), ROSTER_200_NEW.md row 21 and a `Sorbeast (3 of 3)` section, BOKI_NAMES.csv, DEX_ORDER_PROPOSAL.md row 78+.
- **Bokidex:** applied to the live dex with `/home/boki/meshy/boki3d/sorbeast/dex-patch/apply.py` (backups `.bak-sorbeast-11120139`).
- **3D:** `boki3d-batch --ids sorbeast` judge 82 (pass 75), 44 cr; judge note: base reads a bit pink and the mane is flatter than the 2D. `dex-glb-sync --only sorbeast` done (it also linked cleavypus's model). `bokidex-site-export` ran (patch.py included); `/home/boki/site-repo` is left uncommitted and undeployed for the coordinator.
