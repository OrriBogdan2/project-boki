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
| 1 | Tenzo | dolm | 2 | 2 | 1 | 2 | 3 | 1 | 3 | 14 | E telegraph is opaque orange discs; X is a thin red line and ring; everything red/orange (now cobalt on this branch); `breah_*` draws flat rings with no debris |
| 2 | Motley | ostra | 2 | 2 | 1 | 2 | 2 | 2 | 3 | 14 | E and X are huge opaque indigo domes over the target; LMB hit is tiny; indigo vs teal signature |
| 3 | Vex | gunslinger | 4 | 4 | 3 | 3 | 4 | 4 | 4 | 26 | was 15 (1/2/2/2/3/1/4). After (ext/vfx-gunslinger, `vfxq-after-gunslinger-2`, before/after pairs on ext/vfx-gunslinger-strips): every round has a lime tracer, a gun-sized flash and a hit spark; E is a needle of light; X is a reticle over a see-through disc, a streaking shell and a flame wall. Left: lime is low-contrast on yellow sand; the Burr cone and slide echoes are still `vv_fx` |
| 4 | Grimble | dredge | 3 | 2 | 2 | 2 | 3 | 1 | 3 | 16 | pink pellets, teal E fan, orange RMB fan, purple hook chain: four colours, none gold; flat fans with no leading edge |
| 5 | Lace | archer | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 27 | re-scored 11-08 from strips (ext/vfx-archer, was 16): every thread, needle, trail and beam is orchid; tap/arrow ribbons 2-3x wider with a pale hot core, stuck and stitched threads hold at match zoom; Heavy Shot release layered (white core, orchid body flare, sweep, seam, sparks); new full-draw, release and arrow-hit sounds. Left: the Heavy Shot is still the big flat arrow (owner Nov 4) with a pale fletch rosette; the gold perfect-release cue stays gold (a timing signal) |
| 6 | Meeko | tender | 2 | 2 | 2 | 3 | 3 | 1 | 4 | 17 | purple orbs, gold seed rings, cyan ult dome: no signature colour; hard-edged flat discs; Hearth Call barely reads |
| 7 | Sable | thief | 2 | 2 | 2 | 3 | 3 | 3 | 3 | 18 | LMB hits nearly invisible; held LMB is a flat unlit purple box; X is pale grey discs |
| 8 | Albert | bulwark | 3 | 3 | 2 | 3 | 3 | 2 | 4 | 20 | gold swing arcs read; dash dome is mint green; E is a flat gold box with dark cubes |
| 9 | Sparkle | mage | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 20 | lightning still cyan (old teal) next to pink orbs; X tints the whole screen purple |
| 10 | Neve | rimewright | 4 | 4 | 3 | 3 | 4 | 4 | 4 | 26 | reads well (shards, shatter burst); the dash ice path is flat untextured boxes |
| 11 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4 | 4 | 3 | 27 | the bar: slash arcs, burning lanes, debris. Polish: cleave sound transient, ult shockwave scale |
| 12 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar: layered flame with a hot core. Polish: soft-particle ground clipping, hold-blade glow |

Strips: the before sheets are jobq `vfxq-before-<arch>`, the after sheets `vfxq-after-<arch>`
(`/home/boki/jobq/done/<id>/out/`). Tenzo's before/after pair is on branch `ext/vfx-quality-strips` (not for merge) and
linked from PR #14.
