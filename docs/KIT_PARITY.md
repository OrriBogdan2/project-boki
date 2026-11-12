# Kit parity audit: 12 Hunters against the source (main 7907d9afe, 2026-11-07; re-audit on ext/release-integ-0244c 23cc281bd, 2026-11-11)

PARITY FIRST audit (briefs/DECISIONS.md 2026-11-07, briefs/PRIORITIES.md step 2). Read-only for the first audit; the ranges table below changed four numbers (data only).

## 0.24.5 verify: Meeko, Tenzo, Grimble, Neve, Motley, Albert, Sparkle, Sable (ext/release-integ-0245 92df78ce4, 2026-11-11)

Each row was read against `content/archetypes/*.json` and the kit code on the 0.24.5 line. **No row regressed**: every `done ... (main)` row above still holds (Meeko Carrier shield gone, drop lock 4 s; Tenzo ally hop; Grimble air slot 12.5 s; Neve Chill 4 s with no slow, late dart homing; Motley bomb 3.5x; Albert throw rate 0.45, E zone 2.3 m, aegis block rules; Sparkle dash to LMB; Sable LMB 8.5 m, no Shred). `--kit-parity-check` 0 failures; combo checks: tender 104, dolm 172, dredge 112, rimewright 116, ostra 213, bulwark 166, mage 143, dancer (Sable) 144, all 0 failures. `--cooldown-parity-check` does not exist on this line (it lives on ext/cooldown-parity-verify).

**Every "branch ready" fix of the 0.24.4 re-audit is still missing from the 0.24.5 line** (none of these branches is an ancestor of it). All trial merges conflict, so each needs a rebase before it can land:

| Hunter | Row still open on 0.24.5 | Fix branch | Conflicts on a trial merge |
|---|---|---|---|
| Meeko | Empowered +40% range (`shot_range_k` 1.4, tender_kit.gd:117,172), Hearthlight `self_k` 0.33 | ext/parity-no-riders-meeko 0d6177875 | KIT_PARITY.md, docs/heroes/tender.md |
| Tenzo | rock `slow_t` 0.8 / `slow_k` 0.3, Rock Hop `slow_t` 1.5 (dolm.json); punch dmg [12, 24] and kb [6, 11] scale with charge | ext/parity-tenzo-rock-slows 44040c047; ext/parity-no-riders-grimble-tenzo 7b130d5c7 | rock-slows: KIT_PARITY.md only; grimble-tenzo: dolm.json, dredge.json, dredge_kit.gd, docs |
| Grimble | E Grounds the foe (dredge.json); cooldowns RMB 12, E 7, R 21 vs 18, 12, 36 | ext/parity-no-riders-grimble-tenzo; ext/grimble-parity-verify d94bc7769 | dredge.json (the E line, also edited by ext/anim-time-grimble-rebased) |
| Albert | Guard meter, Shield Slam, slam stun 0.6 (bulwark.json `resource`, `slam`); Crushing Blow `smash_stun` 0.4; aegis routing; R cd 40 vs 50 | ext/albert-parity-verify b69c6ca3b (carries guardcut); ext/parity-albert-blow-stun 46a88e3a1; ext/combat-albert-aegis-input 91c3dba10 | bulwark.json, bulwark_kit.gd, bjorn_fx.gd, archer_bulwark_combo_check.gd, wiki |
| Motley | un-popped Brimseed fizzles at 10 s (`hold_full` 10.0) | ext/motley-seed-fizzle 9f521695a | KIT_PARITY.md, docs/heroes/ostra.md |
| Neve, Sparkle, Sable, Meeko, Albert | cooldowns not at source level 1 (see each section) | ext/cooldown-parity-verify 2be9877c2 | rimewright.json, thief.json, dredge.json and the slice heroes' data |
| Sparkle | Skycall circle 1.5 (source reading 1.8) | ext/parity-skycall-size 7a40610b7 | KIT_PARITY.md |
| Sable | E range 14 (source reading 16.2) | ext/parity-ranges-rest bee6f9728 | KIT_PARITY.md |

Not a regression but stale text: the Albert section's E row says r 3.5; the data is 2.3 (the ranges table is right). Still owner or `[?]`, unchanged: Tenzo ridge 12 m, Motley orb slow 10% vs 6%, floats, Neve rink +15%, Sparkle slide 3.4. Filed in docs/DEBT.md.

## Re-audit 2026-11-11 (0.24.4 candidate, ext/release-integ-0244c 23cc281bd)

Every row below marked differ, missing or `[?]`, and the top-20 table, was re-read against the candidate's `content/` and kit code. Each one now ends with a mark: **done** `ext/<branch>` (the branch that fixed it; `main` = already on main d255acbee, else only on the candidate), **open** (still a gap), or **owner** (an owner note overrides the source, or the fix needs an owner call). "Branch ready" = a READY branch in briefs/EXT_TO_MAIN.md that fixes it but is not on the candidate (docs/GATE_0244.md lists what was merged). No numbers or code were changed here.

**Still open, slice Hunters first:**

