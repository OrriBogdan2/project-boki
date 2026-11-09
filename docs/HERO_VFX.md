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
the empties; Kael reads `anchor_blade_tip`, `anchor_blade_mid`, `anchor_chain_hand`, `anchor_feet` when present, Lace
`anchor_nock`, `anchor_bow_root`, `weapon_muzzle`, `halo_bow_top`, `halo_bow_low`.

## Team read: rival vs ally (source study, 2026-11-09)
Question: in a 30-Hunter match, does the source mark a rival's ground zone, telegraph or projectile apart from a
teammate's (edge tint, outline, opacity), with the Hunter's own colour kept as the fill?

**Looked at.** The only footage with allies and rivals in real fights: `footage/breah` (the commentated guide, 4 fps,
720 px) frames 736-790 and 1030-1125. Every other folder is the practice range against dummies.
briefs/hero-ref/HUD.md covers plates only (self yellow-green, ally blue, rival red), nothing on ability looks.

**Seen.**
- Effects keep their caster's colours on both sides: the cyan ring (746) and purple ring (758) round units, the
  magenta disc round a rival (1066, 1072), the orange spike wall (1054-1060), the magenta beam (1090). No red or blue
  edge, outline or dimming on any of them.
- The only red indicators are the viewer's own aim: Tetra's thin red aim line (764-788, 1088, 1096, 1104) and her
  red Volcano Crusher circle (1090; breah.md). They are drawn for the caster only, so they say nothing about how a
  rival's cast looks to you.

**Not settled.** No frame shows the same ability cast by an ally and by a rival, and at 720 px and 4 fps a thin edge
tint or a small opacity drop would not survive. So nothing is built from this study.

**Ours today (not from the source).** AimDraw lerps a rival's shared telegraph (`"all": true`, e.g. Kitefall's ring
and landing disc, Faultline's lane) 45% toward `Feel.RIM_ENEMY` (accent 30%); HeroVfx draws an ally's effects at
`ALLY_K`; your own aim reticles are drawn for you alone.

**Options for the owner.**
1. Keep today's cues as they are.
2. Edge only: one HeroVfx team pass tints the outer rim of a rival's ground looks (scorch, skirt) toward
   `Feel.RIM_ENEMY` and leaves the fill in the Hunter's colour; AimDraw would tint the rim only, not the whole shape.
3. Remove the ours-only cues (the RIM_ENEMY lerp and `ALLY_K`) if better footage shows the source has none.
4. Settle it first: a 1080p+ clip of a trio match (or the source's settings, if it has an enemy-indicator colour
   option) where an ally and a rival cast the same ability. Recommended before any of 1-3.

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
