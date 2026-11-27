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
- **Walls, props and games (follow-up):** the portal ring and the glider rack count as walls (rules `props`), a
  building's roof counts 0.8 m past its tile. With a wall close behind, the camera keeps `wall_min_m` (2.6 m) from you
  by tipping the view up (to `wall_pitch_deg`) instead of closing in until the face fills the screen. A minigame
  round (Volley, Fetch, Echo Steps) tips the view up to 48 degrees and draws it back 1.6x so the court shows; Kite Tow's
  13 m loop is too wide for that and blends to the top-down view for the flight.
- **Back to top-down:** build mode, the training sessions and a tutorial spotlight (it lights a Boki or building that
  may be behind the camera) blend to the Settings view over 0.8 s and back.
- **Not touched:** matches, the tutorial arena and expeditions (their `MatchCam` / `CamRig` use is unchanged; `lean_scale`
  stays 1, so bodies keep the match lean). The house interior (`interior.gd`) keeps its own top-down camera.

`--farm-cam-check` holds all of this; `--farm-cam-clip` films it (GPU worker).
