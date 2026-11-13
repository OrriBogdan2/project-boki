# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07)

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only for the first audit; the ranges table below changed four numbers (data only).

**How to read a verdict.** `match`: same mechanic, within footage error. `differ`: built, not the same (says how). `missing`: not built. `differ (owner)`: an owner note overrides the source, so it stays unless the owner reverses it; not a gap. `ours`: not in the source at all.

**Evidence:** [D] game data (supervive_kits.md, supervive_physics.md), [F] footage (briefs/hero-ref), [O] owner note. Order of trust: O > D > wiki > F. Source references live only on `origin/ext/agent-briefs` (briefs/supervive-data, briefs/hero-ref, briefs/specs/kit-audit).

**What was and was not verified.**
- Numbers, modes and code paths were read from main. The Nov 3 audit (briefs/specs/kit-audit) is stale: many of its gaps are closed, and rows here were re-checked against main before use. `ext/online-displace` and `ext/no-shake` are merged, so the online pull bug and self-shake are closed.
- All 12 `--<hero>-combo-check` runs pass: 1,560 PASS, 0 FAIL. They assert our spec, not the source, so a pass is not parity proof.
- **Animation timing was not re-measured frame by frame.** Animation rows report clip coverage (computed from kit code, `warden_anim/*.json` and each GLB) plus timings already recorded in docs/heroes. Hitbox rows use content numbers; the in-game hit shapes of Vex, Kael, Lace and Cinder were then measured and shot with the hitbox circles (section "Hit shapes in game"), the other eight were not.
- `[?]` marks a row carried from a hero doc that I could not settle from code here.

**Every Hunter, shared:**
- **Q:** ours (a glove, gear slot, with V). Not in the source, so no parity target. DashFlow fires it through dashes.
- **Keys:** R = hunter ult (JSON slot `x`), X = Fuse, G = Boki (owner).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4.
- **Buffer:** `DashFlow.BUFFER_S` 0.15 s past a dash's end; the data gives no window.
- **Cooldowns below** read ours / source level 1 [D].

## Ranges and radii: RMB, E, R (main d255acbee, 2026-11-10)

Source = `briefs/supervive-data/supervive_kits.md` (the tooltips carry no range numbers, so only the Black Hole radius, 350/500 uu = 3.5/5.0 m, is data) plus the footage measures in `briefs/hero-ref` (1 body height = 1.8 m; a later per-ultimate re-measure wins over the first sheet). Ours = `content/archetypes/<id>.json`, metres. The aim indicator and the hit read the same JSON field for every row below; the Bola lane is drawn at the width the hit reaches (0.45 + body radius per side). **fixed** = changed here and asserted in `--kit-parity-check`. `[?]` = not measurable from the source, or an owner note stands.

| Hero | Slot, number | Ours | Source | Verdict |
|---|---|---|---|---|
| Vex | RMB range, cone, lane | 10.5, 6 m at 100, 0.72 | 5-6 bh (9-10.8), 3.5 bh at 100, 0.4 bh | match |
| Vex | E range, beam width | 18, 1.8 | 10+ bh (18+), beam 0.5 bh (0.9) | range match; width differs (owner item 68 widened it) |
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range **Not determinable**: Mini Nuke frames f29-f45 (dummy ~5 bh = 9 m away) and f95-f111 (empty ground) land at the cursor, and no cast was made at the cursor's maximum, so 14 stays |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | reach match; angle **Not determinable**: the one slam (frames 0154-0158) hit a dummy dead centre at 2.4 bh, no foe off-centre, so neither a cone nor a lane can be told apart; 70 stays |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) |
| Kael | RMB air slam disc, reach | **2.2** (was 2.6), 5 | 1.2 bh (2.16), cursor to ~5 | **fixed** |
| Kael | RMB chain spin radius | **2.2** (was 2.6) | 1.2 bh (2.16) | **fixed** |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not determinable (no clip pays out past the throw) | range match; tether max **not determinable**, 24 m ours (clips: docs/heroes/juggernaut.md "Tether length") |
| Kael | R strip | 3.6 x 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | **Not determinable**: the only miss (frame 0133) ended at 6.5 bh (11.7 m), short of 14 m, so a cursor clamp and a 14 m cap both fit; 14 stays |
| Cinder | E radius | 4.5 | 2.5 bh (4.5) | match |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2) | match, burst locked: the sheet reads the disc as the burst area and the 1.8 bh (3.2) flare as the trigger VFX; one target only, so nothing shows a wider hit |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach not determinable: every throw lands on the cursor, no clamp is reached (sheet open question) |
| Meeko | R range | 12.6 | tether ring 7 bh (12.6) | match |
| Tenzo | RMB radius, core | 4.5 (3.82 tap), 0.9-1.8 | 2.5 bh (4.5), 0.5-1 bh | match |
| Tenzo | E ahead, span | 3.4, 5 | 2 bh (3.6), 3 bh (5.4) | match |
| Tenzo | R ridge length, cast range | 12, 11 | 10-12 bh (18-21.6), - | differ ~40%, kept: f2b60dc70 narrowed it 19.8 to 12 on purpose, no DECISIONS line either way; [?] |
| Tenzo | Passive cone length (Tremor Sense, sneaking) | 18 growing to 25 over the 2 s `grow` that widens it 25 to 40 deg (`passive.len`, `len_max`) | 10-14 bh (18-25), lengthens with the hold (breah.md 0693-0725); closes dolm.md row 9 | match |
| Grimble | RMB range | 11.5 | 6-7 bh (10.8-12.6) | match |
| Grimble | E depth, angle | 3.0, 110 | 1.5 bh deep x 2 bh wide (2.7 x 3.6), a box | depth match, locked; angle not determinable: the source hit box is a rectangle, not a sector (ours 8.6 m², the box 9.7 m²) |
| Grimble | R fan, depth | 105, 5.9 | 100-110, 3.3 bh (5.9) | match |
| Neve | RMB range, zone, burst | 12, 2.2, 2.7 | lands at the cursor, zone 1.2 h (2.16), dome 1.5 h (2.7) | zone, burst match, locked; range not determinable: it lands on the cursor and no clamp is reached (owner: travel time grows with distance) |
| Neve | E width, slide | 1.8 to 4.5, 4.5 m/s to 16.2 | 1 h to 2.5 h (1.8-4.5), 6 h in 2.4 s (4.5 m/s) | width, speed match, locked; slide length not determinable: one slide seen (6 h), stop rule unknown (sheet open question) |
| Neve | R rink radius | 7.2 | 4 bh (7.2) | match |
| Motley | RMB range | 13 | hit after about 3 h; bundle crosses 6 h (10.8) in a frame, max not seen | not determinable: no miss to max range in the clip (sheet open question) |
| Motley | E seed radius | 3.2 | 1.8 h (3.2) | match |
| Motley | R radius, range | 3.6 / 5.1 swollen, 10 | 350 / 500 uu (3.5 / 5.0), cast 2-3 bh away | radius match; range not determinable: cast only on a near dummy, the clamp is never reached |
| Albert | RMB aegis, slam | 4.2 at 140, 2.6 at 100 | slab 2.2 h wide (4.0), no slam in the kit | aegis match; slam not determinable: the source has no slam (its only knock is the Empower Shield Bash augment, unmeasured), and DECISIONS 2026-11-07 cuts the Shield Slam (left to the owner) |
| Albert | E zone radius | **2.3** (was 3.5) | green disc 1.3 h (2.34) | **fixed** |
| Albert | R lane | 16 x 4.5 | 9 bh x 2.5 bh (16.2 x 4.5) | match |
| Sparkle | RMB range | 13 | 7.5 bh (13.5) | match |
| Sparkle | E radius, reach, slide | 1.5, 11, 3.4 | circle ~2 bh across (radius 1.8), -, ~4 bh (7.2) | differ 17% and 53%, kept: mage.md set 1.5 as the hit on purpose; [?] |
| Sparkle | R radius, range | 2.7, 14.4 | ring 1.5 bh (2.7), 8 bh | match |
| Sable | RMB range, lane | 7 + 3.8, **1.8 wide** (was 1.4) | lane 5.5-6 bh (9.9-10.8), 1 bh wide (1.8) | **fixed** (width) |
| Sable | E range | **16.2** (was 14) | no-target dagger landed about 9 bh out (16.2) | **fixed**: 14 could not reach the landing seen; 16.2 is the least range that does, max not seen |
| Sable | R ring | 5.4 (rim band outer 25%) | 3 bh (5.4); the first sheet's 3.5 bh is superseded | match |

