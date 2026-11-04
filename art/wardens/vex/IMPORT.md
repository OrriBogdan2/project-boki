# Vex (r3b, the owner's pick): import note

`vex.glb` is the owner-approved round-3 Vex redesign (docs/art/gen/wardens_r3/vex_* and VEX_KIT.md on
ext/imagegen fb523188), built as the design variant `vex_r3b` and picked by the owner over the r3 model
(INBOX_S2 2026-11-04 09:00; r3 stays in git history). Built by script, nothing hand-edited in Blender; steps and run log: docs/art/wardens/PIPELINE.md "r3b".

    # 9:16 crops of the turnaround, edited (left arm down; braids and backpack hoses out): Meshy image-to-image
    python3 -I tools/meshy/meshy_task.py edit ~/meshy/vex_r3b/edit_front ~/meshy/vex_r3b/crops/front.png --prompt "..." --aspect 9:16
    # (3/4, side, back alike; the prompts are in each edit_*/request.json), padded square into ~/meshy/vex_r3b/in/
    python3 -I tools/meshy/meshy_task.py create ~/meshy/vex_r3b/runA_noenh in/front.png in/tq.png in/side.png in/back.png --texture-refs in/front.png in/tq.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/vex_bake.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/vex_fit.json

- **Body:** Meshy meshy-7.1 (four edited views, 2k geometry, 8k texture, no remesh) baked to a 36k-triangle
  low-poly with a 4096 atlas. Gun-arm on her RIGHT, cyber eye on her RIGHT eye, as the turnaround draws them.
  Scaled so her hip-to-shoulder span is the rig's (her long legs shorten instead); head x1.12, hand x1.2,
  girth x1.06 (game proportions).
- **Gun-arm:** the six-barrel forearm cut off at the elbow into `weapon` (the Gun node's space, the muzzle on
  the Gun's Muzzle), its barrels the child `weapon_spin` (HunterAnim spins them while firing).
- **Braids:** real geometry (tools/meshy/warden_parts.py): three woven strand tubes each, draped against the
  body, copper wire wraps, steel bolts, a tuft; on `spring_braid_L_*` / `spring_braid_R_*` bone chains under the
  head that WardenGlb.Springs swings. Their own atlas `vex_braid_atlas.jpg`.
- **Cyber eye:** a brass rim and a glowing lens dome on her right eye plate (`glow` slot, `vex_lens_atlas.jpg`).
- **Texture:** the bake, smoothed within its UV islands and recoloured by ramps of the art's colours per slot
  and hue (toxic-green hair and trim, flat blacks, pale skin, gunmetal, brass); the face keeps its own paint.
- Imports: the three extracted atlases lossless (`compress/mode=0`); `vex.glb.import`:
  `generate_lods=false`, `force_disable_compression=true`.
