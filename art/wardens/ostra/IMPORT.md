# Ostra: import note (stage 2, 2026-11-04)

`ostra.glb` is stage 1 of the round-2 Ostra (ext/imagegen docs/art/gen/wardens_r2/ostra_* and OSTRA_KIT.md):
Meshy generation, the bake, the rig fit. No hand polish yet (stage 2 applies the Vex r3c recipe). Built by script,
nothing hand-edited in Blender; run log in docs/art/wardens/PIPELINE.md.

    # 9:16 crops of the turnaround, edited: his raised right hand lowered; the crescent halo, the void orb, the
    # strings, the card shards, the floating shadow and the ground line out (prompts in edit_*/request.json)
    python3 -I tools/meshy/meshy_task.py create ~/meshy/ostra/runA in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/ostra_bake.json
    godot --headless -- --warden-rig-json --warden=ostra --out=res://art/wardens/src/ostra_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/ostra_fit.json

- **Body:** meshy-7.1 from three edited views (the 3/4 edit failed), baked 1.1M -> 36k triangles with a 4096 atlas
  (2048 in the game). Archetype body build 0.65 (his thin shoulders). Meshy ended the body at the coat's hem; its
  ground is set below the hem (`sole_z`) so the hips land on the rig's and the hem hangs 0.2 m up. The coat below
  the hips rides the hips bone (no legs to swing it).
- **Hover:** the rig's own (KMovesStone.hover lifts Rig 0.3 m with a bob; the root bone follows), so he floats
  with a gap over his shadow and ring as the procedural Ostra does.
- **Wisp:** a curling tube with three tendrils (`void-wisp`) under the hem on a `spring_wisp_*` chain under the
  hips: hero_void.gdshader's starfield, soft (fading to its tip and edges). The coat's tears are the `void` slot
  too (the same starfield, opaque).
- **Mask (his relic):** split off as its own skinned mesh `Mask` (`leather-mask`) with an emissive layer
  `ostra_mask_emit.jpg`: the violet mouth, eye pinpoints, tear and crack lit.
- **Crescent halo:** `glow-halo`, rigid on the head bone behind his head.
- **Weapon:** an empty `weapon` node: the procedural tether lantern is hidden (not in his art). The strings, card
  shards and the void orb are VFX/props for the kit, not in the model.
- Imports: atlases lossless (`compress/mode=0`); `ostra.glb.import`: `generate_lods=false`, `force_disable_compression=true`.

## Stage 2 (the Vex r3c recipe; owner refs ostra_head_sheet, ostra_mask_sheet, ostra_cap_halo_sheet, ostra_front_float on
ext/imagegen fb503983)
- **Proportions:** archetype body legs 1.8 and size 0.74 (was 0.9): his hips and hem ride higher so the wisp hangs long
  below the coat, nearly to the ground with a gap over his shadow (ostra_front_float), at the same 1.09x height.
- **Paint-over:** smooth within the UV islands, then ramps of the art's violets, blacks, the grey ruff and the gloves.
  The mask keeps Meshy's paint: the art's projection greyed the porcelain (its painted shading).
- **Halo:** violet (no longer white), larger (0.42 m) behind the head, softer cracks.
- **Wisp:** 1.3 m along a curl with four tendrils on five spring bones; opaque further down (hero_void fade_from 0.72).
- **Orb:** a glowing violet orb (`glow-orb`) on the right hand, raised to the shoulder by the stance (`ostra` carry),
  the left hand open and out to the side, as ostra_front_float draws him.
- **Look:** content/rules/warden_look.json `ostra`: a violet rim on the coat (fres, fres_color) and the match-camera
  lift so he reads at match zoom; the mask's emission stronger; the halo's glow lower so it stays violet.
