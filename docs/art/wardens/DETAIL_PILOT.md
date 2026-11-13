# Hunter detail pilot (11-09): normal map, 25k and 40k triangles

The owner's order: the 3D reads rough and low-poly, make the models better, cost is no object. This pilot
rebuilt two Hunters, Vex (gunslinger) and Cinder (ashwick), from their dense Meshy meshes in four ways and
measured each. No new Meshy runs. The shipped models are unchanged; the owner picks a tier, then the roster
is rebuilt to it.

## What was built
| Tier | What changes | Vex tris | Cinder tris | Vex .glb | Cinder .glb |
|---|---|---|---|---|---|
| shipped | | 10,715 | 11,775 | 4.3 MB | 7.8 MB |
| normal | the same mesh, the normal map baked again (below) | 10,715 | 11,775 | 6.9 MB | 12.7 MB |
| 25k | more triangles, the same bake | 23,543 | 25,382 | 7.7 MB | 14.0 MB |
| 40k | more triangles, the same bake | 37,224 | 40,285 | 8.6 MB | 14.8 MB |

Textures in every tier: one 2048² atlas (Cinder also a 2048² glow map and her hair cards), one 2048² normal map.
In the game a 2048² normal map is 5.6 MB of video memory and about as much in the download (RG compressed,
mipmapped), whatever its size in the .glb. Cinder shipped without one, so every tier adds that to her.

Three things the brief assumed that are not so:
- Vex already shipped with a baked normal map (4 samples, stored as JPEG). The new bake is cleaner, not new.
- Both are built by `tools/art1/<name>_*.py`, not `decimate_warden.py`. The triangles are set there, by part.
- Cinder and Kael import with `generate_lods=false`; the other ten have LODs. The tiers here have them on.

## The three levers
**(a) Normal map.** Cycles, selected to active, from the dense mesh under Meshy's own normal texture, 2048²,
16 samples. Three fixes over the bake Vex shipped with:
- A tight cage (Vex 5 mm out, 12 mm reach; Cinder 3 mm, 8 mm). With a wide cage 11.5% of Cinder's texels hit a
  back face or the next layer (armour over skin, hair over armour).
- `paintkit.clean_normal` flattens what still tilts past 65°: such a texel is a wrong hit, and flat it shades
  by the mesh. Share flattened: Cinder 4.8% / 3.3% / 2.2% (normal / 25k / 40k), Vex 0.9% / 0.7% / 0.35%.
- The map is stored lossless (PNG) in the .glb. JPEG at quality 92 bent the normals by 4.4° on average (13.5°
  at the 95th percentile), which shows as grain under the toon ramp. The engine compresses it either way; the
  cost is the repo (.glb +2.6 MB Vex, +4.9 MB Cinder).

Strength: at ×1.0 Cinder's skin reads a little plastic and a dark smudge sits beside one eye; at ×0.6
(`"painted": {"normal_k": 0.6}` in `warden_look.json`) the brow, cheek and horn ridges stay and the face is
soft again (`detail_pilot/cinder_normal_strength.jpg`). On Vex the new bake is hard to tell from the shipped one.

**(b) Triangles.** The builds take their budgets from the environment:

| | Vex | Cinder |
|---|---|---|
| shipped | `VEX_LOW_TRIS=5400 VEX_HEAD_TRIS=5000 VEX_FACE_TRIS=1800` | `CINDER_LOW_TRIS=12500 CINDER_FACE_TRIS=2300 CINDER_HAND_TRIS=800` |
| 25k | `14000`, `7000`, `3500`, `VEX_HEAD_WELD=seam` | `27300`, `4000`, `1400` |
| 40k | `24000`, `13000`, `5000`, `VEX_HEAD_WELD=seam` | `42300`, `6000`, `2000` |

Run the Hero's steps in order with those set: `vex_source.py`, `vex_headscan.py`, `vex_finish.py`,
`vex_clips.py`; `cinder_source.py`, `cinder_finish.py`, `cinder_clips.py` (arguments as in PIPELINE.md).
The rig, weights, anchors, slots and clips come out the same; `--warden-glb-check` passes on every tier
except for its 15k cap.

**(c) Where the decimation was ugly.** Both builds already decimate by part (face, hands, horns and the rest
each get their own budget), so the face and hands are protected by budget; the tiers raise those budgets
most (Vex's face 1.8k → 5k, Cinder's hands 800 → 2,000 each). The one real fault found: Vex's head welds every
vertex within 3.5 mm after decimating, to close the seams between its pieces. That collapses the thin hair
and cuts the head from about 7,500 triangles to 2,510: the flat, chunky hair in the shipped model.
`VEX_HEAD_WELD=seam` welds only the open borders, so the head keeps what it was given.