| Hunter | Still open | Fix waiting |
|---|---|---|
| Vex | R cd 42 vs 55 (0.76x), RMB cd 6.5 vs 9 (gap 10) | branch ready: ext/cooldown-parity-verify 2be9877c2 |
| Vex | Hold dash measured 10.3 m (0.18 s skid, then the 7 m slide), against 7 m in this doc; the source gives no hold length `[?]` | reported by ext/verify-starter-trio (not re-measured here) |
| Vex | R cast range 14 `[?]` (no clamp in the source) | none (no data) |
| Kael | Ours-only CC riders: fireblast slow 30% (`lmb.wave_slow`), Chain Lunge stun 0.35 s, Haul Slam stun 0.25 to 0.6 s (`rmb.haul.stun`); the source has none | none; Haul is a documented move, owner call |
| Kael | Air RMB cd 7.2 vs 9, R cd 36 vs 45 (gap 10) | branch ready: ext/cooldown-parity-verify |
| Kael | Warchain leash 24 m and slam angle 70 `[?]` (no data) | none |
| Lace | 8 of 17 dash-flow rows unsourced `[?]` (6 hold rows `keep`, 2 Q rows ours) | none (no source) |
| Lace | RMB range 14, E reach 9, R range 18 / width 0.5 `[?]` (not in the footage) | none |
| Lace | Spirit Walk ending inside a ledge: the candidate sets her on top; the follow-up puts her back on last clear ground and fixes the expiry snap-back | branch ready: ext/combat-lace-spirit-ledges-rebased 40f7865d8 |
| Cinder | RMB cd 7 vs 9, R cd 36 vs 45 (gap 10) | branch ready: ext/cooldown-parity-verify |
| Cinder | RMB range 14 `[?]`; 3 dash-flow `keep` rows and `dash.ground.lmb` unsourced `[?]` | none |
| Albert | Invented Guard meter and Shield Slam (gap 15, owner 11-07 said cut), Shield Slam stun 0.6 s | branch ready: ext/parity-bulwark-guardcut b2e942eb4 |
| Albert | RMB aegis/bash routing `[?]` | branch ready: ext/combat-albert-aegis-input 91c3dba10 |
| Albert | Crushing Blow stun 0.4 s (no source row); R cd 40 vs 50 | none / ext/cooldown-parity-verify |
| Meeko | Empowered +40% range and Hearthlight self_k 0.33 are ours (source silent); R cd 46 vs 60 | branch ready: ext/parity-no-riders-meeko 0d6177875; ext/cooldown-parity-verify |
| Grimble | E Grounds the foe (ours); RMB 12 vs 18, E 7 vs 12, R 21 vs 36 (0.58x to 0.67x) | branch ready: ext/parity-no-riders-grimble-tenzo 7b130d5c7; ext/cooldown-parity-verify |
| Tenzo | Punch charge scaling (ours); rock slow 30% 0.8 s and Rock Hop crash slow 1.5 s (ours) | grimble-tenzo branch covers the punch; the slows have no branch |
| Neve | E cd 17 vs 20 (gap 10) | ext/cooldown-parity-verify |
| Motley | E fizzle 10 s (ours); orb slow 10% (wiki) vs 6% (card read); "floats" `[?]` (the body hovers 0.3 m, a gameplay float not traced) | none; the slow is an owner call |
| Sparkle | RMB cd 8 vs 10, R 42 vs 60; Skycall circle 1.5 / slide 3.4 kept on purpose `[?]` | ext/cooldown-parity-verify |
| Sable | RMB cd 7 vs 13, R 24 vs 50, E 15 vs 28 (level 1); pair stun 0.9 vs ~1.8 s (owner pacing) | ext/cooldown-parity-verify |
| All | Dash curves not decoded (`dash_exit_run` 1.0 stands in) `[?]`; a glide dive held to the ground does not land at the glide sink | branch ready: ext/glide-dive-land e4081da34 |

**Owner, not gaps:** air control (DECISIONS 2026-11-08 "real matches HAVE air control" overrules the source's 0.015), Kael's air RMB as a straight down slam 2.4 m 0.8 m ahead (owner 11-10, ext/jugg-downslam), Neve's rink 8.3 m (owner 11-08 +15%), Vex Coin Blast and palm-fired Longneedle (owner 11-08 presentation; ext/vex-coin-palm-1108 not on the candidate), and every `differ (owner)` row below.

**A check that asserts a stale number:** `content/rules/kit_parity.json` pins Kael's `rmb.drop.radius` at 2.2 ±0.22 (the source's cursor disc); the candidate's down slam is 2.4 (ext/jugg-downslam, owner 11-10), so `--kit-parity-check` passes only at the edge of the tolerance (2.42). Owner call: re-pin it to the owner's 2.4 or drop the row, since the down slam is no longer the source's cursor disc. No other row is stale; the ranges table's Neve rink "7.2, match" was stale and is fixed below (not asserted anywhere).

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
- **Run speed, ground accel, gravity, fall cap:** match [D]. **Stopping, air control, dash carry:** differ, see gaps 2 to 4 (re-audit 11-11: stopping and carry **done**, air control **owner**).
- **Buffer:** `DashFlow.BUFFER_S` 0.15 s past a dash's end; the data gives no window.
- **Cooldowns below** read ours / source level 1 [D].

## Ranges and radii: RMB, E, R (main d255acbee, 2026-11-10)

Source = `briefs/supervive-data/supervive_kits.md` (the tooltips carry no range numbers, so only the Black Hole radius, 350/500 uu = 3.5/5.0 m, is data) plus the footage measures in `briefs/hero-ref` (1 body height = 1.8 m; a later per-ultimate re-measure wins over the first sheet). Ours = `content/archetypes/<id>.json`, metres. The aim indicator and the hit read the same JSON field for every row below; the Bola lane is drawn at the width the hit reaches (0.45 + body radius per side). **fixed** = changed here and asserted in `--kit-parity-check`. `[?]` = not measurable from the source, or an owner note stands.

