# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07)

**Refresh 2026-11-09 (main d255acbee):** the Vex, Kael, Lace, Cinder, Meeko and Tenzo tables below were re-checked row by row against main and use the canon display names (briefs/DECISIONS.md, ids unchanged). A closed gap names the commit that closed it; `pending ext/<branch>` is a READY branch not yet on main that would close or move the row. The other six tables and the top-20 list below are still the 7907d9afe text and use the old names.

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only: no game code changed.
PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only for the first audit; the ranges table below changed four numbers (data only).

**How to read a verdict.** `match`: same mechanic, within footage error. `differ`: built, not the same (says how). `missing`: not built. `differ (owner)`: an owner note overrides the source, so it stays unless the owner reverses it; not a gap. `ours`: not in the source at all.

**Evidence:** [D] game data (supervive_kits.md, supervive_physics.md), [F] footage (briefs/hero-ref), [O] owner note. Order of trust: O > D > wiki > F. Source references live only on `origin/ext/agent-briefs` (briefs/supervive-data, briefs/hero-ref, briefs/specs/kit-audit).

**What was and was not verified.**
- Numbers, modes and code paths were read from main. The Nov 3 audit (briefs/specs/kit-audit) is stale: many of its gaps are closed, and rows here were re-checked against main before use. `ext/online-displace` and `ext/no-shake` are merged, so the online pull bug and self-shake are closed.
- All 12 `--<hero>-combo-check` runs pass: 1,560 PASS, 0 FAIL. They assert our spec, not the source, so a pass is not parity proof.
- **Animation timing was not re-measured frame by frame.** Animation rows report clip coverage (computed from kit code, `warden_anim/*.json` and each GLB) plus timings already recorded in docs/heroes. Hitbox rows use content numbers; no in-game overlay run was done.
- `[?]` marks a row carried from a hero doc that I could not settle from code here.

Heals, shields, knock heals and Anti-Heal are tabulated in [HEAL_PARITY.md](HEAL_PARITY.md).

**Every Hunter, shared:**
- **Q:** ours (a glove, gear slot, with V). Not in the source, so no parity target. DashFlow fires it through dashes.
- **Glove band:** gloves must not outshine the kits' E. `--glove-band-check` holds every glove at every rarity to the 12 E abilities' maximum for damage per cooldown second (4.38), CC seconds per cast (4.4) and travel metres per cast (14). Launch gloves keep their numbers in content `launch` (m/s, m). Gust's forward launch went 9 to 7.5 m/s (15.9 to 13.3 m, over Thief's 14 m blink-to-knife before).
- **Keys:** R = hunter ult (JSON slot `x`), X = Fuse, G = Boki (owner).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** match since the source brake 22.2 + friction 2, air control 0.015 and a dash that exits at run speed (bc1a70608, 4071fe66a; gaps 2 to 4 closed). **Jump:** 6.8 kept over 7.5 on purpose and pinned (0f70d1a8a). **Glide dive:** built (280404102, gap 18).
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
| Kael | RMB air slam disc, reach | **2.2** (was 2.6), 5 | 1.2 bh (2.16), cursor to ~5 | **fixed** |
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
| Sparkle | E radius, reach, slide | 1.5, 11, 3.4 | circle ~2 bh across (radius 1.8), -, ~4 bh (7.2) | differ 17% and 53%, kept: mage.md set 1.5 as the hit on purpose; [?] |
| Sparkle | R radius, range | 2.7, 14.4 | ring 1.5 bh (2.7), 8 bh | match |
| Sable | RMB range, lane | 7 + 3.8, **1.8 wide** (was 1.4) | lane 5.5-6 bh (9.9-10.8), 1 bh wide (1.8) | **fixed** (width) |
| Sable | E range | 14 | landed at 9 bh (16.2), max not seen | [?] |
| Sable | R ring | 5.4 (rim band outer 25%) | 3 bh (5.4); the first sheet's 3.5 bh is superseded | match |

Left alone and why, for the owner: Kael lunge (owner), Vex needle width (owner item 68), Cinder flight (owner item 20), Tenzo ridge (deliberate narrowing, source 10-12 bh), Sparkle Skycall circle (deliberate). Ideas of ours stay out of the build.

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s (no reload pause), damage 100% to 50% over 10 rounds then flat, tracer/flash/impact thin with it (to 40%), string resets after the 0.35 s rest | match; the wiki gives mag 30 and the decay only, "rapidly reloads when not firing" is game data, the refill rate is ours |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | `quill_rifle.json`: rate 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain (half punch after), Dazed +90% | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Burr Charge from the launcher, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |

## Kael (`juggernaut`, source Brall) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Rate .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; ground dash→LMB still buffers, now cited: the dash is his attack [D] (gap 9, 4e788af65 left it) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) |
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D]; Lunge ~2.5-3 bh = 4.5-5.4 m [F] | cd 2.0, hold .3, lunge 4.5-5.4 m (+20% perfect), levelled-blade pose | match; perfect release differs (owner) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape |
| Anim | Full set | 20 moves, all on `kael.glb` clips (49) via `warden_anim/kael.json` | match on coverage; **closed** (gap 1): 3419a661a (merged a4e410361) |

