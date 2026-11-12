# Ability VFX quality: the bar, the rules, the scorecard (2026-11-08)
# Ability VFX quality: the bar, the rules, the scorecard (2026-11-08, re-scored 2026-11-09)

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
`r`, plus a Hunter's own parts (`tools/vfx_reel/<arch>.gd`, e.g. Grimble's `hook`). The 11-08 pass ran `vfxq-before-<arch>`
on main's tree (d255acbee). The 11-09 re-score strips are in `docs/art/vfx_rescore/<arch>.jpg` (see below).

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
- Only five kits are data-driven (`content/vfx/`: archer, ashwick, juggernaut, rimewright, tender). The rest draw with
- `pin_draw.gd` defaults to `#e8483e`.
- Only six kits are data-driven (`content/vfx/`: archer, ashwick, dredge, juggernaut, rimewright, tender). The rest draw with
  `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`). Moving each to `HeroVfx` data is
  how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's E/X scorch (`VvFx.disc`), Motley's well dome, Meeko's seed and
  ult discs and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm (tender's are gone on ext/vfx-tender). Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- `pin_draw.gd` defaults to `#e8483e`.
- Only six kits are data-driven (`content/vfx/`: archer, ashwick, dredge, juggernaut, rimewright, tender). The rest draw with
  `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`). Moving each to `HeroVfx` data is
  how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's E/X scorch (`VvFx.disc`), Motley's well dome, Meeko's seed and
  ult discs (fixed on ext/vfx-tender: `care_disc` `glow`) and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
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
| 3 | Vex | gunslinger | 1 | 2 | 2 | 2 | 3 | 1 | 4 | 15 | LMB and held LMB show almost no tracer or muzzle flash; RMB crescents are pink; E/X are opaque brown scorch discs |
| 4 | Grimble | dredge | 3 | 2 | 2 | 2 | 3 | 1 | 3 | 16 | pink pellets, teal E fan, orange RMB fan, purple hook chain: four colours, none gold; flat fans with no leading edge |
| 5 | Lace | archer | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 27 | re-scored 11-08 from strips (ext/vfx-archer, was 16): every thread, needle, trail and beam is orchid; tap/arrow ribbons 2-3x wider with a pale hot core, stuck and stitched threads hold at match zoom; Heavy Shot release layered (white core, orchid body flare, sweep, seam, sparks); new full-draw, release and arrow-hit sounds. Left: the Heavy Shot is still the big flat arrow (owner Nov 4) with a pale fletch rosette; the gold perfect-release cue stays gold (a timing signal) |
| 4 | Grimble | dredge | 3 | 2 | 2 | 2 | 3 | 1 | 3 | 16 | pink pellets, teal E fan, orange RMB fan, purple hook chain: four colours, none gold; flat fans with no leading edge. **After (ext/vfx-dredge): 26**, see below |
| 5 | Lace | archer | 2 | 3 | 2 | 3 | 3 | 1 | 2 | 16 | tap needle and threads are hair-thin red lines; Heavy Shot is a flat red pinwheel and arrow sprite; X beam reads but is Kael's red; few sounds |
| 6 | Meeko | tender | 2 | 2 | 2 | 3 | 3 | 1 | 4 | 17 | purple orbs, gold seed rings, cyan ult dome: no signature colour; hard-edged flat discs; Hearth Call barely reads |
| 7 | Sable | thief | 2 | 2 | 2 | 3 | 3 | 3 | 3 | 18 | LMB hits nearly invisible; held LMB is a flat unlit purple box; X is pale grey discs |
| 8 | Albert | bulwark | 3 | 3 | 2 | 3 | 3 | 2 | 4 | 20 | gold swing arcs read; dash dome is mint green; E is a flat gold box with dark cubes |
| 9 | Sparkle | mage | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 20 | lightning still cyan (old teal) next to pink orbs; X tints the whole screen purple |
| 10 | Neve | rimewright | 4 | 4 | 3 | 3 | 4 | 4 | 4 | 26 | reads well (shards, shatter burst); the dash ice path is flat untextured boxes |
| 11 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar: layered flame with a hot core. Polish: soft-particle ground clipping, hold-blade glow |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4→5 | 4 | 3→4 | 27→29 | the bar: slash arcs, burning lanes, debris. Done (ext/vfx-kael-polish): the X crescent is the strip's leading edge (was 4.3m across a 1.8m strip). Left: the LMB slash sound is a swish with no hard edge; the cleave sound's cut lands on the strike, sharp (was 84 ms late and 4 dB over its swish) |

