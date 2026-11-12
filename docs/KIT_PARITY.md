# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07)

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only for the first audit; the ranges table below changed four numbers (data only).

**How to read a verdict.** `match`: same mechanic, within footage error. `differ`: built, not the same (says how). `missing`: not built. `differ (owner)`: an owner note overrides the source, so it stays unless the owner reverses it; not a gap. `ours`: not in the source at all.

**Evidence:** [D] game data (supervive_kits.md, supervive_physics.md), [F] footage (briefs/hero-ref), [O] owner note. Order of trust: O > D > wiki > F. Source references live only on `origin/ext/agent-briefs` (briefs/supervive-data, briefs/hero-ref, briefs/specs/kit-audit).

**What was and was not verified.**
- Numbers, modes and code paths were read from main. The Nov 3 audit (briefs/specs/kit-audit) is stale: many of its gaps are closed, and rows here were re-checked against main before use. `ext/online-displace` and `ext/no-shake` are merged, so the online pull bug and self-shake are closed.
- All 12 `--<hero>-combo-check` runs pass: 1,560 PASS, 0 FAIL. They assert our spec, not the source, so a pass is not parity proof.
- **Animation timing was not re-measured frame by frame.** Animation rows report clip coverage (computed from kit code, `warden_anim/*.json` and each GLB) plus timings already recorded in docs/heroes. Hitbox rows use content numbers; no in-game overlay run was done.
- `[?]` marks a row carried from a hero doc that I could not settle from code here.

**Every Hunter, shared:**
- **Q:** ours (a glove, gear slot, with V). Not in the source, so no parity target. DashFlow fires it through dashes.
- **Glove band:** gloves must not outshine the kits' E. `--glove-band-check` holds every glove at every rarity to the 12 E abilities' maximum for damage per cooldown second (4.38), CC seconds per cast (4.4) and travel metres per cast (14). Launch gloves keep their numbers in content `launch` (m/s, m). Gust's forward launch went 9 to 7.5 m/s (15.9 to 13.3 m, over Thief's 14 m blink-to-knife before).
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
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range [?] |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | match; angle [?] |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) |
| Kael | RMB air slam disc, reach | **2.4**, 0.8 ahead (straight down) | 1.2 bh (2.16), cursor to ~5 | owner 11-10 down slam (ext/jugg-downslam), not a gap |
| Kael | RMB chain spin radius | **2.2** (was 2.6) | 1.2 bh (2.16) | **fixed** |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not seen | range match; tether [?] (owner Warchain note) |
| Kael | R strip | 3.6 x 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | [?] |
| Cinder | E radius | 4.5 | 2.5 bh (4.5) | match |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2; flare 1.8 bh = 3.2) | match; flare [?] |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach [?] |
| Meeko | R range | 12.6 | tether ring 7 bh (12.6) | match |
| Tenzo | RMB radius, core | 4.5 (3.82 tap), 0.9-1.8 | 2.5 bh (4.5), 0.5-1 bh | match |
| Tenzo | E ahead, span | 3.4, 5 | 2 bh (3.6), 3 bh (5.4) | match |
| Tenzo | R ridge length, cast range | 12, 11 | 10-12 bh (18-21.6), - | differ ~40%, kept: f2b60dc70 narrowed it 19.8 to 12 on purpose, no DECISIONS line either way; [?] |
| Grimble | RMB range | 11.5 | 6-7 bh (10.8-12.6) | match |
| Grimble | E depth, angle | 3.0, 110 | 1.5 bh deep x 2 bh wide (2.7 x 3.6) | within footage error [?] |
| Grimble | R fan, depth | 105, 5.9 | 100-110, 3.3 bh (5.9) | match |
| Neve | RMB range, zone, burst | 12, 2.2, 2.7 | lands at the cursor, clamp and rings not measured | [?] (owner: travel time grows with distance) |
| Neve | E width, slide | 1.8 to 4.5, to 16.2 | narrow to ~2.5 h (4.5), slide not measured | width match; slide [?] |
| Neve | R rink radius | 7.2 | 4 bh (7.2) | match |
| Motley | RMB range | 13 | bundle seen over 6 h (10.8), max not seen | [?] |
| Motley | E seed radius | 3.2 | 1.8 h (3.2) | match |
| Motley | R radius, range | 3.6 / 5.1 swollen, 10 | 350 / 500 uu (3.5 / 5.0), - | match; range [?] |
| Albert | RMB aegis, slam | 4.2 at 140, 2.6 at 100 | slab 2.2 h wide (4.0), bash not seen | aegis match; slam [?] |
| Albert | E zone radius | **2.3** (was 3.5) | green disc 1.3 h (2.34) | **fixed** |
| Albert | R lane | 16 x 4.5 | 9 bh x 2.5 bh (16.2 x 4.5) | match |
| Sparkle | RMB range | 13 | 7.5 bh (13.5) | match |
| Sparkle | E radius, reach, slide | **1.8** (was 1.5), 11, 3.4 | circle ~2 bh across at placement `0184` and strike `0190` (radius 1.8), -, ~4 bh over ~1 s at `0197`-`0224` (7.2) | radius **fixed** (re-measured 11-11; the 1.5 had no owner line); slide differs 53%, kept: owner item 9b ("wasn't that drastic in the game") |
| Sparkle | R radius, range | 2.7, 14.4 | ring 1.5 bh (2.7), 8 bh | match |
| Sable | RMB range, lane | 7 + 3.8, **1.8 wide** (was 1.4) | lane 5.5-6 bh (9.9-10.8), 1 bh wide (1.8) | **fixed** (width) |
| Sable | E range | 14 | landed at 9 bh (16.2), max not seen | [?] |
| Sable | R ring | 5.4 (rim band outer 25%) | 3 bh (5.4); the first sheet's 3.5 bh is superseded | match |

