# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07)

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only: no game code changed.

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
- **Keys:** R = hunter ult (JSON slot `x`), X = Fuse, G = Boki (owner).
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4.
- **Buffer:** `DashFlow.BUFFER_S` 0.15 s past a dash's end; the data gives no window.
- **Cooldowns below** read ours / source level 1 [D].

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m, hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |

## Zedran (`juggernaut`, source Brall) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2, cursor marker | match; 0.8x cd |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source length unknown |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` |
| Dash | Dash attack, charges, 13 s [D] | 4.5 m/.3 s raw, ×.85/×1.15 feel, 2 charges, cd 10.4 | match; dist scaled |
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
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | 3.5 m/.24 s raw → ~3 m/.28 s, walks rocks and barriers, **not ledges** | differ (gap 8) |
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
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | Felt ground 2.9 m/.32 s (3.4/.28 ×feel), stops on foe, 2 charges. Air poof 8/.24 is scaled twice: 5.8 m/.32 s, not 6.8 m/.28 s | differ (gap 11) |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41) | match on coverage |

## Pip (`tender`, source Elluna)

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours |
| RMB | Shot, delayed Root, 11.5 s [D] | Hop form, windup 1.0, cd 10.5 | differ `[?]` motion |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, raw 4.2/.174 and 13.3/.95, air steer (owner) | match |
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
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops, cd 12 | differ (owner item 111) |
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
