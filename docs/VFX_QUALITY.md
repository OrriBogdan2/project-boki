# Ability VFX quality: the bar, the rules, the scorecard (2026-11-08, re-scored 2026-11-09)
# Ability VFX quality: the bar, the rules, the scorecard (2026-11-08)

Owner playtest 11-08: abilities look janky; Cinder and Kael look decent. This doc sets the bar from those two kits
(plus the source footage in `docs/KIT_PARITY.md`), lists the shared causes of jank and what the shared layer now does,
and scores every Hunter worst-first. Each Hunter's fix is a backlog item (role `feel`) that must ship a before/after
strip made with the reel below.

## Strips
`godot --path . --hero-vfx-reel --reel-hero=<arch> --shots-dir=shots/<arch>` (through `jobq submit --needs gpu`) writes
one PNG sheet per part: `shots/<arch>/<hero>_<part>.png`. Parts: `lmb`, `hold` (LMB held 1.4 s), `rmb`, `dash`, `e`,
`r`, plus a Hunter's own parts (`tools/vfx_reel/<arch>.gd`, e.g. Grimble's `hook`). The 11-08 pass ran `vfxq-before-<arch>`
on main's tree (d255acbee). The 11-09 re-score strips are in `docs/art/vfx_rescore/<arch>.jpg` (see below).
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
| `fx_dot` particles cut hard into the ground | `FxDot.material()` is the one material: Forward+ and Mobile fade by the depth behind the dot, gl_compatibility and the Low presets by height above the ground under the burst (no depth copy); `--dot-soft-shots` (`--dot-hard` = the before look), GPU shots in `docs/shots/dot-soft/`: `glcompat_*` (Apple M5, before/after, high and low) and `forwardplus_high_after_*` (RTX 4090). GPU `--perf-bench` 60 s 1920x1080, main vs this: high draws 1003/1017, gpu 0.90/0.88 ms; low draws 881/844, gpu 1.69/0.42 ms (flat) |

Still open (shared, not done here):
- `fx_dot` particles are `blend_mix` and have no soft-particle depth fade, so they clip hard into the ground. A depth fade
  breaks gl_compatibility, so it needs a mobile fallback.
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm (tender's are gone on ext/vfx-tender). Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- `pin_draw.gd` defaults to `#e8483e`.
- Only six kits are data-driven (`content/vfx/`: archer, ashwick, dredge, juggernaut, rimewright, tender). The rest draw with
  `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`). Moving each to `HeroVfx` data is
  how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's E/X scorch (`VvFx.disc`), Motley's well dome, Meeko's seed and
  ult discs (fixed on ext/vfx-tender: `care_disc` `glow`) and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm, tender. Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- Only five kits are data-driven (`content/vfx/`: archer, ashwick, juggernaut, rimewright, tender). The rest draw with
  `Fx` primitives in code (`dj_fx`, `ld_fx`, `vv_fx`, `pin_fx`, `bjorn_fx`, `breah_*`). Moving each to `HeroVfx` data is
  how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's E/X scorch (`VvFx.disc`), Motley's well dome, Meeko's seed and
  ult discs and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
  rim plus a soft inner falloff (alpha 0.25 or less at the centre), never a solid fill. Each kit sets these, so the fix
  is per kit (backlog).
- Motley's kit draws its well and orbs in indigo/violet, but his slot colours and signature are teal. The ostra item
  moves them to teal. The alternative (keep void violet) would clash with Sable.

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
| Grimble | dredge | 16 | 4 | 4 | 4 | 3 | 3 | 4 | 3 | **25** | E / RMB wedges: flat pale sectors with no leading edge; slugs small at match zoom |
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

