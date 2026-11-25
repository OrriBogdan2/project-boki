## Farm third-person view (`FarmCam`, 2026-11-24)

The farm (both zones: the start zone with the beds and the hub with the house) opens in a close third-person view:
behind you, 20 degrees down, 3.5 to 5.5 m back (the mouse wheel and Ctrl look still change the distance), lens 50.
`scripts/home/farm_cam.gd` drives the home's `CamRig` (pitch, lens, rise, yaw, `dist_mul`) every frame, so the
tutorial pans (`CamLook`, talk framing) still hand the camera a focus point and it follows it. Numbers and the single
flag are in `content/rules/camera.json` "farm": **`"third_person": false` puts the top-down view back everywhere**.

- **Orbit:** hold the right mouse button and drag (or the right stick); it also tips the view between 8 and 42 degrees.
- **Keys:** W walks away from the camera (`FarmCam.keys` turns the move keys by the view's yaw); you face where you walk,
  not at the cursor. The cursor still picks things (hover, prompts, the fetch toss).
- **Walls:** the view is pulled in along itself so it never sits inside the ground, a building, a tree or a rock (the
  placed blocks under buildings are only 1.2 m tall for climbing, so `building_m` / `tree_m` say how tall they are to
  the camera), and backs out again at 5 m/s. Fences and benches are low and do not pull it.
- **Back to top-down:** build mode, the training sessions and a tutorial spotlight (it lights a Boki or building that
  may be behind the camera) blend to the Settings view over 0.8 s and back.
- **Not touched:** matches, the tutorial arena and expeditions (their `MatchCam` / `CamRig` use is unchanged; `lean_scale`
  stays 1, so bodies keep the match lean). The house interior (`interior.gd`) keeps its own top-down camera.

`--farm-cam-check` holds all of this; `--farm-cam-clip` films it (GPU worker).
