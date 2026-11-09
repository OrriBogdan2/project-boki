# Ability VFX quality: the bar, the rules, the coverage, the scorecard (2026-11-08, coverage 11-09)

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
- All 12 Hunters have a data file (`content/vfx/`). Still drawn in code: Vex's slide echoes and Burr look (`vv_fx`),
  Lace's dash fletch (`pin_fx`), Grimble's barge (`ld_fx`), Sable's dash streaks (`dj_fx`), Albert's hammer and dash
  (`bjorn_fx`, now in his palette), Motley's LMB and dash (violet, kept by the dash-feel lane). See the coverage table.
- **Opaque zone fills** (seen in the strips): Vex's X scorch (`VvFx.disc`, fixed on ext/vfx-gunslinger), Motley's well dome, Meeko's seed and
  ult discs and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
  rim plus a soft inner falloff (alpha 0.25 or less at the centre), never a solid fill. Each kit sets these, so the fix
  is per kit (backlog).
- Motley's kit draws its well and orbs in indigo/violet, but his slot colours and signature are teal. The ostra item
  moves them to teal. The alternative (keep void violet) would clash with Sable.

## Coverage per Hunter and slot (2026-11-09, ext/vfx-pass)
What draws each moment, after the 11-08 VFX branches (merged into ext/vfx-pass) and this pass. **ok**: its own look in
the Hunter's palette (HeroVfx data or the kit's pooled module). **ph** (placeholder): shared primitives, off-palette, or a
known weak spot. **miss**: nothing in the world (the overhead plate's word or icon only). Slice Wardens first.
Status = what the kit puts on a foe. "before → after" where this pass changed it.

| Hunter | LMB | RMB | Dash | E | R | Impact | Status on the foe |
|---|---|---|---|---|---|---|---|
| Vex (slice) | ok | ok (`vv_fx`) | ok (`vv_fx` echoes) | ok | ok | ok | Dazed ok; stun miss → ok |
| Kael (slice) | ok | ok | ok | ok | ok | ok | stun miss → ok; Blight miss |
| Lace (slice) | ok | ok | ok (`pin_fx`) | ok | ok | ok | stun miss → ok; Blight miss |
| Cinder (slice) | ok | ok (body red-pink, as the hero doc specs) | ok (jets) | ok | ok | ok | Ablaze ok; slow miss |
| Meeko | ok | ok | ok | ok | ok | ok | root miss |
| Tenzo | ph → ok (punch; the boulder, flying rocks, hop rocks and fists had molten-orange cracks and trails: now cobalt) | ok | ph → ok (`dash_dust`) | ok; rock/boulder bursts ph → ok (`rock_burst`) | ok | ok | stun ok (kit crown → shared); Shred ph (ring + word) |
| Grimble | ok | ok | ok (`ld_fx` barge) | ok | ok | ok (slugs read small) | stun ok (kit spiral → shared); Grounded ok |
| Neve | ok | ok | ph → ok (shared team pill over the skate removed) | ok | ok | ok | stun miss → ok; slow/root miss |
| Motley | ph (violet, kept by the dash-feel lane) | ok | ph (violet puffs) | ok | ok | ok | stun ok (kit crown → shared); Disoriented ph |
| Albert | ph → ok (gold/orange → his palette) | ok | ph → ok (palette) | ok | ok | ok | stun miss → ok |
| Sparkle | ok | ok | ok | ok | ok | ok | stun miss → ok; Grounded ph (flat amber disc) |
| Sable | ok | ok | ok (`dj_fx` violet) | ok | ph → ok (blade hits were no bigger than the LMB's: now a crossed slash) | ok | stun miss → ok; Grounded ok |

**Ours vs source** (`briefs/hero-ref`, KIT_PARITY):
| Moment | Source [F] | Ours before | Ours now |
|---|---|---|---|
| A stun | a marker over the head on every stun: "a dark spiral" (dredge.md 0236), "a stun swirl" (dancer.md), "stun stars" (breah.md 0122), "a pink stun marker" (ostra.md f33); shown ~1.2-1.4 s, as long as the stun | two kit-only looks (Tenzo/Motley's star crown, Grimble's spiral); 8 of 12 kits' stuns showed nothing on the body | `StunMark`: spiral + 3 stars over every stunned Hunter or monster for its whole stun, fading over the last 0.2 s; size and colour [?] (not recorded), so the plate's STUNNED yellow |
| A dash | dust and the hero's own trail; no ring or burst (DECISIONS) | Neve: the shared team-colour pill (a new mesh and material every 0.028 s) over her skate; Tenzo: two puffs a tick; Albert: orange | every kit its own look; no Hunter reaches the shared pill (asserted) |
| An ult hit vs an LMB hit | bigger (the bar's scale rule) | Sable's Encore hit 1.3 m vs her bolt hit 1.25 m | Encore hit: two crossed violet slashes (1.6 m) and a 1.8 m flare (2.4 m on the rim); every data ult hit is asserted wider than its LMB hit |
| Slow, root, burn, Blight on the body | not recorded [?] | plate word/icon (Blight: none) | unchanged: parity first, no invented looks. Suggestion for the owner: a frost rim for slow, roots at the feet, embers for burn, a dark heal-cut tick for Blight |

Frame cost: `StunMark` is a fixed pool of 8 marks built once (one billboard quad with the existing `ld_fx` spiral
shader + 3 star boxes sharing one material); nothing is made per frame, and with nobody stunned its `_process` is off.
Tenzo's dash is one HeroVfx hold (pooled particles, inside `MAX_LIVE`) instead of two `Fx.burst` calls per 0.028 s.
Neve's dash no longer makes a MeshInstance3D and a material per after-image tick.

## One colour table per Hunter (ext/vfx-hunter-colours, 11-09)
Owner 11-08: every Hunter's abilities are colour-coded to them (Vex green fire, Sparkle pink, Tenzo blue). The other nine read
their colour from `content/vfx/<arch>.json` "palette" only: kits ask `HeroVfx.col("<arch>", "<key>")` (the check
`--hero-vfx-check` asserts every key exists), and the archetype `color` / ability `col` and the weapon `color` agree with it.
Kael's glow is white-hot over crimson (never orange: orange is Cinder's); status colours (heal green, root violet, red
failure words) stay.

| Hunter | colour | was off-colour, now in the table |
|---|---|---|
| Kael | crimson body, white-hot glow | orange/gold/magenta/violet palette (guard, chain, wave, drop markers, Slam lane) |
| Cinder | flame orange | Cinder Shot's pink-red body (pilot flame stays cyan: her sheet) |
| Lace | orchid | gold perfect-release cue and Executed word, lime target ring, blue cremation flames |
| Grimble | coin gold | pink aim lines |
| Neve | frost cyan | lilac accent |
| Albert | ivory/gold | orange sparks, blue aegis and shield colours |
| Sable | violet | gold/blue empowered chakram and aim line, gold glint, pink stars |
| Motley | sea teal | violet orb glow, swap landing, vortex disc, pink swell |
| Meeko | leaf green | amber Hearthlight lamp |

## Scorecard (worst first)
Each axis is scored 1–5: R readability, S shape, L layering, T timing, Sc scale, C colour (before the shared fix), Snd
sound. Scored from the `vfxq-before-*` strips (main d255acbee); sound is scored by code read (the strips are silent).

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | main problem (from the strip) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 10 | Tenzo | dolm | 3 | 3 | 4 | 3 | 4 | 4 | 3 | 24 | re-scored 11-08 from strips (ext/vfx-dolm): slam, RMB charge, hop landings and Basalt Spine are HeroVfx data (`content/vfx/dolm.json`): crack crater, wall, rock debris, crack lanes. Left: punch, boulder and launched-rock bursts in `dolm_kit` still draw `Fx` rings |
| 10 | Motley | ostra | 4 | 3 | 4 | 3 | 4 | 4 | 3 | 25 | was 14. RMB, E and X are data-driven in sea teal over a void core, each with an afterglow; Nightwell now reads as a black well with teal arms (strips: jobq vfxq-ostra-abil-before/after). Left: the dome tell is a pale grey-teal, the Snap's flight is one bundle. Dash, LMB and the Swollen pink stay violet (void-jester-dash-feel-1108) |
| 3 | Vex | gunslinger | 4 | 4 | 3 | 3 | 4 | 4 | 4 | 26 | was 15 (1/2/2/2/3/1/4). After (ext/vfx-gunslinger, `vfxq-after-gunslinger-2`, before/after pairs on ext/vfx-gunslinger-strips): every round has a lime tracer, a gun-sized flash and a hit spark; E is a needle of light; X is a reticle over a see-through disc, a streaking shell and a flame wall. Left: lime is low-contrast on yellow sand; the Burr cone and slide echoes are still `vv_fx` |
| 4 | Grimble | dredge | 3 | 2 | 2 | 2 | 3 | 1 | 3 | 16 | pink pellets, teal E fan, orange RMB fan, purple hook chain: four colours, none gold; flat fans with no leading edge. **After (ext/vfx-dredge): 26**, see below |
| 5 | Lace | archer | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 27 | re-scored 11-08 from strips (ext/vfx-archer, was 16): every thread, needle, trail and beam is orchid; tap/arrow ribbons 2-3x wider with a pale hot core, stuck and stitched threads hold at match zoom; Heavy Shot release layered (white core, orchid body flare, sweep, seam, sparks); new full-draw, release and arrow-hit sounds. Left: the Heavy Shot is still the big flat arrow (owner Nov 4) with a pale fletch rosette; the gold perfect-release cue stays gold (a timing signal) |
| 9 | Meeko | tender | 4 | 3 | 3 | 3 | 4 | 4 | 4 | 25 | after ext/vfx-tender (was 17: 2/2/2/3/3/1/4): all leaf, ember at its hit radius, lit soft zones, petals, heal afterglow, a Hearth Call swirl per tick. Left: fades are mostly linear; the shape is a stack of discs and swirls, not one form |
| 9 | Sable | thief | 4 | 4 | 3 | 4 | 3 | 4 | 3 | 25 | after (`vfxq-after-thief-2`): bolt hits are a violet crescent slash with an afterglow, Cartwheel arcs wide with an afterglow, blink out/in bursts, no gold flashes, X ring a lit rim. Left: X blade hits still small against the 5.4 m ring; the ring wash still tints sand; the dash streaks are DJFx |
| 9 | Albert | bulwark | 4 | 4 | 4 | 3 | 3 | 3 | 4 | 25 | after ext/vfx-bulwark (was 20: mint E dome, flat gold X box with dark cubes, brown plate wall): the aegis is a clear ivory dome with a rim halo, E an ivory column and a ring of rising motes, X erupts cell by cell (fissured ground, ivory shards, dark debris, a racing crack). Left: his bulky model hides the dome's upper half at reel zoom; LMB and dash still draw in the old gold and orange |
| 9 | Sparkle | mage | 3 | 4 | 4 | 4 | 4 | 4 | 3 | 26 | was 20 (3/3/3/3/3/2/3). After (ext/vfx-mage, `vfxq-after-mage`, `vfxq-after-mage-lmb2`; before `vfxq-before-mage-reel`, same reel `tools/vfx_reel/mage.gd`; pairs on ext/vfx-mage-strips): all pink (#ff5ab4 body, #ffd6ee core) via content/vfx/mage.json; the range-wide dark violet disc under the Kitefall hang (the purple screen) is gone; Kitefall strikes as a white-hot core bolt inside a wide pink one, a flare, a shock wall and scorch the size of its 2.7 m hit, debris and a settling spark afterglow; Skycall the same at 1.5 m with a gathering countdown; the Storm Rod has a tip crackle, a trail and a shock-ring hit. Left: the finger bolt trail still reads thin at match zoom; Grounded draws a flat orange disc under the target (shared status look); sounds unchanged |
| 10 | Neve | rimewright | 4 | 4 | 3 | 3 | 4 | 4 | 4 | 26 | reads well (shards, shatter burst); the dash ice path is flat untextured boxes |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4→5 | 4 | 3→4 | 27→29 | the bar: slash arcs, burning lanes, debris. Done (ext/vfx-kael-polish): the X crescent is the strip's leading edge (was 4.3m across a 1.8m strip). Left: the LMB slash sound is a swish with no hard edge; the cleave sound's cut lands on the strike, sharp (was 84 ms late and 4 dB over its swish) |
| 12 | Cinder | ashwick | 4 | 4 | 5 | 5 | 4 | 4 | 4 | 30 | the bar: layered flame with a hot core. Done (ext/vfx-cinder-polish): embers land and fade into the ground; a palm heat glow builds over 0.8 s of roaring and cools after. Left: Cinder Shot's pink-red body is off her orange signature (C) |

Strips: the before sheets are jobq `vfxq-before-<arch>`, the after sheets `vfxq-after-<arch>`
(`/home/boki/jobq/done/<id>/out/`). Tenzo's before/after pair is on branch `ext/vfx-quality-strips` (not for merge) and
linked from PR #14.

### Grimble after (ext/vfx-dredge): 26
| R | S | L | T | Sc | C | Snd | total |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 3 | 4 | 3 | 26 (+10) |

LMB, hold, hook/RMB, E and X now play `content/vfx/dredge.json` through HeroVfx, all in coin gold with white/pale cores.
The hook is a gold chain of links (HeroVfx's new hold-only `chain` layer): it pays out slack and swaying, is yanked
taut and glowing on the bite (a burst of coins, sparks and a flash on the target) and again on each haul, and throws
sparks as it snaps back. The E and X telegraphs are gold; sparks rise along the cone's edge through the wind-up and
charge, and each slam or wave ends in a gold sweep that burns away, a flash, debris and coins. Kept from LDFx: the bone
hook (now a gold rim), the ghost anchor, the reel's chain ring, the stun spirals (now the shared StunMark) and the barge (dash not in scope).
Sound is unchanged (3). Scale stays 3: the slugs read as small pale-gold dots with thin trails at match
zoom; a gold body on sand or autumn ground has less contrast than on grass (the dark rims and char carry it).