## Lace (`archer`, source Myth) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect (0.15 s) → quick draw | match |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .15 (was .5), wall pin 4.94x the shot, stun 1.2, cd 16 | match; **closed** (gaps 6, 7): 4aa011a49 |
| Q | none | glove | ours |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match |
| R | 3 empowered shots, no charge, 60 s [D] | 3 travelling arrows (90 m/s, dfaeae389), window 6 s, nock .5, recover 1.0 (97ffe28a9), cd 60 | match |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | 3.5 m/.24 s raw, ×.85/×1.15 feel, 2.8 s walk; rocks, trees, barriers pass, terrain ledges still stop it | differ; pending `ext/parity-phasewalk-rebased` 2178ea313 (raised terrain passes, ending inside snaps back; gap 8) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m, `climb_tall` | match; **closed** (gap 5): Focus/Deadeye cut, ffa20b0f7 |
| Anim | Footage poses | 17 moves, all on `hem.glb` (48 clips) | match on coverage |
| Flow | Silent on shooting in the walk [F] | Dash→LMB `fire` (4e788af65); 8 of 17 rows unsourced `[?]` (hold.lmb/rmb × 3, Q × 2) | match; sources open (item 20 below) |
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
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | Ground 3.4 m/.33 s, air poof 6.8 m/.28 s, both off the global feel (`dash_feel.json`), stops on foe, 2 charges | match; **closed** (gap 11): 2f24ae36b |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41 clips) | match on coverage |
| Flow | Silent | Dash→LMB `fire` (4e788af65); RMB, E (ground) buffer and X cancels, each cited | match |

## Meeko (`tender`, source Elluna)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Ramp per hit; idle shot Empowered [D] | Rate .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D] | Burrseed: wind-up 1.0, seed delay .7, root 1.1, range 14, cd 10.5 | differ `[?]` motion; pending `ext/meeko-rmb-verify` eba7147eb (checked vs footage: press to seed ~0.36 s, root 1.1 s match; cd 10.5 vs 11.5 and tap vs hold-aim stay open) |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered = cue only (no range, no refund) | match; Empowered effect is not in the source, our rider removed |
| RMB | Shot, delayed Root, 11.5 s [D] | Hop form, windup 1.0, cd 10.5 | differ `[?]` motion |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, no self factor | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, raw 4.2 m/.174 s and 13.3 m/.95 s, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2, a hit or stun drops them, lock 4 s; Carrier shield removed | match; **closed** (gap 19, Meeko's share): 3bcb50eca |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45 clips) | match on coverage |
| Flow | Silent | Dash→LMB buffers (cited), RMB, E, X, Q `fire`; 3 `keep` rows unsourced `[?]` | pending `ext/flow-rows-source` dd2c83be5 |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45) | match on coverage |

## Tenzo (`dolm`, source Tetra)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Tap boulder; hold punch launches rocks, .6 s [D] | Boulder .6, punch .7 (step .6) | match |
| RMB | Hold slam, centre stun, jump to leap, 11 s [D] | Hold .2, cd 11, glide slam at 32.5 m/s | match |
| Q | none | glove | ours |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Stone Row, cd 12.5; an ally jumping against a rock hops it, walking and foes are stopped (`--dolm-combo-check`) | match; **closed** (gap 14): 5968c387e; the audit missed it |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; an ally in the air hops a Tenzo rock, a foe is stopped (`StoneStand`) | match (gap 14 closed) |
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Molten Guard, built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48 clips) | match on coverage; hand polish pending `ext/anim-hand-tenzo` f44d76294 |
| Flow | Silent | Dash→LMB, →RMB, air LMB `fire` (4e788af65); 6 `keep` rows unsourced `[?]` | match; sources open |
| Passive | Punching rocks grants Shield [D] | Built; shield 18 flat (the data has no number); punch 10.6 flat, no charge scaling (removed 11-09) | match |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48) | match on coverage |

## Grimble (`dredge`, source Kingpin)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D]; ~30 degree fan, 20 rested, recovering between shots [F] | 20 degrees rested, +10 a shot to 35, breathes back 24/s from 0.1 s; edge lines breathe with it | match (Nov 8: the bloom never recovered while firing and rested at 30) |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain (0.1 s wind, whip 45.5 m/s slowing, 0.4 s out), hook r .36, reel, 20% braced shuffle, cd 12 | match; 0.67x cd |
| LMB | 7 slugs, bloom [D] | Seven-slug blast, slugs hang at 6.3 m, bloom folds back 0.7 s after the last shot | match |
| RMB | Arm pierces terrain, pulls first target (enemy or ally), scoops Wisps, 18 s [D] | Abyssal Hand: 11.5 m through rocks and cliffs (a placed wall stops it), reel, braced shuffle at 1/5 walk, ally and Wisps caught, cd 12 | match; 0.67x cd (gap 10) |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Anchor Drop: windup .38, r 3, 25 dmg, stun 1.1, air dive ring 3.2 m, rank 3 double over the abyss, cd 7, Grounded (ours) | match; **0.58x cd** (gap 10) |
| R | Two waves, 36 s [D] | Brass Broadside: charge 1.1, 2 waves of 6 slugs, 4 dmg + Anti-Heal 3 s, cd 21 | match; **0.58x cd** (gap 10) |
| Dash | One every 7 s; own air slot 12.5 s [D] | Barge: 3 chained shoves, cd 10. Air pounce 35% further, 3.7 m with the dash feel applied once, **own 12.5 s slot, 2 s less per rank** | differ (owner): 3 charges, cd 10 vs 7. Air slot closed `0a5b33f48`, double scale closed `2f24ae36b` |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5% each, lose 1 on down, knock heals 16%; hits on a back +50% (ours) | match; back bonus ours |
| Anim | Footage poses | 13 moves plus the fusion move, all on `dredge.glb` (40 clips); hook-arm v2 model `315cdf2af` | match on coverage |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, no Grounded (removed 11-09, the source dunk is the abyss bonus) | match; **0.58x cd** |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air shares slot | differ (owner); air slot missing (gap 13) |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Neve (`rimewright`, source Celeste)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large darts; they leave along the aim, then curve onto the foe at the cursor over 35 to 70% of the flight. **Skating beams home the same way** after leaving straight on the aim | match; gap 16 closed `e5c73480c` (bend assert pending `ext/parity-neve-skate-home` 9b65ea7f1) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Ice Spear: pushed out to the cursor (12 m), 18 dmg, 2.2 m slow zone 35%, bursts 60 at 1.8 s, 2 charges, cd 10.2 | differ (owner: push-like release); 0.85x cd |
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight, 2x damage while skating | match; skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) |
| Dash | Hold, release stops, 13 s [D] | 11.5 m/s (F 10-11), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Chill + 15% slow (ours) | differ: slow ours |
| Anim | Footage poses | 19 moves, all on `claire.glb` (49) | match on coverage |
| Body | 1.1-1.15 [F] | size 1.15 | match |
| E | Wall pushes, recast freezes, 20 s [D] | Rink Wall: 0.2 s tell, slides 4.5 to 16.2 m, grows 1.8 to 4.5 m, 70 HP, E again freezes 6 s, cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Rimelock: hold 3.5, skate carry .8 (owner), 40 dmg + 0.75 s stun, early recast cancels, cd 80 | match |
| Dash | Hold, release stops, 13 s; ice islands over the abyss [D] | Skate 11.5 m/s (F 10 to 11), up to 1.6 s, early-release refund .6 (owner), ice ribbon in the air, cd 13 | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Hoarfrost: Chill 4 s, 8 darts shatter, knock shatters. **Chill slow removed** | match; closed `3bcb50eca` |
| Anim | Footage poses | 19 moves plus the fusion move, all on `claire.glb` (49 clips); v2 model `59ac7b48d` | match on coverage |
| Body | 1.1 to 1.15 [F] | size 1.014 (1.56 m, owner height chart `4538174a8`) | differ (owner) |

