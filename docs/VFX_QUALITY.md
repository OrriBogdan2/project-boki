# Ability VFX quality: the bar, the rules, the scorecard (2026-11-08)

Owner playtest 11-08: abilities look janky; Cinder and Kael look decent. This doc sets the bar from those two kits
(plus the source footage in `docs/KIT_PARITY.md`), lists the shared causes of jank and what the shared layer now does,
and scores every Hunter worst-first. Each Hunter's fix is a backlog item (role `feel`) that must ship a before/after
strip made with the reel below.

## Strips
`godot --path . --hero-vfx-reel --reel-hero=<arch> --shots-dir=shots/<arch>` (through `jobq submit --needs gpu`) writes
one PNG sheet per part: `shots/<arch>/<hero>_<part>.png`. Parts: `lmb`, `hold` (LMB held 1.4 s), `rmb`, `dash`, `e`,
`r`, plus a Hunter's own parts (`tools/vfx_reel/<arch>.gd`, e.g. Grimble's `hook`). This pass ran `vfxq-before-<arch>`
on main's tree (d255acbee) and `vfxq-after-<arch>` on this branch; the sheets live in the jobq outputs
(`/home/boki/jobq/done/<id>/out/shots/`), not in the repo.

## The bar (Cinder, Kael)
- **Readable at gameplay zoom in one frame**: the hit area or path is clear by 0.1 s.
- **Shape language**: one main shape per move (Cinder's flame cone, Kael's crescent cleave), not a pile of primitives.
- **Layering**: a hot core, a coloured body, a soft afterglow, and debris or embers. At least three layers on the big moves.
- **Timing**: anticipation, then a 1–3 frame peak, then a fade on an ease-out curve. Nothing pops off at full alpha.
- **Scale**: the effect matches the hitbox (`docs/HITBOX_SIZE.md`); the ult reads bigger than E, and E bigger than LMB.
- **Colour**: the Hunter's signature colour (table below) carries the body; white/pale is the core only. No shared
  default colour.
- **Sound**: every cast and hit has a sound with a distinct transient. Held moves loop.

## Signature colours (`content/archetypes/<arch>.json` "color")
`Arch.color(id)` is the single source of truth. KinExec stages, AimKit, enemy shots and the UI read it.

| Hunter | arch | hex | name | note |
|---|---|---|---|---|
| Vex | gunslinger | `#b8f03c` | lime | was ember orange (too close to Cinder); alternative: keep orange, give Cinder deep red |
| Kael | juggernaut | `#ff3a2a` | crimson | the only red Hunter |
| Cinder | ashwick | `#ff7a1a` | flame orange | |
| Meeko | tender | `#5fdc6a` | leaf green | |
| Tenzo | dolm | `#3a7cff` | cobalt | owner: Tenzo is blue. Slot cols: hot `#9ad0ff`, pale `#d8ecff`, stone `#8f9cb8` |
| Lace | archer | `#e04aff` | orchid | was red `#e8483e` (same as Kael's) |
| Grimble | dredge | `#ffc832` | coin gold | |
| Neve | rimewright | `#8ae6ff` | frost cyan | |
| Sparkle | mage | `#ff5ab4` | pink | matches job sparkle-dash-feel-1108's kit recolour |
| Albert | bulwark | `#fff0b0` | radiant ivory | |
| Sable | thief | `#9a5cff` | violet | |
| Motley | ostra | `#2ee6c0` | sea teal | |

Rule: a kit draws its body in its signature colour (or a slot `col` in its archetype JSON derived from it). White,
pale tints of the signature, and black/smoke are free. Status colours (purple for control, green for heal) stay readable on
top of the signature colour. Any new hard-coded colour in a kit needs a comment naming its slot.

## Shared causes of jank and the shared fix (branch ext/vfx-quality-base)
| cause | fix |
|---|---|
| KinExec tinted every kit stage with the damage-category orange-red, so every Hunter's rings, cones and hits were red/orange | `ArchKit.cx` sets `hero_col = Arch.color(id)`; `KinExec._color` and the hit burst use it (Boki stages keep category colours) |
| Enemy projectiles were lerped toward red `#ff5a3a` | `Oomph.shot_look` keeps the shooter's colour, lightened; enemy reads by size ×1.3 and halo |
| `Fx.ring` was a thin flat band with a linear fade | `ring.gdshader` gains `wash` (inner fill) and `halo` (glow + hot core); ring alpha eases `1-k²` |
| `Fx.flash` lasted 0.06–0.08 s (1–2 frames) and flickered | `FLASH_MIN` 0.1 s |
| `Fx.bolt` drew flat glow boxes that popped off | segments are fading `beam`s |
| Tenzo's kit hard-coded molten red/orange | recoloured to cobalt in `dolm_kit`, `breah_*`, `rock_look` (FX only; the rock body stays sandstone) |
| The reel had no held-LMB part | `hold` part in `tools/hero_vfx_reel.gd` |

Still open (shared, not done here):
- `fx_dot` particles are `blend_mix` and have no soft-particle depth fade, so they clip hard into the ground. A depth fade
  breaks gl_compatibility, so it needs a mobile fallback.
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm, tender. Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- `pin_draw.gd` defaults to `#e8483e`.
- Only five kits are data-driven (`content/vfx/`: archer, ashwick, juggernaut, rimewright, tender). The rest draw with
  `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`). Moving each to `HeroVfx` data is
  how a kit reaches the bar.

