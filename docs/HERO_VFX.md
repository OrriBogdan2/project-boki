# Hero VFX and sounds

A Hero's ability looks and sounds are data: `content/vfx/<arch>.json`, played by the shared `HeroVfx`
(`scripts/match/hero_vfx.gd`, one pooled node per match). A Hero needs a data file, a line per
moment in its kit, and sounds. Check: `--hero-vfx-check` (every data file against its kit, plus the shared runtime). Tuning a
palette: `--hero-vfx-gallery --shots-dir=<dir> [--reel-hero=<arch>]` plays every move side by side (no Hero: one of every
layer kind). Approval sheets and the reel: `--hero-vfx-reel` (the tool's header has the movie-writer command); a Hero's
scripted parts go in `tools/vfx_reel/<arch>.gd`, otherwise the generic set plays.
The parity reels (`--parity-reel`, one MP4 per Hunter with the keys shown, `docs/parity_reel/`) are `tools/parity_reel.gd`.

## From a kit
- `vfx("move", at, dir, {...})` (ArchKit): a moment. Sounds and layers come from the recipe; online it goes to other
  games as the `["fx", "hvfx", ...]` event, since they don't run the kit. Set `"net": false` on a recipe to keep it local.
- `HeroVfx.of(m).hold(h, "move", k)`: something that lasts while the kit asks every tick (a blade heating). It follows its
  anchors and turns with the aim (a hose sweeping), and stops by itself when the asks stop, whichever way the move
  ended. Particle layers only, and local.
- `HeroVfx.of(m).trail(h, "move", node)`: the move's `ribbon` layers follow a projectile's node (a shot's mesh) until it
  is hidden or freed, at most `TRAIL_MAX` s. For tracers, needles, thrown charges.
- `run_own(stage, cx)` (ArchKit) in place of `run`: the stage's rules run, the shared cast language (AbilityFx, KinExec's rings,
  cones and delivery sounds) stays out, so only the Hero's own look shows.

## A recipe
`"move": {"sfx": [...], "fx": [...]}`. Options the kit passes (`"r"`, `"len"`, `"w"`, `"k"` the charge, `"flip"`, or any flag
named by a layer's `"when"` / `"unless"`) fill sizes: `"size": "r"` with `"size_x"` to scale it, `"size_k"` to grow with `k`.

| layer `p` | what | key fields |
|---|---|---|
| `sweep` | an arc of flame, burning away; its head runs the arc in `turn` s (default 0.28 of the life); `band` (0..1 of its depth) draws an even blade, not tapered (a 360 ring) | `size` outer radius, `arc` deg, `tilt`, `yaw`, `flip`, `turn`, `band` |
| `scorch` | the ground burning, fissures cooling; with `"stitch": true` a lane is a seam of cross-stitches | `shape` disc / lane / cone, `size` or `len` + `w`, `arc` |
| `skirt` | a wall of flame growing out | `size`, `from`, `tall`, `arc` (share of the circle) |
| `flare` | a ragged burst facing the camera | `size`, `grow`; `"ride": true` keeps it on its `at` while it lives (any surface look: it follows the Hero and the clip, e.g. a hop) |
| `ribbon` | a mesh trail following an anchor, or the kit's `o.follow` node with `"follow": true` | `at`, `life`, `tail` s, `size` width, `wave` m of sideways drift (a thread) |
| `thread` | a loose thread lying on the ground from `at` along `dir`, swaying | `len`, `w`, `life` (may outlast the 2.2 s cap, with its needle) |
| `string` | holds only: a thin glowing line through named anchors | `through`, `size`, `skip_if` (a model node that means it brings its own) |
| `bolt` | a strip from A to B facing the camera: lightning with `jag` > 0 (0.3-0.7), a taut thread at 0 | `size` width, `len` along the aim, or `to` (an anchor), or the kit's `o.to` (a Vector3; local only, other games use `len`) |
| `vortex` | a ground disc spinning inward to a dark core (`c3`); with `"thin": true` only three lit comet arcs on its rim (no fill, no core), which `grow` < 1 draws in toward the centre | `size` radius, `spin` turns/s (negative: the other way), `grow`, `thin` |
| `ring` | a shockwave racing out over the ground: a hard band with a hot lead edge, a flash of dust inside, breaking up as it spends | `size` radius it reaches |
| `ember` / `smoke` / `chunk` / `shard` / `card` / `coin` / `star` / `drop` | GPU particles: hot streaks, cel puffs (lit `c`, shaded `c3`), dark debris, crisp crystals, tumbling cards burning from the edges, spinning metal glints, twinkling four-point stars, water drops | `n`, `speed`, `spread`, `way` up / fwd / back / along, `grav`, `drag`, `curl`, `shape` ball / line / disc / gather / arc, `burst` 1 all at once .. 0 over the life |

All layers: `at` (`here`, `h` the body, or an anchor), `y`, `fwd`, `delay`, `life`, `c` / `c2` / `c3` (palette keys: body,
hot, char), `near` (dropped past LOD_NEAR). Sounds: `n`, `db`, `other` (extra dB for anyone but the player), `pitch`,
`pitch_k`, `var`, `delay`, `at`, `when` / `unless`.

## The cel look
Every effect in the game shares one cel pass, `shaders/cel.gdshaderinc`: `hard()` (a one-pixel anti-aliased edge),
`cel()` (heat in `CEL_BANDS` flat steps), `cel_cover()` / `cel_glow()` (a soft cover or additive glow turned into flat
steps with edges ragged by the noise) and `cel_ring()` (the shockwave ring: a hard band with a hot lead edge that
breaks up as it spends). They sample `art/vfx/noise.png` (r billows, g fbm, b cell walls, baked by
`python3 tools/gen_vfx_noise.py`) through the `vfx_noise` shader global in project.godot, so no material wires it.
Smoke is a lumpy puff in two flat tones (`c` lit from screen up-left, `c3` shaded), eaten away by noise; it is near
opaque, so a recipe needs fewer, smaller puffs than a soft smoke did.

Who includes it: the data looks here (`hero_vfx.gdshader`, `hero_vfx_mote.gdshader`, ring layer `"p": "ring"`), the
kit shaders (`ld_fx` Ashwick / Dredge, `dj_fx` Kael / Sable, `vv_fx` Sparkle / Vex, `KitShaders` Hem / Breaker,
`care_disc` / `care_glow` Pip / Claire, `molten_rock` Tarek's hard cel cracks, `void_glass` Ostra's banded rim) and the shared hit effects in `Fx` (`impact`, `spark`, `fx_dot` dust in two
tones, `swoosh`). The ring modes of `ld_fx` (11), `dj_fx` (4) and `vv_fx` (2) and the shared `Fx.ring` burst (`fx_ring`) draw `cel_ring()`. A ground ring means gameplay (the area something hits or marks): no bursts on dashes, landings or resets. A new effect shader
includes the file and runs its cover and glow through `cel_cover()` / `cel_glow()` last.

## FX anchors
`"anchors"` in the data names points on the Hero. Each resolves in order: `nodes` (empties on the .glb, e.g.
`anchor_blade_tip`, or `weapon_muzzle`), `bone` (a contract bone such as `hand.R`, `forearm.L`, `head`, with `off` [x, y, z] in the bone's space: follows the live pose on any .glb model), `gun` (a point in the Gun node's space), `body` ([side, up, forward] from the feet along
the aim), with `hand` r / l between them for a point that rides a hand bone. So a look works on today's model and picks the new anchors up when a model ships them. `docs/RIG_STANDARD.md` lists
the empties; Kael reads `anchor_blade_tip`, `anchor_blade_mid`, `anchor_chain` (his right wrist, where the hanging
warchain hides when thrown), `anchor_feet` when present, Lace `anchor_nock` (on the string bone `bow_s`, so it follows
the draw), `anchor_bow_root`, `weapon_muzzle`, `halo_bow_top`, `halo_bow_low`. An empty rides the bone that carries
its mesh: Vex's muzzles sit on `forearm.R` with the minigun, not on the clips' `gatling` and `launcher` bones.
`--hero-vfx-check` (tools/hero_vfx_emit.gd) holds each ability's emitter within 0.15 m of its bone, or of the mesh
the bone carries, through every clip of Vex, Kael, Lace, Cinder, Albert and Meeko.

## Cloth ends
A top-level `"scarf"` block hangs two cloth tails off the Hero (Claire: the frost-scarf ends from the back of her neck
wrap). `scripts/match/hero_scarf.gd` runs them for every Hero on the map: each tail is an 8-point rope pinned beside the
`at` anchor (`gap` m either side along her shoulders) and drawn as one lit, two-sided ribbon mesh
(`shaders/scarf_ribbon.gdshader`: `c` at the knot fading into `c2` toward a cut point). At rest a tail hangs `len` m down,
a little `back` and out (`splay`); moving, the air's drag streams it back against the motion and it flutters harder the
faster she goes. Keys: `at`, `gap`, `len`, `w` m wide, `back`, `splay`, `c`, `c2`. A wearer keeps its pair of meshes; a
gone one's pair goes back to the pool, and one drawn while the match loads compiles the shader. Off at the Low preset, past `LOD_FAR` and while the Hero is hidden.

## Rules
- **Colour:** looks stay in the Hero's palette. The you / ally / enemy language is the telegraphs' and outlines' job: lanes
  and discs are AimKit's and are not drawn here. An ally's effects draw at `ALLY_K`.
- **Budget:** `MAX_LIVE` GPU particles alive in a match, `POOL` nodes per kind, the quality preset's `fx` thins particles,
  past `LOD_NEAR` the `near` layers drop and particles halve, past `LOD_FAR` nothing draws. No per-ability lights. Looks
  last at most 2.2 s, flares at most 4 m, swirls at most 4.5 m (checked).
- **No stall on first cast:** `prewarm(at)` (called from `Match.warm_up`) holds up one node of every kind, particles
  running, so their shaders compile with the match's other stand-ins. A new layer kind must be added to `POOL`.
- **Sound:** everything is a one-shot through `Sfx.play`, so nothing can outlive a match. The sound files and their loudness
  standard are docs/AUDIO.md's (content/sfx/<arch>.json); a recipe only says which to play and how loud.

## Shot floor (LMB projectiles)
Every LMB projectile (not a swing, decoy, mob shot or ability, which have their own tells) carries `ShotFloor`'s
beacon: a hot white core at least `MIN_CORE_PX` (6 px) across at 720p (9 px at 1080p) with the default camera, sized
at the farthest a shot can be in view (the floor under the top edge, `ShotFloor.far_depth`), inside a side-coded rim
(foe's shots red-orange, your side's cool and softer), drawn over particles (render priority) on its own render layer
(`ShotFloor.LAYER`). The shot keeps its own look and Hunter ability colour. It is visual only: the hit radius
`s["r"]` is never touched. `--shot-size-check` reads each kit's core radius in pixels at 720p and 1080p and asserts
the hit radius is unchanged; `--shot-size-shots --shots-dir=<dir> --res=720|1080` (GPU) renders each kit's shot at
exactly that size and measures its own look, the core and the rim in pixels across the flight line.
