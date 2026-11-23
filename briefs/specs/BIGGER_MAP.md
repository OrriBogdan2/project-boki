# Bigger map: running notes for the spec (queued last)
- 2-3x area with streaming; keep frame time and load flat; keep keys-cover's biome cover shares; scale landmarks, shops, key carriers and extraction points (main session, 13:35 ET).
- **Sky train (owner, 16:50 ET):** today it only runs through the central islands. Route it further out, closer to the edges (not all the way), so it loops past more of the outer islands. Generate it in make_hollowcrown.py, and check its stops still reach landing spots and extraction points.
- **Sky train shape (owner, 17:01 ET):** not a perfect circle. A winding, interesting route: curves, switchbacks, varied distance from the centre, passing close to features. Still a loop, but irregular.
- **Remove the out-of-place high islands (owner, 17:01 ET):** delete the floating upper islands that are reached by a jump pad. Higher ground is fine where it's part of the terrain (hills, ridges, plateaus, cliffs reached by walking, ramps or climbing). There's no jump-pad-to-island-on-top, especially anything that fights the camera (occlusion, sudden zoom or tilt, losing sight of your hunter).
  - Check: no walkable surface higher than X m above its surroundings unless a walkable ramp or path reaches it.
  - Check: no jump pads whose only purpose is reaching an isolated upper island.
  - Check the camera's occlusion test at every high spot.
