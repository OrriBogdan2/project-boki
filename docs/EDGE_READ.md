# Reading an edge before the step (2026-11-09)

Walking off a ledge is always allowed (DECISIONS), so the player has to see what is below before stepping. From the
match camera a terrace lip and an abyss edge looked alike: both were the same pale lip. Now, behind the existing
"Height cues" setting (`depth_cues`), in `shaders/terrain.gdshader` only (no particles, no ground ring):

- **Terrace lip** (a step of 0.8 m or more down to other ground): a warm, golden top-edge highlight.
- **Abyss edge** (ground touching the abyss, baked per tile in the height texture's blue channel by
  `TerrainMesh.height_texture`): a thin cold blue rim, and a violet haze just under the lip that thins as the rock
  drops away. The mark is baked rather than read off the filtered height, because on raised ground the filtered
  height falls well before the abyss does, which painted a false warm terrace band inside the cold rim. The faces of an abyss cliff haze toward violet, a terrace face still goes dark
  toward its foot.
- A ramp's gentle fall is neither (the step threshold keeps slopes plain).

It is part of the terrain material, so Low (no shadows, no bloom, 0.8 render scale) draws it exactly as High does.
Very Low is not on main yet (it is on ext/particle-budget); the same shader runs there, and downscaled to 540 px the
rim still reads (checked on a 960x540 resize of the Low frame).

Shots: `docs/edge_read/edge_<n>_<abyss|terrace>.jpg`, left before, right after, a 640x360 crop around the Hunter
on the lip, Low preset, match camera, Hollow Crown seed 77. Made with `--depth-shots --edge-read --quality=low`.
Edges 1-3 are abyss, 4-5 terrace (after: jobq 20261109-175103-27366). Check: `--edge-read-check` (the height
texture is 0 exactly over the abyss; its b is 1 on the abyss, 0.5 on ground touching it, 0 elsewhere; both edge kinds
exist on the map).
