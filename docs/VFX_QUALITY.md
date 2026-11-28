# Ability VFX quality: the bar, the rules, the scorecard (re-scored 2026-11-22 on main 41de1b3f01)

Owner playtest 11-08: abilities look janky; Cinder and Kael look decent. This doc sets the bar from those two kits
(plus the source footage in `docs/KIT_PARITY.md`), lists the shared causes of jank and what the shared layer does, and
scores every Hunter on today's main. Each Hunter's fix is a backlog item (role `feel`) that must ship a before/after
strip made with the reel below.

## Strips
`godot --path . --hero-vfx-reel --reel-hero=<arch> --shots-dir=<dir>` (through `jobq submit --needs gpu --tree <tree>
--out <dir> -- ...`) writes one PNG sheet per part (a 3x3 grid of crops): `<dir>/<hero>_<part>.png`. Parts: `lmb`, `hold`
(LMB held 1.4 s), `rmb`, `dash`, `e`, `r`, plus a Hunter's own parts (`tools/vfx_reel/<arch>.gd`, e.g. Grimble's `hook`).
The 11-22 strips: one contact sheet per Hunter with every part, 2 sheets wide, in
`docs/art/vfx_rescore_1122/<arch>.jpg`; the full-size sheets are in the jobq outputs
(`/home/boki/jobq/done/<id>/out/`). All 13 ran on main 41de1b3f01, real GPU, rc 0, 1328x908 sheets:

| arch | jobq id | worker | arch | jobq id | worker |
|---|---|---|---|---|---|
| gunslinger | 20261122-061509-28597 | rp1-1 | rimewright | 20261122-060410-12846 | rp2g-0 |
| juggernaut | 20261122-060245-01175 | rp1-3 | mage | 20261122-060424-27265 | rp2g-2 |
| ashwick | 20261122-060300-10304 | rp1-2 | bulwark | 20261122-060438-32285 | rp1-3 |
| tender | 20261122-060314-07334 | rp2g-3 | thief | 20261122-060452-29113 | rp1-1 |
| dolm | 20261122-060328-06429 | rp2g-2 | ostra | 20261122-060511-28404 | rp2g-1 |
| archer | 20261122-060341-10332 | rp2g-3 | gil | 20261122-060525-00883 | rp1-0 |
| dredge | 20261122-060356-17479 | rp1-2 | | | |

(The first gunslinger job, 20261122-060232-19055, took 832 s on a Mac worker; the same reel on rp1-1 took 101 s, so it
was re-run there and that one is scored.)

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
| Lace | archer | `#d41e2e` | deep red | the table said orchid `#e04aff`; the file is deep red now (close to Kael's crimson: see follow-ups) |
| Grimble | dredge | `#ffc832` | coin gold | |
| Neve | rimewright | `#8ae6ff` | frost cyan | |
| Sparkle | mage | `#ff5ab4` | pink | matches job sparkle-dash-feel-1108's kit recolour |
| Albert | bulwark | `#fff0b0` | radiant ivory | |
| Sable | thief | `#9a5cff` | violet | |
| Motley | ostra | `#2ee6c0` | sea teal | |
| Gil | gil | `#2fa08c` | sea green | water blue-cyan in the strips |

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
| Tenzo's kit hard-coded molten red/orange | recoloured to cobalt in `dolm_kit`, `breah_*`, `rock_look` ; the rock bodies, thrown and raised, follow in 11-21: blue slate with rune-teal cracks and rim, like his arm (`KitLooks.slate_mat`) |
| The reel had no held-LMB part | `hold` part in `tools/hero_vfx_reel.gd` |
| `fx_dot` particles cut hard into the ground | `FxDot.material()` is the one material: Forward+ and Mobile fade by the depth behind the dot, gl_compatibility and the Low presets by height above the ground under the burst (no depth copy); `--dot-soft-shots` (`--dot-hard` = the before look), GPU shots in `docs/shots/dot-soft/`: `glcompat_*` (Apple M5, before/after, high and low) and `forwardplus_high_after_*` (RTX 4090). GPU `--perf-bench` 60 s 1920x1080, main vs this: high draws 1003/1017, gpu 0.90/0.88 ms; low draws 881/844, gpu 1.69/0.42 ms (flat) |

Soft edges (ext/vfx-soft-dots): `fx_dot` has its own ground fade (row above: depth on Forward+/Mobile, per-burst height on
gl_compatibility and the Low presets). The other camera-facing effect shaders (LDFx's upright looks, HeroVfx's upright
looks and motes) include `shaders/soft_fade.gdshaderinc` and fade out over 0.25 m where they meet the ground instead of
cutting a hard line into it. One include, picked by renderer: Forward+/Mobile fade by the scene depth behind the
fragment; Compatibility (no depth texture to spare) fades by height over the match's tile ground (`fx_ground`, shared by
`FxGround` on the World; off outside a match). Flat looks (scorch, rings, ground decals) lie on the ground and don't
fade. `--hero-vfx-check` asserts each shader takes the include and the match world shares its ground map.
Cost (`--perf-bench --bench-secs=30 --quality=medium`, real GPU, RTX 4090, Forward+, same worker, main vs branch): match
GPU 7.13 -> 7.34 ms at 2560x1440 (3D scale 0.75), 0.32 -> 0.31 ms at 640x360; match wall 64.5 -> 65.4 ms (CPU-bound
both sides, script 20.0 -> 20.8 ms); hub budget ok both (frame 13.5 / 13.2 of 16.7 ms). Strips: docs/shots/vfx-soft-dots.
(Measured before `fx_dot` took main's version; the dot shader's cost is in the row above.)

Done (11-19, ext/vfx-no-generic-orange): the generic damage orange (`AbilityFx.CAT`, `Feel.CAT`, `KinRules.CAT_COLORS`) is Boki's
and generic casts' only. `KinExec.make_cx` gives every cast whose caster is a Hunter with an archetype `hero_col` = its slot colour,
so Kael's Searing Wave and merge casts (which built their context by hand) no longer fall through; the fall-through
(`KinExec.generic_col`) asserts it is never a Hunter's, and `--hero-vfx-check` pins `hero_col` per Hunter next to its
existing recorded-colour fence. `pin_draw.gd` has no `#e8483e` any more.

Still open (shared, not done here):
- Data-driven kits: all 13 Hunters have `content/vfx/<arch>.json`; code still draws Albert's hammer and shield meshes (`bjorn_fx`, `aegis_wall`), Sable's LMB, RMB and E (`dj_fx`) and Tenzo's rock bodies (`breah_*`).
- Zone rule (seen in the strips): a zone is a lit rim plus a soft inside (alpha 0.25 or less at the centre), never a solid fill. Vex's X, Albert's Faultline and Sable's RMB lane still break it (follow-ups above; Gil's lanes are soft since 11-25).

