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
  breaks gl_compatibility. HeroVfx motes now fade by height over the ground instead (docs/HERO_VFX.md "Ground"), which
  works on every renderer: the same fix fits `fx_dot`.
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm, tender. Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- `pin_draw.gd` defaults to `#e8483e`.
- Six kits are data-driven (`content/vfx/`: archer, ashwick, gunslinger, juggernaut, rimewright, tender). The rest draw
  with `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`); Vex still uses `vv_fx` for her
  slide echoes, the Burr Charge's cone and smear, and the Dazed swirl. Moving each to `HeroVfx` data is
  how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's X scorch (`VvFx.disc`, fixed on ext/vfx-gunslinger), Motley's well dome, Meeko's seed and
  ult discs and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
  rim plus a soft inner falloff (alpha 0.25 or less at the centre), never a solid fill. Each kit sets these, so the fix
  is per kit (backlog).
- Motley's kit draws its well and orbs in indigo/violet, but his slot colours and signature are teal. The ostra item
  moves them to teal. The alternative (keep void violet) would clash with Sable.

## Scorecard (worst first)
Each axis is scored 1–5: R readability, S shape, L layering, T timing, Sc scale, C colour (before the shared fix), Snd
sound. Scored from the `vfxq-before-*` strips (main d255acbee); sound is scored by code read (the strips are silent).

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | main problem (from the strip) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | Tenzo | dolm | 3 | 3 | 4 | 3 | 4 | 4 | 3 | 24 | re-scored 11-08 from strips (ext/vfx-dolm): slam, RMB charge, hop landings and Basalt Spine are HeroVfx data (`content/vfx/dolm.json`): crack crater, wall, rock debris, crack lanes. Left: punch, boulder and launched-rock bursts in `dolm_kit` still draw `Fx` rings |
| 10 | Motley | ostra | 4 | 3 | 4 | 3 | 4 | 4 | 3 | 25 | was 14. RMB, E and X are data-driven in sea teal over a void core, each with an afterglow; Nightwell now reads as a black well with teal arms (strips: jobq vfxq-ostra-abil-before/after). Left: the dome tell is a pale grey-teal, the Snap's flight is one bundle. Dash, LMB and the Swollen pink stay violet (void-jester-dash-feel-1108) |
| 6 | Vex | gunslinger | 3 | 3 | 2 | 3 | 3 | 3 | 4 | 21 | `vv_fx` tracer and muzzle flashes; was ember orange through the shared layer, now lime; reload/E have no shape of their own |
| 2 | Grimble | dredge | 2 | 2 | 2 | 2 | 3 | 2 | 3 | 16 | `ld_fx` primitives; hook chain is a beam with no weight; coin gold shares the stock flash gold |
| 7 | Lace | archer | 3 | 3 | 3 | 3 | 3 | 3 | 2 | 20 | data-driven; was red `#e8483e` (Kael's red); thin arrow trails; few sounds |
| 9 | Meeko | tender | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | data-driven; heal and seed read, but the LMB pellet is small for its hitbox |
| 4 | Sable | thief | 2 | 3 | 2 | 3 | 3 | 2 | 3 | 18 | `dj_fx` slashes are thin; blink has no in/out pair; flashes hard-coded gold, not violet |
| 3 | Albert | bulwark | 2 | 2 | 2 | 2 | 3 | 2 | 4 | 17 | `bjorn_fx` piles of rings/flashes (9 calls); shield reads as a flat disc; hard-coded gold |
| 9 | Sparkle | mage | 3 | 4 | 4 | 4 | 4 | 4 | 3 | 26 | was 20 (3/3/3/3/3/2/3). After (ext/vfx-mage, `vfxq-after-mage`, `vfxq-after-mage-lmb2`; before `vfxq-before-mage-reel`, same reel `tools/vfx_reel/mage.gd`; pairs on ext/vfx-mage-strips): all pink (#ff5ab4 body, #ffd6ee core) via content/vfx/mage.json; the range-wide dark violet disc under the Kitefall hang (the purple screen) is gone; Kitefall strikes as a white-hot core bolt inside a wide pink one, a flare, a shock wall and scorch the size of its 2.7 m hit, debris and a settling spark afterglow; Skycall the same at 1.5 m with a gathering countdown; the Storm Rod has a tip crackle, a trail and a shock-ring hit. Left: the finger bolt trail still reads thin at match zoom; Grounded draws a flat orange disc under the target (shared status look); sounds unchanged |
| 8 | Neve | rimewright | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | data-driven; frost shards read; held beam needs a hot core and ice debris on the end |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4→5 | 4 | 3→4 | 27→29 | the bar: slash arcs, burning lanes, debris. Done (ext/vfx-kael-polish): the X crescent is the strip's leading edge (was 4.3m across a 1.8m strip). Left: the LMB slash sound is a swish with no hard edge; the cleave sound's cut lands on the strike, sharp (was 84 ms late and 4 dB over its swish) |
| 11 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar: layered flame with a hot core. Polish: soft-particle ground clipping, hold-blade glow |

Strips: the before sheets are jobq `vfxq-before-<arch>`, the after sheets `vfxq-after-<arch>`
(`/home/boki/jobq/done/<id>/out/`). Tenzo's before/after pair is on branch `ext/vfx-quality-strips` (not for merge) and
linked from PR #14.