| Hero | Slot, number | Ours | Source | Verdict |
|---|---|---|---|---|
| Vex | RMB range, cone, lane | 10.5, 6 m at 100, 0.72 | 5-6 bh (9-10.8), 3.5 bh at 100, 0.4 bh | match |
| Vex | E range, beam width | 18, 1.8 | 10+ bh (18+), beam 0.5 bh (0.9) | range match; width differs (owner item 68 widened it) · **owner** |
| Vex | R range, disc | 14, 3.4 | clamp not seen, 1.8-2 bh (3.2-3.6) | disc match; range [?] · **open** [?] |
| Kael | RMB slam reach, angle | 4.0, 70 | 2.4 bh (4.3), a lane not a cone | match; angle [?] · **open** [?] |
| Kael | RMB lunge length | 4.5 to 7.5 | 5 flat (4.1-5.8) | differ (owner: release flings far) · **owner** |
| Kael | RMB air slam disc, reach | 2.4, 0.8 m ahead (straight drop; was 2.2 at the cursor) | 1.2 bh (2.16), cursor to ~5 | differ · **owner** (11-10 down slam, ext/jugg-downslam); the check still pins 2.2 ±0.22 (see the re-audit) |
| Kael | RMB chain spin radius | **2.2** (was 2.6) | 1.2 bh (2.16) | **fixed** |
| Kael | E range, tether max | 13, 24 | 7 bh (12.6), max not seen | range match; tether [?] (owner Warchain note) · **open** [?] (ext/kael-chain-length re-checked, no data) |
| Kael | R strip | 3.6 x 1.8 | 1.5-2 bh x 1 bh (2.7-3.6 x 1.8) | match |
| Lace | RMB range | 14 | grows with the charge, max not seen | [?] · **open** |
| Lace | E arc, reach | 120, 9 | 120, cursor seen to 6 bh (10.8) | arc match; reach [?] · **open** |
| Lace | R range, width | 18, 0.5 | not in the footage | [?] · **open** |
| Cinder | RMB range | 14 | clamp not seen (6.5 bh = 11.7 reached) | [?] · **open** |
| Cinder | E radius | 4.5 | 2.5 bh (4.5) | match |
| Cinder | R carpet, ring, flight | 1.8, 2.2, 22.7 | 1 bh, 1.2 bh, 16-18 | width, ring match; flight longer (owner item 20) · **owner** |
| Meeko | RMB range, burst | 14, 2.2 | 8-9 bh (14.4-16.2), disc 1.2 bh (2.2; flare 1.8 bh = 3.2) | match; flare [?] · **open** |
| Meeko | E ring, thrown, reach | 2.6, 2.9, 9 | 1.3-1.5 bh, 1.6 bh, - | match; reach [?] · **open** |
| Meeko | R range | 12.6 | tether ring 7 bh (12.6) | match |
| Tenzo | RMB radius, core | 4.5 (3.82 tap), 0.9-1.8 | 2.5 bh (4.5), 0.5-1 bh | match |
| Tenzo | E ahead, span | 3.4, 5 | 2 bh (3.6), 3 bh (5.4) | match |
| Tenzo | R ridge length, cast range | 12, 11 | 10-12 bh (18-21.6), - | differ ~40%, kept: f2b60dc70 narrowed it 19.8 to 12 on purpose, no DECISIONS line either way; [?] · **owner** |
| Grimble | RMB range | 11.5 | 6-7 bh (10.8-12.6) | match |
| Grimble | E depth, angle | 3.0, 110 | 1.5 bh deep x 2 bh wide (2.7 x 3.6) | within footage error [?] · **open** |
| Grimble | R fan, depth | 105, 5.9 | 100-110, 3.3 bh (5.9) | match |
| Neve | RMB range, zone, burst | 12, 2.2, 2.7 | lands at the cursor, clamp and rings not measured | [?] (owner: travel time grows with distance) · **open** |
| Neve | E width, slide | 1.8 to 4.5, to 16.2 | narrow to ~2.5 h (4.5), slide not measured | width match; slide [?] · **open** |
| Neve | R rink radius | 8.3 (was 7.2; this row said match) | 4 bh (7.2) | differ +15% · **owner** (11-08, c05e9d3a5) |
| Motley | RMB range | 13 | bundle seen over 6 h (10.8), max not seen | [?] · **open** |
| Motley | E seed radius | 3.2 | 1.8 h (3.2) | match |
| Motley | R radius, range | 3.6 / 5.1 swollen, 10 | 350 / 500 uu (3.5 / 5.0), - | match; range [?] · **open** |
| Albert | RMB aegis, slam | 4.2 at 140, 2.6 at 100 | slab 2.2 h wide (4.0), bash not seen | aegis match; slam [?] · **open** |
| Albert | E zone radius | **2.3** (was 3.5) | green disc 1.3 h (2.34) | **fixed** |
| Albert | R lane | 16 x 4.5 | 9 bh x 2.5 bh (16.2 x 4.5) | match |
| Sparkle | RMB range | 13 | 7.5 bh (13.5) | match |
| Sparkle | E radius, reach, slide | 1.5, 11, 3.4 | circle ~2 bh across (radius 1.8), -, ~4 bh (7.2) | differ 17% and 53%, kept: mage.md set 1.5 as the hit on purpose; [?] · **owner** |
| Sparkle | R radius, range | 2.7, 14.4 | ring 1.5 bh (2.7), 8 bh | match |
| Sable | RMB range, lane | 7 + 3.8, **1.8 wide** (was 1.4) | lane 5.5-6 bh (9.9-10.8), 1 bh wide (1.8) | **fixed** (width) |
| Sable | E range | 14 | landed at 9 bh (16.2), max not seen | [?] · **open** |
| Sable | R ring | 5.4 (rim band outer 25%) | 3 bh (5.4); the first sheet's 3.5 bh is superseded | match |

Left alone and why, for the owner: Kael lunge (owner), Vex needle width (owner item 68), Cinder flight (owner item 20), Tenzo ridge (deliberate narrowing, source 10-12 bh), Sparkle Skycall circle (deliberate). Ideas of ours stay out of the build.

