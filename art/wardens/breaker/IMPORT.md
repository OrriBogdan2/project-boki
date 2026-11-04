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
- **Size and hit radius:** the biggest Warden: bulwark `body.size` 1.02 -> 1.19, so he stands 1.32x a medium
  hunter (`--warden-model-check`'s sheet height 1.15 -> 1.30; BREAKER_KIT asks ~1.5x, left for the owner). The hit
  radius stays the heavy class's 0.50 m (the ring and the hitbox don't grow with him).
- Imports: the atlases lossless (`compress/mode=0`); `breaker.glb.import`: `generate_lods=false`,
  `force_disable_compression=true`.

## Stage 2 (the Vex r3c recipe, owner GO 11:25; owner sheets fb503983)
- **Scale:** 1.5x a medium hunter (owner 11:15): bulwark `body.size` 1.354 (the model check's sheet 1.50x). The hit
  radius stays the heavy class's 0.50 m. `body.head` 0.42 -> 0.35 so the rig's neck-to-crown span is the mesh's
  (the fit stretched the head 1.2x vertically to reach the old one).
- **Paint-over:** `smooth`, `ramps` of the art's own colours per slot (copper-red beard as the portrait and the
  head and front sheets paint it, blue-grey skin, fur, navy tunic, leather, iron, brass), `despeckle`, and
  `project_late` of the edited front view's face and beard/compass, each registered on the mesh's own render
  (tools: register.py), front-facing faces only.
- **Look** (content/rules/warden_look.json `breaker`): a moderate match-camera lift (skin, fur, leather), a
  beard rim, iron rims without sheen, the glow toned down.
- **Hold** (content/rules/warden_stance.json `bulwark` carry): the hammer up over his RIGHT shoulder, the haft
  back from the fist (breaker_front, the turnaround); it lets go into the aim the moment he swings.
- **Hammer** (`hammer`, to breaker_hammer_sheet): the plain ice block in two rusty riveted ship-bands, icicles, a
  rusty socket, a weathered haft with two rope wraps, an iron end cap (2.1k triangles).
- **Shield** (`shield_card`, from breaker_shield_sheet): a thick card cut to the sheet's front outline (the broken
  top planks, the riveted iron rim, icicles), its face painted with the sheet's front (the carved bearded
  figurehead), its back with the back view (rope grip, strap), bent so its middle stands out; smaller and a
  little further out at his LEFT side than stage 1 (560 triangles). It replaces the scripted prow (the kit's
  scroll top: the owner's shield sheet has none).