## Motley (`ostra`, source Void)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Orb; idle next orb stronger, terrain, Slow [D] | Tether Lantern: 9 dmg every 0.6 s, 14 m; waiting up to 1.4 s makes the next +34% with a Slow; every orb pierces terrain | differ (owner items 60, 117; data overruled) |
| RMB | Shards, stun, 10 s [D] | Shard Snap: wind-up .32 vs .2, 13 m, stun .8 to 1.8 s by flight, cd 10 | differ (owner item 40) |
| Q | none | glove | ours |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.5, waits at full size until popped, no timer; cooldown on the plant [?] | match (the fizzle is removed) |
| R | Vortex stun + pull, 70 s [D] | Tell 1.0, 3.5 s, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 35% (owner 11-08 +17%; source gives no drift), moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; floating `[?]` |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 30%, moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; float = no footsteps + ground hazards pass him [D] (wiki: water/sand, none on our maps); no gap hover, slower fall or landing change in any source, so none built |
| Anim | Footage poses | 14 moves, all on `ostra.glb` (45) | match on coverage |
| E | Bomb grows, reactivate, up to 3.5x [D] | Brimseed: grows 6.5 s, 12.5 dmg up to **3.5x**, fizzles 10 s (ours), cd 10 vs 8 | match; peak closed `5b9a528d2`; fizzle ours |
| R | Vortex stun + pull, 70 s [D] | Nightwell: tell 1.0, 3.5 s, r 3.6, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, faster when Empowered [D] | Lantern Trade: 12 m lob, 1.8 s (Swollen 1.25 s), drift 30%, moves foes and allies, cd 9.5 | match |
| Passive | Damage Empowers; floats [D] | Swell fills Swollen 9 s; floats, ground hazards turn him away (`hazards_dodged`) | match; footstep silence `[?]` |
| Anim | Footage poses | 15 moves plus the fusion move, all on `ostra.glb` (45 clips); v2 model `76f589389` | match on coverage |

## Albert (`bulwark`, source Oath)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Throw + recall; hold charged swing [D] | Tap throws and recalls (cadence **.45**), hold is the source's wind-up, swing 36 to 66. Owner-kept: walks 55% while charging (#59), 1.5 to 1.8 m step + 4 m perfect launch (#30, #49) | match; riders differ (owner). Cadence `1eecee8c3`, hold `e625aa8e0`, hold-walk assert `9c336682d` |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | Aegis hold .1, 160 HP, Shield Charge on Shift, cd 6 | match; routing `[?]` |
| Q | none | glove | ours |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | Mending Ground: r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | Faultline: 4 cells, stun .5, cd 40 | match; 0.8x cd |
| Dash | Spin Dash 8 s, knock [D] | 360 Smash 3.5 m, cd 8 | match |
| Passive | Wall knock Stuns [D] | Crushed built. **Guard meter and Shield Slam still on main** | differ (gap 15): pending `ext/parity-bulwark-guardcut` b2e942eb4 (also in `ext/misc-ready-integ` 55446e046) |
| Anim | Footage poses | 17 moves plus the fusion move, all on `breaker.glb` (48 clips) | match on coverage |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | 4 cells, stun .5, cd 40 | match; 0.8x cd |
| Dash | Spin Dash 8 s, knock [D] | Whirl 3.5 m/.17 s (F), off the dash feel, cd 8 | match |
| Passive | Wall knock Stuns [D] | Built; **Guard meter, Shield Slam invented** | differ (gap 15); owner question open |
| Anim | Footage poses | 17 moves, all on `breaker.glb` (48) | match on coverage |

## Sparkle (`mage`, source Joule)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt + Static, F .8 s [D,F] | Coilcaster: 12 dmg every .648 s, 13 m, stops on first foe, 1 Static | differ (owner items 70, 116) |
| RMB | Hold/release, knock, orb, 10 s [D] | Storm Rod: hold 1.0 (tap .33), 18 to 30 dmg, knock, stun on wall .8, 1 Static, charge orb, cd 8 | match; 0.8x cd |
| Q | none | glove | ours |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Skycall: delay .8, 20 dmg, slide 3.4, drag built, 1 Static, cd 10.5 | match; 0.88x cd |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Kitefall: hover 1.7, crash 22, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Wirerun 40 m/s vs ~32 (owner), lane 7.5 to 13 m, dmg 20, Blowout reset, cd 8 | differ (owner) |
| Passive | Static, 4 stacks [D] | Static 4 stacks, 4.5 s, orb pickup resets Wirerun (items 71, 74) | match |
| Anim | Footage poses | 16 moves plus the fusion move, all on `ryzz.glb` (45 clips); v2 model `6355dee78` | match on coverage |
| Flow | Silent | Dash→LMB fires mid-dash (closed `4e788af65`); X row `[?]` | match; X unsourced |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Drag built, delay .8, stacks 1, cd 10.5 | match |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 7.5-13 m at 40 m/s (owner), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) |
| Passive | Static, 4 stacks [D] | Built, orb reset closed by owner | match |
| Anim | Footage poses | 16 moves, all on `ryzz.glb` (45) | match on coverage |
| Flow | Silent | Dash→LMB, X buffer | gap 9 |