## Vex (`gunslinger`, source Ghost) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold; 30 rounds, rapid refill when idle, first 10 rounds stronger [D] | Cadence 0.12, mag 30, refill 40/s after 0.35 s, 10-round sustain, no fire slow | match |
| RMB | Sticky grenade, wall cone knock, Daze; lane on hold [D,F] | Launcher shot, cd 6.5/9 (footage 5.4) | differ (owner, item 112) · **owner**; cd **open** (gap 10) |
| Q | none | glove | ours |
| E | 0.6 s cast standing, beam pierces terrain, recoil, -20% cd on hit [D,F] | Charge 0.6, recoil 6, range 18, shave 20%/30%, linger 0.75, cd 11.5/12 | match |
| R | Target zone, ~1.6 s delay, 3 s fire + Slow, 55 s [D,F] | Delay 1.6, 3 s zone, slow 30%, cd 42/55 | match; cd 0.76x (gap 10) · cd **open** (branch ready: ext/cooldown-parity-verify) |
| Dash | Press or hold longer, fires through, knock resets, 11.5 s (F 7.5) | Tap 4.8 m/.45 s (F 4.8/.47), off the dash feel; hold 7 m at +40% cd, 8.5 s, all rows `fire`, sourced 15/15 | match |
| Passive | +6% omnivamp 3.5 s on ability hit [D] | 6%, 3.5 s, 1 stack; Dazed +90% rifle | match |
| Anim | Footage poses | 7 moves, all on `vex.glb` clips (36) | match on coverage |

## Kael (`juggernaut`, source Brall; was Zedran) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Press combo; hold ranged fireblast [D] | Cadence .34, hold .22-.95, wave 36 m/s, arc 175, reach 3.1 | match; dash→LMB buffers (gap 9) · **done** `ext/parity-dashlmb` (main): `buffer` kept, sourced (Flame Step is itself the attack) |
| RMB | Context: Slam, Lunge, air Slam, chain Spin; 2.5 s [D] | cd 2.0, hold .3, perfect release, over-head pose | match in shape; overhead/perfect differ (owner) · **owner** |
| Air RMB | Own 9 s slot [D]; cursor disc [F] | `drop` cd 7.2; now a straight down slam, 2.4 m hit 0.8 m ahead | differ · **owner** (11-10, `ext/jugg-downslam`); cd 0.8x **open** (gap 10) |
| Q | none | glove | ours |
| E | Tether, reactivate to self-pull, 16 s [D] | Impulse 22 m/s, sling, steer, tether 24 m (ours), cd 12.8 | match in model (owner); source throw ~12.6 m (7 bh, a floor), leash `[?]` (no data, no frame shows one; 24 m kept) · **open** [?] |
| R | Invulnerable, strike back, heal, kill resets, 45 s [D] | Riposte: guard .65, strike .1, recover .35, heal, cd 36 | match in shape; kill reset `[?]` · kill reset **done** `ext/kael-ult-reset-rebased-rebased` (through HeroUlt, asserted); cd 0.8x **open** (gap 10) |
| Dash | Dash attack, charges, 13 s [D] | 0.07 s dip, then 4.5 m/.17 s raw (owner 113.8), ×.85/×1.15 feel: felt 3.8 m/.2 s (F ~2 bh/.2 s), 2 charges, cd 10.4 | differ (owner) · **owner** |
| Passive | Damage empowers; heal on knock [D] | Rage, Enrage 6 s, heal_knock .2 | match in shape |
| Anim | Full set | **20 moves. `kael.glb` has 0 clips and no `warden_anim/kael.json`: stays on procedural HunterAnim** | **missing** (gap 1) · **done** `ext/kael-v2-model` (main): `kael.glb` has 49 clips, `warden_anim/kael.json` maps them |

## Lace (`archer`, source Myth; was Hem) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold to charge, release; perfect speeds next draw [D,F] | PinDraw two stages, reticle, stops at cursor, cadence .5, perfect → quick draw | match |
| RMB | Hold, release, knock, wall stun up to 173 extra on 35 [D] | Hold .5 dead zone (ours), wall_dmg 12, floor .4, stun 1.2, cd 16 | **differ**: payoff ~0.4x vs ~5x (gap 6) · **done** `ext/parity-lace` (main): `pin.wall_mult` 4.94, hold 0.15 from the press (gap 7) |
| Q | none | glove | ours |
| E | Cone of arrows, slow, anti-heal, 15 s [D] | Tell .35, 4.4 s, slow 35%, curved wall, cd 15 | match |
| R | 3 empowered shots, no charge, 60 s [D] | 3 shots, window 6 s, nock .3, cd 60 | match |
| Dash | Roll to cursor, then Phase Walk through terrain incl. raised walls, 9.5 s [D] | Roll 3 m/.27 s (F), off the dash feel; walks rocks and barriers, **not ledges** | differ (gap 8) · **done** `ext/parity-phasewalk-rebased`, `ext/lace-phasewalk-verify`: passes raised terrain, set on top if it ends inside; follow-up in ext/combat-lace-spirit-ledges-rebased (not on the candidate) |
| Passive | Fog vision of injured; tall-ledge climb [D] | Hawk Sense 22 m; **Focus/Deadeye invented** | differ (gap 5); owner question open · **done** `ext/parity-lace-focus` (main): Focus and Deadeye cut, Hawk Sense kept; climb asserted (`ext/lace-tall-climb-rebased`) |
| Anim | Footage poses | 18 moves, all on `hem.glb` (48) | match on coverage |
| Flow | Silent on shooting in the walk [F] | Dash→LMB buffers; 8 of 17 rows unsourced | gap 9 · LMB **done** `ext/parity-dashlmb` (main, fires mid-dash); 8 rows unsourced **open** [?] |