Second pass (2026-11-11): the open Meeko, Grimble, Neve, Motley, Albert and Sable rows above are settled or marked not determinable from the hero-ref sheet measures (the frames behind them, 1 bh = 1.8 m); settled numbers are locked in `content/rules/kit_parity.json`.

Left alone and why, for the owner: Kael lunge (owner), Vex needle width (owner item 68), Cinder flight (owner item 20), Tenzo ridge (deliberate narrowing, source 10-12 bh), Sparkle Skycall circle (deliberate). Ideas of ours stay out of the build.

## Hit shapes in game: Vex, Kael, Lace, Cinder (main 88b06b9e7, 2026-11-12)

How: `--hit-shape-fine` (tools/hit_shape_fine.gd) fires each input of the four hunters at ONE training dummy moved around, in a match stepped at the game's 60 Hz, level 6 (rank 3 numbers apply): a scan along the aim line gives the nearest and farthest foe centre that still takes damage, a scan across the middle gives the lane, a scan round it the arc; the numbers below have the foe's circle taken off. `--hit-shape-shots` (tools/hit_shape_shots.gd) fires the same inputs at a field of dummies, each wearing its ground circle (its hitbox), at the gameplay camera: strips in `docs/shots/verify-hitbox-slice/`. Ours = `content/archetypes/<id>.json`; source = `briefs/supervive-data/supervive_kits.md` (no sizes) and the footage sheets in `briefs/hero-ref` (1 bh = 1.8 m).

What the game does with a number (so a row reads straight): areas (cone, ring, strip, disc, lane of a beam) take a foe in when its body circle, 0.40 m, touches them, so measured = content to 0.15 m. Bullets, hooks and swing rays take it in at body circle + 0.08 m + their own radius; a bullet starts 0.6 m ahead of the hunter and lives to the end of the 1/60 s step in which its range runs out (74 m/s: +1.2 m, 90 m/s: +1.5 m); a swing is a fan of 7 or 9 such rays 0.22 m wide, so its arc reads about 30 degrees wider than the drawn one (175 reads 206).

| Hero | Move | Ours | Measured in game | Source | Verdict |
|---|---|---|---|---|---|
| Vex | LMB rifle | range 11, bullet 0.13 | reach 11.9, lane 0.24 (11 + 0.13 + 0.6 start, then the step) | no number; tracers ~1.5 bh, reach not seen | match; source gap |
| Vex | RMB Burr | range 10.5, lane 0.72, cone 6 at 100 deg | lane reach 11.1, cone flank 6.1 from the stick point; angle not isolated (a lone foe leaves the cone by its length first) | 5-6 bh (9-10.8), 0.4 bh (0.72), cone 3.5 bh at 100 | match |
| Vex | E Longneedle | range 18, beam 1.8 wide (JSON `width` 0.9 is the half) | reach 18.0, lane 1.8 | 10+ bh (18+), 0.5 bh (0.9) thick | match; width 2x source (owner item 68) |
| Vex | R Cinderfall | range 14, radius 3.4 | disc centre 14.0 (cursor clamped), radius 3.4 | clamp not seen, disc 1.8-2 bh (3.2-3.6) | match; clamp [?] |
| Kael | LMB sword | reach 3.1, arc 175 | reach 3.7, arc of centres 206 (ray 0.22 + circle) | ~180 deg, radius 1.8 bh (3.2) | match (-4%, -3%) |
| Kael | LMB hold, Searing Wave | range 7 to 14, size 0.3 to 0.6, 36 m/s | full charge: reach 14.4, lane 1.14 | flies 20 bh/s (36), reach no number | match; reach gap |
| Kael | RMB tap, Smash | radius 4, 70 deg | reach 4.0, angle 70 | 2.4 bh (4.3), a lane not a cone | match; angle and lane width [?] |
| Kael | RMB hold, Lunge | 4.5 to 7.5 | full charge: reaches 8.6 with the body (7.5 + circles) | 5 flat | differ (owner: release flings far) |
| Kael | E Warchain | range 13 | reach 14.2 (13 + hook + step), lane 0.44 | 7 bh (12.6) | match |
| Kael | R Riposte | strip 3.6 x 1.8 from where he planted | length 3.6, width 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match; the drawn lane and the hit read one field |
| Lace | LMB, Empowered | range 12, arrow 0.18 | reach 13.7 (12 + 0.2 + 0.6 start + step) | lands at the cursor, ~6 bh (10.8) seen | match |
| Lace | LMB, Supercharged | range 16 | reach 18.1 | no number | match; source gap |
| Lace | RMB Heavy Shot | 14 (+3 at rank 3), size 0.3 | reach 18.5 at rank 3 (17 + 0.6 + step) | gold bar ~2 bh while held; range not seen | match; range [?] |
| Lace | E Hail Wall | reach 9, 120 deg, 1.8 deep | wall centre 9.0, arc 125 | 120 deg, centre at the cursor (8-10.8) | match |
| Lace | R Starpiercer | range 18, width 0.5 | reach 20.4 (18 + 0.6 + 1.5 step), lane 0.5 | ~1.5x normal range (1.5 x 12 = 18) | match |
| Cinder | LMB flame | range 6.1, width 0.65 to 2.85 | reach 6.8, fan 1.8 wide at 4 m (2.8 in foe centres) | ~4 bh (7.2) whatever the cursor; 0.3 bh to 1-1.5 bh wide | match; reach -15% to source |
| Cinder | RMB Cinder Shot | range 14, size 0.3 | reach 13.9 | flew 6-8 bh (10.8-14.4); a miss ended at the cursor (11.7) | match; always-full-range vs ends at cursor [?] |
| Cinder | E Furnace Cloak | radius 4.5 | radius 4.5 | 2.5 bh (4.5) | match |
| Cinder | R Flue Flight | 12.6 m/s for 1.8 s, carpet 1.8 | carpet along the whole 22 m, lane 1.8 | 7 bh/s (12.6) for 1.3-1.4 s (16-18), carpet 1 bh | match; flight 26-40% longer (owner item 20) |