## Sable (`thief`, source Shiv)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt, stacks passive [D] | Arc Shots .45, to the cursor, 12 m, 13 dmg | match; range unconfirmed |
| RMB | Bolas, Ground, two targets stun, 13 s [D] | Bola: 7 m, Ground 1.5 s, slow 30% (owner item 53), two foes stun .9 + 13, cd 7 | differ (owner); **0.54x cd** (gap 10) |
| Q | none | glove | ours |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, wall refund .25, foe .5, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore: r 2.3 to 5.4, rim band blights, 10 blades in 2 s, gives the Vault back, cd 24 | match; **0.48x cd** (gap 10) |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | Vault 4.5 m/.48 s (8.4 m from a jump), next shot 2.34x + 2 Marks, landing it resets, cd 4.5, off dash_feel | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks +10% each (16 of the 160 shot), no cap; knock heals 15% extra. **Shred gone** | match; closed `3bcb50eca` (stale text only) |
| Anim | Footage poses | 17 moves plus the fusion move, all on `sable.glb` (47 clips); v2 model `1c5d44fac` | match on coverage |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, air 8.4 m/.95 s (F), off the dash feel, prime 2.34x, cd 4.5 | match |
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
| Sable | Bola: first foe Grounded 1.5 s and slowed 30% (owner item 53); a pair stun 0.9 s; Shadow Knife slow 50% 2.5 s | Grounded, rings about 1.5 bh [F]; pair "Stunned", the label showed about 1.8 s [F]; knife "Slows" | match for Ground and slow; pair stun 0.9 vs 1.8 is noted in `docs/heroes/thief.md` as an owner pacing call, kept |

**Fixed in this change (1):** Albert's Crush stun 0.5 to 1.0 s (`content/archetypes/bulwark.json` `resource.crush_stun`, text and docs), asserted by `combo bulwark: a Crush stuns 1.0 s` in `--bulwark-combo-check`.

**Suggestions, not built (PARITY FIRST):**
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow).
- Albert: the Shield Slam stun 0.6 s and the Crushing Blow stun 0.4 s have no source row.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s.
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, prime 2.34x, cd 4.5, excluded from dash_feel; reset on the empowered hit, Encore, Knife in a foe at rank 3 (`vault_back`: charges and long dash) | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks: flat 10% of the bolt per LMB hit (16 on 160), no cap, 4 s (assumed); empowered hit 2 (owner); Bola and dagger add none | match; duration and decay unsourced; Shred gone |
| Anim | Footage poses | 17 moves, all on `sable.glb` (47) | match on coverage |

## Damage over time: tick parity (ext/parity-dot-ticks)

One shared path: `Ent.tick_status` (Ignite and every other burn, whole hits every `BURN_EVERY` 0.5 s, the number shows the same hit) and `Fields` (zones). Each hit's number is the hit. Trust order O > D > wiki > F; ours scales the data by the hero's own anchor (hose, shell, orb) or by class HP.