## Cinder (`ashwick`, source Felix) · slice Warden

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, hose, ignite, % HP vs Ignited [D,F] | Hose stream (`ashwick_hose.gd`), range 7, .35 relight, no fuel | match |
| RMB | Bolt + Slow, upgrades Ignite, 9 s [D] | Range 14, slow 30%, cd 7, +1 charge at rank 3 | match; 0.78x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Spin pull, shield per foe, knock resets, 13 s; ~.2 s arm fling [D,F] | Instant, r 4.5, pull 14 m/s, cd 10.5 | differ (owner item 11) · **owner** |
| R | Fly forward, burning ground + Slow, 45 s [D] | 12.6 m/s, 1.8 s, trail 5.2 s, slow 30%, cd 36 | match; 0.8x cd · cd **open** (gap 10) |
| Dash | ~3.4 m/.33 s, stops on first foe, 2 charges [D,F] | 3.4 m/.33 s (F), air poof 6.8 m/.28 s, off the dash feel; stops on foe, 2 charges | match |
| Passive | Ignite levels, bonus dmg [D] | Flashover 1/2, `ignite_bonus`, heal_knock .16 (wiki only) | match |
| Anim | Footage poses | 12 moves, all on `cinder.glb` (41) | match on coverage |

## Meeko (`tender`, source Elluna; was Pip)

**0.24.5:** tender-combo 104/0. Carrier shield gone and the 4 s drop lock stand. Open (fix not on the line): Empowered range and `self_k` (ext/parity-no-riders-meeko); cooldowns RMB 10.5, E 11, R 46 vs 11.5, 12, 60 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Ramp per hit; idle shot Empowered [D] | Cadence .4, Empowered +40% range (ours) | match; range bonus ours · **open** (branch ready: ext/parity-no-riders-meeko) |
| RMB | Shot, delayed Root, 11.5 s [D]; wiki 2 s delay | Hop form, windup 1.0, cd 10.5; roots after 2 s of the foe within 15 m (owner 11-10), unwinds 2x out of it | differ `[?]` motion · **owner** (11-10) |
| Q | none | glove | ours |
| E | 2.5 s zone, burst, throw, attaches, 12 s [D] | 2.5 s, r 2.6, throw, cd 11, self_k .33 (ours) | match · self_k **open** (branch ready: ext/parity-no-riders-meeko) |
| R | Channel on ally/Wisp; revive and pull; cancels on stun, knock, range; 60 s [D] | Tether 5 s, range 12.6, cd 46 | match in shape; 0.77x cd · cd **open** (gap 10) |
| Dash | Ground 7 s, air 14 s, separate [D] | 7 s and 14 s, 3.6 m/.2 s (F) and 13.3 m/.95 s (F), off the dash feel, air steer (owner) | match |
| Passive | Carry Wisps; damage or stun drops, 4 s lockout [D] | Carry up to 2 + Carrier shield (ours) | differ: shield ours. Drop lockout built (lock 4 s); which hits drop not traced · shield **done** `ext/parity-no-riders` (main); drop triggers **done** `ext/meeko-carry-drop-rebased` (stun, or damage past the shield) |
| Anim | Footage poses | 16 moves, all on `pip.glb` (45) | match on coverage |

## Tenzo (`dolm`, source Tetra; was Tarek)

**0.24.5:** dolm-combo 172/0. Ally hop stands; cooldowns 11, 12.5, 45, 12 already match the source. Open: rock and Rock Hop slows, punch charge scaling (ext/parity-tenzo-rock-slows, ext/parity-no-riders-grimble-tenzo).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Tap boulder; hold punch launches rocks, .6 s [D] | Boulder .6, punch .7/.6 | match |
| RMB | Hold slam, centre stun, jump to leap, 11 s [D] | hold .2, cd 11, glide slam built | match |
| Q | none | glove | ours |
| E | Three rocks, allies hop by jumping, ~12.5 s [D] | Rock wall, cd 12.5; **no ally hop** | missing: ally hop (gap 14) · **done** `ext/tenzo-ally-hop`: an ally clears a teammate's rock (bots hop at once), asserted |
| R | Tap wall, hold drag angle, Slows, 45 s [D] | 9 rocks, drag, cd 45, slow data present | differ (owner item 15 said rocks only) · **owner** |
| Dash | Landslide: dash, launches rock, ~12 s [D] | Rock Hop: 3 hops of 2.8 m/.26 s raw ×.85/×1.15 = 2.4 m/.3 s, cd 12 | differ (owner item 111) · **owner** |
| Passive | Punching rocks grants Shield [D] | Built; charge scaling ours | match · charge scaling **open** (branch ready: ext/parity-no-riders-grimble-tenzo) |
| Anim | Footage poses | 17 moves, all on `tarek.glb` (48) | match on coverage |

## Grimble (`dredge`, source Kingpin)

