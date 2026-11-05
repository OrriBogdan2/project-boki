# ART-1 style notes (Kael pilot; every ART-1 Hero follows this) — v2, final design, branch ext/art1-kael

Status: final-design first pass runs in game (model + 42 clips + blend tree); owner iterating. The shared code is safe to base on (health clean). Read tools/art1/*.py and content/rules/warden_anim/kael.json; they ARE the recipe.

## Keep merges clean (per-Hero data, no shared edits)
- New shared code lives on ext/art1-kael: scripts/heroes/warden_clips.gd, tools/clip_shots.gd, tools/art1/{meshkit,posekit}.py, small hooks in warden_glb.gd, hunter_anim.gd (1 line), models.gd (`body.shoulder`), rig_standard_check.gd, check_registry.gd. Merge or cherry-pick that branch; don't re-implement.
- Per Hero, only add: content/rules/warden_anim/<art>.json, tools/art1/<art>_*.py, art/wardens/<art>/*, its warden_look.json block, its archetype `body`. Extra bones go in the JSON ("extra_bones"), never WardenGlb.EXTRA.

## Model recipe, v2 (Kael final design; tri budget <=20k incl. weapon unless S1 posts lower)
1. Art to scan: crop the owner's turnaround views; Meshy image-to-image (9 credits a view) takes OUT everything loose (long hair cut at the nape, tails, chains); Meshy multi-image run (40 credits) on the four edited views, upscaled 2x, tex refs the same. Rebuild the loose parts yourself. See ~/meshy/kael_f (prompt in request.json).
2. tools/art1/kael_source.py: joints read off tools/meshy/grid_renders.py, then soft weights by distance to bone segments (no bone heat) and a per-bone move onto the rig: length along the bone, girth across it. So proportions land on the armature with the scan's paint intact. It handles splayed legs, arms off the body, everything. Cut what gets rebuilt (head, neck, hands), weld, Decimate to ~9.5k.
3. Rig to the art, not the art to the rig: archetype `body`: `legs` (hip height), new `torso` (hip to shoulder, neck), `shoulder` (arm pivots in), `size`. Kael: legs 2.09, torso 0.78, shoulder 0.9, size 1.08. Then `--warden-rig-json`. Keys written for another build play through posekit `remap` (rig "dz", "leg_k").
4. Rebuild the signature pieces as scripted geometry (kael_pieces.py): SDF head as a heightfield face patch + skull; brows, lids, eyes on their own pieces and bones; funnel scarf as ring profiles; long tails as thin double-faced ribbons (`scarf_tail`) on `spring_scarftail_*` chains: the rest shape leans BACK so they read from above, Sync adds a slow ripple; hair as big wedges then locks; hands with real curl round the hilt; chain from `link`/`chain_along`.
5. The weapon is built in the rest pose in the hand, skinned 100% to hand.R (item 76b). FX points are empties on the bones: `weapon_muzzle`, `anchor_blade_root`, `anchor_blade_mid`. Data: "skinned_weapon": true, "blade": {root, tip}.
6. One 2048 atlas: unique islands left 75%, shared tiles right (hair, chain, hook, eye, glow). Weld before unwrapping or every face is an island. Unwrap the scan by body part with seams (kael_finish.py), never Smart UV on it. Few surfaces: skin, skin-hot, cloth, cloth-ember-hot, leather, metal, metal-blade-hot, hair, eyes, glow.
7. Texel-space paint (kael_paint.py): raster position/normal per texel, Cycles AO on SMOOTH faces (flat faces give camouflage facets), scan paint by nearest surface. bpy image.pixels are display values: no gamma. Slots by the paint's hue per face.
8. Glow: `*-hot` materials key per texel: paint the key colour (1, .76, .44). A tag can have its own colour in archetype model_glow (Kael "ember"); fissures from `crack_map` (stretched Voronoi edges); keep them ~5 mm wide. No smoke particles from the model look (hard black discs on the GL backend); that's ART-2.
9. Vertex colour alpha = ink room (Piece.room); RGB = shade (hair layers, warden_look hair "vertex_ao": true).
10. Near-black paint reads as gloss under the toon rim: lift it to charcoal, lower `fres` on cloth and leather.

## Rig
- Contract bones + per-Hero extra bones (Kael: lid.L/R, brow.L/R, fingers.L, thumb.L, foot.L/R; springs spring_mane_*, spring_hangwarchain_*, spring_hangcuff_*, spring_scarf_*). foot.* gives flat feet on bent knees; use it for all Heroes.
- Use `body.shoulder` to narrow the rig's shoulders; NOT `body.chest` (that squashes the torso non-uniformly). Rerun `--warden-rig-json --warden=<id>` (needs `godot --headless --import` once in a fresh worktree or it hangs).
- root = pelvis, hips = chest: weight the belly root->hips for a two-segment spine.

## Animation
- posekit.py: keys are targets (pelvis, torso, head, feet + yaw, grip position + blade direction + edge, off-hand place or Lw 1 = on the hilt, brows, lids, fingers); sampled at 30 fps, two-bone IK solved, FK baked per frame. FnClip for cycles; `gait(speed, heading)` makes all walk/run directions.
- Clip times = the kit's kmove table times (kmoves_*.gd): WardenClips seeks a clip to the kit's own kmove_t. Map in content/rules/warden_anim/<art>.json "kmoves", with "hold_from" for held moves, "upper": true for torso-only.
- Blend tree (built in code from the JSON): loco BlendSpace2D (idle, walk ring, run ring) > stance > air > upper (filtered, one channel) > full (two crossfaded seek channels). Note: one node output can feed only one input.
- Export: glTF ACTIONS, .import `remove_immutable_tracks=false`, generate_lods=false, force_disable_compression=true.
- Previews: `xvfb-run -a godot --path <wt> --rendering-driver opengl3 --audio-driver Dummy --resolution 480x480 -- --clip-shots --warden=<id> --shots-dir=<d> --clips=a,b --fps=8 --size=480`.

## Export (v1.1)
- Blender's scene default is 24 fps: set `bpy.context.scene.render.fps = FPS` (30) before the glTF export, and key from frame 0, or every clip runs 25% long. kael_clips.py does; `--clip-check` asserts clip length = kit move length.