**Result:** 20 moves, no plain mismatch between what the game draws, what it hits and what the content says, so no kit was changed. The follow-ups are all source gaps:
1. Kael's sword has two numbers: `greatsword.json` says range 3.4, arc 160, the kit draws and hits `lmb` reach 3.1, arc 175 (the first is what `--hit-shape-check` and HITBOX_SIZE.md read; it also feeds bot range). One of them should go.
2. Cinder's flame is 6.1 m against the footage's 4 bh (7.2); the far end is 2.85 wide against 1.8-2.7.
3. Cinder Shot always flies 14 m; the footage shows a miss ending at the cursor (11.7 m) once, with no clamp read. The card says "long-range".
4. Open source numbers, nothing to compare yet: Vex R range clamp, Kael slam lane width and wave range, Lace Supercharged and Heavy Shot max range, the Hail Wall depth.
5. Already filed above for the owner: Kael lunge, Vex needle width, Cinder flight.
6. The coarse `--hit-shape-check` reads swings and cones short (a ray stops at the first dummy of the grid, 20 Hz steps): Kael LMB there is 1.6 m / 113 deg against 3.7 / 206 here. Use `--hit-shape-fine` for those four heroes' areas.

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.08 (~12 rounds/s, docs/WEAPON_FIRING_DATA.md; was 0.12 until fun audit 11-11), mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, dmg 24 (the source's 0.157 of a target; 36 until 11-11), recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +76% rifle (the source's +39 on 51; the ours-only pause of the string's falloff on a Dazed foe is gone) | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |

## Zedran (`juggernaut`, source Brall) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash **not determinable** (no data; no clip pays the chain out past its throw, 11-11; 24 m kept) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match; kill reset settled: a hunter taken down by the cleave (docs/KNOCK_RESETS.md) |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) |

## Hem (`archer`, source Myth) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) |
| Q | none | glove | ours |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 |

## Cinder (`ashwick`, source Felix) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3 | match; 0.78x cd |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41) | match on coverage |

## Pip (`tender`, source Elluna)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered = cue only (no range, no refund) | match; Empowered effect is not in the source, our rider removed |
| RMB | Shot, delayed Root, 11.5 s [D] | Hop form, windup 1.0, cd 10.5 | differ `[?]` motion |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, no self factor | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D]; ally pass refunds half the cd + 1 s E only on the footage card's Super (older build), absent at every rank in [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner); no ally refund | match; ally refund `[?]` (tender.md "Ally-pass refund") |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45) | match on coverage |

## Tarek (`dolm`, source Tetra)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Tap boulder; hold punch launches rocks, .6 s [D] | Boulder .6, punch .7/.6 | match |
| RMB | Hold slam, centre stun, jump to leap, 11 s [D] | hold .2, cd 11, glide slam built and checked per glide state | match |
| Q | none | glove | ours |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; **no ally hop** | missing: ally hop (gap 14) |
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48) | match on coverage |

## Grimble (`dredge`, source Kingpin)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D]; [F] fan 20 rested, 30 firing, fixed stop ~3.5 bh, no falloff with range | 7 slugs, the first volley of a burst on the aim line (owner 11-10), then fan 20 + bloom to 30 (was 30 + 15, fixed), stop 6.3 m, no falloff; aimed volley 14.0 at 2, 6 and 6.2 m; a 30 degree volley 14.0 at 2 m, 8.9 (3 slugs) at 6 m and 6.2 m, asserted in `--dredge-combo-check` | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** |
| R | Two waves, 36 s [D]; [F] 6-7 orbs, ~120 degrees, ~756 a close volley against 193 for the gun | Charge 1.1, 2 waves of 6, 105 degrees, 4 a slug (3.4x a gun volley, burst cap), no falloff, cd 21 | match; **0.58x cd**; damage ratio 3.4x vs 3.9x is held by the burst cap |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air shares slot | differ (owner); air slot missing (gap 13) |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Claire (`rimewright`, source Celeste)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end of burst, 0.5 s barrage cd [D]; one uniform stream while held [F] | Hold = one burst of plain darts (0.18 s), 3 large on the let-go, 0.5 s pause; skating: beams, semi-homing, 2x damage | match (burst); skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skating beams semi-homing (owner, gap 16 done) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) |
| Dash | Hold, release stops, 13 s [D] | 10.5 m/s (F 10-11, the mean), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Chill + 15% slow (ours) | differ: slow ours |
| Anim | Footage poses | 19 moves, all on `claire.glb` (49) | match on coverage |
| Body | 1.1-1.15 [F] | size 1.15 | match |

## Ostra (`ostra`, source Void)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Orb; idle next orb stronger, terrain, Slow [D] | .6, continuous charge to 1.4 s, every orb pierces | differ (owner items 60, data overruled) |
| RMB | Shards, stun, 10 s [D] | cd 10, wind-up .32 vs .2 | differ (owner item 40) |
| Q | none | glove | ours |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.5, waits at full size until popped, no timer; cooldown on the plant [?] | match (the fizzle is removed) |
| R | Vortex stun + pull, 70 s [D] | Tell 1.0, 3.5 s, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift at 67.5% speed (owner 11-08, halved slow 11-10; source gives no drift), moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; floating `[?]` |
| Anim | Footage poses | 14 moves, all on `ostra.glb` (45) | match on coverage |

## Bjorn (`bulwark`, source Oath)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .48 vs .45, walks 55% vs stands | differ (owner); cadence S fix (gap 12) |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | hold .1, aegis, bash cd 6 | match; routing `[?]` |
| Q | none | glove | ours |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | 4 cells, stun .5, cd 40 | match; 0.8x cd |
| Dash | Spin Dash 8 s, knock [D] | Whirl 3.5 m/.17 s (F), off the dash feel, cd 8 | match |
| Passive | Wall knock Stuns [D] | Built; **Guard meter, Shield Slam invented** | differ (gap 15); owner question open |
| Anim | Footage poses | 17 moves, all on `breaker.glb` (48) | match on coverage |

## Ryzz (`mage`, source Joule)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt + Static, F .8 s [D,F] | .648, range 13, no pierce | differ (owner items 70, 116) |
| RMB | Hold/release, knock, orb, 10 s [D] | Hold 1.0, cd 8 | match; 0.8x cd |
| Q | none | glove | ours |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Drag built, delay .8, stacks 1, cd 10.5 | match |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 5.6-9.75 m at 40 m/s (owner item 70, cut 11-10), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) |
| Passive | Static, 4 stacks [D] | Built, orb reset closed by owner | match |
| Anim | Footage poses | 16 moves, all on `ryzz.glb` (45) | match on coverage |
| Flow | Silent | Dash→LMB, X buffer | gap 9 |

