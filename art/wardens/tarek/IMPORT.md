# Tarek (dolm): import note (stage 1, 2026-11-04)

`tarek.glb` is stage 1 of the round-2 Tarek (ext/imagegen docs/art/gen/wardens_r2/tarek_* and TAREK_KIT.md):
Meshy generation, the bake, the rig fit. No hand polish yet (stage 2 applies the Vex r3c recipe). Built by script,
nothing hand-edited in Blender; run log in docs/art/wardens/PIPELINE.md.

    # 9:16 crops of the turnaround (~/meshy/tarek/tools/crops.py), edited: his raised right fist lowered; the
    # three stones, the shard swirl, the ground ripples and the ground line out (prompts in edit_*/request.json)
    python3 -I tools/meshy/meshy_task.py edit ~/meshy/tarek/edit_front ~/meshy/tarek/crops/front.png --aspect 9:16 --prompt "..."
    python3 -I tools/meshy/meshy_task.py create ~/meshy/tarek/runA in/front.png in/side.png in/back.png --texture-refs in/front.png in/side.png in/back.png --enhance off
    blender -b --factory-startup --python tools/meshy/bake_warden.py -- art/wardens/src/tarek_bake.json
    godot --headless -- --warden-rig-json --warden=dolm --out=res://art/wardens/src/tarek_rig.json
    blender -b --factory-startup --python tools/meshy/fit_warden.py -- art/wardens/src/tarek_fit.json

- **Body:** meshy-7.1 from three edited views (the 3/4 edits failed twice), baked 1.17M -> 36k triangles with a
  4096 atlas (2048 in the game). Archetype body head 1.2, legs 1.6, neck -0.02 so the rig's joints land on the
  art's; scaled by the hip-to-shoulder span (the legs shorten: the game build). Locs are Meshy's chunky geometry,
  fused to the head (no spring bones in stage 1).
- **Bracers:** split off as their own skinned mesh `Bracers` (`leather-bracers`), with an emissive crack layer:
  `tarek_bracers_emit.jpg`, the dark seams between the stone plates lit amber (WardenGlb's emit layer).
- **Seeing-stones (his relic):** three rough geodes, amber iris and slit pupil (`glow`) facing out, plain rock
  backs, unskinned under `orbit_stones` on the head bone; WardenGlb.Orbits turns them round his head and bobs each.
- **Crystals:** 14 small amber octahedra (`glow-crystals`) seeded on the locs, skinned like the loc they sit on.
- **Weapon:** an empty `weapon` node: the procedural rock fists are hidden (his fists and bracers are the weapon).
- Ground ripples: VFX only, not in the model.
- Imports: atlases lossless (`compress/mode=0`); `tarek.glb.import`: `generate_lods=false`, `force_disable_compression=true`.
