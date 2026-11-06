# Ostra (Motley, the Void Jester): import note (ART-1, 2026-11-05)

`ostra.glb` is the owner's final design, a cursed jack-in-the-box (briefs/art-refs ostra_FINAL_sheet, motley_turnaround, motley_splash), built by
script in Blender on the shared armature; id and files stay `ostra`. Under the 15k budget, 6 materials, 36 hand-keyed clips at 30 fps.

    blender -b --factory-startup --python tools/art1/ostra_build.py            # ~/art1/motley/ostra.blend (OSTRA_WORK moves it)
    blender -b ~/art1/motley/ostra.blend --python tools/art1/ostra_anim.py -- all --export art/wardens/ostra/ostra.glb
    godot --headless --path . --import

- **Rig:** `root` is the Rig; the box rides `x_box` under it, with `x_boxlid` (the lid, 0 open as modelled, 1 shut), `x_crank` (his right side only),
  `x_void` (the void tail goes into the box with him), `x_smoke` (the smoke wound on the spring, scaled to nothing in every still). `hips` sits at the
  top of the spring: the spring is a blend of x_box and hips, so moving the hips compresses it. Clips key the hips' position and scale (`offset_bones`):
  a scale of 0.02 with the lid shut is "down in the box" (the arrive, the emote, the death).
- **Normal map:** `ostra_normal.jpg`, made from the paint's own relief (`ostra_paint.normal_map`): plank gaps, grain, folds, pleats. hero_toon `use_nrm`, `normal_k` per slot in warden_look.json.
- **Face:** an emissive texture on a dished plane inside the hood (`tools/art1/ostra_mask.py`, to briefs/art-refs/ostra_head.png), tipped up 16 degrees for the match camera; `x_jaw`,
  `x_brow.*`, `x_cheek.*` bend the grin and slits.
- **No weapon (item 136):** the void orb is gone. `anchor_orb`, `anchor_hand_r` (right palm), `anchor_hand_l`, `anchor_cards` (left palm), `weapon_muzzle` (right fingertips, an FX
  point the Gun follows). The fan of cards on `x_fan` is the deck. The flurry's card is `void_card.png`, built by `scripts/heroes/void_card.gd`.
- **Cards:** `orbit_cards`, `orbit_cardsb` on the hips, tumbled by WardenSway (`sway` in content/rules/warden_anim/ostra.json), some burnt or torn.
- **Clips:** `tools/art1/ostra_clips.py` (keys), `ostra_pose.py` (hands by target, two-bone IK, fingers, face, box), `ostra_anim.py` (30 fps from frame 0).
- Imports: `animation/fps=30`, `remove_immutable_tracks=false`, `generate_lods=true`, `force_disable_compression=true`; textures `compress/mode=2`,
  high quality, mipmaps (S1's budget).