Left alone and why, for the owner: Kael lunge (owner), Vex needle width (owner item 68), Cinder flight (owner item 20), Tenzo ridge (deliberate narrowing, source 10-12 bh), Sparkle Skycall slide (owner item 9b). Ideas of ours stay out of the build.

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match | A round every 0.13 s held (0.12 on the clock, frame-rounded), first 0.07 s after the press; 6.0, 5.7, 5.4, 5.1 on the first hits, 3.0 by round 10; 82 dmg in 3 s. **match** |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) | 22 dmg + Dazed, lands 0.20 s after the press at 6 m, cd 6.5 s; wall cone 16 + shove, fuse 0.9 s (combo check). Still named Burr Charge: owner 11-08 Coin Blast not on this branch (gap A). **match, rename missing** |
| Q | none | glove | ours | not measured (ours) |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match | Beam at 0.63 s, 36 dmg (+20% on Dazed, passes a wall), cd 11.5 s, shave 20%/30%. Still fires from the rifle: owner 11-08 Palm Lance (palm origin) not on this branch (gap A). **match, palm missing** |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) | Impact 1.62 s after the press (24, 36 in the core), then 3 per tick for 3 s, cd 42 s. Ticks are 0.52 s apart, not 0.5 (gap C). **match** |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match | Tap 4.85 m, 98% by 0.43 s (data 4.8/.45); hold 10.3 m in 0.82 s: the 0.18 s skid then the 7 m slide, charge cost 1.4 (gap B); 8.5 s per charge. Fires through both; dash-flow rows 0 fail. **match; hold is skid + 7 m** |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match | 6% for 3.5 s, one stack; Dazed +90% rifle, all PASS in the combo check. **match** |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage | Clip on within 0.03 s (LMB), 0.10 s (RMB); move lengths RMB 0.5, dash 0.87 (legs back 1.30 on a hold), E 1.07, R 0.60 s; all PASS. **match** |

## Kael (`juggernaut`, source Brall; was Zedran) · slice Warden

| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) | Taps swing every 0.35 to 0.40 s at 0.1 s press steps (0.34 s rate, 3 slashes in 1 s PASS), 8 then 12.8 per slash; hold 0.5 s lets go a wave of 15.3 (12 to 20 by hold), 20 at full 0.95 s, the wave flies 36 m/s (0.15 s to 6 m); held 3 s it never fires. **match** |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) | Slam 26 lands 0.72 s after a tap (0.6 wind-up); Lunge 16 at hold 0.45 s, 20 at 0.8 s and over; cd 2.0 s. Held 5 s it never fires, blade over the head, a flash each second; release on the flash flings 7.8 m against 6.6 m (+18%, owner note). **match** |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd | Air row PASS (airborne after a chain launch = Meteor Drop); cd 7.2 s in the data, disc 2.2 m. **match** |
| Q | none | glove | ours | not measured (ours) |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) | Hook 8 dmg 0.28 s after the press at 10 m (32 m/s), cd 12.8 s from the cast; recast hauls 9.4 m, within 2 m of the foe 0.37 s later (22 m/s); holds 5 s, pays out to 24.06 m and holds taut, a strafe or a look bends the pull 2.9 m aside, backing away slings 24.5 m/s (owner Warchain note PASS). **match** |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` | Guard 0.65 + strike 0.1: 43 dmg at 0.77 s, cd 36 s (source 45). **match; cd 0.8x** |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) | 4.14 m in 0.35 s (0.07 dip, 3.1 m by 0.2 s: 3.8 m felt plus 0.35 m exit carry); 2 charges, a charge back every 10.4 s; hold = tap. dash-flow rows 0 fail. **match** |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape | Damage fills Rage, full = Enraged +15%, ability and dash haste (combo check PASS). **match** |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) | Still `kael.glb` 0 clips (gap 1 below). **missing** |

## Lace (`archer`, source Myth; was Hem) · slice Warden

| Slot | Source | Ours | Verdict | Re-check 2026-11-10 (ext/release-integ-0244-fix ec3c9dafb, Training Area) |
|---|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match | Tap 0.1 s: 15 at 0.20 s at 6 m; Empowered 0.6 s: 30; Supercharged 1.15 s: 60; overdraw 1.65 s: half. Shots at least 0.60 s apart at 0.1 s press steps (rate 0.5); perfect window opens at +0 and closes by +0.19 s (+0.13 s counts). **match** |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) | A 0.1 s tap loosens nothing and costs no charge; 0.6 s hold 23, full 1.1 s 30, wall pin 178 on the shot (173 extra, 4.94x); stun 1.2 s; cd 16 s; 38% speed while held. Gap 6 closed. **match** |
| Q | none | glove | ours | not measured (ours) |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match | First tick 0.38 s (tell 0.35), 5 per tick, 8 ticks in 4.4 s at 0.52 s (gap C); slow 35%, cd 15 s. **match** |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match | First beam 0.90 s after the press and fire held (nock 0.5); 18, 18, 25 (finisher under 12%), 1.52 s apart (footage 1.5), cd 60 s. **match** |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) | Roll 3.03 m, 98% by 0.37 s (data 3.0/.27), cd 9.5 s; Spirit Walk passes rocks and terrace walls (combo PASS). Gap 8 closed on terraces. dash-flow rows 0 fail. **match** |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open | Hawk Sense shows only the injured (PASS); Focus and Deadeye cut. **match** |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage | Draw, loose, perfect, overdraw, Heavy and ult clips all PASS by name. **match** |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 | Draw and hold carry through a dash, jump out in 0.1 s (item 51 PASS). **match** |

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
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45) | match on coverage |

## Tarek (`dolm`, source Tetra)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Tap boulder; hold punch launches rocks, .6 s [D] | Boulder .6, punch .7/.6 | match |
| RMB | Hold slam, centre stun, jump to leap, 11 s [D] | hold .2, cd 11, glide slam built | match |
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
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight, 2x damage while skating | match; skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) |
| Dash | Hold, release stops, 13 s [D] | 11.5 m/s (F 10-11), 1.6 s, early-release refund .6 (owner) | match; refund owner |
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
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 35% (owner 11-08 +17%; source gives no drift), moves foes and allies (counters both) | match |
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
| Passive | Wall knock Stuns [D] | Crushed stun built; the invented Guard meter and Shield Slam are **cut** (gap 15, owner 2026-11-07) | match |
| Anim | Footage poses | 17 moves, all on `breaker.glb` (48) | match on coverage |

## Ryzz (`mage`, source Joule)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt + Static, F .8 s [D,F] | .648, range 13, no pierce | differ (owner items 70, 116) |
| RMB | Hold/release, knock, orb, 10 s [D] | Hold 1.0, cd 8 | match; 0.8x cd |
| Q | none | glove | ours |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Drag built, delay .8, stacks 1, cd 10.5 | match |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 7.5-13 m at 40 m/s (owner), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) |
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
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, air 8.4 m/.95 s (F), off the dash feel, prime 2.34x, cd 4.5 | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` |
| Anim | Footage poses | 17 moves, all on `sable.glb` (47) | match on coverage |

