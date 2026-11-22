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
- Zone rule (seen in the strips): a zone is a lit rim plus a soft inside (alpha 0.25 or less at the centre), never a solid fill. Vex's X, Albert's Faultline, Sable's RMB lane and Gil's lanes still break it (follow-ups above).

## Scorecard (re-scored 2026-11-22, worst first)
Rubric, each axis 1-5: R readability, S shape, L layering, T timing, Sc scale, C colour (against the Hunter's current
signature colour above), Snd sound. One hand scored all 13 from the 11-22 strips above. Snd is carried from the earlier
code read (the strips are silent). The worker's ground renders yellow, so read colours against that.

| # | Hunter | arch | R | S | L | T | Sc | C | Snd | total | was | what the strips show |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 | Albert | bulwark | 3 | 4 | 3 | 3 | 3 | 3 | 4 | 23 | 24 | Faultline (R): the lane is a screen-wide pale cream slab with a lightning crack, it hides the ground and the foe; the 360 Smash ring (Shift) is amber/orange, not ivory; swing and shield-charge crescents are gold/ivory and read |
| 2 | Grimble | dredge | 4 | 3 | 3 | 3 | 4 | 3 | 3 | 23 | 25 | E: flat translucent orange hex slabs, the palette `main` is copper `d89040`, not coin gold; LMB slugs small; hook, dash ribbon and X fan read |
| 3 | Vex | gunslinger | 3 | 3 | 3 | 3 | 4 | 4 | 4 | 24 | 25 | X Nuke: the zone ends as a near-opaque dark green disc that hides the foe; E cone is a flat pale lime band; LMB tracer is a short lime dart (reads) |
| 4 | Sable | thief | 4 | 3 | 3 | 3 | 4 | 4 | 3 | 24 | 24 | RMB Bola wind-up lane: a flat lavender slab; LMB bolt and hit now read, X rings are lit rims and read |
| 5 | Sparkle | mage | 4 | 3 | 3 | 3 | 4 | 4 | 3 | 24 | 24 | E Skycall: a big white blob over a brown disc hides the foe for 3 frames; RMB orb sits in an orange haze (off pink); LMB bolt thin; X dome is a pink rim and reads |
| 6 | Meeko | tender | 4 | 3 | 3 | 3 | 4 | 3 | 4 | 24 | 26 | LMB orb is orange with a gold ring (not leaf green); E ring is a thick flat green band; Hearth Call tether and heal rise read |
| 7 | Lace | archer | 3 | 3 | 3 | 4 | 4 | 4 | 4 | 25 | 25 | tap shots and misses: thin faint red lines at match zoom; Heavy Shot and X are layered and read |
| 8 | Neve | rimewright | 4 | 3 | 4 | 3 | 3 | 4 | 4 | 25 | 25 | X Rimelock: no longer one cyan screen, but a grey-cyan veil with ice cracks still covers the whole frame for 0.4 s; dash plates read as ice |
| 9 | Tenzo | dolm | 4 | 3 | 4 | 3 | 4 | 4 | 3 | 25 | 23 | cobalt lane, rings and Rockfall slam layered; boulder is blue slate with rune-teal; dust is thin now. LMB punch has no own part in his reel |
| 10 | Gil | gil | 4 | 3 | 3 | 3 | 4 | 4 | 4 | 25 | 26 | E and dash lanes are flat translucent rectangles with a hard edge; puddle rim, splash and wave read |
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
1. Albert, `scripts/arch/kits/bjorn_ult.gd`: the Faultline lane is a screen-wide pale slab that hides the ground and the foe; make it a lit rim plus a soft inside. Also the 360 Smash ring (`spin` in `content/vfx/bulwark.json`) is amber, not ivory.
2. Grimble, `content/vfx/dredge.json`: the E fist/wedge slabs are flat translucent orange because palette `main` is copper `d89040`; move `main` to coin gold `#ffc832` and give the slab a lit rim.
3. Vex, `content/vfx/gunslinger.json` `x_shell` / X zone end: the Nuke ends as a near-opaque dark green disc over the foe; cap the inside alpha at 0.25 and keep the lit rim.
4. Sable, `scripts/arch/kits/thief_kit.gd` (RMB Bola wind-up lane): a flat lavender slab; use the `soft` AimKit lane (lit rim, inside at most 0.1).
5. Sparkle, `scripts/arch/kits/mage_sky.gd` (E Skycall): a white blob over a brown disc hides the foe; thin it to a pink-white column on a soft rim. The RMB orb's orange haze (`mage_gum.gd`) goes pink too.

Next in line (24-25, smaller): Meeko LMB orb palette (`content/vfx/tender.json`), Lace's deep red against Kael's crimson (owner's call), Neve's X veil, Lace/Sparkle thin tap trails.

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
