# Dredge: import note

`dredge.glb` is the hand-made Blender model by the owner's friend (origin/ext/imagegen
docs/art/gen/models/dredge_friend/Dredge.glb, 2026-11-04), fitted to the Warden contract by script. No Meshy credits.
It follows the owner-locked r2 art (docs/art/gen/wardens_r2/dredge_*): the brass diving-sphere hull with one
porthole and the red eye, the horn (blunderbuss) right forearm, the three-finger grab-claw on the left, the winch
drum on top with the rope and cargo hook on his left, iron limbs, boots, tar drips, seaweed and barnacles.

    git show origin/ext/imagegen:docs/art/gen/models/dredge_friend/Dredge.glb > ~/meshy/dredge_friend/Dredge.glb
    godot --headless -- --warden-rig-json --warden=dredge          # -> art/wardens/src/dredge_rig.json
    blender -b --factory-startup --python tools/blender/fit_rigged.py -- art/wardens/src/dredge_fit.json
    godot --headless --import

- **Source:** one mesh, 43,690 triangles in 3,440 loose primitive pieces, 10 materials, 27 joints, a rigid skin (one
  bone a vertex), one 4 s clip (not used: HunterAnim and the kit moves drive him). Both exports lost the materials'
  colours (every base colour came out white or grey): the colours here are picked from the art.
- **Scale and body:** x0.665 into rig space, turned to face +Y. The archetype body (`legs` 1.738, `build` 1.07,
  `neck` -0.066) puts the rig's hips, shoulders, elbows, the shoulder and hip spacing and the head (on the hull's
  centre) on his own joints (within 5 mm); `size` 0.99 makes him 1.28x a medium hunter in his hunched stance (the art's ~2.25 m; 0.95 before the stance). Needed
  the one-line fix in Models.hunter: a bulky hero's leg length (and the limbs slider) was reset by its bulk.
- **Bones:** his bones renamed onto the contract (Hips, Spine and Chest -> `hips`; Head -> `head`; arms and legs
  one to one; the boots ride `shin`); the shoulder domes split off the Chest onto `pauldron.L/R`; `root` and `skirt`
  carry nothing. His claw fingers, eye, winch, rope and hook are Dredge's variant bones (`WardenGlb.EXTRA`,
  RIG_CONTRACT "Variant bones"). Re-posed onto the rig: thighs, shins and upper arms turned and stretched joint to
  joint, the forearms moved onto the rig's elbows (his long claw arm keeps its length and angle; the hand bone sits
  on the rig's hand, the claw hangs on below it, rigid).
- **Weapon:** the horn (his Hand.R) cut into `weapon` in the Gun node's space, narrow end on the shotgun's grip,
  mouth forward, x0.95 (r3; x1.3 before), solidified 12 mm (its mouth has an inside); `weapon_muzzle` on its mouth moves the Gun's
  Muzzle there. 3,200 triangles.
- **Budget:** planar dissolve (1 degree) then collapse to 7,400 triangles (r3: the old shell stripped first), plus the
  new hull, the orb and the drips: 13,572;
  hard edges sharp past 50 degrees.
- **Aged paint (r2b, owner 09:05):** tools/blender/warden_paint.py, from the spec's `paint`, `orb` and `drips`:
  - one 2048 painted atlas (`dredge_atlas.jpg`, Godot extracts it), fresh smart UVs over the body and the horn, baked
    in Cycles (CPU, about 10 s): each material's colour with grime in the crevices (AO), verdigris on the brass and
    rust on the iron (noise patches gathered in the crevices), dents as painted light and shade (a voronoi bump lit
    by a fixed key light), scratches, worn edges, a painted highlight on the glossy tar, cracks and the eye's red
    light over the lens, a warm gold highlight painted on the upper curves (verdigris kept to the crevices).
    Colours: brass 654a26 (highlight c8963e), iron 4c4844, boot 4e3e32, tar 120d0e, glass 4e5862 (the rest as r2);
  - the eye: the old red asterisk replaced by an emissive orb (`glow-eye`, ff2418, flat) on the `eye` bone, set in
    the cracked lens;
  - 24 tar drips (about 66 triangles each) hanging from the faces that look down: the hull's underside (12), the
    porthole (3), the shoulder domes, the elbows, the hips and the claw, each on the bone of what it hangs from;
  - the materials keep their slot names (metal, leather, cloth, glow); the game shades the atlas like Vex's.
- - **Hull (r3, owner 13:10):** the friend's sphere, domes, rivets, hatch and red gashes (1,342 pieces of the
  Chest, `strip`) replaced by a scripted hull (tools/blender/warden_hull.py, `hull`): a dented sphere (16 dents),
  two raised plate bands, and four faceted lames on each shoulder (on pauldron.L/R) in place of the domes. Its
  colour is the art's: three nano-banana edits of the art (front, side, back: the hull alone, ~/meshy/dredge_r3)
  projected along their axes and baked into the atlas (`metal-hull`, lifted x1.3). The rest of the brass is the
  art's olive-gold (7d6c3e, highlight c4b070); the horn x0.95 (it read too big at x1.3). The porthole, lens, orb,
  winch, rope, hook, claw and tar stay. 45 credits (5 edits); no Meshy 3D run.
- **r3b (credit-free):** the hull's outline broken by five modelled tears (a jagged dark gash and a plate flap
  peeled 20-28 degrees out about it: right of the porthole, lower front, his left side, two on the back); the
  shoulders three big curved lames each (wider, hanging lower) in place of four bands; the front image's own
  porthole faded where the model has its porthole (`mask`); the porthole's iron rings moved to brass (`remat`).
- **r3d (credit-free):** the stance on the branch (ext/warden-stance's four commits: hunched, the horn hanging
  low); deeper dents (22, 4-8.5% of the radius) and seven tears with flaps peeled 36-44 degrees out; a fourth,
  wider lame flaring each shoulder's lower edge; the lens's crazed paint replaced by six sharp crack strips over
  the dome (`cloth-crack`) and a white glint on the orb (`glow-shine`); six tar strands sagging from the hull to
  the pelvis; a red core glowing inside the ribs (`glow-core`); a tar pool at his feet on the new variant bone
  `pool` (root), which DredgeKit spreads while he stands and takes away when he moves or leaves the ground. The
  projections' grey backgrounds filled with the hull's own colour (plate undersides were grey).
- **r3e (credit-free):** nine tar runs that follow the hull's surface down from the porthole, the tears and the
  seams and drip off its underside (17 plain drips now, from 24, to pay for them); the back's riveted hatch as a
  raised iron plate and its pipe as an iron tube standing off the hull; eight stronger, white lens cracks; a soft
  warm highlight painted on the hull's upper curves. Body 14,741 triangles (decimation 6,600).
- `dredge.glb.import`: `generate_lods=false`, `force_disable_compression=true`.