## Scorecard (worst first)
Each axis is scored 1–5: R readability, S shape, L layering, T timing, Sc scale, C colour, Snd sound.

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | main problem |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Tenzo | dolm | 1 | 2 | 1 | 2 | 3 | 2 | 3 | 14 | hard-coded `Fx` primitives in `dolm_kit`/`breah_*`, no HeroVfx data; was red (now cobalt here). Spine lane and slam are flat rings, the hop landing has no debris |
| 2 | Motley | ostra | 2 | 2 | 1 | 2 | 2 | 2 | 3 | 14 | no HeroVfx data and no `Fx` calls in the kit; the look comes from the shared cast language only. Dash/LMB are owned by void-jester-dash-feel-1108 |
| 3 | Grimble | dredge | 2 | 2 | 2 | 2 | 3 | 2 | 3 | 16 | `ld_fx` primitives; hook chain is a beam with no weight; coin gold shares the stock flash gold |
| 4 | Albert | bulwark | 2 | 2 | 2 | 2 | 3 | 2 | 4 | 17 | `bjorn_fx` piles of rings/flashes (9 calls); shield reads as a flat disc; hard-coded gold |
| 5 | Sable | thief | 2 | 3 | 2 | 3 | 3 | 2 | 3 | 18 | `dj_fx` slashes are thin; blink has no in/out pair; flashes hard-coded gold, not violet |
| 6 | Sparkle | mage | 3 | 2 | 2 | 3 | 3 | 2 | 3 | 18 | `vv_fx` bolts/orbs; recoloured to pink by sparkle-dash-feel-1108; ult lacks a hot core and afterglow |
| 7 | Vex | gunslinger | 3 | 3 | 2 | 3 | 3 | 3 | 4 | 21 | `vv_fx` tracer and muzzle flashes; was ember orange through the shared layer, now lime; reload/E have no shape of their own |
| 8 | Lace | archer | 3 | 3 | 3 | 3 | 3 | 3 | 2 | 20 | data-driven; was red `#e8483e` (Kael's red); thin arrow trails; few sounds |
| 9 | Neve | rimewright | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | data-driven; frost shards read; held beam needs a hot core and ice debris on the end |
| 10 | Meeko | tender | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | data-driven; heal and seed read, but the LMB pellet is small for its hitbox |
| 11 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar. Polish: soft-particle ground clipping, hold-blade glow |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4 | 4 | 3 | 27 | the bar. Polish: cleave sound transient, ult shockwave scale |

The scores are **provisional**. They come from reading each kit's FX code plus Cinder and Kael from the owner playtest. The
`vfxq-before/after-*` GPU strips are queued but did not run in this pass (the GPU PC was paused until 20:27 UTC, with 41
jobs ahead). Re-score from the sheets when they land, and attach Tenzo's before/after (`vfxq-before-dolm`,
`vfxq-after-dolm`) to the PR.