## Starter trio re-check: Vex, Kael, Lace (2026-11-10, ext/release-integ-0244-fix ec3c9dafb)

DECISIONS 2026-11-10: the first pick is Lace, Kael or Vex, so every new player touches these three. The last column of the three hero tables above is the re-measure, run in the Training Area (`Match.start({"training": true})`, a 10000 HP dummy, a clean `XDG_DATA_HOME`). The base is the release integration branch, not main: main has no `--kit-parity-check` or parity bench yet.

**Method.** Each number is read from the dummy's HP over 60 Hz steps (first hit after the press, hit sizes, gaps) and from the kit's cooldown table; dashes are the hunter's travel with no keys held, aimed along +x. The same driver was run on origin/main d255acbee: every LMB, RMB, E and R number is identical there, so the integration broke none of them. The only changes are the dash lengths (the merged dash-feel pass: Vex tap 4.32 to 4.85 m, Lace 3.35 to 3.03 m, Kael 3.99 to 4.14 m), all toward the sourced figures. `--parity-bench-check` 19 ok, 0 FAIL; the bench panel reads the same hit and status events.

**Cancels and buffers (docs/heroes/dash_interactions.md).** `--dash-flow-check` 0 failures (140 rows for the three, 14 skipped for all heroes). Kael: ground and air dash into LMB buffer to the dash's end (0.02 s after it), RMB fires mid ground dash and cancels the air dash into the Meteor Drop, E fires mid-dash and cancels out with Shift, X cancels the dash. Vex: every pair fires mid-dash, LMB, RMB, E and X keep running into a dash. Lace: every slot fires mid-dash, the draw carries through a dash, a jump or a hold lets go in the air.

**Owner notes.**
- Kael's Warchain: PASS. The chain pays out to 24 m as he backs away and holds taut there, the pull bends with a strafe or a look and slings when he backs away (combo check "jug chain").
- Kael RMB: PASS. Held 5 s it never fires; a release on the flash flings about 18% further (7.8 against 6.6 m).
- Lace's missed arrows linger: PASS. A spent arrow stays stuck in the ground at the cursor (`pin vfx` check).
- Vex Coin Blast and Palm Lance: **not on this branch**, gap A.