| Source | Data / footage | Ours | Verdict |
|---|---|---|---|
| Cinder Ignite (DoT) | D: "dealing damage Ignites"; F: ticks about every 0.5 s, two stages (24 / 47) | 2% then 4% of max HP a second for 3 s; was a hit every frame; now 6 whole hits at 0.5 s. A new Ignite refreshes the time and replaces the rate; burn ignores shields | fixed (tick); no data on shields |
| Cinder Flue Flight carpet | D: 239.2 dmg/s + Slow (hose 258) | 25 a second against the hose's 27, 0.1 s ticks, a re-entry or a second cast does not double it (one hit per foe per tick); was 4.5 a second every 0.3 s | fixed |
| Vex Cinderfall patch | D: 59 dmg/s for 3 s after a 203 impact; F: ticks 0.4-0.5 s | 3.5 every 0.5 s (24 impact); two shells each tick on their own; was 3 | fixed (small) |
| Hem Hail Wall | D: 61 dmg/s + Slow + Anti-Heal on 1,100 HP | 3.4 every 0.5 s on 124 HP (same share); one wall at a time, a new one replaces it; was 5 | fixed |
| Ostra Nightwell | D (card): 2.5 every 0.1 s for 3.5 s | 0.16 every 0.1 s (the same share of our 9 orb); one well | match |
| Ostra seed (E) | D: upgrade IV, 250 dmg/s on overlap | 8.2 a second in 0.5 s hits (0.69 of the 12.5 blast, source 0.69 of 365) | match |
| Claire Rimelock and Chill | D: slowing zone, Shatter stacks, then 155 and a stun; Chill has no damage | slow ramp, one hit at the end; Chill is a mark | no DoT in either |
| Bjorn zone | D: Regen Field heals | heal ticks 0.5 s | heal only |
| Ryzz Static | D: stacks, a burst on the dash | stacks, a burst | no DoT in either |
| Grimble, Sable, Pip, Tarek zones | no damage zone in the source | none (Pip's are heals) | none |
| Zedran wave burn | not in the source | 8 over 2 s | ours |
| Items, gear | no burns in the source's items; ours: none | none | none |

Tick numbers under 0.5 (Nightwell's 0.16) show no floating number: `Fx.number` drops hits under 0.5. Existing per-kit timers kept (Flue Flight, Cinderfall, Hail Wall, Nightwell): moving them onto `Fields` is a larger change.

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
| 14 | Tarek's allies can't hop his rocks | Closed: an ally hops them (`--dolm-combo-check`, "hop rocks") | stone_stand.gd | done |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner |
| 16 | Claire's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows had no source `[?]` (Hem 8, Ryzz 5, Tarek 6): 1 settled by Breah's footage, 14 now cite what was checked as "Not determinable", the 4 Q rows stay ours | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |
**Status** (Nov 9, checked against origin/main d255acbee): `closed <sha>` is on main, `pending ext/<branch>` is a READY branch not yet merged, `open` has neither. The Grimble, Neve, Motley, Albert, Sparkle and Sable tables above were re-checked the same day (canon names, ids unchanged).

| # | Gap | Fix | Files | Effort | Status |
|---|---|---|---|---|---|
| 1 | Kael has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L | closed `ca52dc648` (Kael v2 model, 49 clips, `warden_anim/kael.json`; `ext/parity-kael-clips` is superseded) |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M | closed `64e6c681f` (brake 22.2, friction 2) |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M | closed `64e6c681f` (air control 0.015) |
| 4 | Dashes stop dead: keep 15%/30% vs carry; global ×.85/×1.15 | Raise carry; drop scale where kit numbers already match | hunter.gd, content/rules/dash_feel.json | M | closed `64e6c681f` (dash exits at run speed), `2f24ae36b` (single dash scale) |
| 5 | Lace's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner | closed `ffa20b0f7` (Focus and Deadeye cut) |
| 6 | Lace's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S | closed `4aa011a49` (wall pin 4.94x) |
| 7 | Lace's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S | closed `4aa011a49` (dead zone 0.15 s) |
| 8 | Lace's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L | pending `ext/parity-phasewalk-rebased` 2178ea313 |
| 9 | Dash→LMB buffers on 6 kits (Lace, Albert, Kael, Cinder, Sparkle, Tenzo air), and Kael, Albert and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S | closed `4e788af65` (Zedran, Albert keep buffer/cancel as sourced) |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner | open (`ext/parity-cooldowns` 69c9753c5 exists, no READY; DECISIONS default is 1.0x, main still 0.48x to 1.0x) |
| 11 | Cinder's dash is short: ground felt 2.9 m vs 3.4 m; his and Grimble's air dashes apply feel twice (likely bug) | Exempt or raise ground; scale air once (Kael already undoes it, `juggernaut_kit.gd:826`) | ashwick_kit.gd:521, dredge_kit.gd:684, ashwick.json | S | closed `2f24ae36b` |
| 12 | Albert's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S | closed `1eecee8c3` (cadence .45); hold-walk kept per owner #59, asserted `9c336682d` |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M | closed `0a5b33f48` |
| 14 | Tenzo's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner | closed `eb93c5b62` (already on main at the audit; bots hopping pending `ext/tenzo-ally-hop` 618098895) |
| 15 | Albert's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner | pending `ext/parity-bulwark-guardcut` b2e942eb4 (also in `ext/misc-ready-integ` 55446e046) |
| 16 | Neve's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner | closed `e5c73480c` (darts and skating beams home late; bend assert pending `ext/parity-neve-skate-home` 9b65ea7f1) |
| 17 | Motley's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S | closed `5b9a528d2` |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M | closed `45f26a5b5` (dive numbers asserted; key is ours) |
| 19 | Ours-only riders: Chill slow, Shred, Meeko's shield | Remove, or owner keeps | kit JSON, kits | S, owner | closed `3bcb50eca` (Chill slow, Meeko's shield out; Shred was already gone) |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows have no source `[?]` (Lace 8, Sparkle 5, Tenzo 6), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S | closed `0f70d1a8a` (jump pinned, 6.8 kept on purpose); source notes on the hold rows pending `ext/flow-rows-source` dd2c83be5 |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 55 dash-flow rows are `[?]` (no source, or "Not determinable"), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S |

## Item 20: jump speed and the unsourced flow rows

**Jump speed.** Source: JumpZVelocity 750 uu/s = 7.5 m/s at gravity 14.7 m/s² (supervive_physics.md:45, [D]). Ours: `Hunter.JUMP_V` 6.8 m/s. Kept on purpose (`docs/MOVEMENT_FEEL.md`, "Jump 9 → 6.8"): 7.5 lets jump plus mantle top four terraces. It is a map-grammar deviation, not a source value; the owner can flip it once the terraces change. `--move-feel-check` now asserts `jump_speed_vs_source` (lift-off over 7.5, must sit in 0.85 to 1.0), so the source number is pinned and the gap cannot drift.

**Dash-flow rows marked `[?]`.** A row in `content/dash_flow` that exists but has no `source`, or whose `source` starts "Not determinable". No source or footage settles these; they run as the kit's default (`keep` for holds, `fire` for Q and the silent dash rows). Not guessed. `tools/gen_wiki.py` puts `[?]` at the start of each one's Source cell in `docs/heroes/dash_interactions.md` (a pair with no row stays empty), so both places list the same 55 rows (names as of 2026-11-09; `*` = already says "Not determinable"):

| Hero | Rows | Result |
|---|---|---|
| Lace (`archer`, Pin) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) | Not determinable, each `source` cites what was checked: pin.md:33-47 (draw, walks while drawing, frames 0111-0116), :91-110 (Impaling charge, 0264-0269, 0494), :247 (open question 'whether you can shoot during it'), :322-334 (roll bare 0388-0389; air dash and jump not shown); supervive_kits.md:73-75, :78. Kept `keep`. Still `[?]` |
| Sparkle (`mage`, Vireo) | `hold.rmb.{ground,air,jump}` (3, `keep`) | Not determinable: vireo.md:80-94 (spear hold 1.2 s, she stood still, frames 0043-0049, 0057-0063, 0078-0084), :211-219 (spear thrown, then Surge), :386 (open question 5), :460-476, :503 (air Surge and jump not shown); supervive_kits.md:66-67. Kept `keep`. Still `[?]` |
| Tenzo (`dolm`, Breah) | `hold.rmb.jump` (1, `keep`) | **Sourced**: breah.md:114 (card frame 0240) 'when she jumps while charging, she leaps forward and the circle comes with her'; supervive_kits.md:106 'Jump while charging to leap forward'. The charge survives the jump, so `keep` is the source. No longer `[?]` |
| Tenzo (`dolm`) | `hold.rmb.{ground,air}`, `hold.lmb.{ground,air,jump}` (5, `keep`) | Not determinable: breah.md:71-82 (punch wind-up 0117-0124), :98-115 (charge, 0938-0958 is a punch pressed during a charge), :140-143 (dunk casts RMB after the dash), :145-158, :357 (open question 3), :361 (no transcript; the tip title 'Punch to Extend Dash/RMB' cannot be read), :433-449 (air dash 'not shown as a dash'); supervive_kits.md:105-106. Kept `keep`. Still `[?]` |

