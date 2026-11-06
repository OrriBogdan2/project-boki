# Hero VFX and sounds

A Hero's ability looks and sounds are data: `content/vfx/<arch>.json`, played by the shared `HeroVfx`
(`scripts/match/hero_vfx.gd`, one pooled node per match). A Hero needs a data file, a line per
moment in its kit, and sounds. Check: `--hero-vfx-check` (every data file against its kit, plus the shared runtime). Tuning a
palette: `--hero-vfx-gallery --shots-dir=<dir> [--reel-hero=<arch>]` plays every move side by side (no Hero: one of every
layer kind). Approval sheets and the reel: `--hero-vfx-reel` (the tool's header has the movie-writer command); a Hero's
scripted parts go in `tools/vfx_reel/<arch>.gd`, otherwise the generic set plays.

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
| `sweep` | an arc of flame, burning away | `size`, `arc` deg, `tilt`, `yaw`, `flip` |
| `scorch` | the ground burning, fissures cooling; with `"stitch": true` a lane is a seam of cross-stitches | `shape` disc / lane / cone, `size` or `len` + `w`, `arc` |
| `skirt` | a wall of flame growing out | `size`, `from`, `tall`, `arc` (share of the circle) |
| `flare` | a ragged burst facing the camera | `size`, `grow` |
| `ribbon` | a mesh trail following an anchor, or the kit's `o.follow` node with `"follow": true` | `at`, `life`, `tail` s, `size` width, `wave` m of sideways drift (a thread) |
| `thread` | a loose thread lying on the ground from `at` along `dir`, swaying | `len`, `w`, `life` (may outlast the 2.2 s cap, with its needle) |
| `string` | holds only: a thin glowing line through named anchors | `through`, `size`, `skip_if` (a model node that means it brings its own) |
| `bolt` | a strip from A to B facing the camera: lightning with `jag` > 0 (0.3-0.7), a taut thread at 0 | `size` width, `len` along the aim, or `to` (an anchor), or the kit's `o.to` (a Vector3; local only, other games use `len`) |
| `vortex` | a ground disc spinning inward to a dark core (`c3`) | `size` radius, `spin` turns/s (negative: the other way), `grow` |
| `ember` / `smoke` / `chunk` / `shard` / `card` / `coin` / `star` / `drop` | GPU particles: hot streaks, puffs, dark debris, crisp crystals, tumbling cards burning from the edges, spinning metal glints, twinkling four-point stars, water drops | `n`, `speed`, `spread`, `way` up / fwd / back / along, `grav`, `drag`, `curl`, `shape` ball / line / disc / gather / arc, `burst` 1 all at once .. 0 over the life |

All layers: `at` (`here`, `h` the body, or an anchor), `y`, `fwd`, `delay`, `life`, `c` / `c2` / `c3` (palette keys: body,
hot, char), `near` (dropped past LOD_NEAR). Sounds: `n`, `db`, `other` (extra dB for anyone but the player), `pitch`,
`pitch_k`, `var`, `delay`, `at`, `when` / `unless`.

## FX anchors
`"anchors"` in the data names points on the Hero. Each resolves in order: `nodes` (empties on the .glb, e.g.
`anchor_blade_tip`, or `weapon_muzzle`), `bone` (a contract bone such as `hand.R`, `forearm.L`, `head`, with `off` [x, y, z] in the bone's space: follows the live pose on any .glb model), `gun` (a point in the Gun node's space), `body` ([side, up, forward] from the feet along
the aim), with `hand` r / l between them for a point that rides a hand bone. So a look works on today's model and picks the new anchors up when a model ships them. `docs/RIG_STANDARD.md` lists
the empties; Kael reads `anchor_blade_tip`, `anchor_blade_mid`, `anchor_chain_hand`, `anchor_feet` when present, Lisette
`anchor_nock`, `anchor_bow_root`, `weapon_muzzle`, `halo_bow_top`, `halo_bow_low`.

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
