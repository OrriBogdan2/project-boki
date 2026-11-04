# Vex (r3e: the owner's pick r3b, polished; the RECIPE_95 reference): import note

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
- **Cyber eye:** her right eye plate and its glowing lens, drawn from the face sheet as a decal (`glow` slot for the lens; see r3e).
- **Texture:** the bake, smoothed within its UV islands and recoloured by ramps of the art's colours per slot
  and hue (toxic-green hair and trim, flat blacks, pale skin, gunmetal, brass); the face keeps its own paint.
- Imports: the three extracted atlases lossless (`compress/mode=0`); `vex.glb.import`:
  `generate_lods=false`, `force_disable_compression=true`.

r3c (the polish pass, INBOX_S2 09:00; the reference recipe in PIPELINE.md):
- **Proportions:** gunslinger body legs 1.95 and size 0.89 (was 1.58 / 0.97): the art's long legs at the same
  1.04x height; the hit radius is the class's and unchanged.
- **Paint:** the art's face, chest (straps, collar, tattoos) and belly painted over the finished atlas
  (`project_late`, registrations measured on the mesh's own render); the body's skin ramp is the art's skin.
- **Hoses:** two ribbed hoses from the backpack to the gun-arm's elbow (`hoses`, weighted hips -> upper arm ->
  forearm, so they stay on while she aims); `vex_hose_atlas.jpg`.
- **Braids:** 1.12 m and 1.0 m, 7.6 cm wide; the collar's green seams and the lens on the glow slot.
- **Shading:** content/rules/warden_look.json "vex": the skin and gunmetal with less top light and rim (no white
  skin, no silvered gun), the hair brighter at the match camera, the glow slot at 1.8.

r3d (the face pass and the 95% pass, INBOX_S2 11:25-13:15; credit-free; docs/art/wardens/RECIPE_95.md):
- **Face:** painted from the flat-lit face sheet (wardens_r3/vex_face) through a thin-plate warp on 15 landmarks:
  her eyes, brows, lips, skin tone, the angular brass eye plate and the circuits as the sheet draws them; the
  sheet's outline, its hair and its jaw panels left out and the skin carried past them (no jaw seam).
- **Lens:** a bladed green iris with a dark pupil (review/vex_eyeplate_detail_ref, iris only) and a glow halo at the
  match camera (warden_look.json "halos" on `anchor_lens`).
- **Look:** the shared painted-look fix (16c18b4f: warm skin, darks a step up); gunmetal and brass a step lighter and
  apart (the gun reads grey and brass at the match camera); the art's back view on the backpack (brass plate, cogs);
  four thick ribbed hoses from the backpack to the gun; the chest's strap area one skin slot, its glancing faces
  cleaned.

r3e (ORCH's reviews after r3d, 14:00 and 14:10; credit-free):
- **Eye plate and lens:** the face sheet's angular brass plate as a decal mesh on the face (fit spec `plate`: its
  outline through the inverse of the face warp, ray-cast onto the skin and metal, a bevelled edge, textured by the
  sheet); the sheet's own lens on it, its concentric rings and highlights, on the glow slot (`glow_circles`, glow
  1.1: at 2.4 it tonemapped to white). The modelled lens is gone (`lens.geometry` false: it never lined up with
  the plate's ring); its anchor stays for the match-zoom halo.
- **Brass:** aged bronze (2e2214..8a7048), less top light and rim on metal: it read highlighter-yellow.
- **Gun:** gunmetal barrels (3a3c42..b4b7bd) with the bronze bands.
- **Blacks:** neutral (1c1d22..64666f); at the match camera cloth, leather and metal take the hue out of the orange
  Arena sun (`light_neutral_warm`), no fresnel lift and no green rim: black + green + bronze, not khaki.
- **Braids:** solid plaits (no speckle: flat strand colours, little AO), copper ties, longer (1.2 / 1.08 m),
  toxic green (126 deg ramp, measured in game).
- **Tattoos:** the belly's circuit lines from the turnaround as thin flat lines (`project_after` line mode); the chest
  skin cleaned (the art's crop-top trim had landed on it as green smears). The face's circuits are the face sheet's.
- **Gorget:** its seams on the glow slot (`reslot_late`).
- Bigger hose loops; the match frame shot on clear grass (`--no-tips`, `demo_at` -4.5,0).
