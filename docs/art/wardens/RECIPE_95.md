# RECIPE_95: a Warden from its art to a shipped 3D model (~95% of the art)

The golden recipe, proven on Vex (r3b -> r3c -> r3d, 2026-11-04). One agent per Hunter runs it on its own branch.
Budget: about 2-3 hours and ~125-200 Meshy credits a Hunter (5 x 9 for input edits, 2 x 40 for the Meshy runs; a
redo or two). The driver `tools/meshy/recipe.py` runs every scriptable step from a spec; the steps marked **(look)**
need your eyes before the next one. Details and history: PIPELINE.md, RIG_CONTRACT.md.

## 0. Set up (10 min)
- Your worktree on `ext/warden-3d-<id>`; merge `origin/ext/warden-vex-r3b` (the tools, the shared painted-look fix
  16c18b4f, the variant loader, the spring chains, the halos). Blender: `~/tools/blender-4.5.15-linux-x64/blender`.
  Godot: the `godot` queue wrapper (fresh XDG per run; never `--fresh`, never a shared save, never pkill by pattern).
- Copy `art/wardens/src/vex_recipe.json` to `<name>_recipe.json`: name (the art name, `WardenGlb.ART`), arch (the
  archetype id), raw (`~/meshy/<name>`), the art paths on `origin/ext/imagegen` (turnaround, side, portrait, face,
  head_sheet, prop sheets). **Read the Hunter's KIT/REFS note first** for parts of a sheet to ignore.
- `python3 tools/meshy/recipe.py SPEC art balance`

## 1. Read the art (10 min)
Write down, from the turnaround, the side view and the notes:
- every asymmetric piece and its side (never mirror; a splash may be mirrored: ignore it for sides);
- everything that hangs loose or crosses the body: braids, tails, cords, hoses, capes, scarves, held props, a hand
  resting on a hip. **These fuse to the body in Meshy**: take them out of the inputs (step 2) and build them as
  geometry (step 6);
- the signature pieces that must read from above (Vex: gun-arm, green braids, green cyber eye);
- what glows (eyes, lenses, cracks, vents): glow slot + halo (step 7).

