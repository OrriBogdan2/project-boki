# Sable (thief): import note

## LIVE v95 master in game (2026-11-12, ext/hunters-v95-ingame)
`~/meshy/v95/Sable/r2/prop1111/cand_B.glb` (CURRENT_OVERRIDES 11-12: solid grey-black eyes, up-pitched moth wings) swapped onto the 11-12 owner-fix sable.glb below, so its narrower idle and stance clips stay. The fix's wing reweight is not re-run: it picks fur below the waist for the old hanging wings and would hang these wings on the thighs and shins; instead the spec's last region gives the wing films (x ±0.36, behind y -0.215, z 0.3-0.84) to the hips whole. 13.0k tris, one 2048 atlas, 47 clips.
Spec `art/wardens/src/sable_v95.json`; proof sheet ~/meshy/v95/_closeups/ingame-1112/sheet.jpg.

## Owner fix 2026-11-12: wings and stance (`tools/art1/warden_fix_1112.py sable`, on the 11-10 file)
"Wings clip through her and her stance is weirdly wide." The moth wings (fur below the waist at the back, grown over the
mesh) had hand and thigh weights from bone heat, so the arms dragged them through the legs. They now ride `hips` at the
root and their own thigh below (both thighs blended across the middle), up to 75% of the shin under the knee, and sit
2.5 cm further back. The `idle` and `stance` clips bring the knees under the hips (knees 0.27 -> 0.19 m apart in idle,
0.32 -> 0.20 in stance; ankles 0.16-0.17 m), the feet kept as they were. Eyes untouched. Wing verts within 2 cm of a leg
over idle, walk_f and run_f: 96 (was 1894). Stretch check worst 18.03 (unchanged).

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

walk_fl, walk_fr, walk_bl, walk_br, run_fl, run_fr, run_bl, run_br, run_r (2026-11-11; the judge kept only these): `blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- art/wardens/sable/sable.glb OUT.glb 1.39 2.9`
(the speed / 1.4, the game's rate cap her `loco.foot_mps` hits, / 1.13, what her `loco.stride` 1.5 adds to a planted sole), then
`python3 tools/art1/glb_add_clips.py art/wardens/sable/sable.glb OUT.glb walk_fl,walk_fr,walk_bl,walk_br,run_fl,run_fr,run_bl,run_br,run_r` (judge: docs/art/wardens/dirloops/JUDGE.md).

walk_b, run_b, run_l (2026-11-11, second pass; the judge kept only these): the hand-keyed loops re-strided,
`blender -b --factory-startup --python tools/art1/hunter_dir_gait.py -- sable.glb B.glb 1.39 2.9 b+,l+`, then
`glb_add_clips.py sable.glb B.glb walk_b,run_b,run_l` and the diagonals walk_bl, walk_br, run_bl, run_br copied back
after it (prefix match: walk_b replaces walk_bl/walk_br too).

Merge of main's v95 cand_B swap (2026-11-13): `sable.glb` = main's model and clips byte for byte (incl. its walk_f/l/r and
run_f, the owner-fix idle and stance), plus the branch's walk_b, run_b/l/r and the eight diagonals by `glb_add_clips.py`
(same 57 joints, rest pose equal; main's walk_f/run_f keep the branch loop's length and hips track, legs within a few
degrees, so the ring stays in step). Alternative not taken: the branch's whole ring incl. its older walk_f/run_f.