**Gaps, none an integration regression.**
- **A. Vex Coin Blast / Palm Lance (owner 11-08).** `content/archetypes/gunslinger.json:59` still "Burr Charge", `:92` still "Longneedle", fired from the rifle. The work is READY as ext/vex-coin-palm-1108 `0478765f6` (9 commits on ext/vfx-gunslinger) and was never merged into the integration or main.
- **B. Vex hold slide is 10.3 m, not 7.** `scripts/arch/kits/gunslinger_kit.gd:369-372`: a held Shift joins the slide at the tap's 0.18 s mark, after the skid has already gone about 3.2 m; `:392` then adds the data's 7 m. Main did the same (9.1 m). Source length for a hold `[?]`; decide whether the 7 m includes the skid.
- **C. Zone ticks run 0.52 s, not 0.5.** `scripts/arch/kits/gunslinger_ult.gd:181-183` (Cinderfall) and `scripts/arch/kits/archer_kit.gd:401-404` (Hail Wall) reset the tick timer and drop the remainder, so 0.5 s costs 31 frames. 3% slow, same on main. Keep the remainder (`+= every`) in both.

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
| Albert | Crush (any knock into a wall): stun **1.0 s** (was 0.5), 8 damage; full Crushing Blow stun 0.4 s | "Knocked into a wall, Stuns"; STUNNED label up about 1 s or more [F] | **fixed**: 0.5 to 1.0 s. the blow's stun is ours (no source row); the Shield Slam is cut |
| Ryzz | Storm Rod wall stun 0.8 s; Skycall Grounded 1.5 s | Stun on a wall or second target [D]; Grounded 1.5 s or more [F] | match |
| Sable | Bola: first foe Grounded 1.5 s and slowed 30% (owner item 53); a pair stun 0.9 s; Shadow Knife slow 50% 2.5 s | Grounded, rings about 1.5 bh [F]; pair "Stunned", the label showed about 1.8 s [F]; knife "Slows" | match for Ground and slow; pair stun 0.9 vs 1.8 is noted in `docs/heroes/thief.md` as an owner pacing call, kept |

**Fixed in this change (1):** Albert's Crush stun 0.5 to 1.0 s (`content/archetypes/bulwark.json` `resource.crush_stun`, text and docs), asserted by `combo bulwark: a Crush stuns 1.0 s` in `--bulwark-combo-check`.

**Suggestions, not built (PARITY FIRST):**
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow).
- Albert: the Crushing Blow stun 0.4 s has no source row.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s.

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
| Claire | Skate 11.5 m/s, up to 1.6 s | same | F speed | none (not a travel) | as raw | as raw |
| Ostra | lob 12 m, 1.8 s | same | F time | none (not a travel) | as raw | as raw |
| Bjorn | 3.5 m/.17 s whirl | 4.2 m/.3 s lumber | F whirl | ×1 | 3.5 m/.17 s | 4.2 m/.3 s |
| Ryzz | lane 5.6-9.75 m at 40 m/s | same | no (owner item 70, lane cut 11-10) | time ×1.15 | 5.6-9.75 m at ~35 m/s | same |
| Sable | 4.5 m/.48 s | the ground one with a charge (item 183) | F | ×1 | 4.5 m/.48 s | 4.5 m/.48 s, then the air's drag |

On a ×1 kit every Shift move runs its raw numbers, including the moves with no source figure: Bjorn's Shield Charge (4.2 m at 18 m/s), his short dash during the wind-up and his lumber, Vex's long dash and Hem's flick are now about 18% longer and 13% quicker than before.

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
| 15 | Done: Bjorn's Guard meter and Shield Slam are cut (owner, DECISIONS 2026-11-07); Shift behind the shield is the source's Shield Charge bash, Crushed wall stun kept | none | asserted in --archer-bulwark-combo-check, --kit-parity-check | done |
| 16 | Claire's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows have no source `[?]` (Hem 8, Ryzz 5, Tarek 6), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |

## Item 20: jump speed and the unsourced flow rows

**Jump speed.** Source: JumpZVelocity 750 uu/s = 7.5 m/s at gravity 14.7 m/s² (supervive_physics.md:45, [D]). Ours: `Hunter.JUMP_V` 6.8 m/s. Kept on purpose (`docs/MOVEMENT_FEEL.md`, "Jump 9 → 6.8"): 7.5 lets jump plus mantle top four terraces. It is a map-grammar deviation, not a source value; the owner can flip it once the terraces change. `--move-feel-check` now asserts `jump_speed_vs_source` (lift-off over 7.5, must sit in 0.85 to 1.0), so the source number is pinned and the gap cannot drift.

**Dash-flow rows with no `source` field `[?]`.** No source or footage settles these; they run as the kit's default (`keep`, or `fire` for Q). Not guessed.

| Hero | Rows `[?]` |
|---|---|
| Hem (`archer`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`; Q is ours, no source exists) |
| Ryzz (`mage`) | `hold.rmb.{ground,air,jump}` (3, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`, ours) |
| Tarek (`dolm`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) |

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