## 2. Inputs (20 min, 45 credits) (look)
- `recipe.py SPEC crop`: 9:16 crops of each view (spec `views`: sheet columns per view; `kill` boxes paint a
  neighbour's intrusion out; or `{"auto": [...]}`).
- Write one edit prompt per view in the spec (`edits`), in this shape (Vex's are in vex_recipe.json):
  "Edit this character concept art (a front view). Make exactly these changes: 1) Her left arm ...: make it hang
  straight down, relaxed, a little away from her hip ... 2) Remove BOTH long green braids completely ...: her hair
  ends at her shoulders and nothing hangs below them; show ... where the braid was. Keep everything else exactly the
  same: the same young woman, her face, ... all colours, the painted art style and line work, the framing, scale and
  position of the figure, and the plain light grey background."
  - Name the side of every arm by the image's side too ("the human arm on the RIGHT side of the image").
  - A side view: say a hidden limb is "completely hidden behind her body" (else it is drawn hanging behind the back).
- `recipe.py SPEC edit` (nano-banana-pro, the four views in parallel) -> `<raw>/edits_sheet.png`: crops over edits.
  Redo a bad view with `edit:side` (set `use.side` to a new dir name first). Paint small invented details out by hand.
- `recipe.py SPEC prep`: padded squares in `<raw>/in`.

## 3. Meshy (15 min, 80 credits) (look)
`recipe.py SPEC meshy`: two runs in parallel, the same max settings, image enhancement off and on:
meshy-7.1, geometry_resolution 2k (4k is single-image only), texture_model meshy-7 at 8k, PBR on, should_remesh
false, pose_mode a-pose, the four edited views (front, 3/4, side, back) as images and as texture references.
Keep the run whose face is closest to the face sheet (Vex: enhancement OFF kept the sultry smirk; ON gave a rounder,
cuter face and stringy hair). `<raw>/variants.png`; log both in PIPELINE.md's run log (task ids in task.json).

## 4. Bake (5 min)
Copy `vex_bake.json` -> `<name>_bake.json` (high: the kept run's glb.glb; the head's centre and r read on
`recipe.py SPEC grid`, which renders the kept Meshy run while there is no bake yet).
`recipe.py SPEC bake`: the 1.1M-triangle mesh to 36k (9k on the head), new UVs, a 4096 atlas baked from the dense
mesh. Never decimate the textured mesh itself (r2's smears).

## 5. Measure and proportions (20 min) (look)
- `recipe.py SPEC grid`: gridded front and side of the low mesh, 500 px per metre about the origin (Meshy frame:
  +Z up, facing -Y, her right is -X). Read the joints (shoulders, elbows, hands, fingers, hips, knees, ankles, neck,
  crown) into the fit spec's `joints`; for a weapon fused to an arm its `elbow` and `tip`.
- Proportions: set `content/archetypes/<arch>.json` body (`legs`, `size`, `head`, `build`) so the rig's hip height
  matches the art's leg length, and `size` keeps the model's height on the sheet's (within 4%); `recipe.py SPEC rig`.
  The fit's `scale_joints: ["hip.L", "shoulder.L"]` keeps the torso at the art's size. The hit radius never changes.
  Vex: legs 1.95, size 0.89, build 1.12; `chunk` head 1.16, hand 1.2, girth 1.06 (the game read).

## 6. Fit spec (45-60 min, credit-free; iterate with `recipe.py SPEC loop`) (look)
Copy `vex_fit.json` -> `<name>_fit.json` and set, in this order of importance:
1. `body_glb` (the bake's low.glb), `joints`, `turn` 180, `snap_y` false, `max_tris` 36000, `fit_weights` true.
2. The weapon: fused to an arm, `gun_arm` (elbow, tip, `r` out, `r_side`, `r_in` toward the body, `r_elbow`, `taper`,
   `spin` for barrels, `slot` metal); a held prop, the weapon glb (PIPELINE.md). `cap_holes`, `cap_flat`.
3. `slot_rules` (first match wins): the face's eye box -> skin; the hair (box above the neck + hue); round parts by
   `circle` [x, z, rx, rz] (an eye plate) -> metal; the face's front box -> skin; metal parts by box (gun shoulder,
   backpack: y behind the back); skin by hue; brass by hue; leather below the knees; cloth. Check it with
   `blender ... tools/meshy/slot_map.py -- GLB OUT 1.62 0.36` (a flat colour per slot): a face split over slots
   reads as patches and seams.
4. `ramps`: the art's colours per slot and texel hue (dark to light), sampled with
   `python3 -I tools/meshy/colour_sample.py art/turnaround.png name:x0,y0,x1,y1:filter` (filters green, skin, brass,
   grey, dark). Vex: hair 123d1c..c4f6a4 (toxic green), green trim and tattoos, blacks 2a222a..727272 and leather
   262123..a39d9e (the art's own darks: they read a step darker in game than painted), skin 885a5e..e4ccc5 (the face
   sheet's), gunmetal 262729..b4b7bd, brass 4a3415..dcb866 (a step apart, so a gun reads grey and brass, not black).
   `smooth` first (edge-preserving, within UV islands), `despeckle` 1.
   **Measure the signature colours in game, not in the atlas**: the lit, tonemapped render moves saturated hues
   (Vex's hair: a 116 degree ramp read 112 in game, a 145 degree one 164, teal); sample both with
   `colour_sample.py <shot> name:box:green` and correct the ramp by the measured shift (Vex: 133 reads the art's 144).
5. The face: **Face rules (r3d)** below (`project_late` "face" from the flat-lit face sheet by landmarks).
6. Other paint-overs (`project_late`, after the ramps): chest and belly from the edited front view, the back (a
   backpack, a cape's emblem) from the edited back view (`view: back`), each with a registration measured by
   `tools/meshy/register_art.py` (front, or `--back`), `feather` from ~0.7 so only clearly frontal faces take the
   art (a front projection on a glancing face smears: Vex's strap smears), then the glancing faces' old dark paint
   cleaned by a `touch_up_late` with `side_only`; `slots` keep each paint-over on its part (the backpack: metal).
7. Pieces as geometry (`tools/meshy/warden_parts.py`, points `rel` to a bone so they follow the rig):
   `braids` (woven strands, copper wraps, bolts, a tuft; on `spring_` chains that swing; `length` to the art),
   `hoses` (ribbed tubes between body and weapon, weighted along their length, e.g. hips -> upper_arm.R ->
   forearm.R; 3-4 thick ones read, 2 thin ones don't), `lens` (a glowing dome on the glow slot; `iris` paints
   blades, dots, pupil and screws; `cut_r` removes the scan's own), `plate` (a plate drawn on the face sheet as
   a decal mesh: its outline in sheet px through the inverse of the face warp, ray-cast onto the face, lifted a few
   mm with a bevel, textured by the sheet itself: Vex's angular eye plate where Meshy built a round one; `holes`
   [col, row, r] where a part of its own must show through, e.g. the glowing lens: else the sheet's dark glass covers it).
8. `touch_up_late` for creases the projections can't reach (`val_max`: dark texels only, `flat` to the mid tone).
`recipe.py SPEC fit` writes `art/wardens/<name>/<name>.glb` and imports it (atlases lossless, LODs off).

## 7. Look (10 min)
The shared painted look (WardenGlb.PAINTED) does two things for every model, so you don't:
- 16c18b4f: it swaps the scene's cool ambient for a warm-neutral one, neutralises the blue fill and lifts near-black
  a step (skin reads warm, darks don't merge);
- f4b59cb3, the match camera: from 8 to 18 m the atlas blends one mip coarser (`far_smooth` 0.7, bias 1.0; more
  mixes a baked atlas's UV islands into mud) and the ink thins 80% (`INK_FAR_THIN`): no speckle, no dark outline
  noise.
- ext/warden-matchzoom, the speckle fringe (ORCH 15:15): from 8 to 18 m the pale fresnel drops to a third
  (`far_fres`), gloss, sheen and the lights' rims go (`far_spec`: the white dots on metal), what is left is
  anti-aliased (`far_aa`), stray texels are clamped to their coarser mip (`far_clamp`: no wider blur, no mud), the
  ink is gone from ~13.5 m (`INK_FAR_CUT`), alpha cards fade edge-on and keep their coverage face-on
  (warden_card `far_edge`, `far_alpha`), `rim_far` is a broad saturated band in `rim_far_color` (`far_rim_soft`),
  and every glow-slot piece gets a 1.4 px halo shell there (`GLOW_SHELL`) and a brighter glow (`far_glow`).
  Per-part opt-outs: `no_ink` (material tags) in the model's warden_look.json; `ink`, `glow_shell` to tune.
Per model, in `content/rules/warden_look.json` under the art name, start from Vex's:
- `painted`: `rim_far` 0.25-0.35 and `rim_far_color` the signature colour, saturated (Vex [0.35, 1.0, 0.45]): a
  rim at the match camera so the silhouette holds (0.9 turned every edge pale);
- `skin`: shade 0.9, top_light 0.35, fres 0.45, far_lift 0.12 (no shadow_tint: the shared one is warm);
- `metal`: top_light 0.15, fres 0.15, fres_tint 0.6, far_lift 0, sheen 0, rim_far 0, light_neutral_warm 0.6 (no
  silvered gunmetal, no highlighter brass: the warm light and top light push saturated gold to yellow; keep brass
  ramps dull, sat <= 0.6, top value <= 0.65, Vex 2e2214..8a7048);
- `cloth` and `leather` when they are black (r3e, ORCH 14:10 "muddy khaki at match zoom"): far_lift 0, fres 0.25,
  rim_far 0, top_light 0.3, light_neutral_warm 0.75. The Arena sun is orange (ffb27a): with the fresnel lift and the
  green signature rim, black trousers read #433d29..#5b5532 (khaki) at the match camera; with these, #171419..#3a3431
  (black). `light_neutral_warm` (hero_toon, default 0) takes the hue out of warm lights on those slots only, so
  skin and hair keep the warm sun;
- `hair`: far_lift 0.5, fres 0.6, glow 0.12 (the signature colour pops at the match camera);
- `glow`: glow 1.1 (r3e; 2.4 tonemaps a flat bright green to white at close range: the lens read as a white disc);
  `halos` for each glowing eye or lens (anchor_<name>; Vex [0.24, 1.0, 0.42], strength 2.2, px 2.4, near_d 7,
  far_d 14).
- If the shared warmth overshoots a palette (ORCH 13:20: Pip coral, Tarek orange, Kael red-brown, Ostra flat
  purple), correct it here per slot (`shade`, `far_lift`, `top_light`; the ramps in the fit), never in PAINTED.
Never change the shared shader's defaults or PAINTED for one Hunter: that is what this file is for. A new key a
Hunter needs goes into hero_toon as a uniform whose default changes nothing (r3e: `light_neutral_warm`), documented in
this file's "doc".

## 8. Stance (10 min)
`content/rules/warden_stance.json` (ext/warden-stance, S2's branch): the Hunter's `carry` for its own weapon (pos,
rot, free_l). Check idle (turnaround_close, front_34) and the run blend (moves_close_1, poses_game): the weapon rests
as the art draws it, no clipping through the body, the free hand where the art puts it.

## 9. Shots and self-score (15 min) (look)
`recipe.py SPEC shots`: --warden-shots (turnaround close and match camera, front_34, back_34, closeup, closeup_front,
moves, poses), the Arena match frame (`--arena=<arch> --record=2 --no-tips --arena-demo=pose_clear
--demo-zoom=1.0 --arena-shot=`: the review frame, no HUD caption or buttons, no sign, aim line or Focus tell, the
hero on clear ground it finds itself with no prop or grass over it; spec "demo_at" "dx,dz" still picks the spot)
and its x4 crop centred on the hero (the frame's DEMO_HERO_RECT line), and the composites vs the art in
`<raw>/shots/compare`. Score them with the rubric below, honestly, beside the art; fix the lowest line first and
loop (`recipe.py SPEC loop`).

### Self-score rubric (ship at >= 95 at BOTH distances)
| Close-up (front, 3/4, back) | pts | Match zoom (the Arena frame, x4) | pts |
|---|---|---|---|
| Silhouette and proportions as the turnaround | 15 | Silhouette reads as her (weapon side, hair shape) | 25 |
| Face: eyes, brows, lips, skin tone as the face sheet | 20 | Signature colours pop (hair, glow, trim) | 25 |
| Hair and its signature pieces (braids, tufts) | 10 | Value separation: darks not merged, skin warm | 20 |
| Signature props and parts (weapon, eye, backpack, hoses) | 20 | Signature props read (weapon grey+brass, not black) | 20 |
| Palette: every part the art's colour, no violet/grey cast | 15 | No artefacts (holes, fringes, flicker, seams) | 10 |
| Clean paint: no seams, smears, grain, patches | 10 | | |
| Outfit details (tattoos, belts, trims, boots) | 10 | | |
Write the score per line in your report and in captions.txt. Below 95: say which lines cost points and why.

## 10. Checks, commit, ship (15 min)
`recipe.py SPEC checks`: --warden-glb-check, --warden-model-check, --mantle-look-check, --move-feel-check,
--weapon-clip-check, the kit's combo check (spec `combo_check`, its flag in scripts/main.gd, e.g.
--gunslinger-combo-check or --hero-combo-check), --warden-stance-check (on the stance branch), `tools/health.py --strict`,
`tools/style_lint.py --strict`, and the secret grep (`git grep` for "msy" + "_" must find nothing). Then commit
(trailer `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`), push your branch, copy the shots to
`/home/boki/shots-s2/warden-3d/<name>/<tag>_*.png` with captions.txt lines, and report the score and the hash.

## Face rules (r3d)
The face is what the owner checks first. Paint it from the **flat-lit straight-on face sheet** (`<name>_face`, ext/imagegen
12:40; the portrait only if there is none: it is tilted and lit by its scene), never from the turnaround, with these
rules (fit spec `project_late`, the "face" entry of art/wardens/src/vex_fit.json; read the KIT/REFS note first for what
to ignore):
1. **One slot for the whole face.** Look at a flat slot map of the head first (tools/meshy/slot_map.py). Meshy's colours
   split a face between skin, cloth (pale highlights under the skin rule's saturation floor), hair (a green or
   blue iris) and metal (tan shading); each slot shades its own way, which reads as patches and as a "seam" along
   the jaw. Slot rules, in this order: the eye's box -> skin (before the hair rule), the hair rule, round parts
   by an ellipse (`circle` [x, z, rx, rz]: an eye plate) -> metal, then the face's front box -> skin.
2. **Align by landmarks, not by a scale.** A sheet has its own proportions (Vex's face sheet has a 22% longer
   lower face than the Meshy head; the portrait is also tilted 10 degrees). Read 12-16 landmarks on a gridded front
   render of the Meshy-frame mesh (tools/meshy/face_grid.py, a known px/m) and on the sheet (tools/meshy/grid_crop.py; read them on gridded
   crops, never on a downscaled whole image: those reads were 100 px off): both eyes (centre, inner and outer
   corners, the liner's wing), the brow (inner end, peak, outer end), the nose tip, the mouth's corners, the lips'
   parting, the lower lip, the chin, the jaw. `warp` fits a thin-plate spline through them (`smooth` 0.002; the
   logged residual should stay under a pixel). The paint then follows Meshy's sculpted eye, nose and mouth.
3. **Never project the art's outline.** The art's ink contour around the face, projected onto a mesh whose jaw is a
   little wider, is the dark jaw seam. `mask`: the face by exclusion (`exclude`: the hair, the sheet's grey ground)
   so plates and panels drawn on the face belong to it, closed over the features (`close` ~26 px fills the eyes
   and lips), eroded past the outline (`erode` 6 px on a 2000 px sheet).
4. **Carry the skin past the outline instead of stopping at it.** `inpaint: "outside"` fills everything outside the
   eroded face (and the art's own hair across the face, its plate and bracket: `skip_art`, `skip_art_box`) from the
   skin around it, fading to the skin's mid tone; the projection then fades only at the mask box's edge (`edge`
   ~28 px), so the blend into the body's skin happens under the hair, never on the cheek.
5. **Blend, don't overwrite.** `feather` [0.12, 0.5] on how much a face turns away; `slots` the face's own slots
   (Vex: skin, and metal for the eye plate the sheet draws: it paints the angular plate onto Meshy's round one;
   `exclude_circles` only for a part you keep as geometry). The body's skin ramp takes the sheet's own skin
   (sample its face, p5..p95), so the face and the neck, arms and belly are one tone. Then look for creases the
   projection could not reach (faces turned away: Meshy's dark paint there is a thin line) and lift them with a
   `touch_up_late` (`val_max`: dark texels only, flat to the mid skin tone).
6. **Eyes, lips, tattoos are the sheet's paint; the hair crossing the face is not.** With the warp the iris, the
   liner, the lids, the brow, the circuits and the lips land on Meshy's own eye and mouth. Hair of the same hue as a
   tattoo or trim (Vex's circuits are hair-green) is told apart by thickness, not colour: `hole_open` (~12 px) keeps
   only thick strands as holes, so thin lines and dots stay. Anything drawn on a part that turns away from the front
   (Vex's jaw panels on the jaw's sides) projects as a faint smeared line, the "seam": leave it out
   (`skip_art_poly`, filled from the skin) or build it as geometry; never let it half-project.
7. **A lens or eye that glows needs a halo to read at the match camera** (a 3 cm lens is a pixel at 23 m): an anchor
   on the lens (`anchor_<name>`, the fit exports it) and a `halos` entry in content/rules/warden_look.json (radius in
   screen pixels, `near_d` / `far_d` so close-ups keep the lens itself; Vex [0.24, 1.0, 0.42], strength 2.2, px 2.4:
   the signature's toxic green, the whiter r3d core read pale). Don't make the lens bigger: compare its size to the
   eye spacing in the face sheet first. When the face sheet draws the plate and its lens (Vex), draw the lens from the
   sheet too (r3e): the plate decal's `glow_circles` [[col, row, radius px]] put the drawn lens (its rings, its
   highlights) on the glow slot, and `lens.geometry: false` drops the modelled lens but keeps its anchor for the
   halo. A modelled lens under a drawn plate never lines up with the plate's ring (r3d/r3e: a black crescent beside
   a white dome).
8. **Check it like the owner does:** the front and 3/4 close-ups beside the portrait (r3d_closeup_vs_art,
   r3d_closeup_34_vs_art), the 3/4 for the jaw and the straps, the match frame for the halo.

## What went wrong on Vex, and the fix (check yours for the same)
| Symptom | Cause | Fix |
|---|---|---|
| A hand fused to the hip | Meshy joins touching parts | edit the input: the arm hangs free |
| Hoses / braids fused to the body | same | edit them out, build them as geometry |
| A side view grows an extra sleeve | the edit drew the hidden arm | "completely hidden behind her body" |
| Lilac skin, violet blacks | the scene's cool ambient + blue fill | the shared look fix (16c18b4f) |
| A black mass of a gun at match zoom | dark ramps + a darkening gain | gunmetal and brass ramps a step up, no gain |
| Patches and a jaw seam on the face | the face split over 3-4 slots; the art's outline projected | slot rules order; Face rules |
| Smears on straps at 3/4 | a front projection on glancing faces | `feather` from 0.55-0.6 |
| Braid NaNs / a line to the floor | the drape stacked two points | fixed in warden_parts (resample, guarded frames) |
| Torso stretched 30% | scaling by the hips' height on a long-legged body | `scale_joints`, the archetype's legs |
| The lens reads amber, the brass highlighter-yellow | a big saturated brass rim and gold ramp under the warm light | a larger, brighter green dome, a dull rim, dull brass ramps, metal top_light/fres 0.15 |
| A model the loader refuses | the rig changed under it (a body edit) | `recipe.py SPEC rig fit` again |
| The hair the wrong green in game | the lit render shifts saturated hues | measure in game, correct the ramp (step 6.4) |
| Hoses invisible from behind | hidden by an arm or a braid, or draped flat on black cloth | hang them in a loop off the body, between the braid and the arm, a grey a step above the cloth |
| Muddy grey-green model at match zoom | a mip bias > ~1 on a baked atlas mixes its UV islands | keep `far_smooth_bias` at 1.0 (f4b59cb3) |
| Khaki / brown blacks at match zoom | the orange Arena sun, the fresnel lift and the signature rim on black cloth | `cloth`/`leather`/`metal`: light_neutral_warm 0.6-0.75, fres 0.25, rim_far 0, far_lift 0 (step 7) |
| The lens a white disc with a black crescent | glow 2.4 on flat green; the decal's hole and the modelled lens out of line | the sheet's lens on the plate (`glow_circles`), `lens.geometry` false, glow 1.1 |
| Green smears on the chest | the art's top trim projected onto skin above the mesh's trim, re-added by a tattoo line pass | no line pass there: `clean_green` on that skin; tattoos only where no trim of their hue is near |
| A caption or a plant over the hero in the match frame | the Arena's tips and its spawn props | `--arena-demo=pose_clear` (recipe.py shots) |
| White/dark speckle fringe at match zoom | per-pixel fresnel, gloss and light rims on a dense mesh; a sub-pixel ink shell; stray texels; edge-on alpha cards | the shared far_* look (ext/warden-matchzoom); `no_ink` for thin parts |
