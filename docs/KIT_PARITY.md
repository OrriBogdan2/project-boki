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

**Every Hunter, shared:**
- **Q:** ours (a glove, gear slot, with V). Not in the source, so no parity target. DashFlow fires it through dashes.
- **Keys:** R = hunter ult (JSON slot `x`), X = Fuse, G = Boki (owner).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4.
- **Buffer:** `Loco.press_buffer` 0.15 s past a dash's end; the data gives no window.
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
| LMB | Hold; 51 a round, 30 rounds, rapid refill when idle, first 10 rounds stronger [D]; opens at 2x, 50% by round 10, 0.08 s [wiki] | 12 -> 6 over 10 rounds (51 of 1285 = 6 of 154), cadence 0.08, mag 30, refill 40/s after 0.35 s, no fire slow | match (ext/parity-ttk-vex, docs/TTK.md) |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | `quill_rifle.json`: rate 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain (half punch after), Dazed +90% | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Burr Charge from the launcher, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m, hold 7 m at +40% cd, cd 8.5, all `fire` rows; feel applied once (2f24ae36b) | match; pending `ext/vex-dash-parity` efbd6af96 (one Shift charge by the archetype's own `dash.charges`, eased Shift) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +38% rifle (+39 on the 102 opening) | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |

## Kael (`juggernaut`, source Brall) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Rate .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; ground dash→LMB still buffers, now cited: the dash is his attack [D] (gap 9, 4e788af65 left it) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source length unknown |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal .8, cd 36; a Hunter knocked or killed by the strike resets it (e152b31d6) | match; 0.8x cd |
| Dash | Dash attack, charges, 13 s [D] | 4.5 m/.17 s raw, ×.85/×1.15 feel (applied once, 2f24ae36b), 2 charges, cd 10.4 | match; dist scaled, cd 0.8x |
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
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel; 31/s = 258 x 154/1285 (docs/TTK.md frame; Flashover bonus sized by `--ttk-check`) | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3; 13 dmg = 106 x 154/1285 | match; 0.78x cd |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5; 9 dmg = 76.8/106 x the bolt 13 | differ (owner item 11); damage ratio match |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36; carpet 4.5/s (source 239.2/s would be 28.7) | owner: burst cap (SERVER_UPDATE6) holds the carpet at 4.5/s; 0.8x cd |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges; 18 dmg = 150.4/106 x the bolt 13, tier IV +5 (+40) | match |
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
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, raw 4.2 m/.174 s and 13.3 m/.95 s, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2, a hit or stun drops them, lock 4 s; Carrier shield removed | match; **closed** (gap 19, Meeko's share): 3bcb50eca |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45 clips) | match on coverage |
| Flow | Silent | Dash→LMB buffers (cited), RMB, E, X, Q `fire`; 3 `keep` rows unsourced `[?]` | pending `ext/flow-rows-source` dd2c83be5 |
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
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
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Molten Guard, built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48 clips) | match on coverage; hand polish pending `ext/anim-hand-tenzo` f44d76294 |
| Flow | Silent | Dash→LMB, →RMB, air LMB `fire` (4e788af65); 6 `keep` rows unsourced `[?]` | match; sources open |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48) | match on coverage |

## Grimble (`dredge`, source Kingpin)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D] | Seven-slug blast, bloom | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air shares slot | differ (owner); air slot missing (gap 13) |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Claire (`rimewright`, source Celeste)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight, 2x damage while skating | match; skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2; detonation 22 = 190/156 x hit 18 | differ (owner); damage ratio match |
| LMB | Hold, semi-homing, 3 heavy at end of burst, 0.5 s barrage cd [D]; one uniform stream while held [F] | Hold = one burst of plain darts (0.18 s), 3 large on the let-go, 0.5 s pause; skating: beams, semi-homing, 2x damage | match (burst); skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skating beams semi-homing (owner, gap 16 done) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80; crash 18 = 155/156 x spear hit 18 | match; +15% radius, +5% slide (owner 11-08) |
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
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .45 on every press (recall too: TTK 1.16x), walks 55% vs stands | differ (owner) |
| RMB | Hold shield, front block, Shift = bash 198 = 1.03x throw, 6 s [D] (supervive_kits.md:89-90) | hold .1, aegis, bash 12.4 (0.95x throw 13), cd 6 | match; routing `[?]` |
| Q | none | glove | ours |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun (31 = 0.16x throw), AoE series 396 = 2.06x, heavy Slow, 50 s [D] (supervive_kits.md:93) | 4 cells, strike 1.9 (.16x), eruption 24.8 (2.06x), stun .5, cd 40 | match; 0.8x cd |
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

## Gil (`gil`, no source hero) · 13th Hunter, 0.24.4

