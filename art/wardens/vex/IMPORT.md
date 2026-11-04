# Vex (r3g: the owner's pick r3b, polished; the RECIPE_95 reference): import note

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

r3f (the r3e report's next steps and ORCH's 15:10 review; credit-free):
- **Chest:** Meshy's blurry tattoos there had gone to the hair slot (green smears): skin rules by box and hue before
  the hair rule, stepped to clear the crop top's piping, then a `fill` touch-up closes the skin over Meshy's green
  in its own shading. The art's circuit curl and the circuit on her left breast are crisp flat lines (`line`
  passes, skin only, `max` under the piping's green); the projections no longer carry the art's tattoos as smudges.
- **Belly:** the same fill, then the art's circuit lines, skin only.
- **Lens:** the face sheet's lens on a smooth dome (fit spec `plate.dome`: on the plane of the face just around
  Meshy's lens horn, the horn cut under it), glow 1.8: a bright core in its rings, no green spike at 3/4.
- **Gorget:** painted from the face sheet (`project_late` "gorget": the dark centre plate, the bronze bands, the
  green seams), its seams on the glow slot.
- **Cartridges:** the ammo belts on both shoulders a bronze ramp (casings and dark links).
- **Brass:** its own slot (`brass`, split off the metal by hue): its look lifts it at the match camera (far_lift
  0.5), so the bronze reads there.
- **Jacket and gun mount:** the gun-side shoulder's dark jacket back on cloth (it had taken the metal ramp: grey
  camo), the atlas smoothed harder (sigma_r 0.1) and the blacks ramp kept dark: clean black leather and gunmetal.
- **Braids:** flatter strand colours, eight thicker locks in each tuft, and a `hair-braid` look (fres 0.15, far_lift
  0.3, no rim): solid plaits, no green edge noise.
- **Hair at the match camera:** far_lift 0.5, fres 0.3, no rim (it had gone pale cyan).
- **The shared match-zoom fix:** v2 (ext/warden-matchzoom-v2 161708cc, c89a5273 and 8af89a9e, picked as 5b6d6ac8,
  3434a660 and 1312af72; the v1 pick 5fa9e23a reverted): no speckle fringe, the ink gone from ~13.5 m, a halo shell on the glow
  pieces; the review frame is `--arena-demo=pose_clear`.

r3g (the r3f report's next steps; credit-free):
- **Chest straps:** the skin around the upper chest's straps cleaned by value (`fill`: Meshy's dark strap shadows and
  the art's white highlights), the straps' own painted edges kept.
- **Circuits:** the belly's and chest's circuit tattoos as vector strokes (`stamp`: the art's lines thinned to their
  centres, stamped 2 mm wide in one green, skin only).
- **Gorget:** its seams stamped from the face sheet in the bright seam green, then onto the glow slot.
- **Gun mount:** the whole block on metal (a value rule had split it with the black jacket: dark blotches) and
  flattened to gunmetal.
- **Halo:** lime [0.7, 1.0, 0.25], a hue apart from the hair's green (it was lost in the hair at the match camera).

r3h (ORCH's 17:10 review of r3f; credit-free):
- **Face:** the eyeshadow's magenta taken to the face sheet's smoky plum (`desat`); the head a little larger and
  wider (chunk head 1.21, head_x 1.04: it read small and gaunt); the cheek and temple circuits stamped from the
  face sheet, their round nodes whole.
- **Chest and belly:** the upper chest's blown highlights capped (`cap`), more of the strap streaks filled; the
  belly's Meshy green filled further down in saturation before its circuit strokes.
- **Gorget:** its grey plates taken to bronze (`warm`), its seams stamped green on the glow slot.
- **Gun mount and left sleeve:** the mount a darker flat gunmetal, the left sleeve flat black leather.
- **Night:** the circuit tattoos glow (`glow_key` on the skin slot, hero_toon); the lens and the gorget's seams
  were on the glow slot already. The lens halo is lifted 3.5 cm toward the camera, in front of her fringe.
