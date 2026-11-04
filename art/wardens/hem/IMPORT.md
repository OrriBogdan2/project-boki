# Hem (archer; was Pin): import note, stage 1 (2026-11-04)

`hem.glb` is Hem's stage-1 model (INBOX_S2 09:05/09:10 fan-out): one Meshy 7.1 run from the owner-approved r3 art
(ext/imagegen docs/art/gen/wardens_r3/hem_* + HEM_KIT.md), baked to a clean low-poly and fitted to the Warden
contract by script. **No hand polish** (stage 2 applies the Vex r3c recipe): no paint-over ramps, palette snap or
lift (`lift` 1/1/1), no per-Warden shader. Raw files in ~/meshy/hem/ (not in git). Run log: docs/art/wardens/PIPELINE.md.

    BP=~/tools/blender-4.5.15-linux-x64/4.5/python/bin/python3.11; B="~/tools/blender-4.5.15-linux-x64/blender -b --factory-startup --python"
    $BP -I tools/meshy/hem_crops.py tools/meshy art/hem_turnaround.png ~/meshy/hem/crops      # 9:16 crops, shadow painted out
    python3 -I tools/meshy/meshy_task.py edit ...  (x4: front, 3/4, side, back; prompts in ~/meshy/hem/edit_*/request.json)
    $BP -I tools/meshy/hem_prep.py tools/meshy ~/meshy/hem                                   # padded squares -> ~/meshy/hem/in
    python3 -I tools/meshy/meshy_task.py create ~/meshy/hem/runA in/front.png in/tq.png in/side.png in/back.png \
        --texture-refs in/front.png in/tq.png in/side.png in/back.png --enhance off
    $B tools/meshy/bake_warden.py -- art/wardens/src/hem_bake.json
    godot --headless -- --warden-rig-json --warden=archer          # -> art/wardens/src/hem_rig.json
    $B tools/meshy/fit_warden.py -- art/wardens/src/hem_fit.json

- **Inputs:** the turnaround's four views, each edited once (nano-banana-pro): the bow, its glowing string, spool and
  loose threads out, her LEFT hand hanging empty (side view: the left arm hidden behind her), the ground line and the
  long clawed VFX shadow out (it is VFX only, never mesh). Nothing mirrored.
- **Body:** Meshy 7.1, no remesh, geometry 2k, meshy-7 texture 8k, PBR, A-pose, enhancement off; baked 706k -> 36k
  triangles (head 9k), new UVs, 4096 atlas. Archetype body: legs 1.85 (her long-legged art; r2 used the same),
  size 0.98 (the sheet's height with the longer legs). `chunk` head 1.12, hand 1.2, girth 1.06. The quiver and its
  needles are weighted to the hips (`weight_rules`), not the right arm.
- **Mask:** the porcelain-shard half-mask is its own mesh (`mask`, material `metal-mask` on the body atlas):
  `pieces` in hem_fit.json splits the white/gilt faces over her nose and mouth off the face, closes the stitches and
  lips into it, keeps its largest part and lifts it 3 mm off the face. Skinned to the head.
- **Thimble claws:** on her right hand, from the scan (no scripted claws in stage 1).
- **Bow (weapon):** built by script, tools/meshy/bow_parts.py: `weapon` in the Gun node's space, as the procedural
  longbow and HunterAnim's `_gun` hold: the LEFT hand on the grip, the RIGHT hand drawing at the string. Black
  faceted recurve, red grip and tip wraps, a spool of red thread on the grip, the string a glowing red thread
  (`glow-bow_string`: an emissive line). The nocked arrow (`weapon_mag`, the Gun's Mag) is an iron sewing needle with
  a red glowing thread through its eye. `anchor_nock` on hand.R. The stitched trail, drifting threads, floating
  needles and her shadow are VFX.
- `hem.glb.import`: `generate_lods=false`, `force_disable_compression=true`; the atlas imported lossless.