## Scorecard (re-scored 2026-11-22, worst first)
Rubric, each axis 1-5: R readability, S shape, L layering, T timing, Sc scale, C colour (against the Hunter's current
signature colour above), Snd sound. One hand scored all 13 from the 11-22 strips above. Snd is carried from the earlier
code read (the strips are silent). The worker's ground renders yellow, so read colours against that.

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | was | what the strips show |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Albert | bulwark | 4 | 4 | 3 | 3 | 3 | 4 | 4 | 25 | 24 | Fixed 11-25 (ext/vfx-albert-faultline-rim; R 3 -> 4, C 3 -> 4, was 23): Faultline (R) is the AimKit soft lane (lit rails, inside under alpha 0.25), each erupting cell a lit outline over a faint inside instead of a solid cream slab and tall cream tubes, so the ground and the foe show through; same 5.5 m lane and timing. The 360 Smash ring (Shift) is ivory now. Swing and shield-charge crescents are gold/ivory and read. Strips: `docs/shots/vfx-albert-faultline-rim/` (grey = before, green = after) |
| 2 | Grimble | dredge | 4 | 3 | 3 | 3 | 4 | 3 | 4 | 24 | 25 | E: flat translucent orange hex slabs, the palette `main` is copper `d89040`, not coin gold; LMB slugs small; hook, dash ribbon and X fan read Sound 3 -> 4 (11-25, ext/sfx-four-snd3, code read and `--sfx-set-check`; owner's ear pending): a distinct hit per ability, a travel loop on every shot that flies over 0.3 s, a tail layer under the thinnest cast, see docs/AUDIO.md "Ability bar: Sable, Sparkle" |
| 3 | Vex | gunslinger | 3 | 3 | 4 | 3 | 4 | 4 | 4 | 25 | 24 | re-scored 11-25 (ext/vfx-vex-nuke-rim; L 3 -> 4, was 24): the X Nuke burning patch is a lit lime rim over a soft inside now, the foe reads through it (the dark fill was `BURN_FILL_A` 3.0 in `scripts/arch/kits/gunslinger_ult.gd`, not the JSON: AimShapes stacks two discs, so it was ~0.9 alpha at the centre; now 0.8 = 0.25 at the centre, ~0.5 by the rim, halving as it burns; size and timing unchanged; `x_shell` is the falling streak, no zone, untouched). Strip `docs/shots/vfx-vex-nuke-rim/x_before_after.jpg` (top grey = main b7258e5028, jobq 20261125-184250-10987; bottom green = after, 20261125-184458-12815; `--hero-vfx-reel --reel-hero=gunslinger --reel-only=r`). Still open: E cone is a flat pale lime band; LMB tracer is a short lime dart (reads) |
| 4 | Sable | thief | 4 | 3 | 3 | 3 | 4 | 4 | 4 | 25 | 24 | 11-28 (ext/vfx-sable-bola-knife, VFX sweep rows 2 and 3, not re-scored): the Bola's first catch and the Knife's stick had no hit frame and no rim. Now `bola_wrap` (flare, lit sweep, stars) plays on the first catch with a 1.6 m lit rim for 0.4 s (2.0 m round each foe of a TANGLE), `knife_stick` is a flare, sweep and stars on a foe, and while the dagger stays a 2.7 m lit rim marks the blink's arrival circle (`e.ring_r`, the source's 1.5 bh). The rims are AimKit `bare` circles (`all`, `tell` false: no TellCue wind-up, they mark no landing hit): the hero_vfx `ring` layer the 11-28 first try used drew only its dust flash on the GPU reels, its band never showed. The wind-up lane is the AimKit `soft` lane with rails twice as wide (`lw` 0.12, `hot` 0.35, `alpha` 0.7): the inside lifts the ground's blue by 11 instead of 41 (frame 1, same spot). Sizes, hit areas, damage, timing unchanged. Cost (`--sable-vfx-perf`, AimDraw rebuild timed 400x per side): the knife ring on a foe moving 0.1 m a frame +0.05 / +0.13 ms a frame, a catch rim's first frame +0.05 / +0.12 ms (rp2g-1 jobq 20261128-113723-30132 / rp1-0 -113737-14563; budget 0.3); the 4v4 frame p95 A/B on these shared workers swings +-10 ms per round (-2.28 / -1.25 ms overall), too noisy to read 0.3. Strip `docs/shots/vfx-sable-bola-knife/sable_bola_knife_before_after.jpg` (grey = main 8d8b678e3e, jobq 20261128-112345-28632 on rp2g-1; green = after, -113338-20901 on rp3g-2; both with this branch's E reel timing). LMB bolt and hit now read, X rings are lit rims and read Sound 3 -> 4 (11-25, ext/sfx-four-snd3, code read and `--sfx-set-check`; owner's ear pending): a distinct hit per ability, a travel loop on every shot that flies over 0.3 s, a tail layer under the thinnest cast, see docs/AUDIO.md "Ability bar: Sable, Sparkle" |
| 5 | Sparkle | mage | 4 | 3 | 3 | 3 | 4 | 5 | 4 | 26 | 24 | Fixed 11-23 (ext/vfx-sparkle-skycall): E Skycall was a big white blob over a brown disc hiding the foe; now a thin pink-white column (`e_count` skirt, size 0.28) on a soft pink rim (pool `band` 0.2; the strike's char disc is the same rim), strike flare 1.8 to 1.2; the RMB orb's orange haze was its pink OmniLight on the yellow ground (`MageKit._build_mote`: slot pink `#ff5ab4`, energy 1.2 to 0.6; it is not in `mage_gum.gd`, which is only the bubblegum). Timing and hit radius unchanged. Strips `docs/shots/vfx-sparkle-skycall/{e,rmb}_before_after.jpg` (grey = main, green border = after; jobq 20261123-151731-04969 before, 20261123-152220-00557 rmb after, 20261123-152546-13620 e after, `--hero-vfx-reel --reel-hero=mage`); LMB bolt thin; X dome is a pink rim and reads Sound 3 -> 4 (11-25, ext/sfx-four-snd3, code read and `--sfx-set-check`; owner's ear pending): a distinct hit per ability, a travel loop on every shot that flies over 0.3 s, a tail layer under the thinnest cast, see docs/AUDIO.md "Ability bar: Sable, Sparkle" |
| 6 | Meeko | tender | 4 | 3 | 3 | 3 | 4 | 3 | 4 | 24 | 26 | LMB orb is orange with a gold ring (not leaf green); E ring is a thick flat green band; Hearth Call tether and heal rise read |
| 5 | Sparkle | mage | 4 | 3 | 3 | 3 | 4 | 4 | 4 | 25 | 24 | E Skycall: a big white blob over a brown disc hides the foe for 3 frames; RMB orb sits in an orange haze (off pink); LMB bolt thin; X dome is a pink rim and reads Sound 3 -> 4 (11-25, ext/sfx-four-snd3, code read and `--sfx-set-check`; owner's ear pending): a distinct hit per ability, a travel loop on every shot that flies over 0.3 s, a tail layer under the thinnest cast, see docs/AUDIO.md "Ability bar: Sable, Sparkle" |
| 6 | Meeko | tender | 4 | 3 | 3 | 3 | 4 | 4 | 4 | 25 | 26 | re-scored 11-23 (ext/vfx-meeko-weak-col; C 3 -> 4, was 24): the LMB comet, trail and hit are leaf green now (pale-green hot core, leaf halo, leaf-star and amber debris, was an orange orb with a gold ring; Cinder's colour); GPU strip `docs/shots/vfx-meeko-weak-col/lmb_before_after.jpg` (grey = main 5a246f9696, jobq 20261123-021310-01890; green = after, -021623-09694). Still open: the Burrseed (RMB) field and its cast flare stay amber on purpose (a hostile zone reads against the green heals), E ring is a thick flat green band; Hearth Call tether and heal rise read |
| 7 | Lace | archer | 3 | 3 | 3 | 4 | 4 | 4 | 4 | 25 | 25 | tap shots and misses: thin faint red lines at match zoom; Heavy Shot and X are layered and read |
| 8 | Neve | rimewright | 4 | 3 | 4 | 3 | 3 | 4 | 4 | 25 | 25 | X Rimelock fixed 11-25 (ext/vfx-neve-veil): the grey-cyan veil with thick cyan cracks covered the whole frame at match zoom (rink fill alpha 0.2-0.45 plus saturated cracks, then a full-radius `rime_crash` scorch disc). Now the veil sits inside the 7.47 m radius only (unchanged), `care_disc` pattern 4 body is clear in the middle (centre alpha fill x 0.04 x 1.6 = 0.04, was 0.2) and gathers toward the lit rim, cracks live in the outer band only and are capped thin, and the crash scorch is a `pool` (rim band 0.12, frost-cyan) not a filled disc. Hit radius and timing unchanged. Strip `docs/shots/vfx-neve-veil/r_before_after.jpg` (grey = main, green border = after; jobq 20261125-183250-12037 before, -185538-26181 after, `--hero-vfx-reel --reel-hero=rimewright --reel-only=r`). Left: dash plates; not re-scored; dash plates read as ice |
| 9 | Tenzo | dolm | 4 | 3 | 4 | 3 | 4 | 4 | 4 | 26 | 23 | cobalt lane, rings and Rockfall slam layered; boulder is blue slate with rune-teal; dust is thin now. LMB punch has no own part in his reel Sound 3 -> 4 (11-25, ext/sfx-four-snd3, code read and `--sfx-set-check`; owner's ear pending): a distinct hit per ability, a travel loop on every shot that flies over 0.3 s, a tail layer under the thinnest cast, see docs/AUDIO.md "Ability bar: Sable, Sparkle" |
| 10 | Gil | gil | 4 | 3 | 3→4 | 3 | 4 | 4 | 4 | 25→26 | 26 | Fixed 11-25 (ext/vfx-gil-soft-lanes): the E spout and Tidal Wave lanes (`_tick_lines`) and the Tide Lunge hold lane (`_tide_tick`) in `scripts/arch/kits/gil_kit.gd` were flat translucent rectangles with a hard edge; they are AimKit `soft` lanes in his colour now (lit rim glowing inward, inside alpha 0.097 at the base, 0.25 at most at the fill front; `SOFT_A` 1.2 keeps the base at 0.1 or less). Length, width and timing unchanged. Strips `docs/shots/vfx-gil-soft-lanes/{e,hold}_before_after.jpg` (grey = main b7258e50, jobq 20261125-183404-11251; green = after, 20261125-183918-08326; `--hero-vfx-reel --reel-hero=gil`, real GPU rc 0). Left: the lane still reads as a rectangle by its rim (that is the hit shape), Ground Swim draws no AimKit lane; puddle rim, splash and wave read |
| 11 | Motley | ostra | 4 | 4 | 4 | 3 | 4 | 4 | 4 | 27 | 24 | the black disc is gone: X is a teal rim with dashes and a pale inside, LMB orb bursts on the foe; first X frames show a flat pale grey disc before the rim lights |
| 12 | Kael | juggernaut | 4 | 4 | 3 | 4 | 5 | 4 | 4 | 28 | 28 | slash arcs, burning lanes and slam read; the lunge telegraph is a pale flat pentagon box; the dash trail is a red/black checker bar |
| 13 | Cinder | ashwick | 4 | 4 | 4 | 4 | 5 | 4 | 4 | 29 | 29 | the bar: layered flame, hot core, lava carpet on Flue Flight; Ignite orb is flame orange now |

Spread 23-29 (was 23-29 on 11-09). `was` is the 11-09 re-score (Gil's is 11-11). Sorted by total, ties by how bad the
worst frame is. The four rows the old table flagged are gone or smaller: Albert's swing arcs are ivory and gold, Tenzo's
boulder is slate, Motley's disc is a rim, Neve's wash no longer fills the frame as one colour. History: the 11-08
before scores (Tenzo 14, Motley 14, Vex 15, Grimble 16, Lace 16, Meeko 17, Sable 18, Albert 20, Sparkle 20, Neve 26,
Kael 27, Cinder 28), the 11-09 and 11-12 re-scores and each fix branch's own notes are in git:
`git show 41de1b3f01:docs/VFX_QUALITY.md`.

## Follow-ups: the worst five (not fixed here)
1. Albert: done 11-25 (ext/vfx-albert-faultline-rim): Faultline is a soft lane with lit outlines, the 360 Smash ring is ivory.
2. Grimble, `content/vfx/dredge.json`: the E fist/wedge slabs are flat translucent orange because palette `main` is copper `d89040`; move `main` to coin gold `#ffc832` and give the slab a lit rim.
3. Vex, `content/vfx/gunslinger.json` `x_shell` / X zone end: the Nuke ends as a near-opaque dark green disc over the foe; cap the inside alpha at 0.25 and keep the lit rim.
4. Sable, `scripts/arch/kits/thief_kit.gd` (RMB Bola wind-up lane): a flat lavender slab; use the `soft` AimKit lane (lit rim, inside at most 0.1).
5. (done 11-23, ext/vfx-sparkle-skycall) Sparkle, `scripts/arch/kits/mage_sky.gd` (E Skycall; the data is `content/vfx/mage.json` `e_count`/`e_strike`): a white blob over a brown disc hides the foe; thin it to a pink-white column on a soft rim. The RMB orb's orange haze (`mage_gum.gd`) goes pink too.

Next in line (24-25, smaller): Lace's deep red against Kael's crimson (owner's call), Lace/Sparkle thin tap trails.
- `fx_dot` particles are `blend_mix` and have no soft-particle depth fade, so they clip hard into the ground. A depth fade
  breaks gl_compatibility, so it needs a mobile fallback.
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm (tender's are gone on ext/vfx-tender). Move these to slot colours.
- Kits hard-code a shared gold (`ffd25a` and near) for flashes: bulwark, thief, dolm, tender. Move these to slot colours.
- `AbilityFx.CAT` damage `#ff7a3d` and `KinRules.CAT_COLORS` damage `#ff7a52` still colour Boki/generic casts. That's right
  for Boki; check that no Hunter path reaches them.
- Data-driven kits (`content/vfx/`): archer, ashwick, bulwark, dolm, dredge, gunslinger, juggernaut, mage, ostra,
  rimewright, tender, thief (Grimble is all `content/vfx/dredge.json` now; Sable's X, dash, LMB, RMB and E are data; only her blade, bola and dagger meshes and the blink's afterimage copies are `dj_fx`). The rest draw with `Fx` primitives in code (`dj_fx`, `ld_fx`, `pin_fx`, `bjorn_fx` (only the meshes that ride his hammer and shield: the thrown hammer, the whirl trail and glint, the aegis wall; every other Albert look is data, below), `breah_*`).
  Moving each to `HeroVfx` data is how a kit reaches the bar.
- **Opaque zone fills** (seen in the strips): Vex's E/X scorch (`VvFx.disc`; fixed on ext/vfx-vex-data), Motley's well dome, Meeko's seed and
  ult discs (fixed on ext/vfx-tender: `care_disc` `glow`) and Sable's X fill the whole area with a near-opaque flat colour that hides the target. Rule: a zone is a lit
  rim plus a soft inner falloff (alpha 0.25 or less at the centre), never a solid fill. Each kit sets these, so the fix
  is per kit (backlog). Done for `VVFx.disc` (Sparkle's Skycall): the rim sits on the hit radius, the falloff
  runs from 0.45 by the rim to `DISC_FILL_A` 0.2 at the centre. Vex's discs are HeroVfx data since ext/vfx-vex-data.
  Done too: Meeko's seed disc and thrown Hearthlight (disc fill and strength, the thorn ring half as strong, the
  vortex's dark core thinned; the seed's second AimKit disc is gone) and Sable's R (Encore was already a thin ring
  since `5e9ea1d07`; `--dancer-combo-check` now measures its centre at 0.10). Sable's X since ext/vfx-sable-data-x:
  the pale lavender band is an AimKit `soft` circle (lanes and cones had it) in her `#9a5cff`: a lit rim, two flat
  glow bands 0.6 m inward (cel steps), the inside rising from 0.03-0.08 at the centre (at most 0.08 at a beat's
  brightest; `--dancer-combo-check`, `--hero-vfx-check`, `--aimkit-check` measure it as drawn).
- Motley's well, seed and orbs are teal since ext/vfx-motley-data (content/vfx/ostra.json). The alternative (keep
  void violet) would clash with Sable.

Albert (bulwark), ext/albert-vfx-data: his remaining code-drawn one-shots are `bulwark.json` moves, in his ivory and with no
fill or ring where there was none to keep: `aegis_up` (the wall rising: dust and ivory sparks), `block` (sparks and a flare on
the face), `mend_burst` (Mending Ground's end: one lit ring at its radius and rising motes) and `mend_revive` (the
kickstarted ally), and the Faultline's `fault_slam` (the near cell), `fault_land` (rock, dust and the char mark; the two
dust rings are cut: no rings on a landing), `fault_cell` (each cell heaving up) and `fault_foe` (a foe thrown). All are
`"net": false`, as the code bursts were (the lane and the ring ride their own events). Timings, hit shapes and sounds are
unchanged. Second pass (same branch): the planted hammer's beacon (`plant_beacon`: rising ivory streaks, was a 5 m gold
beam), the dash wake (`dash`: ivory specks and dust on his body, was gold and ember chevron bands), and Mending Ground's
light column (`mend_fall`: ivory light falling onto the zone during its 1 s delay, was a gold beam) and standing zone
(`mend_zone`: rising ivory specks and pluses inside AimKit's lit rim, no fill; was a second code-drawn disc) are
`HeroVfx` holds; the end burst is `mend_burst` alone. Strips redone from jobq 20261120-153944-25090 (after, same before):
`e_before_after.jpg` green (the opaque gold cone that hid him is gone), `throw` and `dash` grey (in his palette now, but the
ray is slimmer than the old beam and the wake reads about the same). `HeroVfx.hold` follows a moving `at` (the zone follows the hammer).
`BjornFx` keeps only the meshes that ride his hammer and shield (thrown hammer and rope, whirl trail and glint, the aegis
wall: translucent since ext/vfx-albert-e-wall), and the shared charge ring is his ivory, not gold. GPU strips at match zoom, grey = main (top), border green = better, grey = no change: `docs/shots/albert-vfx-data/{throw,dash,wall,r}_before_after.jpg` (jobq 20261120-145918-29886 before, -145258-27518 after, `--hero-vfx-reel --reel-hero=bulwark`). The throw and the 360 Smash look the same (their looks were already data); the Faultline landing loses its dust rings, the wall and charge ring are ivory.
Albert (bulwark), ext/vfx-albert-e-wall (row 8 again: the slab boxes were still reading as flat orange chunks on yellow
ground): the aegis is `scripts/arch/kits/aegis_wall.gd` + `shaders/aegis_wall.gdshader`, four meshes (was 31 boxes, so
27 fewer draw calls): an outer translucent sheet in the palette `slab` pale gold (deeper low down, amber seams between
the 7 plates, a hammer cross), a brighter inner sheet a hand inside it, a lit ivory rim bar along the top and a soft
gold ground contact that fades out along the foot and at the ends. Both faces draw alike (`cull_disabled`), so it reads
from behind too (not shot). Shape, size, rise, block flash, hurt tint and break are as before; no hit or timing change.
Strip at match zoom (grey = main, green = after): `docs/shots/vfx-albert-e-wall/aegis_before_after.jpg` (GPU jobq
20261120-113804-24869 before, 20261120-120528-04629 after; `--hero-vfx-reel --reel-hero=bulwark --reel-only=shield`).
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
| Grimble | dredge | 16 | 4 | 4 | 4 | 4 | 3 | 4 | 3 | **26** | was 25 (E / X wedges flat, no leading edge): fixed on ext/vfx-grimble-wedges, see below. Left: slugs small at match zoom; sound |
| Lace | archer | 16 | 4 | 3 | 4 | 3 | 4 | 4 | 3 | **25** | tap shots and misses: hair-thin trails (Heavy Shot and X read) |
| Meeko | tender | 17 | 4 | 3 | 4 | 3 | 4 | 4 | 4 | **26** | X root field: a pale flat teal disc, only its centre burst is layered (11-20, ext/vfx-meeko-heal-hurt: heals leaf green rising, hurts embers falling, Hearthlight / root field inside at most 0.25 to the rim, bloom a rim swirl; not re-scored) |
| Sable | thief | 18 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | X Encore and E: flat pale lavender wash over the area, no rim or debris |
| Albert | bulwark | 20 | 4 | 4 | 3 | 3 | 3 | 3 | 4 | **24** | LMB / RMB swing arcs still hot orange, not ivory (Kael's colour) |
| Sparkle | mage | 20 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | Grounded's flat orange disc on the target (LMB finger bolt fixed 11-22, ext/vfx-sparkle-bolt: a hot pink body ~0.75 m wide with a white core and a short 1.8 m tail, `content/vfx/mage.json` `lmb_trail`; strip `docs/shots/vfx-sparkle-bolt/lmb_before_after.jpg`, jobq 20261122-085823-02083 before / 20261122-091902-07818 after, `--hero-vfx-reel --reel-hero=mage --reel-only=lmb`; grey = main, green = better; not re-scored) |
| Sparkle | mage | 20 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | LMB finger bolt: thin; Grounded fixed 11-22 (ext/vfx-sparkle-grounded): two thin pink binding rings round the target, one dashed, seen by all (`MageSky._tick_bound`, the Bola's look without a filled disc), and the shared cords and arrow in the caster's colour (`KitStatus` meta `gnd_by` from the `kst` caster nid, `StatusLooks._tint`; Bola and Warchain stay amber); before/after `docs/shots/vfx-sparkle-grounded/grounded_before_after.jpg` |
| Neve | rimewright | 26 | 4 | 4 | 3 | 3 | 3 | 4 | 4 | **25** | X Rimelock veil confined to the 7.47 m rink (fixed 11-25, ext/vfx-neve-veil: clear middle, lit rim, thin outer cracks; not re-scored); dash path was flat grey tiles (since textured, ext/vfx-neve-ice-path) |
| Kael | juggernaut | 27 | 4 | 4 | 4 | 4 | 5 | 4 | 3 | **28** | Smash lunge telegraph: a flat magenta box, off his crimson |
| Cinder | ashwick | 28 | 4 | 4 | 4 | 4 | 5 | 4 | 4 | **29** | RMB Ignite orb: blue-violet and magenta, not flame |

Snd, Motley and Gil (11-20, ext/sfx-motley-gil-bar, code read): 3 -> 4 each. Every ability's cast and hit are the
Hunter's own and distinct, the Snap miss, the Trade's far end, an unpopped seed and the slime puddle's end have cues, and
Gil's move looks play his own set instead of other Hunters' sounds (cue maps in docs/AUDIO.md). Not 5 then: Nightwell's
close, Riptide's spout hit and the Tide lunge's cast had none. Filled 11-21 (ext/sfx-motley-last-three: os_well_close,
gil_spout_hit, gil_tide_lunge; the last two are Gil's), so Snd is 5 for both, pending the owner's ear.

Reading it: every Hunter now sits at 23-29 (the 11-08 spread was 14-28), and the old worst four (Tenzo, Motley, Vex,
Grimble) gained 9-10 each. The per-hero branches claimed a little more for their own hero (Vex 26, Lace 27, Sparkle 26,
Cinder 30, Kael 29); scoring all twelve from the strips with one hand puts them 1-2 lower. Neve went down one point
(26 to 25): her Rimelock X reads as a screen-wide wash next to the others.

Parity rule (DECISIONS: match the source's readability and polish, no explosions on dashes, a ground ring means
gameplay): no Hunter's dash plays an explosion in these strips. Ground rings worth a check against a hitbox: Vex's
Shift (ring plus lane), Tenzo's X rings, Neve's dash path. Checked against the code on `ext/vfx-ground-ring-hitbox`
(DECISIONS: a ground ring means gameplay; no rings or discs on dashes, landings or resets); the verdicts:

| Ring | What it is in code | Verdict |
|---|---|---|
| Vex Shift (Slipstep) | Nothing draws a ring or disc: `GunslingerKit.on_dash` plays after-images, dust and two skid streaks (a lane of marks along the slide, no hit). (`ext/vfx-dash-no-rings` found the pale ring in the strip is her ground shadow plus the start flash.) | No change. `--gunslinger-combo-check` asserts no `Fx.ring` or `VVFx` ring/disc appears from the press to the slide's end. |
| Tenzo X (Basalt Spine) rock-rise ring | Each rock's rise hurts and slows foes within `x.slow_r` (1.6 m, `BreahSpine._raise`), but the ring was `DolmImpact.RISE_RING` (1.4 m, Stone Row's size). | Fixed: the ring takes `slow_r`. `--dolm-combo-check` asserts every ring up during a cast sits on a rock's spot with radius `slow_r`, every frame. |
| Tenzo X cast ring | A 1.2 m ring at the ridge's centre for other players (`net_ring`): no hit or zone there, the cracks already show to everyone. | Removed. |
| Neve Skate plates | `rimewright_kit._lay_slabs`: flat ice plates (not rings) under the blades, 3 s, decoration. | Kept: it is the non-ring trail. |
| Neve Skate frost patch, hockey-stop scorch | `skate_frost` (a round `scorch` disc every third plate, 2 s) and a `scorch` in `skate_stop` (the landing mark): decoration discs on a dash. | Removed. `--rimewright-combo-check` asserts no `scorch` disc is live while skating or after the stop. |
| Neve rank-3 ice over the Abyss | `HeroZones.bridge` (3.6 m x 1.6 m, walkable terrain): gameplay, drawn as the span itself, not a ring. | Kept. |

Suggestion, not built (parity first): Tenzo's Stone Row rock-rise ring (`DolmImpact.rise` from `DolmKit._raise`, 1.4 m)
marks a rock's footprint, not a hit or zone, so by the same rule it could go or shrink to the rock's width.

## Backlog (remaining fixes, from the table)
1. Motley X: soften the black disc to a lit rim plus a soft inside (alpha 0.25 or less at the centre).
2. Neve X: done 11-25 (ext/vfx-neve-veil); the dash path tiles are textured (ext/vfx-neve-ice-path).
3. Vex LMB and hold: a wider, brighter tracer at match zoom.
4. Tenzo LMB and hold: a bigger punch and a visible charge for the hold.
5. Albert: ivory swing arcs for LMB/RMB.
6. Kael: crimson Smash telegraph instead of the flat magenta box.
7. Cinder: flame-coloured Ignite orb.
8. Meeko, Sable: zones as a lit rim over a faint inside (X root field, Encore/E). Grimble's wedges are done (below).
9. Lace tap shots and Sparkle LMB: thicker trails.
10. Merge-time fixes: the `HeroVfx` mode 8 clash (`chain` vs `dome`) and the duplicate `shine` shader name.
## Scorecard (worst first)
Each axis is scored 1–5: R readability, S shape, L layering, T timing, Sc scale, C colour (before the shared fix), Snd
sound. Scored from the `vfxq-before-*` strips (main d255acbee); sound is scored by code read (the strips are silent).

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | main problem (from the strip) |
|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Tenzo | dolm | 3 | 3 | 3 | 3 | 4 | 3 | 3 | 22 | re-scored 11-12 (was 14): cobalt lane, rings and Rockfall slam read at match zoom, layered crack + debris + blast. Under the bar: `scripts/arch/kits/kit_looks.gd` `_build_rock` still builds the thrown boulder/rock as a molten orange lump with an orange haze (heat 0.75-0.95, haze `Color(1.0, 0.42, 0.1, 0.28)`): give it basalt + cobalt rim (heat 0, haze `#3a7cff`); `content/vfx/dolm.json` palette `dust` `#c8b496` puffs land as opaque beige clouds that hide the foe in the quake, rocks and dash strips: lower the `smoke` layers' alpha / size or tint `stone` `#8f9cb8`; the dust puffs are thin (gain 0.4, half height, 0.6x life, fewer and smaller) so the crack and debris carry the read, ext/vfx-tenzo-dust-thin |
| 2 | Motley | ostra | 2→4 | 2→4 | 1→3 | 2→3 | 2→4 | 2→4 | 3 | 14→25 | re-scored 11-11 from --hero-vfx-reel strips (ext/vfx-motley-data, `docs/shots/vfx-motley-data/*_before_after.jpg`, xvfb opengl3; GPU strip jobq 20261111-151420-01798 seen, `gpu_after_full_e_r.jpg`, same read): his moments are content/vfx/ostra.json on HeroVfx in sea teal; X is a teal rim with arms and no floor, E a low teal drum, both clear over the target; every LMB orb bursts on the foe it hits (flash, shards, from half charge a ring). Left: the Trade lantern and its sigils stay violet (owner 11-08), Swollen pink; sounds unchanged. Orb-hit follow-up 11-12 (ext/vfx-motley-orb-hit, `docs/shots/vfx-motley-orb-hit/{lmb,r}_{before,after}.jpg`, local xvfb opengl3; the GPU jobq strip stayed queued behind 17+ jobs): the LMB impact is sized by the orb hit radius (`orb_hit` flare 4.5x and ring 5x the radius, 0.28 m plain to x1.9 full) with a second layer of longer pale shards; the black orbs (Nightwell rim orbs, Snap wind-up, the hand orb) are near-black glass with a broad lit sea-teal rim (`KitLooks.dark_mat`) |
| 3 | Vex | gunslinger | 3 | 3 | 3 | 3 | 3 | 4 | 4 | 23 | re-scored 11-12 (was 15): lime/green-fire throughout, the Longneedle beam and Cinderfall burst are the strongest frames, E/X are soft discs now. Under the bar: `content/vfx/gunslinger.json` `shot_trail` / `shot` (LMB) are still a short pale puff, the round is not in flight on most frames of the LMB strip (this tree lacks `ext/vfx-vex-tracer`, which conflicts with the data port): widen the tracer to ~0.34 m with a hot core as that branch does; `x_cast` pre-cast zone reads as a pale-yellow wash at 0.1 s: tint it `main` with a lit rim; the Burr dash slab (`slide`, `slide_air`) is a faint flat green rectangle: add a core streak |
| 4 | Grimble | dredge | 4 | 3 | 3 | 3 | 4 | 3 | 3 | 23 | re-scored 11-12 (was 16): gold wedges with a lit rim for E and X, gold slugs and chain, the hook bite reads. Under the bar: E has no Anchor Drop fist (`ext/vfx-grimble-anchor`, conflicts with the wedge data in `content/vfx/dredge.json` + `scripts/match/hero_vfx.gd`): port the `fist` layer onto the wedge look; the dash is fixed 11-20 (`ext/vfx-grimble-dash`, `docs/shots/vfx-grimble-dash/dash_before_after.jpg`, top before / bottom after, GPU jobq 20261120-120107-32169 (main) / 20261120-115956-01136, the reel's `_dredge_dash` rolls into a dummy 3 m out: `dash` in `content/vfx/dredge.json` is a gold ribbon trail on `ffc832` + `hot`, the orange orb puffs from code are gone, no ring or burst; `dash_hit` is a small gold flash + specks on the foe's near edge at the ball's crown (y 2.1, 0.3 s; lower it sits inside the ball), once per foe per shove; score stays 23: the camo ball still wears its orange opening rim (the model, a 3D job) and the X pink flecks and E fist are open); the X hit throws pink flecks (`scripts/arch/kits/dredge_blast.gd` hit sparks): coin gold |
| 5 | Lace | archer | 4 | 3 | 4 | 4 | 4 | 4 | 4 | 27 | re-scored 11-08 from strips (ext/vfx-archer, was 16): every thread, needle, trail and beam is orchid; tap/arrow ribbons 2-3x wider with a pale hot core, stuck and stitched threads hold at match zoom; Heavy Shot release layered (white core, orchid body flare, sweep, seam, sparks); new full-draw, release and arrow-hit sounds. Left: the Heavy Shot is still the big flat arrow (owner Nov 4) with a pale fletch rosette; the gold perfect-release cue stays gold (a timing signal) |
| 6 | Meeko | tender | 3 | 3 | 3 | 3 | 3 | 2 | 4 | 21 | re-scored 11-12 (was 17), tree = main + kindle numbers + zone rims + root field (the look-weight branch `ext/vfx-meeko-weight-rebased-rebased` conflicts and is not in it). Under the bar: `content/vfx/tender.json` palette: LMB orb is lilac `#c8a8ff` / pink `#f6a6c8` with a lilac ring, Hearthlight E ring is gold, and the Hearth Call dome rim is cyan: only the root field is leaf green; move orb, ring and dome rim to `#5fdc6a` slots (gold stays the heal accent); LMB hit is a thin ring (no debris layer: add a leaf-spark burst in the same file); Hearth Call (R) is a small pale bubble with a tiny ring, ~1 m across next to E's 7 m dome: scale it to the tether range |
| 7 | Sable | thief | 2 | 2 | 2 | 3 | 3 | 3 | 3 | 18 | LMB hits nearly invisible; held LMB is a flat unlit purple box; X is pale grey discs |
| 8 | Albert | bulwark | 3 | 3 | 2 | 3 | 3 | 2 | 4 | 20 | gold swing arcs read; dash dome is mint green; E is a flat gold box with dark cubes. 11-19 (ext/vfx-albert-dome): no mint dome is left on main: the dash is the ivory/gold 360 Smash ring and the mint Mending Ground column/disc (the strip's "dome") took his colour in 757e57fbb/3145b1f20; the last mint, the closing-burst and revive sparks (kit const `BjornFx.GREEN` 7dffb0), now uses his palette `ivory` from `content/vfx/bulwark.json`; `docs/shots/vfx-albert-dome/mend_burst_before_after.jpg` (reel part `mend`, grey = before, green = after) |
| 7 | Sable | thief | 2→3 | 2→3 | 2→3 | 3 | 3 | 3 | 3 | 18→21 | re-scored 11-19 for the LMB only (ext/vfx-sable-lmb, `docs/shots/vfx-sable-lmb/{lmb,hold}_{before,after}.jpg`, GPU jobq 20261119-224204-11098 / -224156-30303 before, -225651-13997 / -225704-30298 after): a bolt in flight is the spinning chakram over a short cel tracer (dark edge, violet body, hot core, about 0.8 m, the source's comet) where it was a flat 1.8 m violet slab; a tap hit is a ragged flare in her LMB slot colour, a lit crescent rim on her side, a cross flare and a spark spray (about 1 m, 0.16-0.28 s) where it was a 0.14 s star the strips mostly missed; held, the hits show in 4 of 9 frames (was 1). Left: X is pale grey discs, Encore/E a flat lavender wash (their own item) |
| 8 | Albert | bulwark | 3 | 3 | 2 | 3 | 3 | 2 | 4 | 20 | gold swing arcs read; dash dome is mint green; E is a flat gold box with dark cubes |
| 9 | Sparkle | mage | 3 | 3 | 3 | 3 | 3 | 4 | 3 | 22 | re-scored 11-11 (ext/vfx-sparkle-ult-local, was 20): the lightning body is pink-white on the hot pink core (no cyan left in `mage_*.gd`, her ability colours and the coilcaster rounds in content are pink); Kitefall draws only the range ring, no 14 m violet dome (the screen-wide purple), the look stays at the ring and the landing spot; strips: `--hero-vfx-reel --reel-hero=mage` jobq 20261111-154346-29635 (before, main) / 20261111-154229-09126 (after), queued, NOT seen yet |
| 10 | Neve | rimewright | 4 | 4 | 4 | 3 | 4 | 4 | 4 | 27 | reads well (shards, shatter burst). Done (ext/vfx-neve-ice-path): the skate's ice path was up to 24 pooled flat untextured boxes (a node and material each); now one MultiMesh strip (`IceStrip`, `shaders/ice_strip.gdshader`): cel-lit pale ice, a faint frost rim, a lighter facet step, a ragged cel fade at the tail; same plate size, form-in, spacing, 24-plate length and 3 s life. Left: the plates are still laid flat (no relief on slopes) |
| 11 | Cinder | ashwick | 4 | 4 | 4 | 4 | 4 | 4 | 4 | 28 | the bar: layered flame with a hot core. Palm glow while Cinder Shot is held done 11-20 (`palm_charge`: flare size, heat and a white-hot bloom build with the hold; `docs/shots/vfx-cinder-blade-glow/strip.png`, top before, bottom after); no polish left (the ground clipping is done: soft edges above) |
| 12 | Kael | juggernaut | 4 | 4 | 4 | 4 | 4→5 | 4 | 3→4 | 27→29 | the bar: slash arcs, burning lanes, debris. Done (ext/vfx-kael-polish): the X crescent is the strip's leading edge (was 4.3m across a 1.8m strip). Done (ext/sfx-kael-slash-edge): the LMB slash sound has a hard edge (snap, short shing, chop) on its contact at 0.08 s, 4-6 dB over the swish like the cleave's cut and about 4 dB under it in game; same 0.42 s, still on the press (was the swish alone, loudest at 0.22-0.27 s); the cleave sound's cut lands on the strike, sharp (was 84 ms late and 4 dB over its swish). Done (ext/vfx-kael-smash-lane): the Slam lane (4.3 x 0.72 m) and the Lunge lane are AimKit "soft" shapes in his #ff3a2a, drawn = hit (`docs/art/vfx_rescore/juggernaut_{lunge,slam}_before_after.jpg`). Done 11-25 (ext/vfx-kael-lunge-trail): the Lunge lane is a straight thrust (no arrow tip) whose rim stays crimson at full charge (was white-pale), and the dash and Lunge trails are a soft crimson streak ribbon (was a hard near-black ribbon); hit shapes unchanged (`docs/shots/vfx-kael-lunge-trail/{lunge,dash}_before_after.jpg`, top grey = main, bottom green = after; GPU reel jobs 20261125-183706-11528 / -183949-29013 lunge, -183719-28644 / -184002-18000 dash). Left: the shared `DashStreak` flat quad still lies under the ribbon on a dash (same for all 12 Hunters) |
| 13 | Gil | gil | 4 | 3 | 4 | 4 | 4 | 4 | 3 | 26 | scored 11-11 (ext/vfx-gil-bar, his reel `tools/vfx_reel/gil.gd`): every look is `content/vfx/gil.json` + keyed poses (`kmoves_gil.gd`); the slime puddle is a lit rim for exactly its slow. smoke fix 11-22 (ext/vfx-gil-smoke-ring, `docs/shots/vfx-gil-smoke-ring/bag_before_after.jpg`, GPU reel jobs 20261122-061030-31119 before, 20261122-061635-27429 after): the Air and Super Zeep breaks' smoke is a lit blue puff (`mark` over `wave`, `gain` 0.25 so alpha is 0.25 at most, fewer and smaller), the Air vortex and the Zeep flash read through it. Left: the held RMB landing ring was not reproduced in code: RMB is one press per throw, its circle is one AimKit entry per throw refreshed each step (the 0.1 s is AimDraw.KEEP, the refresh window), and its tell sound fires once on the first step, so no recipe `once` was needed (re-checked on the GPU `rmb` strip: one circle per throw, filling to the break, gone 0.1 s after it); score not changed here |

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

## Meeko and Albert ground rings (ext/vfx-gold-ground-rings)

Rule (DECISIONS, Movement and combat feel): a ground ring means gameplay (a hit area, a zone, a tether range). Kept rings
are in the Hunter's own colour (`content/archetypes` "color": Meeko `#5fdc6a`, Albert `#fff0b0`), never the shared gold,
so they do not read as each other's or as loot. Asserted in `--tender-combo-check` and `--bulwark-combo-check`.

| Hunter | Ring | Class | Now |
|---|---|---|---|
| Meeko | Burrseed wind-up glow, 1.4 m round her (violet, gold rim) | decoration (the dotted lane is the aim) | cut |
| Meeko | Kindle foot glow under a foe (violet to amber per stack) | decoration (a stack, not an area; the HUD reads n/5) | cut |
| Meeko | Burrseed disc under the foe, `burst_radius()` (violet) | gameplay, hit area | kept, violet (not gold) |
| Meeko | Hearthlight ring on her / thrown disc, 2.6 / 2.9 m (gold, teal rim) | gameplay, heal zone | kept, leaf green |
| Meeko | Hearthlight landing swirl (`hearth_land`) | decoration (the zone disc is already up) | cut |
| Meeko | Hearthlight last-heal swirl (`bloom`, gold) | gameplay, the burst's area | kept, leaf green |
| Meeko | Hearth Call reach ring 12.6 m, aim line, pick ring on the mate (gold, green) | gameplay, tether range and target | kept, leaf green |
| Meeko | Hearth Call ring 0.7 m on herself (`x_me`) | decoration | cut |
| Meeko | Hearth Call arrival swirls (`call_land`, `mended`, gold) | decoration (a heal marks no area) | cut |
| Albert | 360 Smash ring at the spin's hit radius, 2.2 m (red-gold) | gameplay, hit area | kept, his pale gold (net ring too) |
| Albert | Mending Ground column, filling ring, lasting disc, start and end pulses (heal green) | gameplay, zone | kept, his pale gold (net ring too) |
| Albert | Aegis push chevrons in front of the wall (gold) | gameplay, push reach | kept, his pale gold |
| Albert | Faultline remote rings at the near cell (ember, gold; 2.0 / 2.4 m circles on a 4 x 4.5 m lane) | decoration (the lane is the area and everyone sees it) | cut |
| Albert | LMB charge ring | not a ground ring: the cursor reticle | unchanged |

Not rings, left as they are: Albert's swing and slam crescents (`bulwark.json` `sweep`, ember to red; real hit
arcs; ext/vfx-albert-ivory-arcs already recolours them) and Meeko's violet Burrseed discs.

GPU strips (jobq rp1/pc, `--hero-vfx-reel`): docs/shots/vfx-gold-ground-rings/ (Hearthlight, the 360 Smash, Mending Ground).
Albert (bulwark), ext/vfx-albert-ivory-arcs: the LMB swing crescent, the Shield Slam fan and the held-swing whirl trail are
his ivory (`#fff0b0`, pale gold `#e8c96a`), no longer Kael's orange. The before/after strip is
`docs/art/vfx_rescore/bulwark_arcs_before_after.jpg` (jobq 20261111-213523-28011 before, 215537-24801 after, match zoom).
On the scorecard of ext/vfx-rescore his row moves 24 to 25 (C 3 to 4); the aegis plates still render orange-red.
Albert (bulwark), ext/vfx-albert-e-slab (row 8, "a flat gold box with dark cubes"; the box is his raised aegis, which
the generic reel and the 3v3 films showed during his E): the aegis plates are a lit slab in `bulwark.json` `slab`
(`#f6e3a8`, own light 0.3, ivory toon rim) and the top rim, ribs and boss in his ivory (`ivory`, Arch.color, light 0.9);
the dark edge pieces, the outlines and the rivet cubes are gone, the plated shape (owner 11-03) is kept. Mending Ground's
standing disc keeps to the ring rule: a lit ivory rim on the zone's edge, a soft falloff to 0.25 or less inside
(`swirl` `edge` 1, was brightest mid-band). Strips at match zoom (grey = main, green = after):
`docs/shots/vfx-albert-e-slab/{aegis,e}_before_after.jpg` (GPU jobq 20261120-031447-00628 / -032527-24137 aegis, -24307 / -26463 E). The dash dome colour is a separate item.
## Ground ring audit, the other 11 kits (ext/vfx-ground-ring-audit)

Same rule and method as the Meeko and Albert table above (DECISIONS: no bursts, rings or discs on dashes, landings or
resets; a ground ring means gameplay: a hit area, a zone, a range). Every `ring`, `vortex` and ground `scorch` layer in
`content/vfx/<kit>.json` and every `AimKit.circle`, `Fx.ring` or `net_ring` a kit script draws was read against what its
move does. Gameplay = it sits on a real hit area, zone, range or target pick. Decoration on a dash, landing, reset, payoff
or a cast with no area = cut. A fixed-size flash on a foe that was hit is hit feedback, not an area: kept, listed as
"hit flash" so the owner can say if those go too. `--hero-vfx-check` asserts the cut moves stay ring-free
(`_decor_rings`). Lace and Sable have no decorative ring: their circles are all areas.

| Kit | Ring or disc | Class | Now |
|---|---|---|---|
| Cinder | `flashover` ring, fixed 2.0 m on the foe (the Flashover payoff; the kit comment already kept payoff rings out) | decoration | cut |
| Cinder | `cloak` thin vortex pair at the blast radius `r` | gameplay, the cloak blast | kept |
| Cinder | cloak shield swirls up her body (`_shield_swirls`, one per foe caught) | gameplay, a count; on the body, not the ground | kept |
| Cinder | `lance_lick`, `shot_hit`, `ram_hit`, `flashover` scorch decals (0.8-1.4 m) | burn marks where a hit lands, not rings | kept |
| Grimble | `reel` ring on him while he reels (`_tick_looks` hold) | decoration, no area | cut (move and call) |
| Grimble | `anchor_slam` ring, fixed 1.8 m, 1.8 m ahead | decoration (the 110 degree cone is the area and keeps its scorch and arc) | cut |
| Grimble | `quake` outer ring at `r` | gameplay, the quake radius | kept |
| Grimble | `quake` inner ring at 0.6 r | decoration (a second ring, not an area) | cut |
| Grimble | `dive` thin ring at the landing spot, radius `quake_r`, and its `AimKit` circle | gameplay, where the fist lands | kept |
| Grimble | back-bonus ring on the foe, 0.9 m (`dredge_kit`) | hit flash (the cue that the back bonus landed) | kept |
| Gil | `dive` (Ground Swim) four rings at the head, 1.1 m and 3 x 0.85 m | decoration on a dash | cut |
| Gil | `tide_lunge` full-charge ring, 1.2 m ahead | decoration on a dash | cut |
| Gil | `wave_land` ring, 2.6 m (Tidal Wave landing: a shield, no hit) | decoration on a landing | cut |
| Gil | `beached` ring, 1.4 m on the foe (the Beach payoff) | decoration (a payoff; no area) | cut |
| Gil | `surface` ring at `dash.radius` (the dive's exit knocks foes up inside it) | gameplay, hit area | kept |
| Gil | `shatter_*` rings and the fire scorch at `r`; potion and slime aim circles | gameplay, the potion's area | kept |
| Gil | `lunge_hit` ring, 0.9 m | hit flash | kept |
| Vex | `e_fire` smoke ring at the palm, 1.3 m (a muzzle puff; the beam is the area) | decoration, cast with no area | cut |
| Vex | `x_impact` ring and scorch at `r`, countdown disc and burning patch (`gunslinger_ult`) | gameplay, ult area and zone | kept |
| Vex | `rmb_hit` ring at victim radius + 0.9 m | hit flash | kept |
| Kael | `slam_hit` ring, fixed 1.3 m, 1.6 m ahead (the slam's lane scorch is the area) | decoration on a landing | cut |
| Kael | LMB wave self ring, 1.35 m, filling with the hold (`AimKit.circle "wave"`; the charge reticle stays) | decoration, wind-up glow with no area (same call as Meeko's 1.4 m Burrseed glow) | cut |
| Kael | `drop_hit` ring and scorch at the shock radius, Meteor Drop disc (`drop_aim`, hidden on a dash) | gameplay, hit area | kept |
| Kael | execute rings on low-health foes, chain marker ring on the hooked foe | gameplay, target picks | kept |
| Sparkle | `e_strike` / `x_strike` ring and scorch at `r`; `x_dive` ring and `x_land` marker, `x_ring` range ring, Skycall rim | gameplay, true hit areas and range | kept |
| Sparkle | `orb_drop` ring at the pickup radius + 0.3 m, `dash_end` ring at `end_r` | gameplay, pickup range, dash blast | kept |
| Sparkle | `grounded` two rings round a foe's body (a status, vertical) | status marker, not a ground ring | kept |
| Sparkle | `rmb_hit` ring, fixed 2.2 m | hit flash | kept |
| Tenzo | `row_tell` scorch disc under each rising rock (the cobalt `AimKit` circle already shows the 0.75 m area) | decoration, wind-up glow | cut |
| Tenzo | `rock_burst`, `quakefall`, `spine_rock` scorch decals; `boulder_hit` ring at the splash radius; X rock-rise rings at `slow_r` | gameplay or ground cracks at a real hit | kept |
| Motley | `well_open` ring, `well_close` and `seed_pop` vortex at the area radius; swap and dash circles | gameplay, zone, seed area, trade range | kept |
| Motley | `orb_hit` ring (hot orbs only) | hit flash | kept |
| Neve | `rime` scorch, fixed 2.2 m under her at the X wind-up (the true radius is 7.5 m: the rink ring and `AimKit` "x") | decoration, wind-up glow at the wrong size | cut |
| Neve | `rime_melt` scorch, fixed 1.1 m under her when the crash ends | decoration, a reset | cut |
| Neve | `rime_crash` ring and scorch at `r`; `spear_land` / `spear_burst` scorch at `zone_r` / `r` | gameplay, hit area and zone | kept |
| Neve | `shatter` scorch, 1.6 m on the Shattered foe | hit decal | kept |
| Sable | Encore rings (`thief_ult`), Bola wrap rings on held foes (`thief_kit`: who is held) | gameplay | kept |
| Lace | no ring layer; the RMB bar, E arc wall and charge ring are aim previews | gameplay | kept |

GPU strips after the cut (`--hero-vfx-reel`, jobq 20261122-071231-04549 Cinder, -32049 Grimble, -23864 Gil, -29461 Vex,
-21003 Kael, -22995 Tenzo, -14895 Neve): `docs/shots/vfx-ground-ring-audit/` (Gil dash and Tidal
Wave, Grimble E and hook, Vex E, Kael slam and wave, Tenzo rocks, Neve R, Cinder E). No ring on the swim, the lunge, the
slam or the wind-ups; the kept area rings (Gil's surfacing, Kael's drop shock, Neve's rink) are still there. No before
strips were filmed: the cut layers are in the diff.

Net: 16 data layers (one whole move) and 2 code lines cut, none added. Sounds, timings and hit shapes are untouched.
Left for the owner: the "hit flash" rows (Gil lunge, Vex RMB, Sparkle RMB, Motley orb, Grimble back bonus) are
fixed-size flashes on a foe, not areas; the rule as written does not name hits, so they stay.

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
| Vex | gunslinger | 15 | 5 | 3 | 3 | 3 | 4 | 4 | 4 | **26** | was 25 (LMB / held LMB: a thin faint tracer): fixed on ext/vfx-vex-tracer-0246, see below. Left: Shift Slipstep, faint streaks and a flat band behind her |
| Tenzo | dolm | 14 | 3 | 3 | 3 | 3 | 4 | 4 | 3 | **23** | LMB punch and its hold: a tiny ember, the hold shows next to nothing |
| Motley | ostra | 14 | 3 | 4 | 4 | 3 | 3 | 4 | 3 | **24** | X: a near-black opaque disc over the target (breaks the zone rule, hides what it hits) |
| Grimble | dredge | 16 | 4 | 4 | 4 | 4 | 3 | 4 | 3 | **26** | was 25 (E / X wedges flat, no leading edge): fixed on ext/vfx-grimble-wedges, see below. Left: slugs small at match zoom; sound |
| Lace | archer | 16 | 4 | 3 | 4 | 3 | 4 | 4 | 3 | **25** | tap shots and misses: hair-thin trails (Heavy Shot and X read) |
| Meeko | tender | 17 | 4 | 3 | 4 | 3 | 4 | 4 | 4 | **26** | X root field: a pale flat teal disc, only its centre burst is layered (11-20, ext/vfx-meeko-heal-hurt: heals leaf green rising, hurts embers falling, Hearthlight / root field inside at most 0.25 to the rim, bloom a rim swirl; not re-scored) |
| Sable | thief | 18 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | X Encore and E: flat pale lavender wash over the area, no rim or debris |
| Albert | bulwark | 20 | 4 | 4 | 3 | 3 | 3 | 3 | 4 | **24** | LMB / RMB swing arcs still hot orange, not ivory (Kael's colour) |
| Sparkle | mage | 20 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | Grounded's flat orange disc on the target (LMB finger bolt fixed 11-22, ext/vfx-sparkle-bolt: a hot pink body ~0.75 m wide with a white core and a short 1.8 m tail, `content/vfx/mage.json` `lmb_trail`; strip `docs/shots/vfx-sparkle-bolt/lmb_before_after.jpg`, jobq 20261122-085823-02083 before / 20261122-091902-07818 after, `--hero-vfx-reel --reel-hero=mage --reel-only=lmb`; grey = main, green = better; not re-scored) |
| Sparkle | mage | 20 | 4 | 3 | 3 | 3 | 4 | 4 | 3 | **24** | LMB finger bolt: thin; Grounded fixed 11-22 (ext/vfx-sparkle-grounded): two thin pink binding rings round the target, one dashed, seen by all (`MageSky._tick_bound`, the Bola's look without a filled disc), and the shared cords and arrow in the caster's colour (`KitStatus` meta `gnd_by` from the `kst` caster nid, `StatusLooks._tint`; Bola and Warchain stay amber); before/after `docs/shots/vfx-sparkle-grounded/grounded_before_after.jpg` |
| Neve | rimewright | 26 | 4 | 4 | 3 | 3 | 3 | 4 | 4 | **25** | X Rimelock veil confined to the 7.47 m rink (fixed 11-25, ext/vfx-neve-veil: clear middle, lit rim, thin outer cracks; not re-scored); dash path was flat grey tiles (since textured, ext/vfx-neve-ice-path) |
| Kael | juggernaut | 27 | 4 | 4 | 4 | 4 | 5 | 4 | 3 | **28** | Smash lunge telegraph: a flat magenta box, off his crimson |
| Cinder | ashwick | 28 | 4 | 4 | 4 | 4 | 5 | 4 | 4 | **29** | RMB Ignite orb: blue-violet and magenta, not flame |

Reading it: every Hunter now sits at 23-29 (the 11-08 spread was 14-28), and the old worst four (Tenzo, Motley, Vex,
Grimble) gained 9-10 each. The per-hero branches claimed a little more for their own hero (Vex 26, Lace 27, Sparkle 26,
Cinder 30, Kael 29); scoring all twelve from the strips with one hand puts them 1-2 lower. Neve went down one point
(26 to 25): her Rimelock X reads as a screen-wide wash next to the others.

Parity rule (DECISIONS: match the source's readability and polish, no explosions on dashes, a ground ring means
gameplay): no Hunter's dash plays an explosion in these strips. Ground rings worth a check against a hitbox: Vex's
Shift (ring plus lane), Tenzo's X rings, Neve's dash path. Not checked against a hitbox here.

### Vex's rounds (ext/vfx-vex-tracer-0246, 2026-11-11): 25 -> 26
Each rifle round, tapped or held, rides a tracer 0.34 m across at its head: her 0.3 m hit width (`HITBOX_SIZE.md`)
plus a rim. It was 0.18 m, with 0.08 m of it visible. A hot pale-lime core line runs down most of its length, the body
is her lime (`color`), a deep green rim holds it on sand, and the back 60% fades out in cel steps. The length stays
2.6 m (about 1.5 bh, the footage's long thin yellow-green bolts). The muzzle star is lime with a pale core, 0.8 m for
0.08 s, on the Gun's Muzzle (the rifle's mouth; it used to sit out on the round). The rifle's data colour (the shared
muzzle flash and the end bursts) and her end sparks are lime too. Nothing new is built per shot: one pooled tracer and
one pooled star per round, as before (`--gunslinger-combo-check` asserts that a second held string makes no nodes).
The VVFx tracer mode draws these layers only when it is given an edge colour, so smears and hand trails (Sparkle's
too) are unchanged. R 4 -> 5: the LMB and hold paths read at match zoom in their first frame; the other axes stand.
Strips: `docs/art/vfx_rescore/gunslinger_rounds.jpg`, before on the left (origin/main + the 0.24.6 audio-vfx line)
and after on the right. They show the full-range LMB frame (`--vv-shots --vv-hero=gunslinger --vv-only=lmb`) and the
reel's lmb and hold sheets. They were rendered with the compat renderer (opengl3 under Xvfb, 1280x720): the GPU after
reel could not be sent (the jobq relay failed to copy the tree four times), and the GPU before reel (jobq
`20261111-213003-09415`) was still queued. The reel's dummy stands 4.5 m off, so its frames mostly catch a round at
the muzzle or on the dummy. The full-range frame is where the tracer shows.
On this line alone her RMB, Shift, E and X are still the ember-orange VVFx looks. ext/vfx-vex-data (READY, on no
train) moves them to green fire and replaces this tracer with a HeroVfx ribbon; when it merges, keep this look in its
`shot_trail` (one ribbon 0.34 m: body `main`, rim `deep`, core `hot`).

## Backlog (remaining fixes, from the table)
1. Motley X: soften the black disc to a lit rim plus a soft inside (alpha 0.25 or less at the centre).
2. Neve X: done 11-25 (ext/vfx-neve-veil); the dash path tiles are textured (ext/vfx-neve-ice-path).
3. Vex LMB and hold: a wider, brighter tracer at match zoom. Done (ext/vfx-vex-tracer-0246, "Vex's rounds" above).
4. Tenzo LMB and hold: a bigger punch and a visible charge for the hold.
5. Albert: ivory swing arcs for LMB/RMB.
6. Kael: crimson Smash telegraph instead of the flat magenta box.
7. Cinder: flame-coloured Ignite orb.
8. Meeko, Sable: zones as a lit rim over a faint inside (X root field, Encore/E). Grimble's wedges are done (below).
9. Lace tap shots and Sparkle LMB: thicker trails.
10. Merge-time fixes: the `HeroVfx` mode 8 clash (`chain` vs `dome`) and the duplicate `shine` shader name.

### Grimble wedges (ext/vfx-grimble-wedges, 2026-11-22): 25 -> 26
The scorecard's "RMB wedge" is his X fan (his RMB is the Abyssal Hand, a reach with no wedge). Both wedges now use
AimKit's `soft` cone, the lit-rim language main uses for zones: a faint inside (never above 0.25 alpha), a lit
coin-gold (#ffc832, `HeroVfx` colour `gold` in `content/vfx/dredge.json`) rim on the exact edge and arc, and a
bright front that sweeps out to the rim with the hit. E: the wind-up's front is the charge (`slam_tell(k)`, fill k),
so it reaches the rim on the slam frame; the slam flashes the rim hot (`e_hit`). It was a thin seafoam outline with
no fill. X: the charge fan is the same wedge (front = the charge); each wave's front runs out to the rim in the
slugs' flight time (`(range - MUZZLE) / speed`, about 0.17 s) and holds lit 0.25 s (`DredgeBlast._wave_front`);
it was two edge lines. The wedges are the hit cones (`e.radius`/`e.angle`, `x.range`/`x.fan_deg`); hit shapes are
unchanged (`--hit-shape-check` Grimble rows). Timing 3 -> 4. Strips at match zoom, top before / bottom after, GPU
reels (`--reel-only=e|r`): `docs/shots/vfx-grimble-wedges/e_before_after.jpg`, `r_before_after.jpg`.
## Foe telegraphs audit (ext/combat-foe-telegraphs, 2026-11-20)
Stabilize sprint, combat clarity: does a rival see a cue before each hit, in the rival's colour, for the whole wind-up?
Measured headless on a flat strip with a rival dummy 4 m ahead (every slot of the 13 kits cast once; first/last tick an
AimKit entry with `all` is up, first damage, the HeroVfx moments played, the colour a rival's view draws). The ground
cue is AimKit's (`all`: a rival's is leaned 45% toward `SideColor.rim()` #ff2d55, hue 349 deg); the body cue is the
kit's `content/vfx/<arch>.json` moment, which stays in the Hunter's palette (a ground ring there would mean gameplay:
none added). Delayed-hit lead, no gap and rival lean stay asserted by `--telegraph-lead-check` (64 checks, 0 failed).
Strips from `--hero-vfx-reel`: `docs/shots/combat-foe-telegraphs/` (own view, match camera, xvfb opengl3).

| Ability | Wind-up to hit (s) | Ground cue a rival sees (s up) | Rival-view hue | Body cue (vfx json) | Verdict |
|---|---|---|---|---|---|
| Kael Finishing Slam (RMB) | 0.67 | lane 0.08-0.65 | 357 | `slam_tell` ribbon, `slam_wind` held | ok |
| Kael Lunge (RMB hold) | 2.0 charge, hit 2.18 | none: the lane is his own aim lane (no `all`) | | `lunge_charge` held 0.32-2.03, red, whine | body cue only (see below) |
| Kael Gilded Riposte (X) | 0.65 guard, hit 0.77 | lane 0.02-0.63 | 20 | `guard_tell` gold | ok |
| Kael Meteor Drop | 0.22 | circle to the hit | | `drop_tell` sound | ok (kept short, TELEGRAPH_LEAD.md) |
| Albert Faultline (X) | first hit 0.42 | lane 0.02-1.57 | 9 | none needed | ok |
| Albert charged swing (LMB hold) | hold, perfect at 0.8 | none: the whirling hammer and its glint (BjornFx) are the tell | | `charge` held, `full` flash | ok, body only |
| Tenzo Stone Row ridge (E) | 0.20 | `e_tell` discs 0.00-0.20 | 279 | `row_tell` scorch 0.9 | ok on lead; hue is violet (see below) |
| Tenzo Quakefall (RMB hold) | 1.37 | ring 0.22-1.35 | 282 | `slam_charge` held | ok |
| Tenzo Basalt Spine (X) | 0.25 | cracks 0.03-0.22 | 279 | `spine_crack` | ok |
| Sparkle Skycall (E) | 0.82 | ring 0.02-0.90 | 335 | `e` | ok |
| Sparkle Eye of the Storm (X) | 2.53 | ring 0.02-2.42, landing mark 2.32-2.52 | 335 | `x_ring` held | ok |
| Motley Nightwell (X) | 1.02 | dome 0.02-0.98 | 349 | `well_open` | ok |
| Motley Brimseed (E) | recast | disc up the whole cast | 347 | | ok |
| Neve Ice Spear (RMB) | zone 1.8 from the landing | disc 0.32-2.10 | 347 | `spear_burst` | ok |
| Neve Rime Wall (E) | 0.50 | lane 0.00-0.48 | 344 | `wall_tell` 0.25 flash | ok |
| Meeko Burrseed (RMB) | 0.70 | disc 0.70-2.68 | 18 | `seed_field` | ok |
| Sable Shiv ult (X) | 0.55 | rings 0.02-2.40 | 318 | | ok |
| Lace Hail Wall (E) | 0.38 | arc 0.00-0.35 | 352 | | ok |
| Vex Rail Cone (E) | 0.63 | cone 0.02-0.62 | 34 | `e_charge` held, lime | ok |
| Vex Nuke (X) | 1.62 | disc 0.02-1.60 | 33 | `x_cast`, `x_shell` | ok |
| Grimble Anchor Slam (E) | 0.38 | ring 0.02-0.37 | 25 | `anchor_fist` | ok |
| Grimble fan (X) | 1.17 | fan 0.02-1.97 | 20 | | ok |
| Gil potions, Tidal Wave | flight / ride | circle or lane from the throw | 345-350 | | ok |
| Cinder | none: Furnace Cloak fires on the press | ring 0.00-0.17 | 7 | `cloak_gather` | no delayed hit |

Result: every telegraphed ability with a ground cue has it up from the press to the hit with no gap, and every wind-up
with a body cue holds it (a `H:` hold) for the whole wind-up. No `content/vfx` stray was found, so no data file changed.
Left for the owner (each needs a code or design change, not a json fix, and adds a foe-visible element):
- Kael's Lunge lane is private: a rival sees the red embers and hears the whine for 2 s but no lane. Showing it to
  rivals is a new foe element (the drawn lane is already in his crimson, `docs/shots/combat-foe-telegraphs/juggernaut_lunge.jpg`).
- The rival lean is one global share (`SideColor.FX_FOE_K` 0.45), so a rival sees Tenzo's cobalt as violet (hue 280),
  and Vex, Meeko, Grimble and Kael's X as orange (18-34). Reads as hostile by its rim and ground order, but not red.
  Raising the share is a policy change for every Hunter.
Pre-existing reds on main at 0b0b680df2, not from this branch: `--hero-vfx-check` 1 failed (Vex LMB rounds 0.154 m
from the forearm, limit 0.15 m); `tools/health.py --strict` style ratchet (hud_hover.gd, ability_text_check.gd,
check_registry.gd long lines).
