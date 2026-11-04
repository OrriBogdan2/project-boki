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
  mouth forward, x1.3; `weapon_muzzle` on its mouth moves the Gun's Muzzle there. 1,700 triangles.
- **Budget:** planar dissolve (1 degree) then collapse to 14,500 triangles (14,130 after import); hard edges sharp
  past 50 degrees.
- **Materials (flat, slot-named):** metal-brass 94804f, metal-iron 6c6762, metal-glass 8c949c, leather-boot 5e4a3c,
  leather-tar 231a1c, leather-rope a07e52, cloth-flesh 8e2a2c, cloth-seaweed 56783e, cloth-barnacle c4b8a0,
  glow-eye ff2418: four toon slots. The loader shades them with the procedural heroes' clean painted look.
- `dredge.glb.import`: `generate_lods=false`, `force_disable_compression=true`.
