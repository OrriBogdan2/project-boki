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
  centre) on his own joints (within 5 mm); `size` 0.95 makes him 1.28x a medium hunter (the art's ~2.25 m). Needed
  the one-line fix in Models.hunter: a bulky hero's leg length (and the limbs slider) was reset by its bulk.
- **Bones:** his bones renamed onto the contract (Hips, Spine and Chest -> `hips`; Head -> `head`; arms and legs
  one to one; the boots ride `shin`); the shoulder domes split off the Chest onto `pauldron.L/R`; `root` and `skirt`
  carry nothing. His claw fingers, eye, winch, rope and hook are Dredge's variant bones (`WardenGlb.EXTRA`,
  RIG_CONTRACT "Variant bones"). Re-posed onto the rig: thighs, shins and upper arms turned and stretched joint to
  joint, the forearms moved onto the rig's elbows (his long claw arm keeps its length and angle; the hand bone sits
  on the rig's hand, the claw hangs on below it, rigid).
- **Weapon:** the horn (his Hand.R) cut into `weapon` in the Gun node's space, narrow end on the shotgun's grip,
  mouth forward, x1.3, solidified 12 mm (its mouth has an inside); `weapon_muzzle` on its mouth moves the Gun's
  Muzzle there. 3,200 triangles.
- **Budget:** planar dissolve (1 degree) then collapse to 12,400 triangles, plus the orb and the drips: 14,139;
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
- - `dredge.glb.import`: `generate_lods=false`, `force_disable_compression=true`.
