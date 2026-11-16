# Kael (juggernaut): import note, v95 swap of Kael appeal3, body c (2026-11-10)

`kael.glb`: the owner's pick (11-10), Kael v95 r2 appeal3 `cand_c.glb` (body variant c with the new appeal3 face:
waist taper, arms and shawl 5 cm in per side), swapped onto juggernaut's own skeleton, clips and anchors by
`tools/art1/v95_swap.py` (docs/art/wardens/V95_SWAP.md) with `art/wardens/src/kael_v95.json`. Raw files in
~/meshy/v95/Kael/r2/appeal3 (never in git); the spec reads `kael_v95_c_body.glb`, which is `cand_c.glb` without its
own sword mesh (`kael_sword`): the game's skinned sword stays.

    blender -b --factory-startup --python tools/art1/v95_swap.py -- art/wardens/src/kael_v95.json WORK art/wardens/kael/kael.glb

Body: 13k triangles (head 2.6k), one 2048 atlas and the master's emission map baked beside it (`"emit": true`), both
embedded (Godot extracts them to `kael_atlas.jpg` and `kael_emit.jpg`). The curse veins are the emission map, tinted
by juggernaut.json `model_glow.core` as before. Slots by colour, bone and box (first match wins): leather (dark),
metal (grey), hair (white, in the head box), skin (chest, both arms, the face's warmer parts), cloth (the crimson
shawl, scarf and sash; the pale shawl; most of his pale face, which the cloth slot keeps warm where kael's skin slot,
with its cool shadow tint, turns it lilac). The face has one rule ahead of hair and skin (face box, s 0.04-0.4, v
0.35-0.95): its tones sit either side of the skin rule's s 0.08 and its ridge highlights took the hair slot, so the
skin and hair triangles drew a pale lilac-blue streak down the nose; the white hair (s < 0.04 or v > 0.95) stays hair.
Weights: bone heat from the spec's joints, limbs on the rig's own segments (`spread: "rig"`); the shawl rides the
hips box, its shoulder wings the pauldrons (minus the upper arms), the head box the head. The master's wrist cuffs and
chains ride the hands; the old spring chains (hangcuff, hangwarchain) stay in the rig, unweighted.

**Curse side:** the v2 build mirrored the scan so the curse sat on his right (sword) arm. The appeal3 master paints it
on his LEFT arm and chest, as the v2 turnaround does, and the swap keeps the master's paint: the bare veined arm and
crimson hand on the left, the black glove on the right (sword) hand. The arm blooms (warden_look `kael`, on
anchor_arm_up / _elbow / _fore) move with it: the spec's `anchor_bones` puts them on upper_arm.L / forearm.L.
Alternative not taken: mirror the master's texture to keep the curse on the sword arm.

Kept from the old build (`keep_mats`): the skinned sword (glow-sword, leather-grip, metal-sword, _dk, _edge; 0.9k
triangles, weighted to hand.R; `skinned_weapon` in content/rules/warden_anim/kael.json), with weapon_muzzle,
anchor_blade_mid and anchor_blade_root on hand.R along the blade, unchanged. Gone: the alpha cards and their sheet
`kael_cards.png` (the master models the torn hem and sash), the scripted wrist chains.

Clips: the 49 clips of the v2 build (the swap keeps the game rig). The swap ran on main's kael.glb, before the
docs/art/IDLE_AUDIT.md idle (6 s) and stance (8 s); the 0.24.4 merge put them back with `kael_retarget.py` (plain
numpy: `python3 tools/art1/kael_retarget.py -- <old kael.glb> <swapped kael.glb> <out>`, the old glb's 49 clips over
the swapped ones, rest rotation drift none), which also adds the `x_breath` leaf (3430 chest-band vertices) and prints
the sword point at the idle's first frame (0.8 cm under the ground, as before). `anchor_head_top` and `anchor_chest`
move onto the new mesh (the spec's `anchors`).

`kael.glb.import`: unchanged (`generate_lods=false`, `force_disable_compression=true`).

Shots on the game rig (`--warden-shots`): docs/shots/kael-appeal/.

Checks (2026-11-11): `--warden-glb-check` 183/0 failed, `--warden-model-check` 157/0 failed. `--stretch-check
--wardens=juggernaut` still flags all 49 clips (worst 7.45x in fusion, idle 2.56x, run_f 4.09x, mostly hips and
thighs), against 31.06x (death), idle 10.39x and run_f 16.72x for the old v2 build: better, but not under 1.3x. No
tearing or arm, chest or cape clipping shows in the turnaround, idle, run or kit poses.

**Anim slice3 (11-11), no change:** walk_f/run_f candidates retargeted from Meshy library actions (rig walk, rig run,
action 510; Meshy API output on the paid plan, commercial use under Meshy's terms), each held to Kael's hunched lean
(hips -22/-23 deg) with the arms carried from the current clips, planted at 2.2 / 4.6 m/s. The blind Fable 5.2 judge kept
the current clips: walk 4.00 vs 3.00 / 2.83, run 4.00 vs 3.00 / 3.00 (the candidates' stride reads narrow and light).
The judge noted that the current walk's sword tip may dip to the ground line. Idle is left to the pilot4 idle job. The judging ran on the v2 build's clips; the appeal3 swap keeps the same 49 clips, so the verdict stands.
