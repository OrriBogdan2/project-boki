# VFX sweep 11-26: audit, rules, PR list

Owner 11-26: "a full sweep vfx upgrade ... particularly around abilities but elsewhere too", with the game staying
fast. Abilities first, shared systems before one-offs, one small PR per system or per hunter, each with real-GPU
stills at the match camera and a frame-time number.

## Scope and rules
- Not touched: hunter glbs, the map layout and art, screen shake (no self-caused shake).
- Frame budget: a PR may not raise p95 frame time of a 4v4 fight by more than 0.3 ms (`--status-edge-shots` prints
  the pattern: `SEDGE frame ms off ... on ... delta`; the same A/B shape fits any PR). Pooled nodes only, GPUParticles
  with low counts, nothing allocated per frame, `HeroVfx.MAX_LIVE` and the quality presets stay the caps.
- Style: our cel/toon look. One main shape per move, a hot core, a coloured body, a soft afterglow, team-readable
  (own and enemy at full, allies at `HeroVfx.ALLY_K`). Telegraphs stay AimKit's (soft lit rim over a faint inside).
- Reference numbers used (behaviour only): hit flash 0.1 s; outline 0.2 s for small hits, 0.5 s for big; screen tints
  for stunned/knocked (blue), invulnerable (yellow), Grounded (yellow, half strength), invisible (very dark blue).

## Audit method
Each ability's looks come from `content/vfx/<arch>.json` (about 340 moves over the 13 hunters: cast, travel, hit,
telegraph, status), the kits in `scripts/arch/kits/` and the shared `fx.gd`. Scores are 0-10 for R (readable at the
match camera: whose, where it hits, when it lands), P (punch: the 1-3 frame peak) and S (style match to the cel look),
from the 11-22 real-GPU strips (`docs/art/vfx_rescore_1122/`) and the later fix notes in `docs/VFX_QUALITY.md`, plus a
read of the data. Fewer layers or moves than the others (thief 15 moves, Grimble 16, Vex 20, against Kael 46) is
counted against the kit.

## The weakest 15 (worst first)

| # | Hunter, ability | What is wrong | R | P | S | Fix, and where |
|---|---|---|---|---|---|---|
| 1 | Everyone: stunned / untouchable / Grounded on YOUR screen | no screen cue at all; a stun reads only from the plate icon and the body tell | 3 | 2 | 5 | PR 1 `status-edge`: one screen-edge tint |
| 2 | Sable RMB Bola (wind-up lane, tangle) | flat lavender slab for the lane; hit nearly invisible | 4 | 3 | 5 | telegraph rim + hit frame (PR 3) |
| 3 | Sable E Shadow Knife + stick | thin bolt, small stick mark, 15 moves in the whole kit | 4 | 3 | 5 | hit frame + stuck ring |
| 4 | Grimble E Anchor Drop (cone) | translucent copper hex slabs; the palette main is not coin gold | 4 | 4 | 4 | lit rim wedge, gold |
| 5 | Grimble LMB blunderbuss | slugs small at match zoom, thin hit | 5 | 3 | 5 | wider slug trail, impact frame |
| 6 | Lace LMB tap shots and misses | thin faint red lines | 4 | 4 | 5 | wider tracer + hit mark |
| 7 | Sparkle LMB bolt | thin; RMB orb sits in an off-colour haze | 5 | 4 | 6 | brighter core |
| 8 | Meeko E Hearthlight ring | thick flat green band, no rim | 5 | 4 | 5 | lit rim ring |
| 9 | Kael lunge telegraph | pale flat pentagon box | 5 | 4 | 5 | AimKit soft lane |
| 10 | Kael dash trail | red/black checker bar | 5 | 5 | 4 | smooth streak |
| 11 | Motley X Nightwell opening | first frames: flat pale grey disc before the rim lights | 5 | 4 | 5 | start on the rim |
| 12 | Tenzo LMB punch | no own reel part, small hit | 5 | 4 | 6 | impact frame |
| 13 | Vex LMB tracer + hit | thin lime line, small hit spark | 5 | 4 | 6 | hit frame |
| 14 | Albert E Mending Ground fall | readable, plain: no rise motes | 6 | 5 | 6 | rising motes |
| 15 | Neve RMB Ice Spear land | shatter reads, ground mark short-lived | 6 | 5 | 7 | longer mark |

Row 1 is the largest gap and the only one every hunter shares; rows 2-15 are one hit-feel or telegraph change each
and share a plan: ONE impact frame (a 0.1 s white-to-colour flash ring through `Fx.impact`) and ONE telegraph look
(the AimKit rim over a faint inside), applied through the data files, not per-kit code.

## PRs
1. `ext/vfx-sweep-status-edge-1126`: the screen-edge status tint (`scripts/match/status_edge.gd`,
   `shaders/status_edge.gdshader`), checks `--status-edge-check` and `--status-edge-shots`.
   Stills (real GPU, 1920x1080, match camera, jobq 20261126-230827-00248): `docs/shots/vfx-sweep-status-edge/`
   `rest.jpg` is the before; `stun.jpg` (blue), `invuln.jpg` (yellow), `grounded.jpg`, `cloak.jpg` the after.
   Frame time, 4v4 fight, 480 frames per side, off/on blocks alternated: off p95 49.74 ms mean 45.33, on p95 49.49
   mean 45.29, delta p95 -0.26 ms (noise; the worker rp1-3 was slow in absolute terms). Budget 0.3 ms: met. The
   first run (job -230505-11228) is void: it timed the loading screen.
   Quality presets: the tint is one quad with no texture read, so very_low pays the same as high and nothing
   is hidden by a preset. Not covered: Rooted and Slowed (no tint, as the reference lists none).
2. Next in line (not built): the shared impact frame, then Sable and Grimble data passes (rows 2-5).
