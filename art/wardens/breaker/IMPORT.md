# Breaker (bulwark, was Bjorn), stage 1: import note

`breaker.glb` is the round-3 sea-ogre (docs/art/gen/wardens_r3/breaker_* and BREAKER_KIT.md on ext/imagegen
3cb1182b; it supersedes wardens_r2/breaker_*), built hybrid by script, nothing hand-edited in Blender. Stage 1
of the S2 fan-out (WARDEN_STAGE1_BRIEF): generation, bake, rig fit and first shots only; the texture clean-up,
shader override, proportions and stance wait for the Vex r3c recipe (stage 2). Run log: docs/art/wardens/PIPELINE.md.

    # 9:16 crops of the turnaround (front, 3/4, side, back; the back view's shield sliver painted out of the side)
    # edited with Meshy image-to-image: the hammer and the prow out, both arms hanging, exactly two hands
    python3 -I tools/meshy/meshy_task.py edit ~/meshy/breaker/edit_front ~/meshy/breaker/crops/front.png --aspect 9:16 --prompt "..."
    # (3/4, side, back alike; the prompts are in each edit_*/request.json), ground line out, padded square into ~/meshy/breaker/in/
    python3 -I tools/meshy/meshy_task.py create ~/meshy/breaker/runB in/front.png in/tq.png in/side.png in/back.png --texture-refs in/front.png in/tq.png in/side.png in/back.png --enhance on
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/breaker_bake.json
    godot --headless -- --warden-rig-json --warden=bulwark --out=res://art/wardens/src/breaker_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/breaker_fit.json

- **Body:** Meshy meshy-7.1 (four edited views, 2k geometry, 8k texture, PBR, no remesh, A-pose, image
  enhancement on: run A, enhancement off, came out with no right hand, a stump under the fur cuff) baked to a
  36k-triangle low-poly with a 4096 atlas. Two arms, two hands, no third hand (checked in every view).
  Scaled so his hip-to-shoulder span is the rig's; the archetype body (head 0.42, legs 1.3, neck 0.1) puts the
  rig's joints on his: the small head low between the huge shoulders, the ogre's legs. Head x1.12, the shield
  hand x1.1. Slots by painted colour: the red beard `hair` (the hair pick tints it), the blue-grey skin `skin`,
  the iron bracers, buckle and the brass compass `metal`, the fur mantle and boot tops `fur`, belt, boots and
  ropes `leather`, the tunic and trousers `cloth`.
- **Hammer** (tools/meshy/hard_parts.py `hammer`): a plain block of glacier ice (no pick, no anchor, no lantern)
  bound by two riveted iron bands, an iron socket with langets on an oak haft, a leather grip and a pommel;
  1.2k triangles, its own atlas `breaker_hammer_atlas.jpg`. Modelled in the space of the Gun node's `Hammer`
  pivot (meta hammer_pivot) as the procedural oar maul: grip on the origin, haft along -Z, the block's middle at
  (0, 0, -0.62) where BjornFx finds the head. The .glb's `weapon`; WardenGlb seats it on the pivot, so the kit's
  swings, spins and slams move it.
- **Prow shield** (`prow`): oak strakes on a keel facing out, iron rails down both edges, two riveted bands, an
  iron-shod foot, icicles, the faint green crack (`glow`) and the stem post rising over the top into the scroll;
  3.9k triangles, `breaker_prow_atlas.jpg`. Modelled in the left hand's `Shield` node's space (SHIELD_AT,
  SHIELD_TURN, SHIELD_K as the procedural prow); the .glb's `shield`, seated there by WardenGlb.
- **Hit radius:** the heavy class's 0.50 m, unchanged (`--warden-model-check`); he stands 1.12x a medium
  hunter (the sheet's 1.15x, within the 4%).
- Imports: the atlases lossless (`compress/mode=0`); `breaker.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.