## Sable (`thief`, source Shiv)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt, stacks passive [D] | .45, to cursor, 12 m, 13 dmg | match; range unconfirmed |
| RMB | Bolas, Ground, two targets stun, 13 s [D] | Bola 30% slow (owner item 53), cd 7 | differ (owner); **0.54x cd** |
| Q | none | glove | ours |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, the same in the air (item 183), off the dash feel, prime 2.34x, cd 4.5 | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` |
| Anim | Footage poses | 17 moves, all on `sable.glb` (47) | match on coverage |

## Crowd control: every stun, root, Ground, slow, Daze and knock effect (main d255acbee, 2026-11-09)

Read from `content/archetypes/*.json` and the kit code. Source = the card text in `supervive_kits.md` [D] and the footage reads in `briefs/hero-ref` [F] (5 fps, so a read is good to about +-0.2 s). **The card gives no CC duration or strength except Ostra's (Snap 0.8 to 1.8 s, Black Hole 3.5 s, orb 6%) and the upgrade steps (Binding +0.3 s root, Primal Slam +0.1 s and +0.2 s stun).** Every other source row is a footage read or just the word "Slow", "Stun", "Daze". No silence and no knock-up (a launch that disables) is built anywhere, and none is in these 12 kits' cards except Oath's Faultline (queued, skipped). Self-slows (cast, charge, carry) are not CC and are left out. Albert's Faultline and Spin Dash are skipped (queued job). Sable's 30% bola slow stays (owner item 53).

| Hunter | Effect (ours) | Source | Verdict |
|---|---|---|---|
| Vex | Burr Charge Daze 1.4 s (only +90% rifle, +20% Railgun, no slow); wall slam: stun 0.7 s and Daze +0.6 s; Cinderfall zone slow 30% (0.6 s refreshed) | Daze about 1.2 s [F]; wall: "Dazed longer and Stunned" and zone "Slow", no numbers [D] | match (1.4 vs 1.2 is one frame at 5 fps) |
| Zedran | Meteor Drop: core stun 0.8 s, ring slow 40% 1.5 s | "Slow + 88 dmg; center hits Stun" [D], no numbers | match in shape |
| Zedran | Fireblast (full) slow 30% 1 s; Chain Lunge stun 0.35 s; Haul Slam stun 0.25 to 0.6 s | none: the tooltips list no slow on the blast and no stun on the chain | ours-only riders, see suggestions |
| Hem | Heartpiercer wall stun 1.2 s (rank 3: dash charge); Rain of Arrows slow 35% 0.8 s refreshed | "enemies that collide with terrain are Stunned", "Slow + Anti-Heal", no numbers; wall stun not shown cleanly [F] | match; numbers unsourced |
| Cinder | Cinder Shot slow 30% 1.5 s; Flue Flight carpet slow 30% 0.5 s refreshed | "Slow" on both [D]; dummy read SLOWED once, maybe the jump pad [F] | match; numbers unsourced |
| Pip | Burrseed root 1.1 s, +0.3 s at rank 3 | Root, +0.3 s upgrade [D]; root seen about 1 s or more [F] | match |
| Tarek | Punch wall stun 0.9 s; Volcano slam centre stun 0.5 to 1.2 s by charge; Basalt Spine slow 35% 1.0 s; rocks slow 30% 0.8 s; Rock Hop crash slow 30% 1.5 s | wall stun and centre stun, slam stun about 1 s [F]; Tetraform slows [D]; no number | match for the stuns and Spine; rock and hop slows are ours-only |
| Grimble | Anchor stun 1.1 s (+0.1 s a rank, +0.2 s rank 3); the hook's foe is stunned the whole reel (0.2 s refreshed), Grimble Grounded while reeling, the foe Grounded 1 s after | Anchor stun 1.2 to 1.4 s [F]; +0.1 s and +0.2 s steps [D]; reeled foe stunned, caster Grounded [F] | match. Dredge gap 3 ("about a third", it was 0.45 s) is **closed**: 1.1 s is 80 to 90% of the read, inside footage error |
| Claire | Ice Spear zone slow 35% and hit slow 35% 0.6 to 0.8 s; Rimelock stun 0.75 s with a slow that builds 15% +12%/s to 55%; Rink Wall touch slow 30% 1 s; splinter slow 30% 1.2 s | Spear "slow zone", Ice Crash "slowing zone, stuns after a delay", slow stacks up to 3.5 s [D,F]; stun not legible, dummy encased about 0.5 s | match in shape; numbers unsourced |
| Ostra | Snap stun 0.8 to 1.8 s by flight; Nightwell stun and pull 3.5 s; full orb slow 10% 1.5 s | 0.8 to 1.8 s; 3.5 s; "slow 6% for 1.5 s" [F, card] | Snap and Nightwell match. **Open:** orb slow 10% (wiki, `docs/heroes/ostra.md`) against 6% on the card read; not changed, wiki outranks footage |
| Albert | Crush (any knock into a wall): stun **1.0 s** (was 0.5), 8 damage; Shield Slam stun 0.6 s; full Crushing Blow stun 0.4 s | "Knocked into a wall, Stuns"; STUNNED label up about 1 s or more [F] | **fixed**: 0.5 to 1.0 s. Shield Slam and the blow's stun are ours (no source row) |
| Ryzz | Storm Rod wall stun 0.8 s; Skycall Grounded 1.5 s | Stun on a wall or second target [D]; Grounded 1.5 s or more [F] | match |
| Sable | Bola: first foe Grounded 1.5 s and slowed 30% (owner item 53); a pair stun 0.9 s; Shadow Knife slow 50% 2.5 s | Grounded, rings about 1.5 bh [F]; pair "Stunned", the label showed about 1.8 s [F]; knife "Slows" | match for Ground and slow; pair stun 0.9 kept: the footage has no two-foe tie (0115-0125 is one dummy and a tree, and a dummy never acts), so the 1.8 s is label time, not a stun; not measurable, frames and verdict in `docs/heroes/thief.md` "Pair stun length"; asserted in --dancer-combo-check |

**Fixed in this change (1):** Albert's Crush stun 0.5 to 1.0 s (`content/archetypes/bulwark.json` `resource.crush_stun`, text and docs), asserted by `combo bulwark: a Crush stuns 1.0 s` in `--bulwark-combo-check`.

**Suggestions, not built (PARITY FIRST):**
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow).
- Albert: the Shield Slam stun 0.6 s and the Crushing Blow stun 0.4 s have no source row.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s (no footage clip can time it; needs a match clip with two tied foes).

## Moving while casting: the slice four (main 88b06b9e7, 2026-11-12)

Vex, Kael, Lace and Cinder, every held or cast ability (LMB hold, RMB hold or charge, E, R), the same columns as the
eight-Hunter table of ext/cast-move-eight. **Source** is the walk speed inside the ability's frame window in the hero sheet
(briefs/hero-ref on ext/agent-briefs), in px/s and body heights a second against that sheet's run plateau; the frames
themselves are not on this worker, so a row the sheet does not measure stays "not seen" and nothing moves. **Ours** is the
kit's `move_k` times the weapon's `fire_slow` / `draw_slow` (`Hunter._fire_slow`), a share of the run. A row is a fix
only when ours is off the source's band by more than 15%; owner rows keep the owner's number. The earlier RMB/E tables for
these four (ext/cast-move-a, ext/feel-cast-move, docs/heroes, never merged) are folded in here; their one fix, Kael's Lunge
charge walk, landed on main through the mc line (`rmb.lunge.walk_k` 0.8).

| Hunter (sheet, run) | Ability, phase | Source | Ours | Verdict |
|---|---|---|---|---|
| Vex `gunslinger` (venator.md, 110 px/s = 2.3 bh/s) | LMB rifle held | walks while firing, upper body on the cursor, "no visible slow" (0007-0023); no px/s inside the firing window | 1.0 (`quill_rifle.fire_slow`) | match (no slow shown); `--gunslinger-combo-check` "she keeps walking while she fires" |
| | RMB Burr Charge | a 0.2 s overhand throw, "the legs keep walking" | a tap, no hold (owner item 112); 1.0 | match (owner) |
| | E Longneedle, 0.6 s cast | stands still through the cast bar (555.8-556.4 s); then a 0.5 bh recoil shove and about 0.4 s of recovery | 0 for the cast (`e.self_slow` 1.0); free the step it fires, with the shove | match for the cast; the recovery walk is not measured; asserted "Vex cast-move" |
| | R Cinderfall | a tap; keeps walking and jumping while it falls (f103, a jump pad) | 1.0 | match |
| Kael `juggernaut` (juggernaut.md, 104 px/s median = 2.1 bh/s; plain runs 113-124) | LMB swings | "keeps walking while swinging" | 1.0 (greatsword, melee) | match |
| | LMB held, Searing Wave charge (0.6-1.0 s) | not measured (the white arc grows, 0087) | 0.55 past the 0.22 s tap | not seen; kept |
| | RMB tap, Finishing Slam wind-up (0.6 s) | not measured (blade cocked low, 0155-0157) | 0.6 | not seen; kept |
| | RMB held, Lunge charge | 85-95 px/s = 1.7-1.9 bh/s against 113-124 plain runs: 0.69-0.84 (0178-0181, 0198-0208) | 0.8 (`rmb.lunge.walk_k`) | match; asserted "juggernaut RMB hold: he walks at 80%" |
| | RMB air, Meteor Drop | hang, crash, about 0.5 s of low recovery; walk not measured | 0 airborne and 0.2 s planted, then 0.3 rising to 1.0 by 0.5 s | not seen; kept |
| | E Warchain, throw and hooked | no lock; the tether stays on while he walks about 2.5 s (0305-0317), no px/s | 1.0 | match (no slow shown) |
| | R Gilded Riposte | planted through the 0.6 s guard (f33-f38), recovered by f44 | 0 in the guard and strike, 0.5 through the 0.5 s recovery | match for the guard; the recovery walk is not measured |
| Lace `archer` (pin.md, 113 px/s = 2.05 bh/s) | LMB draw held | "walks slowly while drawing", body side-on (0111-0116); no px/s | 0.7 (`longbow.draw_slow`); 0.85 on the quick draw after a perfect | a slow is shown, its size is not measured; kept |
| | LMB, the 0.5 s after a shot | "she can walk between shots", no px/s | 0.8 (the ranged `fire_slow` default) | not measured; kept |
| | RMB Heavy Shot held | the draw pose, sunk lower (0494, f264); no px/s | 0.38 (`rmb.pin.hold_move`) | owner item 114 (slowed while holding RMB); the number is ours |
| | Shift Spirit Walk | 117-126 px/s = 2.1-2.3 bh/s against 113: 1.04-1.12 (0349-0356) | 1.1 (`dash.walk_k`) | match; asserted "pin cast-move" |
| | E Hail Wall | a tap, instant; the bow raised, no stop (f456, f496) | a 0.35 s lob tell, no lock; 1.0 | match |
| | R Starpiercer | a tap self-buff with no cast lock; "she can walk between shots" | 1.0; the empowered draws keep the LMB's 0.7 | match |
| Cinder `ashwick` (linwick.md, 205-230 px/s at 50 px/m = 4.1-4.6 m/s, 2.3-2.6 bh/s) | LMB stream held | walks while firing, "no visible slow" (0007-0019); no px/s | 1.0 (the kit runs the lance; no `fire_slow`) | match (no slow shown); `--ashwick-combo-check` "lance audit ... at his full walk" |
| | LMB, 0.35 s after letting go | not resolvable at 5 fps (sheet gap 12: "subtle", keep) | 0.6 (`lmb.slow_after`) | not seen; kept |
| | RMB Cinder Shot, lane held about 0.4 s, release | "does not stop moving" (0072-0137); a quick arm thrust | 1.0 | match; asserted "cinder cast-move" |
| | E Furnace Cloak | arms wide about 0.2 s, then the blast; walk not stated | instant on the press (owner item 11); 1.0 | match (no lock shown) |
| | R Flue Flight | a flight: about 500 px/s (10 m/s) for 1.6 s, the ult clip 9-10 bh in 1.3-1.4 s; walks on with no landing beat | the flight carries her (12.6 m/s for 1.8 s); 1.0 on landing | n/a for a walk factor; match on landing |

**Result:** no row is off by more than 15%, so no kit data moved. The two rows the sheets measure (Kael's Lunge charge
0.69-0.84 against 0.8, Lace's Spirit Walk 1.04-1.12 against 1.1) match; every other row either shows no slow where we have
none, or has no number. **Checks:** the four combo checks (`--gunslinger-combo-check`, `--juggernaut-combo-check`,
`--archer-combo-check`, `--ashwick-combo-check`) and `--move-feel-check`. **Footage to get:** a straight walk during Kael's
wave charge, Slam wind-up and Meteor recovery, Lace's draw and Heavy Shot hold, and Cinder's 0.35 s after the stream.

## Felt dash per kit (gap 4)

`content/rules/dash_feel.json` defaults to ×1 / ×1: a kit whose dash is the source's measured one runs it as-is. The owner's "slower and shorter" (×.85 distance, ×1.15 time) stays only where no source number exists; Ryzz gets the time part only (his lane is the owner's, item 70). Felt = raw × feel, measured in `--move-feel-check` (`felt dash` rows, ±5% / ±0.035 s) to the moment the dash ends: the step it ends in runs the dash for the time it had left, then the hand-over (on the ground the run, in the air the dash's speed carried on under drag, owner 11-08), and that tail isn't counted.

| Kit | Raw ground | Raw air | Sourced | Feel | Felt ground | Felt air |
|---|---|---|---|---|---|---|
| Vex | 4.8 m/.45 s tap | 4.7 m/.33 s (2/3 hold, patch notes) | F tap | ×1 | 4.8 m/.45 s | 4.7 m/.33 s |
| Zedran | 4.5 m/.17 s (+.07 dip) | class long dash | no (owner 113.8) | ×.85/×1.15 | 3.8 m/.2 s | ×feel |
| Hem | 3.0 m/.27 s roll | 5.0 m/.22 s flick (light long dash) | F roll | ×1, speed ×0.7 (owner item 9) | 3.0 m/.39 s | 5.0 m/.22 s |
| Cinder | 3.4 m/.33 s | 6.8 m/.28 s | F | ×1 | 3.4 m/.33 s | 6.8 m/.28 s |
| Pip | 3.6 m/.2 s | 13.3 m/.95 s glide | F | ×1 | 3.6 m/.2 s | 13.3 m/.95 s |
| Tarek | 2.8 m/.26 s hop | class long dash | no (owner item 111) | ×.85/×1.15 | 2.4 m/.3 s | ×feel |
| Grimble | 3.2 m/.16 s | 4.3 m/.16 s (×1.35) | no (owner 23:40) | ×.85/×1.15 | 2.7 m/.18 s | 3.7 m/.18 s |
| Claire | Skate 10.5 m/s, up to 1.6 s | same | F speed | none (not a travel) | as raw | as raw |
| Ostra | lob 12 m, 1.8 s | same | F time | none (not a travel) | as raw | as raw |
| Bjorn | 3.5 m/.17 s whirl | 4.2 m/.3 s lumber | F whirl | ×1 | 3.5 m/.17 s | 4.2 m/.3 s |
| Ryzz | lane 5.6-9.75 m at 40 m/s | same | no (owner item 70, lane cut 11-10) | time ×1.15 | 5.6-9.75 m at ~35 m/s | same |
| Sable | 4.5 m/.48 s | the ground one with a charge (item 183) | F | ×1 | 4.5 m/.48 s | 4.5 m/.48 s, then the air's drag |

On a ×1 kit every Shift move runs its raw numbers, including the moves with no source figure: Bjorn's Shield Charge (4.2 m at 18 m/s), his short dash during the wind-up and his lumber, Vex's long dash and Hem's flick are now about 18% longer and 13% quicker than before.

Those five, measured against the footage (`origin/ext/hero-ref-footage`, 5 fps; 1 bh = 1.8 m) and `briefs/supervive-data` on 2026-11-12: none shows the move, so none has a measure, no number moved and no `felt dash` row was added. DECISIONS has no owner line on any of them.

| Move | Raw (ours) | Source | Looked at | Row |
|---|---|---|---|---|
| Bjorn Shield Charge | 4.2 m / .23 s (18 m/s) | Oath Shield Bash: knock-back and brief invulnerability, no travel figure (supervive_kits.md) | bjorn 0180-0362 every 6th, 0296-0311 and 0343-0362 every frame: the shield is held planted; the bash flares (0300, 0352-0353) move his body under 5 px (0.2 m), the second one at point blank on the dummy, so no travel can be read | [?] |
| Bjorn short dash in the wind-up | 2.6 m / .13 s (20.5 m/s) | none: Spin Dash is a plain Shift | bjorn 0100-0172 every 3rd (the charged swings: he walks the hold, no Shift in it); 0363-0371 (the 360 Smash starts with no charge glint) | [?] |
| Bjorn lumber (long dash) | 4.2 m / .3 s (14 m/s) | none: the source has no long dash; Oath never leaves the ground (bjorn.md 5) | same frames as above; 0512-0518 is Earthshatter, not a dash | [?] |
| Vex long dash (air slide) | 4.7 m / .33 s (2/3 of the 7 m / .55 s hold) | patch notes only; Combat Slide card has no figure | venator_ghost 0114-0153 every 3rd: the three slides (0117, 0135, 0150) are all on the ground, no hold told apart, none in the air | [?] |
| Hem flick (long dash) | 5.0 m / .22 s (light class) | none: Phase Walk has no long dash, an air Shift is the same roll (item 183) | pin 0048-0056 (pin.md 5's 2.3 m push): it is her wall climb up the tower (Soul Hunter), not a dash; 0388-0389 is the ground roll | [?] |

## The 20 biggest feel gaps, ranked

Slice Wardens and LMB rank first (PRIORITIES step 2). Effort: S under a day, M a few days, L a week or more. `owner` = needs an owner call before building.

| # | Gap | Fix | Files | Effort |
|---|---|---|---|---|
| 1 | Zedran has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M |
| 4 | Dashes stop dead: keep 15%/30% vs carry | Raise carry. **Scale part done:** the ×.85/×1.15 layer runs only on kits with no source dash (table below) | hunter.gd | M |
| 5 | Hem's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner |
| 6 | Hem's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S |
| 7 | Hem's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S |
| 8 | Hem's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L |
| 9 | Dash→LMB buffers on 6 kits (Hem, Bjorn, Zedran, Cinder, Ryzz, Tarek air), and Zedran, Bjorn and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner |
| 11 | Done: Cinder is off the dash feel (3.4 m/.33 s, poof 6.8 m/.28 s); Grimble's air barge is scaled once (measured 3.7 m/.2 s) | none | asserted in --move-feel-check | done |
| 12 | Bjorn's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M |
| 14 | Tarek's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner |
| 16 | Done: Claire's skating beams home late like her darts (owner: semi-homing, 2x damage) | none | asserted in --rimewright-combo-check | done |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows had no source `[?]` (Hem 8, Ryzz 5, Tarek 6): 1 settled by Breah's footage, 14 now cite what was checked as "Not determinable", the 4 Q rows stay ours | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |

## Item 20: jump speed and the unsourced flow rows

**Jump speed.** Source: JumpZVelocity 750 uu/s = 7.5 m/s at gravity 14.7 m/s² (supervive_physics.md:45, [D]). Ours: `Hunter.JUMP_V` 6.8 m/s. Kept on purpose (`docs/MOVEMENT_FEEL.md`, "Jump 9 → 6.8"): 7.5 lets jump plus mantle top four terraces. It is a map-grammar deviation, not a source value; the owner can flip it once the terraces change. `--move-feel-check` now asserts `jump_speed_vs_source` (lift-off over 7.5, must sit in 0.85 to 1.0), so the source number is pinned and the gap cannot drift.

**Dash-flow rows with no `source` field `[?]`.** No source or footage settles these; they run as the kit's default (`keep`, or `fire` for Q). Not guessed.

| Hero | Rows | Result |
|---|---|---|
| Lace (`archer`, Pin) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) | Not determinable, each `source` cites what was checked: pin.md:33-47 (draw, walks while drawing, frames 0111-0116), :91-110 (Impaling charge, 0264-0269, 0494), :247 (open question 'whether you can shoot during it'), :322-334 (roll bare 0388-0389; air dash and jump not shown); supervive_kits.md:73-75, :78. Kept `keep`. Still `[?]` |
| Sparkle (`mage`, Vireo) | `hold.rmb.{ground,air,jump}` (3, `keep`) | Not determinable: vireo.md:80-94 (spear hold 1.2 s, she stood still, frames 0043-0049, 0057-0063, 0078-0084), :211-219 (spear thrown, then Surge), :386 (open question 5), :460-476, :503 (air Surge and jump not shown); supervive_kits.md:66-67. Kept `keep`. Still `[?]` |
| Tenzo (`dolm`, Breah) | `hold.rmb.jump` (1, `keep`) | **Sourced**: breah.md:114 (card frame 0240) 'when she jumps while charging, she leaps forward and the circle comes with her'; supervive_kits.md:106 'Jump while charging to leap forward'. The charge survives the jump, so `keep` is the source. No longer `[?]` |
| Tenzo (`dolm`) | `hold.rmb.{ground,air}`, `hold.lmb.{ground,air,jump}` (5, `keep`) | Not determinable: breah.md:71-82 (punch wind-up 0117-0124), :98-115 (charge, 0938-0958 is a punch pressed during a charge), :140-143 (dunk casts RMB after the dash), :145-158, :357 (open question 3), :361 (no transcript; the tip title 'Punch to Extend Dash/RMB' cannot be read), :433-449 (air dash 'not shown as a dash'); supervive_kits.md:105-106. Kept `keep`. Still `[?]` |

Left as ours: Hem (`archer`) `dash.ground.q`, `dash.air.q` and Ryzz (`mage`) `dash.ground.q`, `dash.air.q` (4, `fire`; Q is ours, no source exists).

Suggestion (not built): the Breah tip 'Punch to Extend Dash/RMB' may describe a held punch through a dash. Settle it with the spoken tip (whisper on breah/audio.wav) or a clip of a punch pressed in a Landslide; if it is a hold-through-dash, `hold.lmb.ground` stays `keep` and gains the source.

Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.

**The other kits' `keep` rows (2026-11-11).** The rows in the sentence above now carry a `source`. Each one cites the frames and lines checked. None could be settled: in every clip the held ability and the dash or jump are in separate windows. All stay `keep` and still `[?]`, and no behaviour changes.

| Hero | Rows | Checked |
|---|---|---|
| Cinder (`ashwick`, Felix) | `hold.rmb.{ground,air,jump}` (3) | linwick.md:55-63 (bolt lane 0073-0074, 0102-0103, 0131), :267-276 (bash 0143-0144, 0159-0160, never inside a lane), :278-279 and :285-286 (air dash and jump not shown); supervive_kits.md:41-42 |
| Zedran (`juggernaut`, Brall) | `hold.rmb.{ground,air,jump}`, `hold.lmb.jump` (4; the old count of 3 missed `hold.lmb.jump`) | juggernaut.md:20 (card 'Dash while attacking', silent on a charge), :41 (blast charge 0087), :57-65 (Charge Dash 0121-0127, 0141-0146), :86-92 and :259-266 (Quick Dash on its own, 0371-0420), :273-274 (air dash not shown), :283 (no plain jump; jumps are Air Slams 0251-0300); supervive_kits.md:18, 21-22, 26 |
| Bjorn (`bulwark`, Oath) | `hold.lmb.jump` (1) | bjorn.md:67-74 (swing holds 0101-0172, all standing), :271 (open question: can he move while charging), :363-366 (air and jump not shown); supervive_kits.md:88 |
| Claire (`rimewright`, Celeste) | `hold.rmb.{ground,air,jump}` (3) | tamsin.md:18 (the spear is a tap in the source), :48-53 (RMB 0094-0168) against :66-79 (Skate 0169-0296), no overlap; :293-298 (air dash and jump not shown); supervive_kits.md:33-34 |
| Pip (`tender`, Elluna) | `hold.rmb.{ground,air,jump}` (3) | mooshmoosh.md:61-72 and :386-388 (aim f105-113, f116-120), :340 (dashes at f35, f157, f181, f227, none in an aim; no clean ground dash); supervive_kits.md:9-11. Ours: holding RMB does nothing past the wind-up, so these rows have nothing held to act on |

I re-checked Cinder's and Grimble's `dash.ground.lmb`: nothing new. Cinder's LMB is never pressed inside a bash (linwick.md:267-276). Grimble's Buckshot (0040-0080) and his ~0.12 s Brute Dash (0188, dredge.md:100-103, 302-306) are in separate windows. Their sources stand as written.

To settle any of these rows, a clip has to show the held ability running into the move: Felix aiming the bolt and then bashing, Brall charging and then Quick Dashing, Oath charging and then jumping, Elluna aiming and then dashing. For Celeste the spear is a tap, so the hold is ours and there is no source row to match.

## Boots and charms (gear parity, `--gear-parity-check`)
Loadout is 2 gloves, 2 charms, boots (DECISIONS). Searched briefs/supervive-data and briefs/hero-ref
(origin/ext/agent-briefs, 2026-11-10) for boots actives, cooldowns and passive move speed: the source data
has no boots or charm items at all (no item tables; PHYSICS_PARITY only says gear scales move speed at
runtime, with no numbers). So no piece has a source match and nothing was changed; the list below goes to
the owner. The check pins these values so any change goes through this list.

| Kind | Piece | Cooldown | Stats (Common) | Source match |
|---|---|---|---|---|
| boots | Springheel Boots (`boots`) | none (passive) | +8% move speed | none |
| boots | Quickstep Boots (`quickstep_boots`) | none | dash back 15% sooner, +3% move speed | none |
| boots | Skylark Boots (`skylark_boots`) | none | +35% glider heat | none |
| boots | Windstep Boots (`windstep_boots`) | none | +10% glide speed, +15% glider heat | none |
| charm* | `booster` | none | +20% glide speed, +20% glider heat | none |
| charm* | `focus` | none | 18% cooldown reduction | none |
| charm* | `heat_sink` | none | +45% glider heat | none |
| charm* | `power_core` | none | +12% damage | none |

\* Charms are not built yet (note 0005): there is no charm gear kind, and these passive gloves are the
pieces meant to become charms. No boots piece has an active, so none needs a key: the HUD boots cell
(GearPanel) shows the icon and rarity with no key and no cooldown, and its hover reads "Boots" plus the
stat line; the check asserts both for every boots piece.
## Friendly fire (--friendly-fire-check)

**Rule** [O: owner brief, PARITY FIRST]: a Hunter's abilities never hurt a teammate or the caster; a world explosion (powder keg, meteor) hurts everyone. `supervive_kits.md` states no exception: every damage line names "enemies", "struck targets" or "foes"; `docs/SUPERVIVE_DATA.md` has no self-damage row.

**Audit (all 128 `.hurt(` call sites).** Every damage source picks its victims through one of three team-filtered lists, so there is no per-kit exception to fix and none was added:

| Victim list | Filter | Sources (file:line) |
|---|---|---|
| `Match.foes_of(team)` (`match.gd:2032`) | `h.team != team`, kins not wild, mobs | gunslinger_kit.gd:558,564,660; gunslinger_ult.gd; juggernaut_kit.gd:798, juggernaut_ult.gd:151; ashwick_kit.gd:408, ashwick_jet.gd:243; effects.gd:325,336,701 (gloves, Boki abilities); verbs.gd:442; fields.gd; abilities.gd:16; merge_kit.gd:156, merge_augment.gd:167,246,256; match.gd:3471 (bolas), 5189 (well); kin.gd:683; mob.gd / boss.gd / blight.gd (monsters, own team -2) |
| `ArchKit.foes_in(at, r)` (`arch_kit.gd:602`) | `m.foes_of(h.team)` + radius | archer, ashwick:670, bulwark, dolm:185,424,470,476, breah_hop/slam/spine, juggernaut_kit.gd:533, juggernaut_drop.gd, mage_kit.gd:668,673, ostra_kit.gd:564,625, ostra_well.gd, rimewright_kit.gd:135,639,682,1019, tender_kit.gd:452 |
| `Match._shot_targets(s)` (`match.gd:3304`) | `h.team != s.team`, `k.team != s.team` | every projectile, `_boom` (match.gd:3562) |
| World, no team | none on purpose | `Breakables._hurt_around` (`breakables.gd:133`: kegs and barrels hit hunters, mobs and kins; credit is dropped for the lighter's own team), `Match._meteor_hit` (match.gd:5279), glider heat, fall and wall damage (`by` null or the last enemy) |

**Result.** `--friendly-fire-check` casts each of the 12 kits' LMB, RMB tap and hold, E (and a second press), R, X and dash, plus the four damaging gloves (blink, grapple, quake, shock; Bubble only reflects), with a foe, a teammate and the caster all inside: 707 checks, 0 failures. It counts hits through `CombatBus.hit_landed`. A powder keg hurts the caster, a teammate and a foe. Control run: with `foes_of` changed to include the caster's team, 127 checks fail across all 12 kits and the gloves, so the check does bite.

**Not reached by the check (no foe damage in that case):** `archer` and `bulwark` RMB taps, `bulwark`, `dolm` and `tender` E (shields, heals), the dashes of `archer`, `dredge`, `gunslinger`, `ostra`, `rimewright`, `tender` and `thief`. Utility belt items (`content/utility`) carry no damage. Boki species abilities (G, ~40 species through `Effects`/`KinExec`) go through the same `foes_of` but are not cast per species here.
## Health

PARITY FIRST ratio audit (briefs/DECISIONS.md 2026-11-07). Our numbers are on a smaller scale than the source's, so each Hunter is compared as a share of its own roster's average: ours = max health / 154 (mean of the 12), source = Base HP / 1285 (mean of the 12). Ratio = ours share / source share; 1.00 is parity, the bar is 1.25x either way.

**Where the numbers live.** Source: `Base HP` column of the per-hunter attribute table, supervive_physics.md (`origin/ext/agent-briefs`, briefs/supervive-data; `supervive_kits.md` has no HP rows) [D]. Ours: `Data.CLASSES[weight].hp` in `scripts/core/data.gd` (light 124, medium 145, heavy 193); every archetype takes its weight class's health (`Arch.weight`), `hunter.gd` adds kin and level growth on top. **Armour:** ours is `round(base health x ARMOR_DUR 2.2)`, so its ratio is the health ratio. The source has no per-hunter armour (a loadout item, `docs/SUPERVIVE_DATA.md` section 3), and no hunter has a base shield in either game (Bjorn's Brightshield, Grimble's and Pip's shields are ability shields, not base stats). So health is the only per-Hunter number.

| Hunter (weight) | Ours | Share | Source (Base HP) | Share | Ratio |
|---|---|---|---|---|---|
| Vex / Ghost (medium) | 145 | 0.942 | 1225 | 0.953 | 0.99 |
| Zedran = Kael / Brall (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Hem = Lace / Myth (light) | 124 | 0.805 | 1100 | 0.856 | 0.94 |
| Cinder / Felix (heavy) | 193 | 1.253 | 1290 | 1.004 | **1.25** |
| Pip = Meeko / Elluna (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Tarek = Tenzo / Tetra (medium) | 145 | 0.942 | 1290 | 1.004 | 0.94 |
| Grimble / Kingpin (heavy) | 193 | 1.253 | 1445 | 1.124 | 1.12 |
| Claire = Neve / Celeste (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Ostra = Motley / Void (medium) | 145 | 0.942 | 1150 | 0.895 | 1.05 |
| Bjorn = Albert / Oath (heavy) | 193 | 1.253 | 1475 | 1.147 | 1.09 |
| Ryzz = Sparkle / Joule (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |
| Sable / Shiv (light) | 124 | 0.805 | 1290 | 1.004 | **0.80** |

**Verdict: no outlier over 1.25x, so no health number was changed** (global scale untouched). Kael and Cinder sit at 1.249 and Neve, Sparkle and Sable at 0.802 (1/1.247): inside the bar by a hair, caused by the same thing: three weight classes against a source where 8 of 12 Hunters share 1290. No owner note on tankiness was found in DECISIONS or OWNER_REVIEW_1103, so none overrides these rows. `--archetype-check` ("health:" rows) asserts every Hunter is inside 0.8x to 1.25x.

**Suggestion, not built.** The source is flatter: 1100 to 1475 (1.34x spread) against our 124 to 193 (1.56x). Lowering heavy to about 185 and raising light to about 128 would bring all five near-limit Hunters to about 1.2x/0.83x. That moves a whole weight class, so it is the owner's call. Per-archetype health (Hem and Motley a little lower, Bjorn and Grimble a little higher) would match the source more exactly but breaks the one-weight-one-health rule.

## 0.24.4 main re-check: eight Hunters (2026-11-12, main 88b06b9e7)

Albert (`bulwark`, section "Bjorn"), Neve (`rimewright`, "Claire"), Tenzo (`dolm`, "Tarek"), Sparkle (`mage`, "Ryzz"), Grimble (`dredge`), Meeko (`tender`, "Pip"), Sable (`thief`) and Motley (`ostra`, "Ostra"). Marks: **done** = still as the row says; **fixed since** = the row's gap is closed on main, the row text above is stale; **open** = still a gap or an owner call; **regressed** = was done, no longer. Numbers were read from `content/archetypes/*.json`, `content/weapons` and `content/dash_flow`; animation coverage and live behaviour were not re-measured, the combo checks stand for them.

**Checks on 88b06b9e7:** `--bulwark-combo-check` 166/0, `--rimewright-combo-check` 116/0, `--dolm-combo-check` 172/0, `--mage-combo-check` 143/0, `--dredge-combo-check` 112/0, `--tender-combo-check` 104/0, `--dancer-combo-check` (Sable) 144/0, `--ostra-combo-check` 213/0, `--kit-parity-check` 0 failures, `--dash-flow-check` 0 failures (14 skipped), `--ttk-check` **22 failures** (the count the 0.24.4 gate already lists; 11 rows are these Hunters: mage 4, bulwark 3, ostra 4).

**Regressed: none.** Health (124/145/193), cooldowns, ranges, crowd-control numbers and the felt-dash table all match the rows above.

| Hunter | Row | 0.24.4 main mark |
|---|---|---|
| Albert | LMB | open (owner): tap whirl, carry and perfect launch stay; **fixed since**: cadence `throw_rate` 0.45 (gap 12 closed) |
| Albert | RMB, E, R, Dash | done: aegis 4.2 at 140, slam 2.6 at 100 stun 0.6, bash cd 6; E zone r **2.3** (the row's "r 3.5" is stale), delay 1, 4 s, cd 12/8; R 4 cells x 4 m, width 4.5, stun 0.5, cd 40; whirl 3.5 m at 20.5 m/s (0.17 s), cd 8 |
| Albert | Passive | open (owner, gap 15): Guard meter and Shield Slam still built; Crush stun 1.0 s done |
| Albert | Dash-flow | open (gap 9): `dash.ground/air.lmb` still `buffer` (sourced from footage, not flipped to `fire`) |
| Neve | LMB | **fixed since** (gap 16): skating beams home like darts (`rimewright_kit.gd`) |
| Neve | RMB, E, R, Dash | done / owner as before: 2 charges cd 10.2 (owner), E 200 HP cd 17, R hold 3.5 s cd 80 rink 8.3 (7.2 +15%, owner), dash 11.5 m/s up to 1.6 s cd 13 refund 0.6 |
| Neve | Passive, Body | open (owner, gap 19): Chill slow is ours-only. Body size is **1.014**, not 1.15: the owner's height chart (4538174a85, Neve 1.56 m) set it; the "Body ... match" row is stale and is an owner call |
| Tenzo | LMB, RMB, Passive | done: boulder 0.6, punch 0.7, slam hold 0.2 cd 11 |
| Tenzo | E | **fixed since** (gap 14): allies hop the rocks (`hop rocks` in `--dolm-combo-check`, owner 23:55); cd 12.5, 3.4 ahead, span 5 done |
| Tenzo | R, Dash | open (owner): ridge 12 m (source 18-21.6, kept), 9 rocks cd 45 range 11; Rock Hop 3 x 2.8 m/0.26 s cd 12 (owner item 111) |
| Tenzo | Dash-flow, CC | gap 9 **fixed since** (`dash.*.lmb` is `fire`); open: 6 `[?]` hold rows, ours-only rock and hop slows (CC suggestions) |
| Sparkle | LMB, RMB, E, R | done: bolt 0.648 s range 13 (`coilcaster.json`, owner); RMB hold 1.0 cd 8; E delay 0.8, stacks 1, cd 10.5, r 1.5 reach 11 slide 3.4; R hover 1.7 cd 42 r 2.7 range 14.4 |
| Sparkle | Dash | open (owner): lane **5.6-9.75 m** at 40 m/s, dmg 20, cd 8 (the section row's "7.5-13 m" is stale; the felt-dash table is right) |
| Sparkle | Flow, Passive | gap 9 **fixed since** (`dash.*.lmb` is `fire`, source "not determinable" `[?]`); passive done |
| Grimble | RMB, E, R, Passive | done: reel 11.5 m cd 12; slam windup 0.38 r 3 stun 1.1 cd 7; R charge 1.1 fan 105 cd 21; Salvage max 10 at +2.5% |
| Grimble | Dash | **fixed since** (gap 13): the air pounce has its own 12.5 s slot (`dash.air.cd`, 10.5/8.5 at ranks 2/3; asserted in `--dredge-combo-check`); the row's "air slot missing" is stale. Open (owner): ground dash off the 0.85/1.15 feel; cooldowns 0.58x of the data |
| Meeko | LMB, E, R, Dash, Anim | done: E 2.5 s r 2.6 cd 11, R 5 s range 12.6 cd 46, dash 3.6 m/0.2 s cd 7 and 13.3 m/0.95 s cd 14, carry 2 with 4 s lock |
| Meeko | RMB, Passive | open: hop form root after 2 s (owner 11-10), motion `[?]`; Carrier shield is ours-only (gap 19) |
| Sable | LMB, E, R, Dash | done: E 14 m 6 s cd 15; R r 2.3 to 5.4, 10 shots, cd 24; Vault 4.5 m/0.48 s cd 4.5, prime +1.34 (2.34x). The row's "air 8.4 m/0.95 s" is stale: the air dash is the ground cartwheel with a charge (item 183) |
| Sable | RMB, Passive | open (owner): bola cd 7 (0.54x of the data) and the 30% slow; R cd 24 is 0.48x; Shred is ours-only `[?]`; pair stun 0.9 vs ~1.8 s |
| Motley | LMB, RMB, R, Dash | done / owner as before: charge from 0.6 s (owner 60), RMB cd 10 (owner 40), Nightwell tell 1.0, 3.5 s, pull 12, cd 70, lob 1.8 s cd 9.5. RMB wind-up 0.32 was not located by key in the JSON (combo check passes) |
| Motley | E | **fixed since** (gap 17): `dmg_max_k` 3.5; grow 6.5 s and r 3.2 done; the fizzle stays ours |
| Motley | CC | open: orb slow 10% (wiki) vs 6% (card read) undecided |

**Shared rows still open for these eight:** gap 2 (stopping), 3 (air control), 4 (dash carry), 10 (cooldown pace 0.48x to 1.0x), 19 (ours-only riders); health ratios unchanged (Neve, Sparkle, Sable 0.80 against the 1.25x bar); every `?` range in the ranges table stays `?`.
