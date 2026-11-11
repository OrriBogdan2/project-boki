# Sable (thief): import note

## Women body pass 11-11 (ext/women-body-1111): the current sable.glb

`~/meshy/v95/Sable/r2/body5/cand_3.glb` (pick.txt and sheet_sable.jpg beside it; cand_4 is the gentler alternative) is appeal4 `cand_6_motheye.glb` (the braid forward, the sly face, the solid grey/black moth eyes of the owner's 11-11 correction, a rounded bust) with a position+normal displacement: waist and shoulders in, hips, glute and bust fuller (max move 3.5 cm, area p95 1.16 / p99 1.31). Eyes and paint untouched. No wings: ext/sable-wings stays out of 0.24.5, and this build carries none (the spring_wing chains stay unweighted, as on appeal3 b). `art/wardens/src/sable_v95.json` reads it. The swap ran on ext/women-body-1111's older tree (d31afaa66), so the 0.24.5 glb's clips were copied back on by node name (tools/art1/glb_add_clips.py, same skeleton: the pet/give/cheer clips and the last frame the older swap dropped) and the glb's orphaned bytes dropped. Shots: docs/shots/women-body-1111/ (sheet_<name>.jpg is 0.24.5 against this build, front and side, rest pose).

## v95 swap, appeal3 body b with the bug eyes (2026-11-10, ext/sable-appeal-b): the current sable.glb

The mesh is the owner's pick (11-10): Sable's v95 master, appeal3 body variant b with the owner-ordered moth/bug eyes
(solid grey eyes, one catchlight), `~/meshy/v95/Sable/r2/appeal3/cand_b_bugeye.glb` (pick.txt beside it; one mesh, face included).
`tools/art1/v95_swap.py` put it on her own skeleton, 47 clips and anchors with `art/wardens/src/sable_v95.json`
(docs/art/wardens/V95_SWAP.md):

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/sable_v95.json WORK art/wardens/sable/sable.glb

13k triangles, one embedded 2048 atlas (Godot extracts it to `sable_atlas.jpg`), no normal map (`sable_normal.jpg` dropped).
The pistols are fused to her hands in the master: rigid on hand.R / hand.L. The long ears, braid, coat tails and tail feathers
are weighted by bone heat and the head box. Slots by colour and box (first match wins): metal (pistols), hair, fur (ears, tail
feathers), skin (head), glow (gem), leather (boots, belts), cloth (coat, trousers). Shots: docs/shots/sable-appeal-b/.
Lost against the v2 build below: the antenna, braid, wing and coat-tail spring chains stay in the rig but carry no mesh, the
hip knives, the procedural pistols and the wing alpha cards.

## Previous build: v2 (2026-11-06)

The owner's v2 redesign (2026-11-06; briefs/art-refs/sable_v2 on ext/agent-briefs; its index.md and "Notes for 3D" win). Built by script from sable_v2_turnaround.jpg, with sable_v2_master_sheet.jpg for detail; nothing is hand-edited in Blender.

    WT=$PWD M=~/meshy/sable_v2 bash tools/art1/sable_build.sh source   # plain (no "source"): finish + clips only

`sable_source.py` fits the scan to the rig, `sable_finish.py` joins it with `sable_pieces.py`, unwraps, bakes, paints (`sable_paint.py`), skins and exports, `sable_clips.py` keys the clips. Recipe and prompts: art/wardens/src/sable_recipe.json. Run log and credits: docs/art/wardens/PIPELINE.md "Sable v2". The raw run stays in ~/meshy/sable_v2 (never in git).

- **Budget:** 14,893 tris, 8 materials, one 2048 atlas, baked normal map. Shared armature, every FX point and anchor name, the 47 clips and the kit wiring are unchanged.
- **Scan:** Meshy multi-image of four edited turnaround crops. It keeps the body, coat, belt, gem and chain positions. The edits take out the antennae, braid, wings, coat tails, knives, keys and pistols, which `sable_pieces.py` rebuilds so they can move and stay in budget.
- **Canon choices:** ONE long white braid (the small sheet views wrongly draw two), on the existing spring chain, its lobes zigzagging with a shallow pinch and chevron creases painted on. Fuzzy moth antennae on a short spring replace the old head wings: feather plumes in a V, a thin dark stem with dusty lilac fuzz on both sides (two sheets back to back, 192 tris each). Top of the model about 1.97, so `height_3d` in tools/warden_model_check.gd is now 1.06 (the old wings stood taller still).
- **Coat:** the front edges are rigid to the torso (no chest bone, so "hips"), so the plunge holds in runs, dashes and shooting. Tails and moth wings are short bone chains; the wings are alpha cards projected from the turnaround's back view.
- **Weapons:** twin flintlocks skinned to hand.R / hand.L, procedural silver and maroon wood with violet runes and a crystal, scaled up from v1 to the sheet (not projected from it). The silver and wood ramps sit a step under the sheet because the engine's toon light lifts them; the muzzle halos are small so the barrels keep their grey. Two moth-curved knives on each hip, from the turnaround's side view (the master shows two on her right). `anchor_bola` keeps its name on the hips; the kit needs the name.
- **Face and skin:** the scan's stitched mouth was removed in three places: the low mesh's crease smoothed (`sable_finish.py`), the normal bake flattened there, and a thin smile painted (`face_fix` in `sable_paint.py`). The same pass grades the skin toward the sheet's grey-lilac (tuned in the engine: a step below the hair, not the Blender preview), redraws the beauty mark, cleans collar violet off the neck and paints the cut buns back to hair.
- **The back of the skull:** the buns the scan grew are cut in `sable_source.py`; `hairback()` closes the hole with a fitted ellipsoid down to the nape.