## Backlog (remaining fixes, from the table)
1. Motley X: soften the black disc to a lit rim plus a soft inside (alpha 0.25 or less at the centre).
2. Neve X: shrink the screen-wide cyan wash to the hit area; texture the dash path tiles.
3. Vex LMB and hold: a wider, brighter tracer at match zoom.
4. Tenzo LMB and hold: a bigger punch and a visible charge for the hold.
5. Albert: ivory swing arcs for LMB/RMB.
6. Kael: crimson Smash telegraph instead of the flat magenta box.
7. Cinder: flame-coloured Ignite orb.
8. Meeko, Sable, Grimble: zones as a lit rim over a faint inside (X root field, Encore/E, E/RMB wedges).
9. Lace tap shots and Sparkle LMB: thicker trails.
10. Merge-time fixes: the `HeroVfx` mode 8 clash (`chain` vs `dome`) and the duplicate `shine` shader name.
## Scorecard (worst first)
Each axis is scored 1–5: R readability, S shape, L layering, T timing, Sc scale, C colour (before the shared fix), Snd
sound. Scored from the `vfxq-before-*` strips (main d255acbee); sound is scored by code read (the strips are silent).

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | main problem (from the strip) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Tenzo | dolm | 3 | 3 | 3 | 3 | 4 | 3 | 3 | 22 | re-scored 11-12 (was 14): cobalt lane, rings and Rockfall slam read at match zoom, layered crack + debris + blast. Under the bar: `scripts/arch/kits/kit_looks.gd` `_build_rock` still builds the thrown boulder/rock as a molten orange lump with an orange haze (heat 0.75-0.95, haze `Color(1.0, 0.42, 0.1, 0.28)`): give it basalt + cobalt rim (heat 0, haze `#3a7cff`); `content/vfx/dolm.json` palette `dust` `#c8b496` puffs land as opaque beige clouds that hide the foe in the quake, rocks and dash strips: lower the `smoke` layers' alpha / size or tint `stone` `#8f9cb8` |
| 2 | Motley | ostra | 4 | 3 | 3 | 3 | 4 | 3 | 3 | 23 | re-scored 11-12 (was 14): teal orb, Snap spear, seed circle and Nightwell read at once and the zones are lit rims, not solid fills. Under the bar: the Trade dash is a magenta pentagram circle with a violet mask (`scripts/arch/kits/ostra_kit.gd` `TRADE_EDGE` `#ff3fd0`, `content/vfx/ostra.json` palette `pink` `#ff4fd8`): move both to the sea-teal slots; LMB hit is still a small burst (`ostra.json` orb-hit recipe: size up, add a shard layer); the Nightwell's black orbs are the only dark mass left |
| 3 | Vex | gunslinger | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | re-scored 11-12 (was 15): lime/green-fire throughout, the Longneedle beam and Cinderfall burst are the strongest frames, E/X are soft discs now. Under the bar: `content/vfx/gunslinger.json` `shot_trail` / `shot` (LMB) are still a short pale puff, the round is not in flight on most frames of the LMB strip (this tree lacks `ext/vfx-vex-tracer`, which conflicts with the data port): widen the tracer to ~0.34 m with a hot core as that branch does; `x_cast` pre-cast zone reads as a pale-yellow wash at 0.1 s: tint it `main` with a lit rim; the Burr dash slab (`slide`, `slide_air`) is a faint flat green rectangle: add a core streak |
| 4 | Grimble | dredge | 4 | 3 | 3 | 3 | 4 | 3 | 3 | 23 | re-scored 11-12 (was 16): gold wedges with a lit rim for E and X, gold slugs and chain, the hook bite reads. Under the bar: E has no Anchor Drop fist (`ext/vfx-grimble-anchor`, conflicts with the wedge data in `content/vfx/dredge.json` + `scripts/match/hero_vfx.gd`): port the `fist` layer onto the wedge look; the dash has no recipe at all in `content/vfx/dredge.json` (no barge/dash key): its camo stone ball with an orange ring and orange glow comes from code, give it `main` `ffc832` + `hot`; the X hit throws pink flecks (`scripts/arch/kits/dredge_blast.gd` hit sparks): coin gold |
| 5 | Lace | archer | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 27 | re-scored 11-08 from strips (ext/vfx-archer, was 16): every thread, needle, trail and beam is orchid; tap/arrow ribbons 2-3x wider with a pale hot core, stuck and stitched threads hold at match zoom; Heavy Shot release layered (white core, orchid body flare, sweep, seam, sparks); new full-draw, release and arrow-hit sounds. Left: the Heavy Shot is still the big flat arrow (owner Nov 4) with a pale fletch rosette; the gold perfect-release cue stays gold (a timing signal) |
| 6 | Meeko | tender | 3 | 3 | 3 | 3 | 3 | 2 | 4 | 21 | re-scored 11-12 (was 17), tree = main + kindle numbers + zone rims + root field (the look-weight branch `ext/vfx-meeko-weight-rebased-rebased` conflicts and is not in it). Under the bar: `content/vfx/tender.json` palette: LMB orb is lilac `#c8a8ff` / pink `#f6a6c8` with a lilac ring, Hearthlight E ring is gold, and the Hearth Call dome rim is cyan: only the root field is leaf green; move orb, ring and dome rim to `#5fdc6a` slots (gold stays the heal accent); LMB hit is a thin ring (no debris layer: add a leaf-spark burst in the same file); Hearth Call (R) is a small pale bubble with a tiny ring, ~1 m across next to E's 7 m dome: scale it to the tether range |
| 7 | Sable | thief | 2 | 2 | 2 | 3 | 3 | 3 | 3 | 18 | LMB hits nearly invisible; held LMB is a flat unlit purple box; X is pale grey discs |
| 8 | Albert | bulwark | 3 | 3 | 2 | 3 | 3 | 2 | 4 | 20 | gold swing arcs read; dash dome is mint green; E is a flat gold box with dark cubes |
| 9 | Sparkle | mage | 3 | 3 | 3 | 3 | 3 | 2 | 3 | 20 | lightning still cyan (old teal) next to pink orbs; X tints the whole screen purple |
| 10 | Neve | rimewright | 4 | 4 | 4 | 3 | 4 | 4 | 4 | 27 | reads well (shards, shatter burst). Done (ext/vfx-neve-ice-path): the skate's ice path was up to 24 pooled flat untextured boxes (a node and material each); now one MultiMesh strip (`IceStrip`, `shaders/ice_strip.gdshader`): cel-lit pale ice, a faint frost rim, a lighter facet step, a ragged cel fade at the tail; same plate size, form-in, spacing, 24-plate length and 3 s life. Left: the plates are still laid flat (no relief on slopes) |
| 11 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar: layered flame with a hot core. Polish: soft-particle ground clipping, hold-blade glow |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4→5 | 4 | 3→4 | 27→29 | the bar: slash arcs, burning lanes, debris. Done (ext/vfx-kael-polish): the X crescent is the strip's leading edge (was 4.3m across a 1.8m strip). Left: the LMB slash sound is a swish with no hard edge; the cleave sound's cut lands on the strike, sharp (was 84 ms late and 4 dB over its swish) |