Lace's row is scored from her strips (before `vfxq-before-archer`, job 20261108-180332-30891; after
`vfxq-after-archer-2`, job 20261108-213129-03140); the pair is on branch `ext/vfx-archer-strips` (not for merge). Her
row keeps its place until the integrator re-sorts the table.

### Grimble after (ext/vfx-dredge): 26
| R | S | L | T | Sc | C | Snd | total |
|---|---|---|---|---|---|---|---|
| 4 | 4 | 4 | 4 | 3 | 4 | 3 | 26 (+10) |

LMB, hold, hook/RMB, E and X now play `content/vfx/dredge.json` through HeroVfx, all in coin gold with white/pale cores.
The hook is a gold chain of links (HeroVfx's new hold-only `chain` layer): it pays out slack and swaying, is yanked
taut and glowing on the bite (a burst of coins, sparks and a flash on the target) and again on each haul, and throws
sparks as it snaps back. The E and X telegraphs are gold; sparks rise along the cone's edge through the wind-up and
charge, and each slam or wave ends in a gold sweep that burns away, a flash, debris and coins. Kept from LDFx: the bone
hook (now a gold rim), the ghost anchor, the reel's chain ring, the stun spirals and the barge (dash not in scope).
Sound is unchanged (3). Scale stays 3: the slugs read as small pale-gold dots with thin trails at match
zoom; a gold body on sand or autumn ground has less contrast than on grass (the dark rims and char carry it).

Strips: the before sheets are jobq `vfxq-before-<arch>`, the after sheets `vfxq-after-<arch>`
(`/home/boki/jobq/done/<id>/out/`). Tenzo's before/after pair is on branch `ext/vfx-quality-strips` (not for merge) and
linked from PR #14; Kael's X pair (`before_juggernaut_r.png`, `after_juggernaut_r.png`) is there too.
## Scorecard: before (11-08) and re-score (11-09)
Rubric as above: each axis 1-5, R readability, S shape, L layering, T timing, Sc scale, C colour, Snd sound (sound is
carried from the code read, the strips are silent). **Before** is the 11-08 score from the `vfxq-before-*` strips.
**After** is scored from the new reel strips only, by the same rubric.

**What was rendered.** origin/main (d255acbee) has neither this doc nor most of the per-hero VFX jobs: they are READY
branches, not merged. So the reels ran on a scratch merge of origin/main with every READY `ext/vfx-*` branch that
merges cleanly: quality-base, ostra-abilities, tender, archer, thief, dredge, mage, rimewright-quality, dolm,
bulwark, gunslinger, kael-polish (Cinder is already on main). Not in it: `ext/vfx-vex`, `vfx-breaker`,
`vfx-lisette`, `vfx-motley`, `vfx-ryzz`, `vfx-sable` and `vfx-tarek` (older takes of the same heroes, they conflict
with the READY ones). Two clashes had to be hand-fixed in the scratch tree (`HeroVfx` mode 8 taken by both
dredge's `chain` and bulwark's `dome`, and a `shine` shader name used twice); both need fixing when those two
branches are merged. The scores are therefore for "all READY VFX branches merged", not for main today. The worker's
ground renders yellow, so read colours against that.

Strips: `docs/art/vfx_rescore/<arch>.jpg`, every reel part stacked top to bottom (alphabetical: dash, e, hold, lmb, ...,
r, rmb; Lace and Grimble add their own). Jobq GPU reels, all rc=0, no shader errors in the logs.

| Hunter | arch | before | R | S | L | T | Sc | C | Snd | after | weakest ability left |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Vex | gunslinger | 15 | 4 | 3 | 3 | 3 | 4 | 4 | 4 | **25** | LMB / held LMB: the tracer is a thin faint line at match zoom (RMB beam and X burst are fine) |
| Tenzo | dolm | 14 | 3 | 3 | 3 | 3 | 4 | 4 | 3 | **23** | LMB punch and its hold: a tiny ember, the hold shows next to nothing |
| Motley | ostra | 14 | 3 | 4 | 4 | 3 | 3 | 4 | 3 | **24** | X: a near-black opaque disc over the target (breaks the zone rule, hides what it hits) |
| Grimble | dredge | 16 | 4 | 4 | 4 | 4 | 3 | 4 | 3 | **26** | was 25: the E / X wedges now have a lit front on the hit (ext/vfx-grimble-wedges, below). Slugs now draw 1.6x (LMB) / 1.25x (X), hit radius unchanged; at the reel's 3 m dummy range the LMB slug still sits inside its muzzle burst, so Scale stays 3. Left: LMB slug read at range |
| Lace | archer | 16 | 4 | 3 | 4 | 3 | 4 | 4 | 3 | **25** | tap shots and misses: hair-thin trails (Heavy Shot and X read) |
| Meeko | tender | 17 | 4 | 3 | 4 | 3 | 4 | 4 | 4 | **26** | X root field: a pale flat teal disc, only its centre burst is layered |
| Sable | thief | 18 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | X Encore and E: flat pale lavender wash over the area, no rim or debris |
| Albert | bulwark | 20 | 4 | 4 | 3 | 3 | 3 | 3 | 4 | **24** | LMB / RMB swing arcs still hot orange, not ivory (Kael's colour) |
| Sparkle | mage | 20 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | LMB finger bolt: thin; Grounded's flat orange disc on the target |
| Neve | rimewright | 26 | 4 | 4 | 3 | 3 | 3 | 4 | 4 | **25** | X Rimelock: the whole screen goes cyan; dash path is flat grey tiles |
| Kael | juggernaut | 27 | 4 | 4 | 4 | 4 | 5 | 4 | 3 | **28** | Smash lunge telegraph: a flat magenta box, off his crimson |
| Cinder | ashwick | 28 | 4 | 4 | 4 | 4 | 5 | 4 | 4 | **29** | RMB Ignite orb: blue-violet and magenta, not flame |

Reading it: every Hunter now sits at 23-29 (the 11-08 spread was 14-28), and the old worst four (Tenzo, Motley, Vex,
Grimble) gained 9-10 each. The per-hero branches claimed a little more for their own hero (Vex 26, Lace 27, Sparkle 26,
Cinder 30, Kael 29); scoring all twelve from the strips with one hand puts them 1-2 lower. Neve went down one point
(26 to 25): her Rimelock X reads as a screen-wide wash next to the others.

Parity rule (DECISIONS: match the source's readability and polish, no explosions on dashes, a ground ring means
gameplay): no Hunter's dash plays an explosion in these strips. Ground rings worth a check against a hitbox: Vex's
Shift (ring plus lane), Tenzo's X rings, Neve's dash path. Not checked against a hitbox here.

### Grimble wedges (ext/vfx-grimble-wedges, 2026-11-11): 25 -> 26
The scorecard's "RMB wedge" is read as his X fan: his RMB is the Abyssal Hand (a reach, no wedge). HeroVfx gains a
`wedge` ground look (docs/HERO_VFX.md): a soft inside (coverage 0.04 at the apex, 0.22 by the rim), a dark char line
and a lit coin-gold rim on the exact edge, and a bright ragged front running out from him. Grimble's E wind-up holds
one whose front is the wind-up's charge, so it reaches the rim on the slam frame; the slam flashes the rim and burns
it away; the X charge holds one whose front is the charge fan's growing edge, so it reaches the rim as the first wave
fires; each Broadside wave's front reaches the rim with the slugs (0.17 s, asserted against `x.range`, `MUZZLE` and
`x.speed`). The wedges are the hit cones (`e.radius`/`e.angle`, `x.range`/`x.fan_deg`); hit shapes and shot sizes
are unchanged. His AimKit tells drop from alpha 1.8 to 0.7 so their fill stays under 0.25 at the apex. Slug trails
(LMB and X) are 0.34 m wide (was 0.16), tail 0.14 s. Timing 3 -> 4 (the front lands on the hit). Scale stays 3: in the GPU LMB
sheet the long pale lines are the aim lines, and the slugs and their 0.34 m trails barely show at match zoom; the
weapon's slug look comes from the shared shot look (Oomph.shot_look), so it is backlog item 9, not this branch. Scored from the Forward+ GPU reel (jobq `20261111-211018-30595`, `--hero-vfx-reel
--reel-hero=dredge`, rc=0): sheets in `/home/boki/gens/vfx-grimble-wedges/gpu_after/` (`dredge_e.png`: the white front
runs out over the wind-up and lands on the slam; `dredge_r.png`: the charge front sweeps to the rim, then the waves).
The before reel (base `origin/ext/w0246-audio-vfx`) failed (rc=97, its worktree was gone) and was re-run, see below.

Slugs (2026-11-12): `HeroVfx.shot` scales the drawn slug and its streak by the move's `"draw"` (`s["vr"]`; the hit
radius `s["r"]` is not touched, --hero-vfx-check asserts both). LMB `slug` draw 1.6, trail 0.5 m / 0.2 s; X gets its
own `broadside_slug` (draw 1.25, trail 0.7 m / 0.16 s). The X muzzle burst is smaller (flare 2.6 -> 1.6 m, smoke
6 x 0.7 -> 3 x 0.4 m) so it no longer hides the slugs in their 0.17 s flight. Re-scored from Forward+ GPU reels of
the final branch (jobq `20261112-044411-09139`) and the base (`335955c3a`, the train merge before any wedge work,
jobq `20261112-054219-29999`), both rc=0, no shader errors: `docs/shots/vfx-grimble-wedges/{e,r,lmb}_before_after_gpu.jpg`
(left base, right after). E and X: the flat pale cones become a lit gold rim over a faint inside with a white front
that sweeps out and lands on the hit. X waves: big gold slugs reach the dummy with the front. LMB: the slug is a
little larger, but at the reel's 3 m range it is still inside the muzzle burst. Score stays **26** (Scale 3).

## Backlog (remaining fixes, from the table)
1. Motley X: soften the black disc to a lit rim plus a soft inside (alpha 0.25 or less at the centre).
2. Neve X: shrink the screen-wide cyan wash to the hit area; texture the dash path tiles.
3. Vex LMB and hold: a wider, brighter tracer at match zoom.
4. Tenzo LMB and hold: a bigger punch and a visible charge for the hold.
5. Albert: ivory swing arcs for LMB/RMB.
6. Kael: crimson Smash telegraph instead of the flat magenta box.
7. Cinder: flame-coloured Ignite orb.
8. Meeko, Sable: zones as a lit rim over a faint inside (X root field, Encore/E). Grimble's wedges done (below).
9. Lace tap shots, Sparkle LMB: thicker trails / a bigger drawn slug (hit size unchanged). Grimble's slugs draw 1.6x / 1.25x now; his LMB still needs a read at range (a smaller LMB muzzle, or a reel shot at 8 m).
10. Merge-time fixes: the `HeroVfx` mode 8 clash (`chain` vs `dome`) and the duplicate `shine` shader name.