Ours only: there is no source row to compare, so every verdict is `ours` and the numbers below are the content values (`content/archetypes/gil.json`, measured shapes in docs/HITBOX_SIZE.md, time to knock in docs/TTK.md, bot use in docs/BOT_KIT_USE.md). `content/rules/kit_parity.json` has no Gil row for the same reason.

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | none | Fencer: two thrusts 7 and a lunge 11 (reach 2.5/2.5/3.2), rate 0.32 s, each steps forward, the third slows 30% 0.5 s | ours |
| RMB | none | Grab Bag: 5 potions (thunder 10 + stun 0.5 s, slime slow, gust, fire, Super Zeep), 2 charges, cd 5 s, tap 8 m, hold 12 m | ours |
| E | none | Riptide: 2 s spin (radius 2.2, tick 2 to 5), press again for a spout, 10 damage + 1 s knockup, cd 12 s | ours |
| R | none | Tidal Wave: 14 m, 18 damage, 1 s knockup then slow 50% 2 s, 40 shield, cd 90 s, unlock rank 6 | ours |
| Dash | none | Ground Swim: 6 m in 0.4 s, 4 damage, 0.5 s knockup, cd 8 s | ours |
| Passive | none | Fish Out of Water: three different potion marks in 5 s Beach a foe (stun 0.75 s, once per 8 s) | ours |
| Health | none | 124 (light weight), 0.80 of the roster mean | ours |

Measured outliers, not retuned: the swordfish chain reads one dummy at 0.8 m in `--hit-shape-check` against a 3.1 m content reach (as Kael and Tenzo read low too); his combo knocks in 5.0 to 7.7 s (the bag is shuffled, so it varies) against 1.3 to 4.2 s for the other combos with a source row, only Motley slower (docs/TTK.md); bots use Ground Swim about once per duel.

## Crowd control: every stun, root, Ground, slow, Daze and knock effect (main d255acbee, 2026-11-09)

Read from `content/archetypes/*.json` and the kit code. Source = the card text in `supervive_kits.md` [D] and the footage reads in `briefs/hero-ref` [F] (5 fps, so a read is good to about +-0.2 s). **The card gives no CC duration or strength except Ostra's (Snap 0.8 to 1.8 s, Black Hole 3.5 s, orb 6%) and the upgrade steps (Binding +0.3 s root, Primal Slam +0.1 s and +0.2 s stun).** Every other source row is a footage read or just the word "Slow", "Stun", "Daze". No silence and no knock-up (a launch that disables) is built anywhere, and none is in these 12 kits' cards except Oath's Faultline (queued, skipped). Self-slows (cast, charge, carry) are not CC and are left out. Albert's Faultline and Spin Dash are skipped (queued job). Sable's 30% bola slow stays (owner item 53).

| Hunter | Effect (ours) | Source | Verdict |
|---|---|---|---|
| Vex | Burr Charge Daze 1.4 s (only +38% rifle, +20% Railgun, no slow); wall slam: stun 0.7 s and Daze +0.6 s; Cinderfall zone slow 30% (0.6 s refreshed) | Daze about 1.2 s [F]; wall: "Dazed longer and Stunned" and zone "Slow", no numbers [D] | match (1.4 vs 1.2 is one frame at 5 fps) |
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

Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`. Re-checked 2026-11-09 (ext/dash-nd-rows-a) against data, footage and the wiki lines in the briefs: Vex `dash.air.lmb` is settled by the card's unqualified "can fire the rifle while sliding" plus the wiki's air tap (asserted in `--dash-flow-check`); Vex `dash.{ground,air}.{rmb,e,x}`, Cinder and Grimble `dash.ground.lmb` stay "Not determinable", each `source` says which lines and frames were read.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x} (all 13 re-checked 11-09 against the data, the pin/vireo frames, the cancel-matrix-a/b tables and the patch lines; none settled, each `source` says why in one line). Other heroes carry further `keep` rows without a source (Cinder 3, Zedran 3, Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.
Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows (Cinder 3, Kael 4, Albert 1, Neve 3, Meeko 3). Each now has a `source` that reads "Not determinable" and cites what was checked, so they stay `[?]`: Kael `hold.lmb.jump`, `hold.rmb.{ground,air,jump}` (juggernaut.md:41, :57-64, :75-83, :284, frames 0087, 0121-0127, 0141-0146, 0251-0300; supervive_kits.md:21-22); Cinder `hold.rmb.{ground,air,jump}` (linwick.md:57-58, :267-286, :323, frames 0073-0074, 0102-0103, 0131, 0143-0144, 0159-0161); Albert `hold.lmb.jump` (bjorn.md:74, :365-366, :398, frames 0116-0118, 0133-0146); Neve `hold.rmb.{ground,air,jump}` (tamsin.md:18, :294, :297-298, :332-334; the source spear is a tap); Meeko `hold.rmb.{ground,air,jump}` (mooshmoosh.md:63, :340, :346-366, :386-388, :453, frames f105-113). No press inside a dash and no hold carried through a dash or jump is visible in any of them, so no row's behaviour changed (all `keep`; every interaction chains). Not covered here: Claire, Pip, Grimble and the other heroes' rows.
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