Left as ours: Hem (`archer`) `dash.ground.q`, `dash.air.q` and Ryzz (`mage`) `dash.ground.q`, `dash.air.q` (4, `fire`; Q is ours, no source exists).

Suggestion (not built): the Breah tip 'Punch to Extend Dash/RMB' may describe a held punch through a dash. Settle it with the spoken tip (whisper on breah/audio.wav) or a clip of a punch pressed in a Landslide; if it is a hold-through-dash, `hold.lmb.ground` stays `keep` and gains the source.
| Hero (id) | Rows `[?]` |
|---|---|
| Vex (`gunslinger`) | dash.ground.{rmb,e,x}\*, dash.air.{lmb,rmb,e,x}\* (7) |
| Kael (`juggernaut`) | hold.lmb.jump, hold.rmb.{ground,air,jump} (4) |
| Cinder (`ashwick`) | dash.ground.lmb\*, hold.rmb.{ground,air,jump} (4) |
| Meeko (`tender`) | hold.rmb.{ground,air,jump} (3) |
| Tenzo (`dolm`) | hold.lmb.{ground,air,jump}, hold.rmb.{ground,air,jump} (6) |
| Lace (`archer`) | dash.ground.lmb\*, dash.air.{lmb,rmb,e,x}\*, dash.{ground,air}.q (Q is ours), hold.lmb.{ground,air,jump}, hold.rmb.{ground,air,jump} (13) |
| Grimble (`dredge`) | dash.ground.lmb\* (1) |
| Neve (`rimewright`) | hold.rmb.{ground,air,jump} (3) |
| Sparkle (`mage`) | dash.{ground,air}.{lmb,rmb,e,x}\*, dash.{ground,air}.q (Q is ours), hold.rmb.{ground,air,jump} (13) |
| Albert (`bulwark`) | hold.lmb.jump (1) |

Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.

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
Dash -> LMB fires mid-dash for Lace, Sparkle, Cinder (both dashes) and Tenzo (air dash), where the source is silent (`--dash-flow-check` SOURCE_ROWS); Kael and Albert dash as the attack and buffer it; Grimble's ground row stays buffered (owner fallback) and his air pounce has its own row.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x} (all 13 re-checked 11-09 against the data, the pin/vireo frames, the cancel-matrix-a/b tables and the patch lines; none settled, each `source` says why in one line). Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows (Cinder 3, Kael 4, Albert 1, Neve 3, Meeko 3). Each now has a `source` that reads "Not determinable" and cites what was checked, so they stay `[?]`: Kael `hold.lmb.jump`, `hold.rmb.{ground,air,jump}` (juggernaut.md:41, :57-64, :75-83, :284, frames 0087, 0121-0127, 0141-0146, 0251-0300; supervive_kits.md:21-22); Cinder `hold.rmb.{ground,air,jump}` (linwick.md:57-58, :267-286, :323, frames 0073-0074, 0102-0103, 0131, 0143-0144, 0159-0161); Albert `hold.lmb.jump` (bjorn.md:74, :365-366, :398, frames 0116-0118, 0133-0146); Neve `hold.rmb.{ground,air,jump}` (tamsin.md:18, :294, :297-298, :332-334; the source spear is a tap); Meeko `hold.rmb.{ground,air,jump}` (mooshmoosh.md:63, :340, :346-366, :386-388, :453, frames f105-113). No press inside a dash and no hold carried through a dash or jump is visible in any of them, so no row's behaviour changed (all `keep`; every interaction chains). Not covered here: Claire, Pip, Grimble and the other heroes' rows.

## Ability shot and lane rules (job ext/parity-ability-pierce)

PARITY FIRST (owner decision 2026-11-07): for every ability projectile and lane (not LMB) of the 12 kits, the source says what it stops on; where it is silent, ours stays. The per-ability tables are the last section of each `docs/heroes/<id>.md`. The rules every shot shares (`Match._update_shots`, `_shot_targets`, `foes_of`):