**0.24.5:** dredge-combo 112/0. Air slot 12.5 s stands. Open: E Grounds the foe (ext/parity-no-riders-grimble-tenzo); cooldowns 12, 7, 21 vs 18, 12, 36 (ext/grimble-parity-verify, ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | 7 slugs, bloom [D] | Seven-slug blast, bloom | match |
| RMB | Arm pierces terrain, pulls first target, 18 s [D] | 11.5 m through terrain, reel, 20% braced shuffle, cd 12 | match; 0.67x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Slam, stun, dunk, 12 s [D] | Windup .38, r 3, stun 1.1, cd 7, Grounded (ours) | match; **0.58x cd** · cd **open** (gap 10); Grounded **open** (branch ready: ext/parity-no-riders-grimble-tenzo) |
| R | Two waves, 36 s [D] | Charge 1.1, 2 waves, cd 21 | match; **0.58x cd** · cd **open** (gap 10) |
| Dash | One every 7 s; own air slot 12.5 s [D] | 3 chained, 3.2 m/.16 s raw (owner 23:40; F 4.6 m/.12 s) ×.85/×1.15 = 2.7 m/.18 s, air ×1.35 = 3.7 m (scaled once), cd 10, air shares slot | differ (owner); air slot missing (gap 13) · **owner**; air slot **done** `ext/parity-grimble-airdash` (main): `dash.air.cd` 12.5, 2 s less a rank |
| Passive | Stacks of max HP [D] | Salvage 10, +2.5%, lose 1 on down | match |
| Anim | Footage poses | 13 moves, all on `dredge.glb` (40) | match on coverage |

## Neve (`rimewright`, source Celeste; was Claire)

**0.24.5:** rimewright-combo 116/0. Chill 4 s with no slow and the late skating homing stand. Open: E cd 17 vs 20 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight while skating | match; skate tracking owner question (gap 16) · **done** `ext/parity-neve-skate-home`, `ext/neve-dart-homing`: late homing while skating, asserted |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) · **owner** |
| LMB | Hold, semi-homing, 3 heavy at end [D] | 4 plain + 3 large; straight, 2x damage while skating | match; skating darts 2x (wiki, `dash.skate_dart_dmg_k`; footage 1.6x, no data number); skate tracking owner question (gap 16) |
| RMB | Spear + delayed blast, 2 charges, 12 s [D] | Push-like emerge (owner), 2 charges, cd 10.2 | differ (owner) |
| Q | none | glove | ours |
| E | Wall pushes, recast freezes, 20 s [D] | Slide, grow, freeze, 200 HP (~50 own darts), cd 17 | match; 0.85x cd · cd **open** (gap 10) |
| R | Invulnerable zone 3.5 s, explode, stun, cancel, 80 s [D] | Hold 3.5, carry .8 x1.05 speed (owner), rink 4 bh +15% (owner), body as ice, cd 80 | match; +15% radius, +5% slide (owner 11-08) · **owner** |
| Dash | Hold, release stops, 13 s [D] | 11.5 m/s (F 10-11), 1.6 s, early-release refund .6 (owner) | match; refund owner |
| Passive | Chill 4 s, shatter on knock [D] | Chill + 15% slow (ours) | differ: slow ours · **done** `ext/parity-no-riders` (main): slow cut; `ext/neve-chill-shatter` asserts Chill 4 s and the knock Shatter |
| Anim | Footage poses | 19 moves, all on `claire.glb` (49) | match on coverage |
| Body | 1.1-1.15 [F] | size 1.15 | match |

## Motley (`ostra`, source Void; was Ostra)

**0.24.5:** ostra-combo 213/0. Bomb 3.5x stands. Open: the 10 s seed fizzle (ext/motley-seed-fizzle); floats `[?]` and the orb slow stay owner/untraced.

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Orb; idle next orb stronger, terrain, Slow [D] | .6, continuous charge to 1.4 s, every orb pierces | differ (owner items 60, data overruled) · **owner** |
| RMB | Shards, stun, 10 s [D] | cd 10, wind-up .32 vs .2 | differ (owner item 40) · **owner** |
| Q | none | glove | ours |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.0, fizzles 10 s (ours) | differ: 3x vs 3.5x, fizzle ours · 3.5x **done** `ext/parity-ostra-bomb` (main); fizzle 10 s **open** (ours) |
| E | Bomb grows, reactivate, up to 3.5x [D] | Grows 6.5 s, dmg_max_k 3.5, waits at full size until popped, no timer; cooldown on the plant [?] | match (the fizzle is removed) |
| R | Vortex stun + pull, 70 s [D] | Tell 1.0, 3.5 s, pull 12, cd 70 | match; ~1 s lock (owner) |
| Dash | Lob, swap all units, ~9.5 s [D] | 1.8 s lob, drift 35% (owner 11-08 +17%; source gives no drift), moves foes and allies (counters both) | match |
| Passive | Damage Empowers; floats [D] | Swollen variants | match; floating `[?]` · **open** [?] (the body hovers 0.3 m; a gameplay float not traced) |
| Anim | Footage poses | 14 moves, all on `ostra.glb` (45) | match on coverage |

## Albert (`bulwark`, source Oath; was Bjorn)