Lace's row is scored from her strips (before `vfxq-before-archer`, job 20261108-180332-30891; after
`vfxq-after-archer-2`, job 20261108-213129-03140); the pair is on branch `ext/vfx-archer-strips` (not for merge). Her
row keeps its place until the integrator re-sorts the table.

## Re-score 11-12 (fresh strips at the gameplay camera)
Tenzo 14, Motley 14, Vex 15, Grimble 16 and Meeko 17 came from strips older than the colour audit and the data ports.
None of those branches is on main (`origin/main` 88b06b9e7) and the audit conflicts with the ports (they replace its
palette work), so each Hunter was rendered on a scratch tree = origin/main plus that Hunter's own unmerged work, then
scored with the rubric above (R S L T Sc C Snd; Snd carried from the earlier code read, the strips are silent). Rows above are
updated; each "Under the bar" line names the file and the fix. Branches that conflicted are listed: they are why a gap
remains and are not scored.

| Hunter | tree (merged onto origin/main) | not mergeable into it | jobq (`--hero-vfx-reel`, GPU) | montage (repo) |
|---|---|---|---|---|
| Tenzo | ext/vfx-tenzo-data eda0f9c6e | vfx-tenzo-impacts, vfx-colour-audit | 20261112-030826-11508 | `docs/art/vfx_rescore/dolm_1112.jpg` |
| Motley | ext/vfx-motley-data ff3d6aaa3 | vfx-motley-swap-marker, vfx-colour-audit | 20261112-030826-04139 | `ostra_1112.jpg` |
| Vex | ext/vfx-vex-data c2a99301c + vfx-vex-lance-beam | vfx-vex-tracer(-0246), vfx-colour-audit | 20261112-030826-22563 | `gunslinger_1112.jpg` |
| Grimble | ext/w0246-audio-vfx 70b9bd7b9 + vfx-grimble-wedges | vfx-grimble-anchor | 20261112-030828-02884 | `dredge_1112.jpg` |
| Meeko | vfx-meeko-kindle-numbers + vfx-zone-rims + vfx-meeko-ult-field | vfx-meeko-weight-rebased-rebased | 20261112-030826-21801 | `tender_1112.jpg` |

Sheets: `/home/boki/jobq/done/<id>/out/<arch>/<arch>_<part>.png` (Tenzo's reel plays `boulder`, `dash`, `quake`, `r`, `rocks`;
the others `lmb`, `hold`, `rmb`, `dash`, `e`, `r`, Grimble also `hook`). Each montage holds five sheets at half size.
Totals are lower than some READY lines claim (Motley 25, Vex 27): the strips show the gaps in the rows. Our ideas, not
parity: none added. The remaining gap to the bar (Cinder 28) is 5-7 points each.

Strips: the before sheets are jobq `vfxq-before-<arch>`, the after sheets `vfxq-after-<arch>`
(`/home/boki/jobq/done/<id>/out/`). Tenzo's before/after pair is on branch `ext/vfx-quality-strips` (not for merge) and
linked from PR #14; Kael's X pair (`before_juggernaut_r.png`, `after_juggernaut_r.png`) is there too.