## What it looks like
Sheets in `detail_pilot/`, each shipped | normal | 25k | 40k, one worker (RTX 4090, Forward+), the game's light:
`<name>_face.jpg`, `<name>_three_quarter.jpg`, `<name>_full.jpg` (weapon and hands), `<name>_match_zoom.jpg`
(the match camera, pixels ×3). The full renders of every tier are in `~/renders/warden-detail-pilot/<tier>/`.

- **At the match camera nothing changes.** A Hunter is about 40 pixels tall there; the four tiers cannot be
  told apart. Everything below is about close views: the title, the hub, Hunter select, the put-on scene.
- **Vex, 40k:** the clear win. Hair in separate locks instead of flat planes, round bandolier shells, a clean
  collar and goggle strap. 25k sits close to shipped: its head budget (7k) is still short for the hair.
- **Cinder, 40k:** fingers read as fingers, hair and jaw line are smooth, the armour plates keep their edges.
  25k sits in between.
- **Cinder's face gets worse at 25k and 40k**: dark patches by the eyes and ember specks on the nose.
  They are there with the normal map off (`~/renders/warden-detail-pilot/40k_no_normal/`), so it is the paint
  step, not the bake: `cinder_finish.py` classes skin, armour and ember by colour and paints the eyes into the
  pits it finds, tuned on the 12k mesh. It needs a pass at the new density before a higher tier of her ships.
- **What triangles do not fix:** the blotchy paint in close-up (Vex's top and jacket, Cinder's hair) is the
  Meshy texture. It is now the roughest thing on both models, more than the polygons.

## What it costs to draw
`--hunter-gpu-bench` (`tools/hunter_gpu_bench.gd`): six Hunters (three of each) and four Boki in idle at the match
camera, 1280×720, quality medium, no frame cap; all tiers in one process on one machine.

| Machine | | shipped | normal | 25k | 40k |
|---|---|---|---|---|---|
| RTX 4070 SUPER (GL Compatibility) | GPU ms a frame | 1.83 | 1.82 | 1.83 | 1.89 |
| | frame ms, no cap | 6.43 | 6.59 | 6.48 | 6.46 |
| Apple M5 (GL Compatibility, no GPU timer) | render CPU ms | 11.47 | 11.27 | 11.29 | 11.75 |
| | frame ms, no cap | 14.29 | 13.56 | 13.78 | 14.64 |
| RTX 4090 (Forward+) | GPU ms a frame | 0.47 to 1.08 | 0.78 to 1.19 | 0.37 to 1.10 | 0.31 to 1.22 |
| any | triangles drawn a frame | 245k | 243k | 390k | 489k |

- 25k costs nothing that can be measured. 40k costs about 0.06 ms of GPU (+3%) on the 4070 and 2% of the
  frame on the M5, which is inside that machine's run-to-run spread (the normal tier read 5% *faster*).
- The 4090 is shared with other jobs, so its rounds swing by more than the tiers differ: the shipped models
  alone read 0.47, 0.68, 0.74 and 1.08 ms in one run, and 40k read both the lowest and the highest. All it
  says is that every tier draws in about a millisecond or less there.
- Draw calls do not change (170). The LODs take a share off the higher tiers at this distance: the 40k
  models have 3.4 times the triangles of the shipped ones and the frame draws twice as many.
- Not measured: a weak integrated GPU, and a real match (more effects on screen, the same Hunters).

## Recommendation
Pick one:
1. **40k for every Hunter, normal map at ×0.6** (recommended). It is the only tier that visibly answers
   "low-poly" in close views, and the GPU cost at the match camera is at most a few percent. The price is the
   download (about +2 MB of mesh a Hunter, +5.6 MB for each Hunter that has no normal map yet), the repo, and
   a rebuild of each Hunter with its own script: the paint and class steps are tuned to today's meshes
   (Cinder's face shows it) and need a pass each. Raise `TRIS_MAX` in `tools/warden_glb_check.gd` and the
   budget line in RIG_CONTRACT.md to 40k in the same change, and turn LODs on for Cinder and Kael.
2. **25k.** Half the mesh size of 40k for the hands, hair volume and armour edges; the hair locks and face
   need 40k. Free on every machine measured.
3. **Keep 15k, new normal bake only.** Small gain; worth taking only for Hunters that have no normal map.

Whichever is picked, the next lever is the paint, not the mesh (a cleaner or larger atlas).

Not done here: the variant .glb files are not in the repo (65 MB for the six); they are in
`~/meshy/vex_v2/wdp/<tier>/c/vex_out.glb` and `~/meshy/cinder_v2/wdp/<tier>/cinder_final.glb`, and a design
variant folder `art/wardens/<art>_<tier>/` plus `--warden-variant=` shows one in the game. The normal bake
changes are in the build scripts, so the next rebuild of Vex or Cinder at any tier picks them up (Cinder
gains her normal map then).
