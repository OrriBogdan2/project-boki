# Ostra (Motley, the Void Jester): import note (ART-1, 2026-11-05)

## Owner fix 2026-11-12: cards (`tools/art1/warden_fix_1112.py ostra`, on the 11-11 file)
"He should be having those cards in his hand, and the cards floating around him should be much smaller." The fan of cards
(on `x_fan`, a child of `hand.L`) floated about 10 cm off the appeal glove: it is turned over and its foot set in the
glove's palm, so it fans out past the fingertips between thumb and fingers. The eight orbiting cards are 0.42 of their
size (about one fan card); their orbits, the sway and the clips are unchanged.

`ostra.glb` is the owner's final design, a cursed jack-in-the-box, built by script in Blender on the shared armature; id and files stay `ostra`.
v2 (2026-11-07) follows briefs/art-refs/motley_v2 (motley_v2_turnaround, motley_v2_master_sheet; the older motley_turnaround is retired): the
sheet's painted palette (magenta-violet and plum doublet, lilac ruff and gloves, muted bronze spring, mauve box with spades front and back and
diamonds on the sides), a near-cube box, no crank mesh, the head and hat at 0.82 of v1 (`HEAD_K`; the sheet's is smaller, kept larger so the grin
reads at the match camera and he keeps the line-up height), the ruff at 0.80, six broad coat tails flung out (reach 0.46-0.56) with the bells hanging clear above the box at z 0.62-0.66 so the spring shows (the sheet's float), arms spread wide in the base pose (`STILL`), one column of buttons, a broader flat void ribbon. He has no legs and hovers (the clips). Under the 15k budget, 6 materials, 36 hand-keyed clips at 30 fps.

    blender -b --factory-startup --python tools/art1/ostra_build.py            # ~/art1/motley/ostra.blend (OSTRA_WORK moves it)
    blender -b ~/art1/motley/ostra.blend --python tools/art1/ostra_anim.py -- all --export art/wardens/ostra/ostra.glb
    godot --headless --path . --import

Re-keying clips on the swapped model (there is no ostra.blend with its mesh): key on the game .glb's own rig, then copy the clips in
(every other clip stays byte for byte the same):

    blender -b --factory-startup --python tools/art1/ostra_anim.py -- walk_f,orb --from art/wardens/ostra/ostra.glb --export /tmp/keyed.glb
    python3 tools/art1/glb_add_clips.py art/wardens/ostra/ostra.glb /tmp/keyed.glb walk_f,orb

**Appeal swap (2026-11-11, owner-approved):** the mesh is now the appeal3 master, body b with the new starry face (`~/meshy/v95/Motley/r2/appeal3/cand_b.glb`),
put on this rig, its clips and anchors by the v95 swap (`art/wardens/src/ostra_v95.json`, docs/art/wardens/V95_SWAP.md). It replaces the
build above's mesh (the build scripts still make the rig and clips): one 2048 atlas (`ostra_atlas.jpg`) and a baked `ostra_normal.jpg`, slots
glow-face (the face window), cloth-ruff, leather (the box and lid), metal (bells, buttons, spring) and cloth. `ostra_face*.jpg`, `ostra_void.jpg`
and `ostra_wisp.jpg` are gone with the meshes that used them; the cards and fan keep `ostra_glow.jpg` and `void_card.png`.

- **Rig:** `root` is the Rig; the box rides `x_box` under it, with `x_boxlid` (the lid, 0 open as modelled, 1 shut), `x_crank` (a bone with no mesh since v2; kept for the clips and `anchor_crank`),
  `x_void` (the void tail goes into the box with him), `x_smoke` (the smoke wound on the spring, scaled to nothing in every still). `hips` sits at the
  top of the spring: the spring is a blend of x_box and hips, so moving the hips compresses it. Clips key the hips' position and scale (`offset_bones`):
  a scale of 0.02 with the lid shut is "down in the box" (the arrive, the emote, the death).
- **Normal map:** `ostra_normal.jpg`, since the appeal swap baked from the master's own normal map (before it, from the paint's relief, `ostra_paint.normal_map`). hero_toon `use_nrm`, `normal_k` per slot in warden_look.json.
- **Face:** since the appeal swap, painted in the master's atlas on the glow-face slot (warden_look.json: the glow look, dark_lift 0 so the void stays black). Before it: an emissive texture on a dished plane inside the hood (`tools/art1/ostra_mask.py`, to briefs/art-refs/ostra_head.png), tipped up 16 degrees for the match camera; `x_jaw`,
  `x_brow.*`, `x_cheek.*` bent the grin and slits (since the swap the face rides `head`; those bones stay in the rig, unweighted). 11-08 rework: a near-black void, thick crescent eyes glaring down at the nose (inner end low), one clean wide grin with a jagged fang seam.
- **No weapon (item 136):** the void orb is gone. `anchor_orb`, `anchor_hand_r` (right palm), `anchor_hand_l`, `anchor_cards` (left palm), `weapon_muzzle` (right fingertips, an FX
  point the Gun follows). The fan of cards on `x_fan` is the deck. The flurry's card is `void_card.png`, built by `scripts/heroes/void_card.gd`.
- **Cards:** `orbit_cards`, `orbit_cardsb` on the hips, tumbled by WardenSway (`sway` in content/rules/warden_anim/ostra.json), some burnt or torn.
- **Clips:** `tools/art1/ostra_clips.py` (keys; gliding, the box swings back on the spring's top, `swing`, and treads), `ostra_pose.py` (hands by target, two-bone IK, fingers, face, box), `ostra_anim.py` (30 fps from frame 0).
- Imports: `animation/fps=30`, `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures `compress/mode=2`,
  high quality, mipmaps (S1's budget).