- A shot stops on the first enemy hunter, enemy Boki or monster it touches, and passes allied hunters and Boki. It stops on terrain, rocks, domes and breakable props (which it smashes). A `pierce` shot (a `hitset`) hits each thing once and flies on; a `pierce_break` shot (only Starpiercer) also flies on through props. A lob sails over everyone and everything and lands where it was aimed.
- An instant lane (Longneedle, Faultline, Wirerun) goes through `Match.foes_of(team)`: enemy hunters that are not downed, enemy Boki that are not wild, and monsters.
- Placed walls (Tenzo's rocks, Neve's ice) are the placed-walls job's: what they block is not restated.
- Audit result: every row already matched the data and footage or is source-silent (kept) except Starpiercer on breakable props, now fixed (`pin ult prop`, `--archer-combo-check`).
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`. Re-checked 2026-11-09 (ext/dash-nd-rows-a) against data, footage and the wiki lines in the briefs: Vex `dash.air.lmb` is settled by the card's unqualified "can fire the rifle while sliding" plus the wiki's air tap (asserted in `--dash-flow-check`); Vex `dash.{ground,air}.{rmb,e,x}`, Cinder and Grimble `dash.ground.lmb` stay "Not determinable", each `source` says which lines and frames were read.

## Cooldown start (when it starts, how charges come back)

Sources: `supervive_kits.md` (tooltips: charges, "reactivate", "-x% CD on hit"), `docs/heroes/*.md` wiki rows, footage `vireo.md` (Surge: HUD shows 7 s while she still holds, so the cooldown starts on the press), `DASH_UI.md` (dash recharge is one charge at a time, the countdown restarts per charge). The sheets record no other cooldown overlay at 5 fps, so everything not listed below is "no evidence": ours stays the shared default.

**Shared rules in ours (the default every row below is measured against).**
- A cast starts its cooldown on the press that casts it: `ArchKit.use_e` (E), `HeroUlt.press` (X), `ArchKit.use_r` (R, at the fuse start), `Hunter.do_dash` / `ArchKit.spend_dash` (Shift). A recast, a channel or an end never moves it.
- RMB charges (`ch_rmb`) and dash charges (`Hunter.dashes`, a float) recharge one at a time: one timer runs, a spent charge does not wait for another, a charge spent mid-recharge keeps the progress already made. No kit recharges all at once, none restarts a running timer.
- A hold-and-release RMB spends at the release (`fire_rmb`), because its "cast" is the release in our kits.

| Hunter | Slot | Source says | Ours | Verdict |
|---|---|---|---|---|
| Vex | RMB, E, X | tooltips only; E "hunter hit -20% CD" (running from the cast) | press; E cut on hit | match |
| Vex | Shift | hold = longer dash on a longer CD | press, the hold takes 0.4 of a charge more at 0.18 s | match |
| Zedran | RMB | air slam is its own 9 s slot | `spend_air`, own slot; lunge doubles if nothing is struck | match |
| Zedran | E | wiki 07.01.25: starts on the pull or when the chain breaks, not the throw | `start_e_cd` on pull, break, miss, stun | match, asserted |
| Zedran | Shift | 3 charges, one at a time (footage) | float charges, one at a time | match |
| Hem | RMB | hold, release; no overlay | spends at the release | no evidence, see "Suggestions" |
| Hem | E, X | X "next 3 shots" | press; X on the cast (`archer.md`) | match |
| Cinder | RMB, E, X | "+1 charge" rank, no overlay | press at the release of the aim hold; charges one at a time | no evidence |
| Cinder | Shift | 2 charges | one at a time | match |
| Pip | RMB | plain shot in the source | owner item 118: 1 s wind-up, spends at the throw | owner note |
| Pip | E | "reactivate to throw the zone" | press; the throw does not touch it | no evidence |
| Pip | X, Shift, air dash | air dash own slot (14 s) | cast; two slots | match |
| Tarek | LMB | patch 2.01/2.04: Quake Punch cooldown starts at cast, not on release | **was on the release, now on the press** | fixed, asserted |
| Tarek | RMB | hold, release | spends at the release | no evidence, see "Suggestions" |
| Tarek | Shift | Landslide: one dash, no chain in the source | Rock Hop (owner item 111): spent on the press, recharge waits for the chain's end (`breah_hop`) | owner design |
| Grimble | RMB | -50% CD on an enemy hit (running from the cast) | press, half off on a hit | match |
| Grimble | E, X | press | press | match |
| Grimble | Shift | ground and air dash separate slots | `dash.air.cd` own slot | match |
| Claire | RMB | 2 charges, 12 s | `ch_rmb` 2, one at a time | match |
| Claire | E, X | "recast to freeze"; "reactivate to cancel" | press; recast/cancel do not touch it | no evidence |
| Claire | Shift | wiki: early release refunds part | press, refund on early release | match |
| Ostra | RMB, E, X | E "reactivate to detonate" | press at the plant; pop does not touch it | no evidence |
| Bjorn | RMB | aegis raise 0.1 s; Shield Bash own 6 s | raise free; Shield Charge spends the RMB slot's charge on the press | match |
| Bjorn | E, X, Shift | press | press; Spin Dash charges separate | match |
| Ryzz | Shift | footage: Surge starts on the press | spent on the press, a cancel keeps it spent | match, asserted |
| Ryzz | RMB, E, X | spear hold-release; X "reactivate" | RMB at the release; E, X press | no evidence |
| Sable | E | "refund 25% CD on terrain, 50% on a foe" (so it runs from the throw) | press at the throw, refund on hit | match |
| Sable | RMB, Shift, X | Quickflip reset on shot | press | match |

**Fixed (1).** Tarek's LMB Quake Punch: the cooldown (`lmb.boulder.rate`, 0.6 s, the card's value) now starts when the hold starts and the punch's own `rate` 0.7 is gone, so a long hold leaves no pause after the release (was 0.7 s). The boulder tap and the bot use the same start. Asserted in `--dolm-combo-check` ("cooldown: the punch's cooldown starts on the press").

**Suggestions, not built (parity first, evidence is by analogy).**
- Hold-and-release RMBs (Hem Heartpiercer, Ryzz Voltaic Spear, Tarek Volcano Crusher) may start on the press like Surge (footage) and the Punch (patch): a shared `ArchKit` rule would spend at the hold's start. Not built: no overlay shows these three, and a spend on the press needs a refund rule for a cancelled hold.
- Every multi-charge dash card reads "0.4 s between uses" (`DASH_UI.md` for Brall's 3 charges; `pin.md` reads a 0.4 s card next to a 9.5 s real cooldown). Ours has no such floor beyond the dash's own length (Rampage 0.17 s plus 0.07 s wind-up). Likely a global minimum gap; not built, it touches every dash.
- Our air dash is a second cooldown slot for every Hunter (`h.ex_cd`), and it also fires when the ground charges are out; the tooltips give a separate air slot only to Pip and Grimble. That is the air-dash rule (owner item 183, `ext/airdash-rule-audit`); left to that branch.
- Rock Hop's "nothing recharges during the chain" is ours; the source's Landslide recharges from the press.

## Recast windows (two-step abilities)

Each recast against [D] supervive_kits.md and [F] the hero-ref sheets: when the recast opens, how long it stays open, what
happens at the end, and when the cooldown starts (the cooldown rows are ext/cooldown-start-parity's). Owner items win.

| Hunter, recast | Source | Ours | Verdict |
|---|---|---|---|
| Motley (`ostra`) E Brimseed pop | from 0.3 s [F card]; grows 6.5 s [F]; end unread; cd on the plant | `min_recast` 0.3, grows 6.5 s, waits, fizzles 10 s at full; cd on the plant | match (fizzle ours, owner audit 8e5c63403) |
| Meeko (`tender`) E Hearthlight throw | while the 2.5 s zone is up, burst at its end [D]; recasts seen 0.4-1.6 s in [F] | any time in the 2.5 s ring, the throw keeps the time left, bloom at the end; cd on the press | match |
| Albert (`bulwark`) LMB hammer recall | stays planted until recalled, no auto-return [D, F ≥3.6 s]; recall seen almost at once [F] | `lie_t` 0 (no auto-recall), `recall_lock` 0.22 s | match |
| Tenzo (`dolm`) Shift Rock Hop | one dash, no recast [D] | 0.6 s per hop, 3 hops | owner item 111 |
| Neve (`rimewright`) E Rink Wall freeze | "recast to freeze" [D]; not shown [F] | while it slides (4.5 s), frozen 6 s; cd on the cast | match |
| Neve X Rimelock early end | any time cancels; late recast ("about 3.2-3.5 s in") stuns [D, F tamsin 222-223, 254]; auto at 3.5 s; cd on the cast | any time; **late window was 0.75 s, now 0.3 s** (`x.late`); auto at 3.5 s | **fixed**, asserted in --rimewright-combo-check |
| Sparkle (`mage`) X Kitefall strike | second press lands; 1.6-2.0 s airborne seen, max unread; "about 2 s, auto-land" [F vireo 397, 427] | from 0.25 s in the air (`min_air`), auto-lands after 2 s | match |
| Kael (`juggernaut`) E Warchain pull | while attached, ≥2.5 s seen [F]; cd on the pull or break (wiki) | 5 s tether; cd on the pull or break | match, lifetime unread |
| Cinder (`ashwick`) X Flue Flight land | ends on a recast or the flight's end, 1.4 s [F linwick 206-226] | 1.8 s, recast lands; cd on the cast | owner item 20 (1.8 s) |
| Sable (`thief`) E Shadow Knife blink | until 6 s, then forced; cd on the throw, refunds on hit [D] | 6 s, forced step; cd on the throw, refunds 0.25/0.5 | match |

## LMB numbers (2026-11-09, branch ext/lmb-range-parity)

LMB projectile speed, max range, spread or bloom, and whether it stops at the cursor, for the 11 Hunters other than Sable (`ext/sable-lmb-range` has her). Ours is from `content/weapons/*.json` and the kit JSONs; source is `supervive_kits.md` and the footage sheets' aim rows (1 bh = 1.8 m). Melee reach, width and arc are the hit-shape job and are not here. Owner rows stay.

| Hunter | Ours: speed, range, spread, aim | Source | Verdict |
|---|---|---|---|
| Vex | 74 m/s, 11 m, 0.03 rad, full range | Past the cursor to max range [F venator]; no speed, range or spread number | match (mode); numbers unsourced |
| Zedran | blast 36 m/s, 7 to 14 m by hold, full range | About 20 bh/s = 36 m/s, past the cursor [F juggernaut]; range not caught | match |
| Pin | 60 / 80 m/s, 12 / 16 m, none; stage 1 stops at the cursor, Supercharged flies full range | Stage 1 lands at the cursor (arrow at about 6 bh), Supercharged past it, near-hitscan [F pin gap 1] | match |
| Cinder | stream 16 m/s, 7 m, 0.5 to 2.2 m wide, full length | About 4 bh = 7.2 m regardless of the cursor, narrow to 1 to 1.5 bh [F linwick] | match |
| Albert | throw 24 m/s, recall 34, 9 m max (2.5 min), stops at the cursor | Lands at the cursor, 5 to 7 bh in 0.2 to 0.4 s, never thrown past about 7 bh [F bjorn] | match in mode; max range unmeasured |
| Tenzo | boulder 20 m/s, 11 m, none, full range | 10 to 12 bh/s = 18 to 22 m/s [F breah]; stop at cursor or not never shown (open question 1) | match; aim open |
| Grimble | 18 m/s slowing, 6.3 m, fan 20 at rest, bloom to +10 (30 firing), fixed range | About 3.5 bh = 6.3 m whatever the cursor; fan about 30 firing, 20 rested [F dredge gap 11] | **fixed**: fan was 30 rest, 45 firing |
| Vireo (Sparkle) | 37 m/s, 13 m, none, `aim: max` | Past the cursor, 7.5 to 8 bh [F vireo gap 3] | differ (owner items 70, 116) |
| Motley | 30 m/s (x1.4 charged), 14 m, none, full range | Past the cursor to max range [F ostra] | differ (owner item 60) |
| Meeko | 30 m/s, 13 m (Empowered x1.4), none, full range | 3 to 4 bh per 5 fps frame = 27 to 36 m/s; past the cursor to about 7 to 8 bh [F mooshmoosh] | **fixed**: range was 12 m |
| Tamsin | 16 m/s (x1.5 heavy), 10 m (x1.3), bow 10 deg, turn 12 rad/s, full range | Homing arcs toward the cursor; range, speed and stop at the cursor not shown [F tamsin] | match; aim open |

Fixed (asserted): Grimble fan 20 deg and bloom cap +10 (`--dredge-combo-check`); Meeko ember range 13 m (`--care-combo-check`).

Suggestions, not built: Albert throw max 9 m to about 12.6 m (7 bh, the farthest seen); measure Tenzo's and Tamsin's stop at the cursor with a near-cursor dummy; Meeko's Empowered range follows the new 13 m (x1.4 = 18.2 m).
