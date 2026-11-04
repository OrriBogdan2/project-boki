# Claire (rimewright), stage 1: import note

`claire.glb` is the round-2 frost demoness skater (docs/art/gen/wardens_r2/claire_* and CLAIRE_KIT.md on
ext/imagegen; the turnaround is the spear-and-skates fix, c8f764f1), built by script, nothing hand-edited in
Blender. Stage 1 of the S2 fan-out: generation, bake, rig fit and first shots only (the paint-over, shader
tuning, proportions and stance wait for the Vex r3c recipe). Run log: docs/art/wardens/PIPELINE.md.

    # 9:16 crops of the turnaround's front, side (her left) and back (the 3/4 is skipped: it lacks the spear);
    # the side view's tail tip painted out of the back crop; edited with Meshy image-to-image: the spear, both
    # wings and the tail out, both arms hanging, both skates pointing forward
    python3 -I tools/meshy/meshy_task.py edit ~/meshy/claire/edit_front ~/meshy/claire/crops/front.png --aspect 9:16 --prompt "..."
    # (side, back alike; the prompts are in each edit_*/request.json), ground lines out, padded square into ~/meshy/claire/in/
    python3 -I tools/meshy/meshy_task.py create ~/meshy/claire/runA in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/claire_bake.json
    godot --headless -- --warden-rig-json --warden=rimewright --out=res://art/wardens/src/claire_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/claire_fit.json

- **Body:** Meshy meshy-7.1 (three edited views, 2k geometry, 8k texture, PBR, no remesh, A-pose, enhancement
  off; one run) baked to 36k triangles (34k after the fit, 31.4k once the horns are split off) with a 4096 atlas.
  Scaled so her hip-to-shoulder span is the rig's; the rimewright body (head 0.66, legs 2.0, neck -0.08, size
  1.3 -> 1.16) puts the rig's joints on her long-legged skater build and keeps her height (1.10x a medium
  hunter, 1.13x with the horns; the model check's sheet 1.11x). Slots: the dark hair `hair`, the face, neck and
  arms `skin`, the boots `leather`, the costume, sheer legs and blades `ice`.
- **Feet:** both skates point forward in the generation; `hard_parts.feet_forward` asserts it at every fit
  (each sole's long axis against the body's forward: dot 0.97 left, 0.96 right; the fit fails under 0.8).
- **Ice costume:** the `ice` slot: hero_toon with a strong cold fresnel rim and a little gloss
  (WardenGlb.ICE), no real transparency.
- **Horns:** their own mesh `horns` (2.6k triangles), the dark slate faces split from the head by colour and
  region, riding the `head` bone rigidly.
- **Wings:** cut-out cards (two layers, 116 triangles each) whose outline and paint are the art back view's
  left wing (`claire_wing_atlas.jpg`; the right card is its mirror, the right wing in the art is crossed by
  the spear), the inner edge tucked under the hair, the tips swept 25 degrees back. Each rides a
  `spring_wingL_*` / `spring_wingR_*` chain from the hips; WardenGlb.Springs swings them and folds them back
  and in while she skates (HunterAnim sets the root's `wing_fold` from the skate dash; `--warden-glb-check`).
- **Tail:** a tapered tube draped clear of her legs with a flat spade (738 triangles, `claire_tail_atlas.jpg`)
  on a `spring_tail_*` chain from the hips.
- **Spear:** the `weapon` in the Gun node's space, her RIGHT hand (the Gun's): a slim faceted ice haft, a
  barbed leaf blade ending just past the Muzzle (-0.82), a butt spike (158 triangles, `claire_spear_atlas.jpg`).
  It takes the procedural hoar fan's hold, which brings both hands to it.
- Imports: the atlases lossless (`compress/mode=0`); `claire.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.

## Stage 2 (the Vex r3c recipe, owner GO 11:25; owner sheets fb503983)
- **Head and horns:** `body.head` 0.66 -> 0.58 so the rig's neck-to-crown span is the mesh's: the fit no longer
  stretches the head (and the horns) 14% upward; the horns sit compact on the skull as claire_head_sheet draws.
- **Face:** `project_late` from claire_face (the owner's flat-lit face: glowing pale-blue eyes, freckles, pink
  blush, lips) in two regions (eyes and brows; nose, cheeks, mouth), registered on the mesh's render by the eyes
  and mouth; the art's dark hair pixels are skipped.
- **Paint-over:** `smooth`, `ramps` of the art's colours (blue-black hair, slate horns, the lavender-blue skin
  and ice, the white skates), `despeckle`; `ink_room` 0.012 (the ink shell speckled the thin ice petals at the
  match camera).
- **Look** (content/rules/warden_look.json `claire`): the ice slot's cold rim and a match-camera lift, a lighter
  rim on her hair, wings, tail and horns so the dark shapes read on grass.
- **Stance** (content/rules/warden_stance.json `rimewright`): the spear planted upright in her RIGHT hand, the
  left hand raised beside her shoulder, legs together, the hip cocked (the turnaround's front view); the wings
  fold back while she skates.
- **Spear:** taller than she is (butt +1.05, tip -0.95 in the Gun's space: about 2.1 m against her 1.9 m), as
  claire_spear_sheet; one-handed (the stance's free left hand).
- **Wings:** the cards leave out her arm and the hair at their root (`drop_boxes`, `hair_lum`) and bleed the
  membrane's colour 40 px past the outline: no dark or pale patch at the inner corner.