**0.24.5:** bulwark-combo 166/0. Throw rate 0.45 and E zone 2.3 m stand (the E row's r 3.5 is stale text). Open: Guard meter and Shield Slam, Crushing Blow stun 0.4, aegis routing (ext/albert-parity-verify, ext/parity-albert-blow-stun, ext/combat-albert-aegis-input); R cd 40 vs 50 (ext/cooldown-parity-verify).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Throw + recall; hold charged swing [D] | Tap whirl hold (owner), carry 1.5-1.8 m + perfect launch 4 m (owner #30, #49), cadence .48 vs .45, walks 55% vs stands | differ (owner); cadence S fix (gap 12) · **owner**; cadence **done** `ext/parity-mossy-cadence` (main): `throw_rate` 0.45 |
| RMB | Hold shield, front block, Shift = bash, 6 s [D] | hold .1, aegis, bash cd 6 | match; routing `[?]` · **open** on the candidate (`ext/mossy-shield-bash`, `ext/parity-aegis-block` merged); closed on ext/combat-albert-aegis-input (branch ready) |
| Q | none | glove | ours |
| E | Zone around hammer, burst, Wisps, 8 s @IV [D] | r 3.5, delay 1, 4 s, burst, cd 12/8 | match |
| R | Fissure stun, AoE, heavy Slow, 50 s [D] | 4 cells, stun .5, cd 40 | match; 0.8x cd · cd **open** (gap 10) |
| Dash | Spin Dash 8 s, knock [D] | Whirl 3.5 m/.17 s (F), off the dash feel, cd 8 | match |
| Passive | Wall knock Stuns [D] | Built; **Guard meter, Shield Slam invented** | differ (gap 15); owner question open · **open**: Guard and `resource.slam` still in `bulwark.json`; branch ready: ext/parity-bulwark-guardcut (owner 11-07 said cut) |
| Anim | Footage poses | 17 moves, all on `breaker.glb` (48) | match on coverage |

## Sparkle (`mage`, source Joule; was Ryzz)

**0.24.5:** mage-combo 143/0. Dash to LMB stands. Open: cooldowns RMB 8, E 10.5, R 42 vs 10, 12, 60 (ext/cooldown-parity-verify); Skycall radius 1.5 (ext/parity-skycall-size).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt + Static, F .8 s [D,F] | .648, range 13, no pierce | differ (owner items 70, 116) · **owner** |
| RMB | Hold/release, knock, orb, 10 s [D] | Hold 1.0, cd 8 | match; 0.8x cd · cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Press, or hold + drag aim, 12 s, 1 Static [D] | Drag built, delay .8, stacks 1, cd 10.5 | match |
| R | Launch, recast, crash, spreads Static, 60 s [D] | Hover 1.7, spread built, cd 42 | match; 0.7x cd · cd **open** (gap 10) |
| Dash | Press or hold, pass dmg, reset on 4 Static, 9 s [D] | Lane 7.5-13 m at 40 m/s (owner), time ×1.15 feel (felt ~35 m/s vs ~32), dmg 20, Blowout reset, cd 8 | differ (owner) · **owner** |
| Passive | Static, 4 stacks [D] | Built, orb reset closed by owner | match |
| Anim | Footage poses | 16 moves, all on `ryzz.glb` (45) | match on coverage |
| Flow | Silent | Dash→LMB, X buffer | gap 9 · **done** `ext/parity-dashlmb` (main): LMB fires mid-dash; 5 rows unsourced **open** [?] |

## Sable (`thief`, source Shiv)

**0.24.5:** dancer-combo 144/0. LMB 8.5 m and no Shred stand. Open: cooldowns RMB 7, E 15, R 24 vs 13, 28, 50 (ext/cooldown-parity-verify); E range 14 `[?]` (ext/parity-ranges-rest).

| Slot | Source | Ours | Verdict |
|---|---|---|---|
| LMB | Bolt, stacks passive [D] | .45, to cursor, 12 m, 13 dmg | match; range unconfirmed · **done** `ext/sable-lmb-range`: 8.5 m (9.5 empowered), bolt 37.5 m/s, asserted |
| RMB | Bolas, Ground, two targets stun, 13 s [D] | Bola 30% slow (owner item 53), cd 7 | differ (owner); **0.54x cd** · **owner**; cd **open** (gap 10) |
| Q | none | glove | ours |
| E | Dagger, 6 s forced return, 20 s @IV [D] | 14 m, 6 s, cd 15 | match; 0.75x of @IV · cd **open** (gap 10; level 1 is 28 s) |
| R | Barrage, edge bonus, resets dash, 50 s [D] | Encore r 2.3-5.4, rim band, 10 shots, cd 24 | match; **0.48x cd** · cd **open** (gap 10) |
| Dash | Dash, empower 2.34x, reset on hit, ~5 s [D] | 4.5 m/.48 s, air 8.4 m/.95 s (F), off the dash feel, prime 2.34x, cd 4.5 | match |
| Passive | +16 per hit stacking; heal on knock [D] | Marks; empowered Shred (ours) | differ: Shred ours `[?]` · **done** `ext/parity-no-riders` (main): Shred was stale text, removed |
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
- Zedran: drop the fireblast slow (`lmb.wave_slow`), the Chain Lunge stun and the Haul Slam stun (`rmb.haul.stun`): the source has no CC on them. Removing the Haul stun changes a documented move, so it needs the owner. **Re-audit 11-11: open**, all three still in `juggernaut.json` / `juggernaut_kit.gd`.
- Tarek: drop `rock.slow_*` and `dash.slow_t` (the source rocks shred armour, they do not slow). **Open**: no branch; ext/parity-no-riders-grimble-tenzo removes only the punch charge scaling and Grimble's Ground.
- Albert: the Shield Slam stun 0.6 s and the Crushing Blow stun 0.4 s have no source row. **Open**: Shield Slam goes with ext/parity-bulwark-guardcut (branch ready); `lmb.smash_stun` 0.4 has no branch.
- Ostra: decide 10% (wiki) or 6% (card read) for the full orb slow. Sable: pair stun 0.9 or about 1.8 s. **Owner**, both unchanged.

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

| # | Gap | Fix | Files | Effort | 0.24.4 (re-audit 11-11) |
|---|---|---|---|---|---|
| 1 | Zedran has no authored animation: `kael.glb` 0 clips, 20 moves procedural | Rig and author clips, add the map | art/wardens/kael, content/rules/warden_anim/kael.json | L | **done** `ext/kael-v2-model` (main): 49 clips mapped |
| 2 | Stopping is a hard stop for all 12: brake 110 vs 22.2 m/s² | Move brake to source, retune | content/rules/hunter_move.json, scripts/match/hunter.gd | M | **done** `ext/parity-move-feel`, `ext/phys-150-parity` (main): `physics.brake` 22.2 + friction 2 |
| 3 | Air control 0.3 vs 0.015, 20x source | Lower it; keep owner-asked steer rows | hunter_move.json, hunter_move.gd | M | **owner**: DECISIONS 2026-11-08 "real matches HAVE air control" overrules 0.015 (`tuning.json` air) |
| 4 | Dashes stop dead: keep 15%/30% vs carry | Raise carry. **Scale part done:** the ×.85/×1.15 layer runs only on kits with no source dash (table below) | hunter.gd | M | **done** `ext/parity-move-feel` (main): `dash_exit_run` 1.0, the dash hands over to the run; `ext/feel-dash-scale-source`, `ext/dash-curve-fit`; exact curves not decoded `[?]` |
| 5 | Hem's invented Focus/Deadeye sits over the draw | Remove, or owner keeps it | archer_kit.gd, archer.json | M, owner | **done** `ext/parity-lace-focus` (main) |
| 6 | Hem's Heavy Shot wall payoff ~0.4x vs ~5x | Raise wall_dmg, drop .4 floor | archer.json | S | **done** `ext/parity-lace` (main): `wall_mult` 4.94 |
| 7 | Hem's RMB .5 s dead zone before the draw reads | Match the footage start | archer.json, pin_needle.gd | S | **done** `ext/parity-lace` (main): hold 0.15, the charge counts from the press |
| 8 | Hem's Phase Walk stops at raised walls | Passable ledge faces | pin_spirit.gd, map height | L | **done** `ext/parity-phasewalk-rebased`, `ext/lace-phasewalk-verify`; end-inside follow-up is branch ready (ext/combat-lace-spirit-ledges-rebased) |
| 9 | Dash→LMB buffers on 6 kits (Hem, Bjorn, Zedran, Cinder, Ryzz, Tarek air), and Zedran, Bjorn and Cinder keep `cancel` rows; item 51 says combine | Flip rows to `fire`, source them | content/dash_flow/*.json | S | **done** `ext/parity-dashlmb` (main): Lace, Sparkle, Cinder, Tenzo air fire; Kael, Albert (and Grimble, Meeko) `buffer` is sourced; the remaining `cancel` rows (Kael, Albert, Cinder X; Kael air RMB, E) carry a source line |
| 10 | Cooldown pace is uneven: 0.48x to 1.0x of data | One rule per kit | content/archetypes/*.json | S, owner | **open**: candidate cds unchanged (0.48x to 1.0x); branch ready: ext/cooldown-parity-verify 2be9877c2 (every kit at 1.0x level 1, `--cooldown-parity-check`) |
| 11 | Done: Cinder is off the dash feel (3.4 m/.33 s, poof 6.8 m/.28 s); Grimble's air barge is scaled once (measured 3.7 m/.2 s) | none | asserted in --move-feel-check | done | **done** `ext/parity-dash-scale` (main) |
| 12 | Bjorn's cadence .48 vs .45; hold walks | Set .45; check hold | bulwark.json | S | **done** `ext/parity-mossy-cadence` (main): `throw_rate` 0.45; hold walk is owner #59 |
| 13 | Grimble's air dash lacks its own 12.5 s slot | Add slot | dredge_kit.gd, dredge.json | M | **done** `ext/parity-grimble-airdash` (main): 12.5 s air slot |
| 14 | Tarek's allies can't hop his rocks | Add jump hop | dolm_kit.gd | M, owner | **done** `ext/tenzo-ally-hop` |
| 15 | Bjorn's Guard meter and Shield Slam are invented | Remove, or owner keeps | bulwark_kit.gd, bulwark.json | M, owner | **open** on the candidate; branch ready: ext/parity-bulwark-guardcut b2e942eb4 (owner 11-07: cut) |
| 16 | Claire's darts fly straight while skating | Owner answer, then home | rimewright_kit.gd | S, owner | **done** `ext/parity-neve-skate-home`, `ext/neve-dart-homing` |
| 17 | Ostra's bomb peaks 3x vs 3.5x | Set 3.5 | ostra.json | S | **done** `ext/parity-ostra-bomb` (main) |
| 18 | Glide: steered accel, no -32.5 m/s dive | Add dive | hunter.gd | M | **done** `ext/parity-glide-dive` (main): `dive_vy` 32.5; steer from `ext/glide-steer-parity`; landing at the glide sink is branch ready (ext/glide-dive-land) |
| 19 | Ours-only riders: Chill slow, Shred, Pip's shield | Remove, or owner keeps | kit JSON, kits | S, owner | **done** `ext/parity-no-riders` (main): Chill slow, Shred text, Meeko's shield; the rest (Meeko Empowered range, Grimble Ground, Tenzo punch scaling) branch ready, Kael and Tenzo CC riders open |
| 20 | Jump 6.8 vs 7.5 m/s (deliberate, sourced below); 19 dash-flow rows have no source `[?]` (Hem 8, Ryzz 5, Tarek 6), listed below | Jump sourced and checked; rows marked `[?]`, not guessed | content/dash_flow, tools/move_feel_check.gd | S | **done** `ext/parity-jump-flowrows` (main): jump kept 6.8, pinned as 0.85 to 1.0 of 7.5; the 19 rows stay **open** `[?]` |

## Item 20: jump speed and the unsourced flow rows

**Jump speed.** Source: JumpZVelocity 750 uu/s = 7.5 m/s at gravity 14.7 m/s² (supervive_physics.md:45, [D]). Ours: `Hunter.JUMP_V` 6.8 m/s. Kept on purpose (`docs/MOVEMENT_FEEL.md`, "Jump 9 → 6.8"): 7.5 lets jump plus mantle top four terraces. It is a map-grammar deviation, not a source value; the owner can flip it once the terraces change. `--move-feel-check` now asserts `jump_speed_vs_source` (lift-off over 7.5, must sit in 0.85 to 1.0), so the source number is pinned and the gap cannot drift.

**Dash-flow rows with no `source` field `[?]`.** No source or footage settles these; they run as the kit's default (`keep`, or `fire` for Q). Not guessed.

| Hero | Rows `[?]` |
|---|---|
| Hem (`archer`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`; Q is ours, no source exists) |
| Ryzz (`mage`) | `hold.rmb.{ground,air,jump}` (3, `keep`); `dash.ground.q`, `dash.air.q` (2, `fire`, ours) |
| Tarek (`dolm`) | `hold.lmb.{ground,air,jump}`, `hold.rmb.{ground,air,jump}` (6, `keep`) |

Also still `[?]` and already marked "Not determinable" in their own `source`: Hem dash.ground.lmb, dash.air.{lmb,rmb,e,x}; Ryzz dash.{ground,air}.{lmb,rmb,e,x}. Other heroes carry further `keep` rows without a source (Cinder 3, Kael 4 on the candidate (was 3), Bjorn 1, Claire 3, Pip 3, one each of Cinder and Grimble `dash.ground.lmb` "Not determinable"): same `[?]`.

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
