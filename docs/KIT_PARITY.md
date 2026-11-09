# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07)

**Refresh 2026-11-09 (main d255acbee):** the Vex, Kael, Lace, Cinder, Meeko and Tenzo tables below were re-checked row by row against main and use the canon display names (briefs/DECISIONS.md, ids unchanged). A closed gap names the commit that closed it; `pending ext/<branch>` is a READY branch not yet on main that would close or move the row. The other six tables and the top-20 list below are still the 7907d9afe text and use the old names.

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only: no game code changed.

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
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** match since the source brake 22.2 + friction 2, air control 0.015 and a dash that exits at run speed (bc1a70608, 4071fe66a; gaps 2 to 4 closed). **Jump:** 6.8 kept over 7.5 on purpose and pinned (0f70d1a8a). **Glide dive:** built (280404102, gap 18).
- **Buffer:** `DashFlow.BUFFER_S` 0.15 s past a dash's end; the data gives no window.
- **Cooldowns below** read ours / source level 1 [D].

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | `quill_rifle.json`: rate 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain (half punch after), Dazed +90% | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Burr Charge from the launcher, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m, hold 7 m at +40% cd, cd 8.5, all `fire` rows; feel applied once (2f24ae36b) | match; pending `ext/vex-dash-parity` efbd6af96 (one Shift charge by the archetype's own `dash.charges`, eased Shift) |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match |
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

## Cinder (`ashwick`, source Felix) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3 | match; 0.78x cd |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | Ground 3.4 m/.33 s, air poof 6.8 m/.28 s, both off the global feel (`dash_feel.json`), stops on foe, 2 charges | match; **closed** (gap 11): 2f24ae36b |
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

## Grimble (`dredge`, source Kingpin)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D] | Seven-slug blast, bloom | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, cd 10, air shares slot, air range scaled twice (3.1 m, single 3.7 m) | differ (owner); air slot missing (gap 13) |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Claire (`rimewright`, source Celeste)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight while skating | match; skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, cd 17 | match; 0.85x cd |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 (owner), cd 80 | match |
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
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.0, fizzles 10 s (ours) | differ: 3x vs 3.5x, fizzle ours |
| R | Vortex stun + pull, 70 s [D] | Tell 1.0, 3.5 s, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 30%, moves foes and allies (counters both) | match |
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
| Dash | Spin Dash 8 s, knock [D] | Whirl 3.5 m, cd 8 | match |
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
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | 40 m/s vs ~32 (owner), dmg 20, Blowout reset, cd 8 | differ (owner) |
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
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, prime 2.34x, cd 4.5, excluded from dash_feel | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` |
| Anim | Footage poses | 17 moves, all on `sable.glb` (47) | match on coverage |

## The 20 biggest feel gaps, ranked

Slice Wardens and LMB rank first (PRIORITIES step 2). Effort: S under a day, M a few days, L a week or more. `owner` = needs an owner call before building.

| # | Gap | Fix | Files | Effort |
|---|---|---|---|---|
| 1 | Zedran has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M |
| 4 | Dashes stop dead: keep 15%/30% vs carry; global ×.85/×1.15 | Raise carry; drop scale where kit numbers already match | hunter.gd, content/rules/dash_feel.json | M |
| 5 | Hem's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner |
| 6 | Hem's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S |
| 7 | Hem's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S |
| 8 | Hem's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L |
| 9 | Dash→LMB buffers on 6 kits (Hem, Bjorn, Zedran, Cinder, Ryzz, Tarek air), and Zedran, Bjorn and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner |
| 11 | Cinder's dash is short: ground felt 2.9 m vs 3.4 m; his and Grimble's air dashes apply feel twice (likely bug) | Exempt or raise ground; scale air once (Zedran already undoes it, `juggernaut_kit.gd:826`) | ashwick_kit.gd:521, dredge_kit.gd:684, ashwick.json | S |
| 12 | Bjorn's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M |
| 14 | Tarek's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner |
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
