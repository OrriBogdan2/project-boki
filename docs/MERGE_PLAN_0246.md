# Merge plan for 0.24.6

Built 2026-11-11 by job 20261111-060130-a6 (rpc1). Nothing has been merged into a release branch; this is a plan only.

## How it was built

- Input: every `READY ext/<branch> <sha>` line in `ext/agent-briefs:briefs/EXT_TO_MAIN.md`, last line per branch, keeping only shas that are not ancestors of `origin/main`, `origin/ext/release-integ-0244c` or `origin/ext/release-integ-0245` (92df78ce4). The coordinator's list `ready-unmerged-1111.txt` (860) was not on rpc1, so it was rebuilt the same way: **875** branches (the small difference is parser tolerance for odd READY formats).
- SUPERSEDED: a later READY line says `SUPERSEDES`/`replaces` it, a `-rebased` (or -v2/-r2/-redo/-fix) twin exists, another READY branch has the same sha, or the branch has no commits beyond release-integ-0245.
- HELD: excluded by the coordinator (ext/anim-uthana-rank NO-GO, ext/sable-wings owner pick; the 10 `ext/boki-<species>` branches are already in via ext/boki-species-integ, so none are on this list), or the READY line asks for an owner pick, says review only, or is an alternative to a fix already merged. DECISIONS.md has no other NO-GO branch.
- STALE: commit date before 11-08 with a conflicting trial merge (or sha missing from origin). Almost everything is from 11-08 or later, so this class is small.
- Trial merge: for every branch, `git merge --no-commit --no-ff <sha>` onto release-integ-0245 in a scratch worktree, then abort. `clean` = no conflicts against 0245 alone. Waves will interact: a later branch can conflict with an earlier one in the same wave even if both are clean alone.
- Stacks: `stack on` names the branch the READY line says it is stacked on / merges after. Merging the child brings the parent; merge the parent first or merge only the child.

## Counts

| Class | Count |
|---|---|
| MERGE | 714 |
| SUPERSEDED | 148 |
| HELD | 11 |
| STALE | 2 |
| **Total** | **875** |

MERGE trial results against release-integ-0245: **57 clean**, **101 light** (conflicts only in docs/, tools/check_registry.gd, tools/style_baseline.json: append-style rows, keep both sides), **556 code conflict**.

Most-hit conflict files: tools/check_registry.gd 332, docs/wiki/Rules.md 209, docs/DEBT.md 141, scripts/core/net.gd 125 (often the Net.VERSION line; not checked per branch), scripts/home/home.gd 123, tools/perf_bench.gd 113, tools/style_baseline.json 109. Most are list/row conflicts; bumping Net.VERSION once per wave avoids the net.gd ones.

Carried: **194** MERGE branches are already ancestors of another MERGE branch tip (mostly via `-rebased` branches and ext/stuck-integ-*), so the number of distinct merge heads is **520**. The `carried by` column names one container; merging it brings the branch along.

## Top 15 the owner will notice

All 15 are MERGE. Trial result against 0245 in parentheses.

1. Every screen gets simpler: fewer tabs, subtitles and boxes (owner 11-10). (`ext/ui-simplify`, conflict)
2. The match HUD shows only what you need now and adds the rest as you learn it. (`ext/ui-hud-reveal-1110`, conflict)
3. Holding Tab shows a new squad board: squads left, who is alive, downed or out. (`ext/ui-tab-scoreboard`, conflict)
4. The glider opens only on a double press of Space, never from holding it (owner 11-08). (`ext/feel-glide-double-press`, conflict)
5. The tutorial teaches the glider as a double press to match. (`ext/tut-glide-double-press`, conflict)
6. First-time hints when each Way Out opens. (`ext/tut-ways-out`, conflict)
7. A 5-second skippable squad intro on a flying skyship before the drop. (`ext/squad-intro-skyship`, light)
8. The new Sable look (appeal pass 4 pick). (`ext/sable-appeal4`, conflict)
9. Garden zone Glasswater, the first zone off the new garden hub. (`ext/garden-hub-theme`, conflict)
10. Garden zone Hushwood on its own island, joined to the hub. (`ext/garden-lantern-zone-hub`, conflict)
11. Hunters visibly carry the Heartspark (one shared carry pose for all 12). (`ext/anim-heartspark-carry`, conflict)
12. Heartspark sounds: a charge hum you can hear from far away, plus take and reveal stings. (`ext/sfx-heartspark`, conflict)
13. Bots play properly when downed and around downed players. (`ext/combat-bots-downed`, conflict)
14. Holding LMB through a dash or ability keeps firing the moment it ends. (`ext/feel-held-fire-resume`, light)
15. Controls: binding a key that is already used offers Swap or Cancel. (`ext/ui-rebind-conflicts`, clean)

## Waves

Order: feel and anim first (most owner-visible, lots of shared kit files), then combat, Boki, UI, tutorial, garden, audio, VFX, the rest. Inside a wave: stack parents before children, clean before conflict.

| Wave | Area | Branches | Clean | Light | Code conflict |
|---|---|---|---|---|---|
| 1 | feel | 91 | 12 | 27 | 52 |
| 2 | anim | 103 | 8 | 8 | 87 |
| 3 | combat | 170 | 13 | 30 | 127 |
| 4 | boki | 19 | 1 | 1 | 17 |
| 5 | ui | 60 | 7 | 8 | 45 |
| 6 | tutorial | 44 | 1 | 1 | 42 |
| 7 | garden | 72 | 3 | 1 | 68 |
| 8 | sfx | 49 | 2 | 4 | 43 |
| 9 | vfx | 57 | 6 | 7 | 44 |
| 10 | net/server | 7 | 0 | 1 | 6 |
| 11 | perf | 7 | 1 | 1 | 5 |
| 12 | tools/docs | 4 | 0 | 1 | 3 |
| 13 | misc | 31 | 3 | 11 | 17 |

### Wave 1: feel (91)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/feel-aim-near-body | 368e36b04 | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | cursor within a body width keeps the last good aim direction in Hunter.aim_dir: LMB, held RMB, E/R and facing; new --aim-near-check: old cod… |
| ext/feel-camera-fast | cf558f02f | 11-09 | clean |  | ext/anim-boki-cast-rebased +39 | camera: across follow locked on the Hunter; --camera-fast-check: offset per frame through every dash, Wirerun, Warchain pull, Abyssal Hand r… |
| ext/feel-cast-move-rebased | b972fc939 | 11-10 | clean |  |  | deep, w2; SUPERSEDES READY ext/feel-cast-move aed445785. origin/main d255acbee was already in the old branch; the 4 conflicts (+ Class-Unbro… |
| ext/feel-dash-no-input-rebased | 569a895ab | 11-11 | clean |  |  | SUPERSEDES READY ext/feel-dash-no-input b5c84f6d2; on rpc3. origin/main d255acbee was already the base of b5c84f6d2, so the MOVEMENT_FEEL.md… |
| ext/feel-dash-refill-order | 0e4f2a72c | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | dash refill is one timer for all 12 kits, asserted in --move-feel-check; Cinder knock refund keeps timer progress; dash slot countdown fixed… |
| ext/feel-hold-release-rules | ffe5bf838 | 11-10 | clean |  |  | holds end like the source: stun or down mid-hold now DROPS the hold (ArchKit._drop_rmb) instead of releasing it: Kael Lunge and Lace Heavy S… |
| ext/feel-impact-tiers-rebased | dc0785a38 | 11-11 | clean |  |  | SUPERSEDES ext/feel-impact-tiers 371e736ab; on rpc1. The merge with origin/main is a no-op: main d255acbee is already inside 371e736ab. The … |
| ext/feel-move-ults | 1c1aa1bfa | 11-10 | clean |  |  | move-ults settled vs data+footage: Flue Flight landing hands over at run speed 4.65 m/s via the shared dash exit (was x0.3 = 3.78) and eases… |
| ext/feel-panel-input | a31545b57 | 11-10 | clean |  | ext/anim-boki-cast-rebased +37 | panel input: first press after the map/Tab backpack/pause menu closes lands on the same frame (measured, no UI swallow found in scripts/ui: … |
| ext/feel-point-blank | f17dbfcb6 | 11-10 | clean |  |  | point-blank shots, one rule in Match.spawn_shot via new ShotOrigin: any shot spawned within 0.7 m ahead of its shooter (every kit muzzle 0.6… |
| ext/feel-range-clamp | 3951872af | 11-10 | clean |  |  | cursor past max range, all 12 Hunters: the source clamps every ground-targeted RMB/E/R (+Motley Trade) to the range edge on the cursor line,… |
| ext/feel-reticle-latency | 70698c86b | 11-10 | clean |  | ext/anim-boki-cast-rebased +37 | same-frame reticle and aim) |
| ext/aim-height | 3e886ea08 | 11-09 | light (1: MOVEMENT_FEEL.md) |  |  | cursor aim at terraces: with no foe under the cursor the aim is the first ground its ray meets, AimMode.ray_ground, shared with Vireo's ult … |
| ext/dash-interactions-refresh | 9577cce44 | 11-09 | light (2: KIT_PARITY.md, dash_interactions.md) |  |  | dash_interactions doc refresh) |
| ext/dash-nd-rows-a | 34fe36678 | 11-09 | light (2: KIT_PARITY.md, dash_interactions.md) |  |  | Not determinable dash rows A) |
| ext/dash-nd-rows-b | 7b951f8f9 | 11-09 | light (2: KIT_PARITY.md, dash_interactions.md) |  |  | Not determinable dash rows B) |
| ext/feel-aim-raw | e017f83d5 | 11-10 | light (2: MOVEMENT_FEEL.md, style_baseline.json) |  |  | aim raw: audit of mouse event to aim point in docs/MOVEMENT_FEEL.md 'Aim: the raw cursor'; no smoothing, acceleration or dead zone on the cu… |
| ext/feel-aim-steady | 26303dbd0 | 11-09 | light (1: style_baseline.json) |  | ext/anim-boki-cast-rebased +40 | aim steady: camera moves before the cursor is read (MatchCam.update, out of Match._process; match.gd -73), so shots fired while the view mov… |
| ext/feel-fps-parity-check | 38524c5cb | 11-10 | light (1: check_registry.gd) |  | ext/feel-dash-off-ledge-rebased +4 | --fps-parity-check: Vex/Kael/Cinder/Sparkle input script at 30/60/144 fps + 20 ms hitches agree within 2%; no _process gameplay drift found) |
| ext/feel-golden-determinism | 9841c4f97 | 11-10 | light (2: DEBT.md, Rules.md) |  |  | feel-golden check runs in a cleared space, golden re-recorded once, 3 identical runs; branched from ext/move-parity-1 since the check is not… |
| ext/feel-held-fire-resume | 48ebdbd0c | 11-10 | light (2: dash_interactions.md, check_registry.gd) |  |  | held-fire resume parity: LMB is a held input; held through dash/RMB/E/X/Q fire resumes the frame the lock ends with no re-press. Measured he… |
| ext/feel-hit-marker | 2f29b06a5 | 11-10 | light (2: HUD.md, check_registry.gd) |  |  | reticle hit tick: one per own landed hit from CombatBus.hit_landed, 4 short strokes in the Hunter colour 0.09 s, knock = longer strokes + ri… |
| ext/feel-hitstop-input | 137e32861 | 11-09 | light (2: check_registry.gd, style_baseline.json) |  |  | hit-stop input parity: an LMB tap inside the freeze fell between frames and was lost; now DashFlow.press_frozen marks it and route replays i… |
| ext/feel-knock-moment | cc269aa43 | 11-11 | light (2: MOVEMENT_FEEL.md, check_registry.gd) |  |  | knock moment parity: KnockMoment.cut from Match.knock drops a held RMB instead of releasing it into its cast (5 of 7 Hunters with a hold ope… |
| ext/feel-lace-tall-climb | a75d33917 | 11-10 | light (1: archer.md) |  |  | Lace tall climb: already live on main via climb_tall in hunter_move.json, so no code change; --wallmove-check section 1b asserts Lace tops a… |
| ext/feel-lag-comp-audit | ce35c0cfc | 11-10 | light (1: check_registry.gd) |  | ext/feel-dash-off-ledge-rebased +4 | lag-comp audit, no game change: online hits are shooter-authoritative (shooter game flies the shot vs its view, owner applies the hit; relay… |
| ext/feel-launch-arc | be68bdfd7 | 11-11 | light (2: MOVEMENT_FEEL.md, check_registry.gd) |  |  | launch-arc parity: a dash onto a Spring pad ran over it with no launch (dash branch held vel.y at 0); UtilityUse.pad_launch now ends the das… |
| ext/feel-lmb-spam | 8cc948ce6 | 11-10 | light (2: MOVEMENT_FEEL.md, archer.md) |  |  | LMB mash vs hold, all 12 Hunters measured headless (3 s held / hold-release cycles / tap rhythms vs 20 Hz clicks on a pinned dummy, table in… |
| ext/feel-mini-mantle | d68d3cd9d | 11-10 | light (2: DEBT.md, Rules.md) |  |  | doc-only, 1 commit on ext/move-parity-1 81ba868ff: mini mantle row marked [?]. The data has no mini-mantle height band; its 0.75 s is a post… |
| ext/feel-press-latency | db6f31f79 | 11-11 | light (1: MOVEMENT_FEEL.md) |  |  | SUPERSEDES READY ext/feel-press-latency db6f31f79: same branch plus one commit, the check's cursor on the foe's feet through the root's fina… |
| ext/feel-stop-slide | 8f160e5a3 | 11-10 | light (2: DEBT.md, Rules.md) |  |  | walking stop = UE ApplyVelocityBraking exactly: GroundFriction x BrakingFrictionFactor rows, 1/33 s sub-steps, 0.1 m/s stop; the 0.38-0.49 m… |
| ext/feel-town-fixed-step | c2435001b | 11-10 | light (2: DEBT.md, Rules.md) |  |  | town + interior on FarmStep, facing blended on farm/town/room; --move-rate-check town/room rows + facing assert; supersedes 1e8d0580f, which… |
| ext/feel-wasd-screen | b74046e41 | 11-11 | light (1: MOVEMENT_FEEL.md) |  |  | 8-direction WASD rows in --move-feel-check: W A S D and diagonals through the real keyboard path on the match camera, screen heading within … |
| ext/feel-water-move | c3127206f | 11-11 | light (1: MOVEMENT_FEEL.md) |  |  | water move parity table in docs/MOVEMENT_FEEL.md: run/dash/jump/glide take-off in shallow and deep water, source vs ours; source briefs sett… |
| ext/input-latency-check | 7618748a5 | 11-09 | light (1: MOVEMENT_FEEL.md) |  |  | input latency check) |
| ext/move-parity-1 | 81ba868ff | 11-10 | light (2: DEBT.md, Rules.md) |  | ext/feel-golden-determinism +3 | movement parity slice 1, base ext/release-integ-0244 ec7bccf3b. docs/MOVEMENT_PARITY.md: every movement quantity vs the source with status. … |
| ext/online-feel-100ms | 0bf60cf97 | 11-09 | light (2: ONLINE_FEEL.md, check_registry.gd) |  |  | online feel at 100 ms: hits/events flush per frame + early dash/cast snapshot, relay hears a press +6-17 ms instead of +24-115; docs/ONLINE_… |
| ext/sparkle-dash-rebased | 6eea8fe9f | 11-11 | light (1: check_registry.gd) |  |  | SUPERSEDES ext/sparkle-dash 754d177a0: that branch sat on a 582-commit integration stack, so it conflicted with main in 9 files; this is onl… |
| ext/cast-move-a | d2c555182 | 11-09 | conflict (4: juggernaut.json, Class-Unbroken.md, juggernaut_kit.gd…) |  |  | moving-while-casting table for RMB/E of Vex, Kael, Lace, Cinder, Meeko, Tenzo in docs/heroes; 1 fix: Kael Lunge charge walks at 0.8 of a run… |
| ext/combat-albert-aegis-input | 91c3dba10 | 11-10 | conflict (1: archer_bulwark_combo_check.gd) |  |  | Albert aegis input cases vs source: tap, hold/release, Shift held, Shift after release, LMB held, dash priority, stun; a press behind the ae… |
| ext/dash-buffer-window-rebased | aae4f8503 | 11-09 | conflict (3: dash_interactions.md, dash_flow.gd, gen_wiki.py) |  | ext/anim-timing-gunslinger +11 | supersedes ext/dash-buffer-window 77fa3ffde: main merged in; rimewright.json + 0010 conflicts kept Neve/Tenzo names and the 0.2 s window; --… |
| ext/dash-curves-b | d7e924199 | 11-09 | conflict (5: dash_feel.json, DEBT.md, Rules.md…) |  |  | fitted dash curves batch b: Albert 360 Smash and Sable ground Cartwheel curves in dash_feel.json from bjorn/dancer sheets, Sable's VAULT_CUR… |
| ext/dash-glide-all | 07957d143 | 11-09 | conflict (3: dash_interactions.md, hunter.gd, airdash_glide_check.gd) |  |  | owner 11-08 Shift cancels into glide: a fresh glide press in an air dash ends it that step and opens the glider at the dash's speed for all … |
| ext/feel-air-casts | b718a5219 | 11-10 | conflict (5: MOVEMENT_FEEL.md, dash_interactions.md, dredge_kit.gd…) |  |  | cast at the top of a jump, all 12 Hunters x LMB/RMB/E/R: what each does to horizontal and vertical speed vs a plain jump, rows air_cast in c… |
| ext/feel-ally-safe | 1eac31212 | 11-10 | conflict (2: KIT_PARITY.md, displace_net_check.gd) |  |  | ally safety: new --ally-cc-check, 12 heroes x every slot ground+air with an ally on each hit spot, none moved or given a status; no kit leak… |
| ext/feel-brake-cast | aed5121a9 | 11-10 | conflict (7: hunter_move.json, MOVEMENT_FEEL.md, SUPERVIVE_FEEL.md…) |  |  | brake under a cast: let go + RMB the same frame slides the plain stop for all 12; HunterMove.brake sheds at GROUND_SHED only over the Hunter… |
| ext/feel-cam-dash | f7372a845 | 11-10 | conflict (2: hunter_move.json, Rules.md) |  |  | camera trails a dash and eases in like the source: min(15 x gap, sqrt(2 x 28 x gap)) m/s in CamRig._trail_xz, numbers in hunter_move.json "c… |
| ext/feel-camera-lead | 1d954e74a | 11-10 | conflict (4: MOVEMENT_FEEL.md, cam.gd, check_registry.gd…) |  | ext/feel-camera-frame | on rpc1. Measured the cursor lead from the source clips in /home/boki/refs/supervive-mantle (hetzner; the /home/claude/svvid hero frames are… |
| ext/feel-dash-jump | ce47665c6 | 11-10 | conflict (4: MOVEMENT_FEEL.md, dash_interactions.md, check_registry.gd…) |  |  | dash-jump parity, all 12 Hunters: per-Hunter "Space and Shift together" table in docs/heroes/dash_interactions.md (gen_wiki from new dash_ju… |
| ext/feel-dash-off-ledge-rebased | 2e18d908d | 11-11 | conflict (118: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES READY ext/feel-dash-off-ledge 04c0748b2; deep on rpc1, escalated from 20261111-014743-a5. origin/main d255acbee was already insid… |
| ext/feel-dash-slopes | 8b9b45b3f | 11-10 | conflict (5: hunter_move.json, MOVEMENT_FEEL.md, Rules.md…) |  |  | dash on slopes, all 12 Hunters: shared HunterMove.follows_floor keeps a grounded walk/dash on the floor when the ground drops < floor_snap 0… |
| ext/feel-dash-wall-slide | 696e227f7 | 11-10 | conflict (2: DEBT.md, hunter.gd) |  |  | dashes slide along walls keeping cos(angle) of their length, per the source: UE CharacterMovementComponent slide under DashCurves; HunterMov… |
| ext/feel-facing-turn-rebased | d5333f969 | 11-09 | conflict (3: hunter.gd, check_registry.gd, move_feel_check.gd) |  | ext/anim-strafe-back | SUPERSEDES ext/feel-facing-turn d5333f969: same commit; origin/main d255acbee was already an ancestor so merging main changed nothing and no… |
| ext/feel-glide-double-press | 404b5c6c4 | 11-10 | conflict (7: MOVEMENT_FEEL.md, game.gd, home.gd…) |  |  | glider opens only on a double press, owner 11-08 decision 0058: Space held from the jump or with Albert's LMB never glides, inp.glide only k… |
| ext/feel-glide-hit | 9387fe89e | 11-10 | conflict (2: hunter.gd, check_registry.gd) |  |  | glider hits at source parity, decision 0055: shot = stays open + 3x heat (Hunter.GLIDER_HIT_HEAT), full heat or overheated = spike, no reope… |
| ext/feel-grimble-reel | 64a565f7f | 11-10 | conflict (3: dredge.json, dredge.md, dredge_combo_check.gd) |  |  | Grimble Abyssal Hand reel vs source, table in docs/heroes/dredge.md "Reel parity": arm out 22.5 m/s (was 26), reel 9 m/s from the grab frame… |
| ext/feel-haste-stack | d851dfcbf | 11-10 | conflict (5: hunter_move.json, Rules.md, warden_clips.gd…) |  |  | move-speed bonuses settled: add as one MoveSpeed attribute, slows multiply the total, clamp to MaxMoveSpeed 7.0 m/s; one rule HunterMove.gro… |
| ext/feel-hurt-dir-wash | 984776b91 | 11-09 | conflict (2: HUD.md, hudref_check.gd) |  |  | low-health red wash now leans toward the last second's hit directions: HurtWash (scripts/ui/hurt_wash.gd) replaces hud.gd's even 5-ring puls… |
| ext/feel-jump-forgive | 6811e055c | 11-09 | conflict (3: MOVEMENT_FEEL.md, hunter.gd, move_feel_check.gd) |  |  | jump forgiveness vs the source: coyote and jump buffer stay 0.12 s, source silent (bCanWalkOffLedges false, JumpCooldown/AirJumpPressDuratio… |
| ext/feel-kael-chain-steer | 4c1f21aca | 11-10 | conflict (1: juggernaut_chain.gd) |  |  | Kael Warchain pull re-measured vs data/wiki/footage: recast adds his speed toward the anchor (impulse), knock mid-pull now carries him inste… |
| ext/feel-knock-override-rebased | 1c92b024b | 11-10 | conflict (2: displace.gd, hunter.gd) |  |  | supersedes ext/feel-knock-override 1c92b024b; rpc3. Same commit: the branch already sits on origin/main d255acbee, so merging main is a no-o… |
| ext/feel-landing-carry | fdcc66aea | 11-10 | conflict (6: hunter_move.json, MOVEMENT_FEEL.md, Rules.md…) |  |  | landing carry parity: HunterMove.air_steer = UE falling CalcVelocity, air_brake 0.75 (FallingLateralFriction 0.375 x BrakingFrictionFactor 2… |
| ext/feel-mantle-timing | b24f26ccb | 11-11 | conflict (5: hunter_move.json, MOVEMENT_FEEL.md, SUPERVIVE_FEEL.md…) |  |  | mantle timing vs the source (MANTLE_185b, supervive_physics, owner clips): rim to top ~0.2 s, max(0.6x approach, 3.5 m/s) over the lip held … |
| ext/feel-pickup-reach | dc6d91c97 | 11-10 | conflict (3: Rules.md, match.gd, check_registry.gd) |  |  | pickup reach: radii/heights for walk-over consumables, shards, gems, seeds, keys (2.2/2.0 m, kept), tunings (1.1), bots (1.4) and gear/treas… |
| ext/feel-reversal | b94eb8803 | 11-10 | conflict (4: hunter_move.json, Rules.md, hunter.gd…) |  |  | walking turn like the source: UE CalcVelocity with keys held bends V toward the keys by GroundFriction 1.0 (turn_friction in hunter_move.jso… |
| ext/feel-same-frame | 047b42a57 | 11-09 | conflict (3: 0010-dash-ability-flow.md, hunter_keys.gd, check_registry.gd) |  |  | same-frame presses: dash first, then the press by its dash-flow row; R queued to the step; --same-frame-check 12x5 ground/air, 0 failures) |
| ext/feel-slow-ramp | 4461103ce | 11-11 | conflict (2: hunter.gd, move_feel_check.gd) |  |  | one ramp rule for every Slow and haste, PARITY FIRST: the source has no ramp time, the cap steps at once and the body follows at the walking… |
| ext/feel-step-up | 387615cfd | 11-09 | conflict (2: hunter_move.json, Rules.md) |  |  | step height 0.45 m [game data: MaxStepHeight left at UE default 45 uu] in hunter_move.json physics.step_height, World.STEP reads it; lips un… |
| ext/feel-summon-on-g | f0b047fd6 | 11-11 | conflict (8: MOVEMENT_FEEL.md, game.gd, net.gd…) |  |  | summon on G, design review 11-10 fix 6 / DECISIONS Controls: with wisps on, G press bursts the wisp into the Boki on the press frame (buffer… |
| ext/feel-summon-press-rebased | 410591940 | 11-10 | conflict (6: MOVEMENT_FEEL.md, game.gd, net.gd…) |  | ext/feel-summon-on-g | summon on G, design review 11-10 fix 6 / DECISIONS Controls: with wisps on, G press bursts the wisp into the Boki on the press frame (buffer… |
| ext/feel-train-inertia | c97932ba2 | 11-10 | conflict (2: Checks.md, train_check.gd) |  | ext/anim-boki-cast-rebased +39 | sky train as a moving platform, parity: only grounded riders are carried, the step you leave a car its speed is added to yours and the step … |
| ext/feel-wall-slide | 4de2100f4 | 11-10 | conflict (1: hunter.gd) |  | ext/feel-dash-wall-slide +1 | Hunters slide along walls at the tangent speed and never catch on corners: Tenzo rocks/barriers push-out + along-wall walk accel, HunterMove… |
| ext/feel-yaw-lock-12-rebased | 6d7ceae7b | 11-10 | conflict (13: archer.json, ashwick.json, bulwark.json…) |  |  | on w2; SUPERSEDES READY ext/feel-yaw-lock-12 6d7ceae7b: same commit. origin/main d255acbee was already an ancestor, so merging main changed … |
| ext/fps-feel | cbdde0a86 | 11-09 | conflict (3: hunter.gd, hunter_move.gd, check_registry.gd) |  | ext/perf-owner-hw +1 | fps-independent movement) |
| ext/glide-cast-rules | f8f23597f | 11-09 | conflict (3: dash_interactions.md, hero_zones.gd, gen_wiki.py) |  |  | every press with the glider open follows the source: table in dash_interactions.md, Meeko RMB and Void E/R no longer blocked in a glide, --g… |
| ext/glide-dive-land | e4081da34 | 11-09 | conflict (5: MOVEMENT_FEEL.md, SUPERVIVE_FEEL.md, glide_dive.gd…) |  |  | glide dive held to the ground lands at the glide sink, as the source does: GlideDive.catch_rate sizes the canopy catch to be back at the sin… |
| ext/glide-text-fix | d0a0d906f | 11-09 | conflict (4: tutorial.json, Rules.md, loading.gd…) |  |  | glide wording is jump, press again in the air, hold: tutorial, loading tips, Settings rows, README, wiki; keys via Settings.key_cap; new --t… |
| ext/glider-heat-parity | e8de9552e | 11-09 | conflict (4: Rules.md, hunter.gd, hunter_move.gd…) |  |  | glider heat parity) |
| ext/move-sfx-positional-rebased | 0e4199c4f | 11-09 | conflict (3: AUDIO.md, Rules.md, match_audio_check.gd) |  | ext/sfx-hunter-foley +2 | supersedes ext/move-sfx-positional 0e4199c4f; origin/main d255acbee already contains its base so the merge was a no-op and no match_audio_ch… |
| ext/no-dash-bursts-audit-rebased-rebased | 45bff0013 | 11-10 | conflict (45: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | supersedes ext/no-dash-bursts-audit-rebased 76cd0bbac; that branch already held origin/main, the conflicts were with ext/mc-20261110-0630, s… |
| ext/parity-jump-hold | 3df495034 | 11-09 | conflict (6: hunter_move.json, MOVEMENT_FEEL.md, Rules.md…) |  |  | jump hold and cooldown) |
| ext/parity-jump-pads | a2715040e | 11-09 | conflict (3: hunter_move.json, Rules.md, hunter.gd) |  | ext/landing-recovery | landing recovery vs the source: no lock anywhere, none added; STACKED on READY ext/drop-parity 8a7cbce24 and READY ext/parity-jump-pads a271… |
| ext/remove-hex | 16e00c03d | 11-09 | conflict (4: ARCHETYPES.md, tender_kit.gd, net.gd…) |  |  | Hex critter status + "hex" Net event removed, Net.VERSION 0.24.4; check, mage/hero combo 0 fails, health strict, wiki ok) |
| ext/sfx-dash-per-hunter-rebased | c696fbceb | 11-10 | conflict (44: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES ext/sfx-dash-per-hunter 53a365770 and the earlier -rebased e4bc51382: same resolution onto merge candidate ext/mc-20261110-0630 (… |
| ext/sfx-move-weight-rebased | a17c916e5 | 11-09 | conflict (3: AUDIO.md, sfx.gd, sfx_set_check.gd) |  | ext/sfx-hunter-foley +2 | supersedes ext/sfx-move-weight 366c29d3f: same weight-aware jump/land/wall-kick sounds plus a17c916e5 (weighted landings keep the 80 ms repe… |
| ext/split-kmoves-pin-bjorn | 89302ce30 | 11-09 | conflict (3: archer.md, rig_standard_check.gd, style_baseline.json) |  |  | split kmoves_pin_bjorn) |
| ext/vex-dash-parity-rebased | bee6851e8 | 11-09 | conflict (6: tuning.json, KIT_PARITY.md, VFX_QUALITY.md…) |  | ext/anim-timing-gunslinger +11 | escalation of 20261109-035233-a1; supersedes ext/vex-dash-parity efbd6af96; no gh on w2, PR: https://github.com/OrriBogdan2/project-boki/pul… |
| ext/vfx-glider-heat | 9dcb9afa1 | 11-10 | conflict (3: match.gd, models.gd, check_registry.gd) |  |  | supersedes 9f48748a3, deep : overheat smoke now reads at match zoom (dark ~0.4 m puffs that linger 1.1 s, was invisible 0.1 m pale dots); --… |
| ext/feel-camera-frame | 4469a16ea | 11-11 | light (2: check_registry.gd, style_baseline.json) | ext/parity-camera-framing |  | camera frame per aspect; STACKED on ext/parity-camera-framing 575798bd5 + ext/feel-camera-lead 1d954e74a + ext/feel-glide-camera f9a6df19a, … |
| ext/feel-glide-wall | a8da67659 | 11-10 | conflict (2: hunter.gd, wall_moves.gd) | ext/feel-wall-slide |  | glider slides along walls at source parity, decision 0023: UE CharacterMovementComponent slide, the into-wall speed dropped, the along-wall … |
| ext/feel-utility-move | dcc3108da | 11-11 | conflict (21: hollowcrown.json, armor_kit.json, tonic.json…) | ext/util-tonic-lamp |  | belt use and moving: per-item table in docs/SOURCE_UTILITIES.md from wiki + patch notes, footage not on this worker so those cells are [?]; … |

### Wave 2: anim (103)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/anim-alt-1111 | 0962adaf9 | 11-11 | clean |  |  | Albert death3, Albert victory, Albert heavy3: candidates only, no swap; MP4s in /home/boki/art-review/anim-alt-1111/) |
| ext/anim-boss-states | a6585add3 | 11-10 | clean |  |  | lair bosses keyed moves: BossAnim wake/sleep/idle/walk, every attack wind-up+strike, phase, stagger, death for colossus/serpent/brood; wind-… |
| ext/anim-extract-board | 5194dee7d | 11-09 | clean |  | ext/anim-boki-cast-rebased +39 | extract leave beat: every Hunter dips and takes off from its own crouch_in and jump clips for 0.7 s before the model hides, remote copies to… |
| ext/anim-results-pose | ec2ee3b48 | 11-10 | clean |  |  | results screen squad stage: ResultsStage in scripts/ui/results_stage.gd, built on open and freed with the screen; extracted squad = up to 3 … |
| ext/anim-timing-bulwark | f5b267fc4 | 11-10 | clean |  |  | Bulwark animation timing: throw release 0.16, recall catch on the clip key, aegis raise on the hold clock, timing table + asserts) |
| ext/anim-timing-tender | cb701fb55 | 11-10 | clean |  |  | Meeko animation timing: WardenClips probe per move asserted in --tender-combo-check, mm_call hand-off fixed to 0.33 s, tender.md timing tabl… |
| ext/anim-uthana-pilot | cd3be3338 | 11-10 | clean |  |  | Uthana AI-motion pilot on Albert+Lace: 11 moves, report docs/UTHANA_PILOT.md, spent $3.42 of $10 cap; renders in art-review/uthana-1110) |
| ext/anim-aim-pitch | a65859dfa | 11-10 | light (1: check_registry.gd) |  | ext/anim-pilot-layers-verify +6 | GPU strip for the aim pitch, superseding ea21ce611: --aim-pitch-shots now waits on process frames instead of frame_post_draw, which hung job… |
| ext/anim-arm-motley | b450797ad | 11-09 | light (1: ANIM_QUALITY_AUDIT.md) |  |  | deep, w2; supersedes 412f4a499, same branch fast-forward; STACKED on READY ext/anim-free-arm-relax a518863da (on ext/anim-quality-audit): me… |
| ext/anim-boki-idle | 8a82fd243 | 11-09 | light (3: RIGGED_BOKI.md, Rules.md, check_registry.gd) |  |  | breathing idle + a 4-9 s fidget for all 21 rigged Bokis, runtime BokiIdle; idle-check, rig-check, system-check, GPU strip pass) |
| ext/anim-flinch-layer | cd5b8b639 | 11-10 | light (2: CLIPS.md, check_registry.gd) |  |  | hit flinch is a torso spring over every clip and cast, 4 directions from hit_dir, scaled by hit_k; hit clip only on a stagger; WardenFlinch … |
| ext/anim-fusion-states-rebased-rebased | b6a98f9c2 | 11-11 | light (1: check_registry.gd) |  |  | SUPERSEDES READY ext/anim-fusion-states a67fd5c03 AND ext/anim-fusion-states-rebased df3fa0479; deep on rpc1, escalated from 20261110-232535… |
| ext/anim-jump-land | 7cf104460 | 11-09 | light (3: DEBT.md, CLIPS.md, check_registry.gd) |  | ext/anim-landing-weight | landing weight by fall speed, parity with the source: HunterAnim.land_tier picks none/hop/drop at touchdown (under 4 m/s a kerb plays nothin… |
| ext/anim-mob-states-rebased | aabf4cfc5 | 11-10 | light (2: ANIM_QUALITY_AUDIT.md, check_registry.gd) |  |  | supersedes ext/anim-mob-states: no rebase needed, origin/main d255acbee is already an ancestor of aabf4cfc5 and merge-tree shows no conflict… |
| ext/tender-gait-rebased | cdeada2b2 | 11-09 | light (1: ANIM_QUALITY_AUDIT.md) |  |  | on rpc1; SUPERSEDES READY ext/tender-gait 4f9fd219f). Merge of origin/main into ext/tender-gait: no textual conflicts now (ANIM_QUALITY_AUDI… |
| ext/air-cast-poses | cf02665e7 | 11-09 | conflict (7: cinder.json, claire.json, pip.json…) |  |  | air cast poses) |
| ext/airdash-anims-1108 | 2d9f67946 | 11-08 | conflict (9: tuning.json, cinder.json, hem.json…) |  | ext/anim-timing-gunslinger +5 | movement-air-core-1108 does not exist, so not rebased on it; no gh on w2, PR: https://github.com/OrriBogdan2/project-boki/pull/new/ext/airda… |
| ext/anim-aim-lead | 5ab860409 | 11-10 | conflict (3: CLIPS.md, warden_clips.gd, check_registry.gd) |  |  | aim lead on the v2 clips: WardenAimLead damped head 60 deg / chest 30 deg over the legs, off under full-body clips, mantle, dead, downed; --… |
| ext/anim-blend-snap | e84d7794c | 11-09 | conflict (11: cinder.json, claire.json, hem.json…) |  |  | strike snaps: 99 kit moves over 12 Hunters had their strike/release key inside the 0.1 s blend-in; per-move "fade" in warden_anim (key + 1 f… |
| ext/anim-boki-cast-rebased | 6ab11658f | 11-10 | conflict (46: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES ext/anim-boki-cast a9e410abe and the earlier -rebased 01725f549; now also has ext/mc-20261110-0630 merged in (0230 merges are a s… |
| ext/anim-cancel-blend | 691639cb1 | 11-10 | conflict (6: cinder.json, DEBT.md, warden_clips.gd…) |  |  | cancel hand-offs on all 12 Hunters: WardenClips upper layer now two crossfaded channels (an upper move cut by an upper move swapped in one f… |
| ext/anim-carry-pose-rebased | 9235196c2 | 11-10 | conflict (5: claire.json, CLIPS.md, warden_clips.gd…) |  | ext/anim-heartspark-carry | Heartspark carry pose: one shared WardenCarry.hold_mote upper-body layer for all 12, the off hand holds the mote at the chest (Lace: right, … |
| ext/anim-dash-travel | bf0ee5b7c | 11-09 | conflict (5: cinder.json, claire.json, DEBT.md…) |  |  | dash clips against the body's travel, owner bug 181 / decision 0020: --dash-frames-check now judges all 12 Hunters' ground dash on the kit c… |
| ext/anim-downed | 44555b467 | 11-09 | conflict (6: wisp_looks.json, Rules.md, hunter.gd…) |  |  | downed fall and rise) |
| ext/anim-elim-beat | 369641470 | 11-10 | conflict (4: Rules.md, hunter_wisp.gd, wisp_check.gd…) |  |  | Wisp elimination beat, 0.6 s: when a downed Hunter bleeds out or is finished the core dims, the Wisp sinks into the deathbox as it grows in,… |
| ext/anim-emote-gestures | c85072b2f | 11-10 | conflict (2: check_registry.gd, clip_check.gd) |  | ext/anim-boki-cast-rebased +40 | each emote-wheel id plays its own clip per Hunter: .glb clips reused where they fit, 11 keyed g_ gestures otherwise, upper body while moving… |
| ext/anim-evolve-moment | 718d78433 | 11-10 | conflict (2: home.gd, check_registry.gd) |  | ext/anim-nook-moment +1 | home evolution moment) |
| ext/anim-foot-plant | 78034f12e | 11-09 | conflict (2: check_registry.gd, perf_bench.gd) |  |  | foot planting on slopes) |
| ext/anim-gait-speed | 0345ac638 | 11-11 | conflict (15: breaker.json, cinder.json, claire.json…) |  |  | loops play at ground speed over their authored speed: one rule in WardenClips._rate, per-Hero planted-sole speeds walk_sole/run_sole/crouch … |
| ext/anim-glide-pose | 6a1a62f0f | 11-09 | conflict (7: hem.json, pip.json, vex.json…) |  |  | glide poses for all 12 Hunters: the Ctrl dive and skydive now go head-down (WardenClips never read air.dive; new WardenAirTilt pitches the .… |
| ext/anim-gun-recoil | 3a00dddd2 | 11-10 | conflict (4: CLIPS.md, warden_clips.gd, check_registry.gd…) |  | ext/anim-pilot-layers-verify +1 | additive arm+shoulder shot kick on Vex/Sable/Grimble v2 clips, 2/3/4 deg, settle 0.07-0.11 s, firing timing untouched; fixes the --recoil-sh… |
| ext/anim-heartspark-carry | cd1e7923b | 11-11 | conflict (8: claire.json, CLIPS.md, Rules.md…) |  |  | Heartspark carry pose: one shared WardenCarry.hold_mote upper-body layer for all 12, the off hand holds the mote at the chest (Lace: right, … |
| ext/anim-hunter-swim | b254dfb85 | 11-09 | conflict (4: cinder.json, home.gd, check_registry.gd…) |  |  | hunters wade with high knees and swim a crawl at swim speed, weapons held per kit, all 12; pond walk in --clip-check, --pond-shots GPU strip… |
| ext/anim-hymotion | e721004a7 | 11-10 | conflict (1: tarek.glb) |  |  | Tarek idle + walk_f from HY-Motion via tools/art1/glb_swap.py; judge idle 3.83 vs 3.42, walk 3.83 vs 3.17; clip-check 0 fail, health OK; LIC… |
| ext/anim-idle-breaks | 35cebb735 | 11-10 | conflict (3: warden_glb.gd, home.gd, check_registry.gd) |  |  | one 2-3 s idle break per Hunter after 6 s calm, from our personality lines; WardenBreak layer + idle_breaks.json; --idle-break-check 204/0 f… |
| ext/anim-idle-walk-gap-rebased | bed93d5dc | 11-09 | conflict (2: ANIM_QUALITY_AUDIT.md, anim_shots.gd) |  | ext/anim-stop-start | supersedes ext/anim-idle-walk-gap b0a1e9843; on w2. Merged origin/main d255acbee: git reports NO conflicts (tools/anim_shots.gd is new on th… |
| ext/anim-key-pose-read | c2d9b1d83 | 11-09 | conflict (4: cinder.glb, claire.glb, pip.glb…) |  |  | key pose readability) |
| ext/anim-landing-weight | 90263c8cd | 11-09 | conflict (3: ryzz.json, CLIPS.md, check_registry.gd) |  |  | landing weight by fall speed, parity with the source: HunterAnim.land_tier picks none/hop/drop at touchdown (under 4 m/s a kerb plays nothin… |
| ext/anim-nook-moment | 027d607ee | 11-11 | conflict (6: Checks.md, care.gd, home.gd…) |  |  | Nook pairing beat: walk, face, nuzzle, circle, settle, egg fades in with glow, unstable wobble, any key skips; --nook-moment-check 0 fails; … |
| ext/anim-pick-lockin | 8fd94b656 | 11-10 | conflict (7: cinder.json, hem.json, kael.json…) |  |  | supersedes fab794e61: lobby lock-in poses now picked per Hunter from existing clips at ~1.0-1.3x, not emotes squeezed to 1.4 s: Vex coin fli… |
| ext/anim-pilot-albert-neve | c70b0f6a2 | 11-10 | conflict (3: IMPORT.md, breaker.glb, claire.glb) |  |  | walk_f/run_f rebuilt for Albert and Neve. Albert: generated giant stride tools/art1/breaker_gait.py, blind Fable judge walk 4.00 vs 2.70 cur… |
| ext/anim-pilot-idle-slice | 5074eba87 | 11-11 | conflict (3: hem.glb, kael.glb, vex.glb) |  |  | Lace/Kael/Vex pilot idles: Meshy a338/a335/a338 beat current on blind Fable judge 4.2/4.5/4.3 vs 3.8/3.9/3.8; deaths kept, Meshy lost; Alber… |
| ext/anim-pilot-layers-verify | 971a5e81f | 11-10 | conflict (5: tarek.glb, vex.glb, CLIPS.md…) |  | ext/anim-pilot-loops-gs | Tarek boulder/wind/punch ride the upper body so legs keep the run; --layer-verify tool; pilot loops verified; merges pilot, recoil, additive… |
| ext/anim-pilot-loops-cm-v2 | 7a1e99243 | 11-11 | conflict (2: IMPORT.md, pip.glb) |  |  | Meeko: paws reweighted off root + sole-locked walk/run f/b/l/r, blind Fable judge 6/6 new; Cinder unchanged; supersedes ext/anim-pilot-loops… |
| ext/anim-pilot-loops-gs | 2e73fb76d | 11-11 | conflict (10: IMPORT.md, IMPORT.md, dredge.glb…) |  |  | Grimble + Sparkle walk/run f/b/l/r on the pilot gait: planted sole at loco speed, layers/combo/clip checks pass; stacked on unmerged ext/ani… |
| ext/anim-pilot-slice3 | 363b4ed13 | 11-11 | conflict (4: IMPORT.md, IMPORT.md, hem.glb…) |  |  | anim slice3 for Kael/Lace/Cinder. Lace walk_f/run_f: v2-rig Meshy retarget from ext/anim-pilot-lace-kael 285c34e45 (never posted), Fable 4.1… |
| ext/anim-prop-handoff | 98b984dd5 | 11-09 | conflict (4: KIT_PARITY.md, bulwark_kit.gd, dredge_kit.gd…) |  |  | thrown prop hand-off) |
| ext/anim-react-2-rebased | 40a96d636 | 11-10 | conflict (52: MERGE_REPORT.md, breaker.glb, claire.glb…) |  |  | SUPERSEDES READY ext/anim-react-2 2eea0e098; . Its conflicts were with candidate ext/mc-20261110-0630, not origin/main (main already in it),… |
| ext/anim-relic-puton | 5c395fce8 | 11-10 | conflict (2: mask_moment.json, Rules.md) |  |  | put-on beat: touch the Relic, porcelain face flickers 3x, Hunter fades in from the feet up, 1.5 s; any key skips once seen; --relic-puton-ch… |
| ext/anim-result-poses | 51f4c3ebe | 11-09 | conflict (3: cinder.json, exits.gd, check_registry.gd) |  |  | result beats for all 12 Hunters: win=own emote, lose=own downed clip, board=keyed pose per personality on the skiff deck; results card + Exi… |
| ext/anim-rooted-legs-rebased | ab8f843d4 | 11-09 | conflict (2: warden_clips.gd, check_registry.gd) |  |  | SUPERSEDES ext/anim-rooted-legs ab8f843d4: same commit; origin/main d255acbee is already an ancestor, so merging main changes nothing. The w… |
| ext/anim-run-start-stop | 7687f701a | 11-10 | conflict (3: MOVEMENT_FEEL.md, warden_clips.gd, check_registry.gd) |  |  | run start and stop poses: WardenStride in the anim module, speed + brake driven, nothing in hunter.gd; start lean settles as shown speed bui… |
| ext/anim-stomp-drink-1 | 26c04bc16 | 11-09 | conflict (13: cinder.glb, hem.glb, kael.glb…) |  |  | stomp, drink, revive-kneel clips now for Kael too: v2 bake script tools/art1/kael_v2_clips.py on actionkit; all four of Vex, Kael, Lace, Cin… |
| ext/anim-stomp-drink-2 | 197cb1d63 | 11-09 | conflict (5: claire.glb, dredge.glb, pip.glb…) |  |  | stomp, drink and revive-kneel clips for Meeko, Tenzo, Grimble and Neve, mapped in warden_anim; the rig stays the fallback) |
| ext/anim-stomp-drink-3 | fb4769a73 | 11-09 | conflict (7: breaker.glb, ostra.glb, ryzz.glb…) |  |  | stomp, revive kneel and drink clips for Motley, Albert, Sparkle, Sable; --anim-shots GPU strips checked, flask shows on GLB drinks; anim-sho… |
| ext/anim-summon-call | 5e6461885 | 11-10 | conflict (6: game.gd, net.gd, check_registry.gd…) |  |  | Hunter summon call gesture: ~0.3 s upper-body call per Hunter (warden_anim summon_call + emote_gestures call_*) fires on the Boki burst, nev… |
| ext/anim-summon-clips | db14e67b7 | 11-10 | conflict (7: game.gd, net.gd, boki_rig.gd…) |  |  | a summoned Boki plays its run/attack/ability/hit/faint clips: faint 0.9 s before the shrink, teleports are not speed, per-body-plan audit in… |
| ext/anim-tarek-pilot | 25f1588d7 | 11-10 | conflict (2: tarek.glb, vex.glb) |  | ext/anim-pilot-layers-verify +3 | Tarek idle+death from Meshy pilot m2; Tarek+Vex walk_f/run_f rebuilt loops that beat current on re-judge (walk 3.58/3.50 vs 2.67/2.83, run 3… |
| ext/anim-tarek-vex-dirloops-2 | 4ccfee1f5 | 11-11 | conflict (5: tarek.glb, vex.glb, tarek.json…) |  |  | Tarek and Vex walk/run b,l,r + real diagonals fl,fr,bl,br re-baked: no slide, pelvis dip 0.34 -> 0.11 m worst, ring in step; pilot run_f sti… |
| ext/anim-time-c | b0048cb76 | 11-10 | conflict (3: CLIPS.md, warden_clips.gd, archer_bulwark_combo_check.gd) |  |  | Albert and Sparkle clip timing tables + fixes) |
| ext/anim-time-cinder-rebased | 940d54f27 | 11-08 | conflict (3: cinder.json, CLIPS.md, warden_clips.gd) |  | ext/anim-timing-gunslinger +11 | supersedes ext/anim-time-cinder 584aa5241; . Merged origin/main d255acbee; one conflict, docs/art/wardens/CLIPS.md loco line: kept main's hi… |
| ext/anim-time-d | d956c4b09 | 11-10 | conflict (4: ostra.json, CLIPS.md, ostra.md…) |  |  | Sable and Motley clip timing tables + fixes) |
| ext/anim-time-kael | bfe9512dc | 11-09 | conflict (2: CLIPS.md, warden_clips.gd) |  | ext/anim-arm-kael +1 | Kael clip retime: 'lead' key in WardenClips, four Kael leads so each strike frame lands on the kit's hit, kael_anim_check asserts in --jugge… |
| ext/anim-time-sable-rebased | 990e28745 | 11-09 | conflict (2: sable.json, warden_clips.gd) |  | ext/anim-arm-sable +12 | supersedes ext/anim-time-sable 53f658240: same Sable timing change merged with origin/main d255acbee; one conflict in scripts/heroes/warden_… |
| ext/anim-timing-ashwick | 7fa218c6b | 11-10 | conflict (4: cinder.glb, cinder.json, ashwick.md…) |  |  | Cinder animation timing pass: ram hit, jet lift-off, cloak fling, landing, run cadence) |
| ext/anim-timing-dolm | 19488f015 | 11-10 | conflict (2: tarek.json, warden_clips.gd) |  |  | Dolm kit animation timing table + asserts; run cadence fixed kit-side) |
| ext/anim-timing-dredge | cb981d972 | 11-10 | conflict (3: dredge.glb, dredge.md, dredge_combo_check.gd) |  |  | Dredge animation timing parity: timing table in docs/heroes/dredge.md, anchor clip 0.8 s and lunge 0.44 s re-keyed so chained barges hold th… |
| ext/anim-timing-gunslinger | 364c76459 | 11-10 | conflict (119: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | Vex animation timing parity pass: X shot on the raised barrel at x_fire_s 0.2 s, held fire re-takes the upper body at each clip end so dash … |
| ext/anim-timing-juggernaut | 74a5a3f41 | 11-10 | conflict (3: kael.json, CLIPS.md, warden_clips.gd) |  |  | Kael parity pass: timing table, run cadence 1.5 to the 4.5/s footage, perfect-release + Riposte phase asserts; carries ext/anim-time-kael bf… |
| ext/anim-timing-mage | 9f4146491 | 11-11 | conflict (2: ARCHETYPES.md, mage_kit.gd) |  |  | Sparkle animation timing: measured table in mage.md, Skycall arm hold, RMB tap throw on the bolt, asserted in --mage-combo-check 150/0) |
| ext/anim-timing-rimewright | 1a4b90eab | 11-10 | conflict (3: claire.glb, rimewright.md, clip_check.gd) |  |  | Rimewright animation timing: wall shove on the 0.2 s eruption, run cycle 0.34 s, table in docs/heroes/rimewright.md) |
| ext/anim-timing-thief | bb024428c | 11-10 | conflict (2: sable.json, thief.md) |  |  | Sable animation-timing parity: run stride 1.63->2.26 Hz via sable.json run_speed, timing table in thief.md, asserts in --thief-combo-check) |
| ext/anim-utility-poses | b660b210c | 11-10 | conflict (6: armor_kit.json, rift_key.json, tonic.json…) |  |  | belt items get a body move: throw, place, read, drink; --utility-pose-check 12 Hunters, strips on GPU) |
| ext/anim-wall-kick | 7e70f8691 | 11-10 | conflict (3: check_registry.gd, style_baseline.json, wallmove_check.gd) |  |  | wall kick/bounce push-off on all 12 Hunters: foot on the wall + chest turns away, heavy Hunters crouch deeper/let go slower, no VFX; builds … |
| ext/anim-wild-boki | 8580a2d61 | 11-10 | conflict (3: boki_rig.gd, kin.gd, check_registry.gd) |  |  | wild Boki match states: startle/bolt/charge/dazed/scan Flex layer per body plan, dazed no longer spins; --wild-boki-states-check 344+ pass, … |
| ext/boki-downed-pose-rebased | fd0344937 | 11-10 | conflict (3: DEBT.md, boki_rig.gd, check_registry.gd) |  |  | SUPERSEDES ext/boki-downed-pose 8a2487d76; origin/main d255acbee was already inside it, so the 3 listed conflicts (boki_rig, kin, kin_puppet… |
| ext/boki-gait | 7caa9f112 | 11-09 | conflict (4: DEBT.md, Rules.md, boki_rig.gd…) |  |  | Boki gait) |
| ext/feel-trigger-edge | 06ef3f5b3 | 11-09 | conflict (1: archer_kit.gd) |  |  | trigger-edge table for all 12 hunters x 5 slots in DASHES_AND_ABILITY_FEEL 7; archer Heavy Shot tap now looses uncharged per source, rmb.hol… |
| ext/idle-archer-rebased | a94bdd7da | 11-09 | conflict (4: IMPORT.md, hem.glb, hem_clips.py…) |  |  | SUPERSEDES ext/idle-archer 8437593bb, which conflicted with main in hem.glb, hem/IMPORT.md and (by the report) posekit.py; build worker 2026… |
| ext/idle-bulwark-rebased | ccea3879a | 11-09 | conflict (2: breaker.glb, IDLE_AUDIT.md) |  |  | supersedes ext/idle-bulwark 53c963ec5, which conflicted with main in scripts/heroes/warden_mood.gd; merge origin/main in, kept main's atlas … |
| ext/idle-dredge-rebased | b217d2ec2 | 11-09 | conflict (3: dredge.glb, grimble_clips.py, posekit.py) |  |  | supersedes ext/idle-dredge b3fdeeeff, which conflicted with main in tools/art1/posekit.py; . origin/main merged in with no textual conflict,… |
| ext/idle-gunslinger-rebased | 4b0767ca7 | 11-09 | conflict (2: vex.glb, posekit.py) |  |  | supersedes ext/idle-gunslinger fa16ce7ef; Vex the Hired Gun idle+stance rework, same content, merged with origin/main d255acbee). The only c… |
| ext/idle-mage-rebased | 3e4ac3e0d | 11-09 | conflict (1: ryzz.glb) |  |  | supersedes ext/idle-mage 9d6d41c02; Sparkle the Storm Chaser idle+stance rework, same content, origin/main d255acbee merged in. Conflicts: r… |
| ext/idle-ostra | 2a99a0912 | 11-08 | conflict (4: IMPORT.md, ostra.glb, IDLE_AUDIT.md…) |  |  | Motley the Void Jester idle+stance rework; based on ext/parity-idle-audit, merge that first; trivial doc/STAND_OPEN conflicts with ext/idle-… |
| ext/idle-tender-rebased | 8cec53574 | 11-09 | conflict (3: pip.glb, pip.json, posekit.py) |  |  | supersedes ext/idle-tender be19bd8bf: Meeko the Dawnfox idle+stance rework on current main. pip.glb = the branch glb re-run through main's p… |
| ext/idle-thief-rebased | 97945e282 | 11-09 | conflict (2: sable.glb, posekit.py) |  |  | supersedes ext/idle-thief 619b8dc32: origin/main d255acbee merged; only art/wardens/sable/sable.glb conflicted, tools/art1/posekit.py auto-m… |
| ext/ostra-gait-rebased | b19403935 | 11-09 | conflict (5: IMPORT.md, ostra.glb, ANIM_QUALITY_AUDIT.md…) |  |  | hetzner; SUPERSEDES READY ext/ostra-gait 89acba32b). Merge of origin/main (d255acbee) into ext/ostra-gait: no textual conflicts now (the IMP… |
| ext/rimewright-skate-rebased | 4012ef0c3 | 11-09 | conflict (1: claire.glb) |  |  | SUPERSEDES ext/rimewright-skate 9e4710f64; ): origin/main d255acbee merged into 9e4710f64 with no conflicts left (main's claire.glb commits … |
| ext/strike-reach-heights | 75a9a854e | 11-09 | conflict (7: IMPORT.md, breaker.glb, cinder.json…) |  |  | on w2; strike reach vs the kits' metre reaches at the owner's heights: new --strike-reach-check (also inside --clip-check) reads "strike" [p… |
| ext/anim-v2-audit-slice | 8ea5dbb93 | 11-09 | clean | ext/anim-quality-audit | ext/anim-boki-cast-rebased +48 | v2 animation re-audit: gait, arms, prop alignment, timing tables hold; kael-sword hand assert restored; merge after ext/anim-quality-audit) |
| ext/anim-arm-kael | 7707b024c | 11-09 | conflict (8: answer.md, tuning.json, kael.json…) | ext/anim-quality-audit |  | SUPERSEDES 33006d6ab; deep : same Kael slam/meteor free_arm off-arm fix plus ext/anim-time-kael bfe9512dc merged in; merge after ext/anim-qu… |
| ext/anim-arm-sable | a176bc764 | 11-09 | conflict (3: sable.json, ANIM_QUALITY_AUDIT.md, warden_clips.gd) | ext/anim-quality-audit |  | SUPERSEDES READY ext/anim-arm-sable a176bc764; merge after ext/anim-quality-audit; contains ext/anim-free-arm-relax and ext/anim-time-sable-… |
| ext/anim-guardian-stance | dee1eaf62 | 11-11 | conflict (6: game.gd, net.gd, boki_rig.gd…) | ext/wisp-guardian-rebased |  | guardian Boki motion: lands facing the nearest threat, per-body-plan low/wide stance on Flex via KinGuardStance (no new rig/clips), turns to… |
| ext/anim-hand-albert | 2182efdc5 | 11-09 | conflict (2: breaker.glb, ANIM_QUALITY_AUDIT.md) | ext/anim-quality-audit |  | Albert lmb_throw/lmb_slam hand travel spread over 6 and 3 frames at 30 fps, audit hand step 0.51 -> 0.42 and 0.64 -> 0.50 body heights; supe… |
| ext/anim-hand-tenzo-rebased | f3e36f0ec | 11-09 | conflict (2: tarek.json, ANIM_QUALITY_AUDIT.md) | ext/anim-quality-audit |  | deep, hetzner; SUPERSEDES READY ext/anim-hand-tenzo f44d76294). origin/main d255acbee merges into f44d76294 with no conflicts. The tarek.glb… |
| ext/anim-mantle-1 | 218d107f8 | 11-09 | conflict (11: cinder.glb, kael.glb, pip.glb…) | ext/anim-quality-audit |  | Vex, Kael, Cinder, Meeko ledge climb: own mantle clip timed to the rise (progress-driven) plus real-time vault, procedural fallback kept; me… |
| ext/anim-mantle-2 | 097e80540 | 11-09 | conflict (6: claire.glb, dredge.glb, hem.glb…) | ext/anim-quality-audit |  | merge after ext/anim-quality-audit; on rpc1. Mantle + ledge pull-up clips for Lace, Tenzo, Grimble, Neve via new tools/art1/glb_climb_clips.… |
| ext/anim-mantle-3 | c55ef02ea | 11-09 | conflict (5: breaker.glb, ostra.glb, ryzz.glb…) | ext/anim-quality-audit |  | merge after ext/anim-quality-audit (merged in); supersedes 6e67216b9. Sparkle, Albert, Sable, Motley keyed mantle + ledge clips wired in war… |
| ext/anim-react-audit | 807d9386e | 11-09 | conflict (8: breaker.glb, claire.glb, hem.glb…) | ext/anim-quality-audit | ext/anim-react-2-rebased +1 | SUPERSEDES READY ext/art1-clip-port 0494c83a6; hit-reaction keys in tools/art1 breaker_anims, hem, claire, sable, ryzz clip scripts, re-bake… |
| ext/anim-stop-start | 6e24c8d29 | 11-09 | conflict (5: DEBT.md, ANIM_QUALITY_AUDIT.md, warden_clips.gd…) | ext/anim-quality-audit |  | stop/start after the source brake, all 12: clip rate follows the feet of the blend (legs hold their stride on a let-go), loco.stop_rate defa… |
| ext/anim-strafe-back | 5f53bb1ca | 11-09 | conflict (12: breaker.json, cinder.json, hem.json…) | ext/feel-facing-turn |  | back-run and strafe planted-foot for all 12 Hunters: dir_foot, rate_max, side_legs, audit direction gate, strips; STACKED on ext/feel-facing… |
| ext/anim-tarek-vex-dirloops | 85503bd61 | 11-11 | conflict (2: tarek.glb, vex.glb) | ext/anim-tarek-pilot | ext/anim-pilot-loops-gs +1 | Tarek+Vex walk/run b/l/r rebuilt on the pilot gait recipe, stacked on ext/anim-tarek-pilot: same length+phase as pilot f loops so diagonals … |
| ext/vfx-origin-v2-rebased | 82998a018 | 11-09 | conflict (44: dolm.json, mage.json, tender.json…) | ext/vfx-pass |  | supersedes ext/vfx-origin-v2 53e5acdc4; merge after ext/vfx-pass b7d8bf3c0, which it contains: origin-v2 sat cleanly on main but conflicted … |

### Wave 3: combat (170)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/combat-mob-damage | 94ef21876 | 11-11 | clean |  |  | --mob-damage-check: a Medium Hunter, classic kit, no Boki, full armour, stands idle among each of the 7 mobs, the 7 fixed camp mixes and the… |
| ext/combat-shield-decay | cf91a3993 | 11-10 | clean |  |  | shield duration/fade/stacking table in docs/ABILITIES.md: data settles only Cinder pounce 150/2s and Void 375/3s, fade/caps stay [?]; Void s… |
| ext/combat-xp-no-trickle | c05160e51 | 11-10 | clean |  | ext/combat-armour-xp | no passive XP trickle and no level XP for damage, armour from Hunter damage kept, knock/lair XP kept; --level-hud-check 0 fail incl. 60 s st… |
| ext/hero-heights | fb4a41b7c | 11-08 | clean |  |  | bulwark clip-check drift fixed: cherry-picked 14e91aebe from ext/fix-albert-blade-clip, which squares the blade bone under the root's x/z bu… |
| ext/kael-lmb-chain | 027b36e8c | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | Kael LMB chain vs hero-ref 0023-0034 at 5 fps: no step into a swing (nameplate pinned 0025-0036; ours 0.00 m, asserted), sides alternate acr… |
| ext/lace-hail-wisps-rebased | 60ae89d11 | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | SUPERSEDES ext/lace-hail-wisps d93205aaa; origin/main d255acbee was already inside d93205aaa, so merging main changes nothing: the 3 listed … |
| ext/mob-boss-sheets | 430005c95 | 11-10 | clean |  |  | 7 mob + 3 lair boss turnaround sheets graded >=8.5, cards + prompt fixes + PICKS_1110.md; owner review at /home/boki/art-review/mobs-1110/, … |
| ext/mob-design-1109 | 1b6a33494 | 11-10 | clean |  | ext/mob-boss-sheets | mob design cards x7 + TURNAROUND_SPEC + turnaround prompts + current renders; docs only, no gens) |
| ext/sfx-mob-death | 0fef6b3e6 | 11-10 | clean |  | ext/feel-dash-off-ledge-rebased +4 | monster death cue per voiced kind in its v_<kind> family, stagger open tick + landed hit, MobSfx positional with a 3-per-200ms death cap, --… |
| ext/sparkle-tooltip-parity | cb98e3f8d | 11-09 | clean |  | ext/anim-boki-cast-rebased +39 | Sparkle passive tooltip: removed false knock-heal 15% line; mage.json + wiki, no gameplay change) |
| ext/vfx-cinder-flight | d6d591846 | 11-09 | clean |  | ext/anim-boki-cast-rebased +48 | supersedes the 982230c64 line: Cinder Flue Flight carpet drawn the full trail_w 1.8m it burns (asserted: look 1.80 = burns 1.80), deep orang… |
| ext/vfx-dmg-number-roll | 7e1c8569d | 11-10 | clean |  |  | damage numbers: same-source ticks roll into one label, size by damage tier, clear of the reticle; --dmg-number-check) |
| ext/vfx-kael-chain | 7b35a2e0d | 11-09 | clean |  | ext/anim-boki-cast-rebased +48 | Kael's Warchain at the match camera: thick striped rope 0.4 m (was a 0.13 m dotted line), marker ring on the hooked foe for both sides, two … |
| ext/ability-bar-charges | 82671deed | 11-09 | light (2: HUD.md, check_registry.gd) |  |  | ability bar charges and slots) |
| ext/combat-boots-charms | 9f526d7cc | 11-10 | light (2: KIT_PARITY.md, check_registry.gd) |  |  | boots and charms to source) |
| ext/combat-bot-dodge | 7a6b016af | 11-10 | light (1: AIMKIT.md) |  |  | bots dodge telegraphs) |
| ext/combat-camp-clear | 1383bd552 | 11-10 | light (1: check_registry.gd) |  | ext/combat-pve-mult | supersedes d607cf333: --camp-clear-check median of 5 alerted same-level trials; table redone; 1.6x band NOT met (4.4-12x), mob hp x2 still 5… |
| ext/combat-deployable-hp | e24b6c82e | 11-09 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +39 | placed objects: HP/lifetime/damagers/on-break table docs/heroes/deployables.md, source rows cited, no kit JSON differed; --deployable-hp-che… |
| ext/combat-friendly-fire-rebased | 661e25ae2 | 11-10 | light (1: KIT_PARITY.md) |  |  | supersedes ext/combat-friendly-fire e77ba7f26: that branch already sits on current main d255acbee, merge is a no-op and KIT_PARITY.md has no… |
| ext/combat-fusion-band | 2fd2116ae | 11-10 | light (1: check_registry.gd) |  |  | Fusion band: --fusion-band-check measures all 19 built Fusions (3 forms + fallback merge per Boki type, worn by Vex/Kael) vs the 12 Hunter u… |
| ext/combat-glove-band | eff2c4e60 | 11-10 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +39 | --glove-band-check: gloves held to the 12 kits E max; Gust launch 9->7.5 m/s) |
| ext/combat-lace-wallclimb | ce48616c4 | 11-11 | light (2: KIT_PARITY.md, archer.md) |  |  | Lace double-wall climb: main's climb_tall already covers it, so no code change; --archer-combo-check +3 asserts (4-terrace wall climbed faci… |
| ext/combat-level-growth | 58fc9de8a | 11-11 | light (1: style_baseline.json) |  |  | level growth to source straight lines: AP +3.9%/lvl, HP +6%/lvl, no half rate; Aegis grows with max HP, Mending Ground + Hearthlight heals w… |
| ext/combat-revive-diminish | e11e3f296 | 11-10 | light (1: DEATH_AND_REVIVE.md) |  |  | the source curve 1/.75/.58/.47 now also slows wisp revives (shared per-victim count with box revives) and stomp finish+drain (own count); on… |
| ext/combat-summon-cc | 710cbf3e5 | 11-11 | light (2: Rules.md, check_registry.gd) |  |  | CC on a summoned Boki: docs/specs/SUMMON_CC.md, every kind = Hunter rule except Grounded (no dash/jump/glide to lose) via SummonCc + 1 line … |
| ext/combat-wall-surfaces | 356eb1854 | 11-09 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +40 | every wall stun asks one test, KnockWall: cliffs, rocks, Rink Wall, train engine stun; tier step, deck, crates, kegs, Hunters (bar Storm Rod… |
| ext/docs-heroes-sweep | 19fb5b69b | 11-09 | light (8: archer.md, ashwick.md, bulwark.md…) |  |  | hero docs sweep) |
| ext/edge-knock-parity | 0286f0cfc | 11-09 | light (1: MOVEMENT_FEEL.md) |  |  | bots no longer held at the rim by a shove; --abyss-check asserts hard-knock glider timing and the half-strength overheated lift; edge-knock … |
| ext/hero-docs-sync-a | 40512360c | 11-09 | light (5: ashwick.md, bulwark.md, dolm.md…) |  |  | hero docs: per-slot tables synced to data for six heroes) |
| ext/hero-docs-sync-b | 03f75a8fd | 11-09 | light (3: archer.md, dredge.md, tender.md) |  |  | mage/dredge/tender/thief/archer/ostra tables synced to data after parity wave) |
| ext/kit-parity-refresh-1 | 4791eb5c9 | 11-09 | light (1: KIT_PARITY.md) |  |  | docs/KIT_PARITY.md: Vex, Kael, Lace, Cinder, Meeko, Tenzo re-checked on main d255acbee, canon names, closing shas, pending branches; doc onl… |
| ext/kit-parity-refresh-2 | f1efc51af | 11-09 | light (1: KIT_PARITY.md) |  |  | KIT_PARITY.md Grimble, Neve, Motley, Albert, Sparkle, Sable tables re-checked on main d255acbee with canon names and closing shas, Status co… |
| ext/motley-seed-fizzle | 9f521695a | 11-09 | light (1: ostra.md) |  |  | Motley's un-popped Brimseed waits at full size with no timer: the source lists no expiry, the 10 s fizzle is removed; cooldown stays on the … |
| ext/parity-downed-numbers | daad5a0f5 | 11-09 | light (2: DEATH_AND_REVIVE.md, Rules.md) |  |  | docs/DOWNED.md source-vs-ours table for the downed loop; set from source: crowd curve 1/0.75/0.58/0.47 for revivers and stompers, revive bar… |
| ext/parity-no-riders-meeko | 0d6177875 | 11-09 | light (2: KIT_PARITY.md, tender.md) |  |  | Meeko Empowered +40% range/double wind-back and Hearthlight self_k 0.33 removed: source silent, fields and code deleted; Empowered = cue onl… |
| ext/sfx-boss-stingers | c18689570 | 11-10 | light (2: AUDIO.md, check_registry.gd) |  |  | own wake roar, phase/enrage sting and defeat sting per lair boss; --boss-sfx-check) |
| ext/sfx-listener-hunter | fd2db44dd | 11-10 | light (2: AUDIO.md, check_registry.gd) |  |  | AudioListener3D on the followed Hunter, camera yaw; pool+loops now AudioStreamPlayer3D so shots pan; hear_range 32 m, 25 m fight ~-16 dB vs … |
| ext/ui-damage-direction | 540cc0d9d | 11-10 | light (1: check_registry.gd) |  |  | hit arcs: DamageDir (scripts/ui/damage_dir.gd) draws a short red arc on a ring round your Hunter, in screen space, at each rival Hunter that… |
| ext/ui-plate-parity | b3622c8ec | 11-10 | light (1: HUD.md) |  | ext/anim-boki-cast-rebased +40 | overhead plates to HUD.md) |
| ext/vfx-mob-tells | fa2e15511 | 11-10 | light (1: style_baseline.json) |  |  | mob attack tells: ground shape = real hit shape filling to the hit frame + body glow, one MobTell source, --mob-tell-check) |
| ext/vfx-ostra-abilities | d21f7a537 | 11-08 | light (1: VFX_QUALITY.md) |  | ext/anim-timing-gunslinger +14 | PR #26 into it). Motley's RMB/E/X ability VFX up to docs/VFX_QUALITY.md: content/vfx/ostra.json in sea teal #2ee6c0 with void cores and afte… |
| ext/albert-parity-verify | b69c6ca3b | 11-09 | conflict (8: bulwark.json, KIT_PARITY.md, bulwark.md…) |  |  | cuts Guard meter and Shield Slam via parity-bulwark-guardcut b2e942eb4 merged onto main; R strike 2 and eruption 25 to data ratios 31/396 vs… |
| ext/albert-size-boop-rebased | dc95e0d18 | 11-09 | conflict (18: MERGE_REPORT.md, IMPORT.md, breaker.glb…) |  | ext/reset-cue-rebased | supersedes ext/reset-cue 1dd752d4d; origin/main d255acbee was already in it, the real conflict was with READY ext/albert-size-boop-rebased d… |
| ext/armour-parity | 254af75c8 | 11-09 | conflict (4: dredge.md, Rules.md, hunter.gd…) |  |  | armour parity) |
| ext/body-hitbox-parity-rebased | 4988bb2e7 | 11-09 | conflict (4: IMPORT.md, gunslinger.json, ARCHETYPES.md…) |  | ext/anim-timing-gunslinger +11 | supersedes ext/body-hitbox-parity b9f481fa0: same parity hit radii (Breaker 0.50, Kael 0.445, Tarek 0.412, Vex 0.400, Claire 0.362) merged w… |
| ext/bot-boki-summon | f34f48ce5 | 11-09 | conflict (4: game.gd, net.gd, perf_bench.gd…) |  | ext/combat-bots-downed +11 | bots press Summon: BotKin.summon on entering a fight (rival/brute within 12 m, hp >= 45%) or a mate downed within 15 m, never fleeing/hexed/… |
| ext/bot-kit-use-b | a2dc282d1 | 11-09 | conflict (2: BOT_KIT_USE.md, archer_kit.gd) |  | ext/bot-kit-use | bots use Sparkle's Skycall drag and Kitefall strike, Meeko's Hearthlight throw, Lace's Starpiercer, Motley's lantern lead; tools/bot_kit_use… |
| ext/camp-parity | b761adb77 | 11-09 | conflict (2: check_registry.gd, perf_bench.gd) |  |  | camp leash fix: stops at 13 m, walks home, heals; --camp-check; docs/CAMP_PARITY.md, no camp numbers in the source so none changed) |
| ext/cinder-sable-polish-rebased | f3bf0403b | 11-09 | conflict (4: sable.glb, sable_atlas.jpg, sable_atlas.jpg.import…) |  |  | supersedes ext/cinder-sable-polish 6952af96d: origin/main d255acbee merged. git reported no conflicts (main has not touched sable.glb or sab… |
| ext/combat-armour-xp | 4e48e792e | 11-11 | conflict (4: shotgun.json, dredge.md, Rules.md…) |  |  | armour progress to content/rules/armor_xp.json via ArmorXp: the source's 2k/3.6k/12k/20k thresholds scaled by base health (145/1,030) to 282… |
| ext/combat-blockers | 900369206 | 11-10 | conflict (4: Rules.md, verbs.gd, world.gd…) |  |  | one blocker rule: content/rules/blockers.json + scripts/combat/blockers.gd, table 10 crossers x 5 blockers in docs/ABILITIES.md, decision 00… |
| ext/combat-boss-tells | 208907fe9 | 11-09 | conflict (2: Rules.md, data.gd) |  |  | boss tells from content, compounding wind-up fix, phase shove ring, --boss-tell-check) |
| ext/combat-bots-downed | 56abc8085 | 11-10 | conflict (51: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | SUPERSEDES 6ed22f37c; deep on rpc1, escalated from 20261110-180846-a4. Bots play downed teammates like a fair player (scripts/match/bot_resc… |
| ext/combat-cc-mobs | 1325b9836 | 11-09 | conflict (3: KIT_PARITY.md, mage_sky.gd, check_registry.gd) |  |  | Hunter CC and displacement on monsters: --mob-cc-check, 20 abilities x Hunter/skitter/brute/boss; Skycall Grounded, Vex Burr wall stun, Basa… |
| ext/combat-hurtbox-parity | 5e5af6791 | 11-10 | conflict (10: archer.json, ashwick.json, dredge.json…) |  |  | per-Hunter hurtbox radius+height from the height chart, body collision separate, --hurtbox-check, overlay shots) |
| ext/combat-in-combat-rule | d9132213a | 11-10 | conflict (6: kin_regen.gd, bot.gd, ent.gd…) |  |  | one InCombat rule, content/rules/combat.json window_s: shield refill, Boki mending, drive music, bot far tick, Boki 10 Hz think and orders r… |
| ext/combat-knock-resets | da8114b89 | 11-10 | conflict (7: KIT_PARITY.md, gunslinger_kit.gd, dash_reset.gd…) |  |  | knock/kill resets audited vs supervive_kits for all 12 (docs/KNOCK_RESETS.md); owner item 159 built: DashReset gives a one-charge dash back … |
| ext/combat-lace-spirit-ledges | 40f7865d8 | 11-10 | conflict (6: ABILITIES.md, KIT_PARITY.md, archer.md…) |  |  | Lace Spirit Walk passes terrain ledge faces, KIT_PARITY gap 8: faces taller than a step-up are passable while the walk lasts, at the height … |
| ext/combat-levelup-refill | 8d0d68c2b | 11-10 | conflict (4: weapon_path.json, Rules.md, check_registry.gd…) |  |  | level-up refills to source) |
| ext/combat-meeko-carry-drop | 2f7dd01f2 | 11-10 | conflict (6: tender.json, KIT_PARITY.md, tender.md…) |  |  | Meeko Soulpack drop traced per case: any damage (shot, DoT) or a stun drops + 4s lock; root, slow, knock-back, heal hold; root/hex removed f… |
| ext/combat-perk-orbs | 6079b6cea | 11-10 | conflict (2: utility_use.gd, style_baseline.json) |  |  | perk orbs vs source) |
| ext/combat-ranks-a | c73595043 | 11-10 | conflict (4: bulwark.json, rimewright.json, bulwark.md…) |  | ext/combat-ranks-c | kit ranks to source tiers II/III+IV for Vex, Albert, Neve, Kael; includes ext/rank-parity-slice + rank-parity-b shared code and Neve rows (n… |
| ext/combat-ranks-b | a863574d8 | 11-10 | conflict (6: mage.json, ashwick.md, mage.md…) |  |  | Cinder, Tenzo, Sparkle, Grimble ranks to source tiers: rank 2 = II, rank 3 = III+IV folded; per-slot rank_cd/rank_dmg(/rank_shield) in JSON,… |
| ext/combat-ranks-c | 2db0d7706 | 11-10 | conflict (10: bulwark.json, rimewright.json, thief.json…) |  |  | kit ranks to source tiers II / III+IV for Meeko, Sable, Lace, Motley: per-slot rank_cd/rank_dmg, Meeko tier IV burst AP ratio built, Lace ar… |
| ext/combat-spread-falloff | 3c1f381bc | 11-10 | conflict (8: kit_parity.json, shotgun.json, KIT_PARITY.md…) |  |  | Grimble scattergun vs Kingpin: 7 pellets and no range falloff match; fan 30+15 -> 20 rested +10 bloom (same two lines as ext/lmb-range-parit… |
| ext/combat-summon-share | ef71de124 | 11-10 | conflict (50: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | summon column: --summon-share-check, Vex hold 6 m and Kael tap 2 m into a Medium dummy with armour, 3 seeded fights each with/without the su… |
| ext/combat-swept-hits | 8e6a2bebd | 11-10 | conflict (1: hunter.gd) |  |  | swept dash hits + dash-vs-block clip via Swept, --swept-hit-check; shots already sliced) |
| ext/combat-xp-last-hit | ea0c47da9 | 11-10 | conflict (2: net.gd, check_registry.gd) |  | ext/combat-boss-parity +1 | kill XP to the last hit's squad plus squadmates within 30 m, none for damage: KillXp.pay from Match.on_mob_dead replaces per-damage XP and t… |
| ext/cooldown-parity-verify | 2be9877c2 | 11-09 | conflict (14: ashwick.json, dredge.json, juggernaut.json…) |  |  | supersedes unmerged ext/parity-cooldowns: merged onto current main keeping main's Barge air recharge and Rampage 0.17 s dash at 1.0x data; t… |
| ext/cooldown-start-parity | ef38f084b | 11-09 | conflict (2: dolm.json, KIT_PARITY.md) |  |  | Cooldown start section in docs/KIT_PARITY.md for all 12 Hunters; fix: Tarek Quake Punch cooldown starts on the press per patch 2.01, asserte… |
| ext/damage-ratio-audit | a89a84bed | 11-09 | conflict (2: rimewright.json, Class-Snowglide.md) |  |  | damage-ratio audit doc, 3 outliers fixed: Sparkle R, Neve R, Cryo Spear burst; rest listed for owner) |
| ext/drop-parity | 8a7cbce24 | 11-09 | conflict (3: MOVEMENT_FEEL.md, hunter.gd, drop_check.gd) |  | ext/landing-recovery | landing recovery vs the source: no lock anywhere, none added; STACKED on READY ext/drop-parity 8a7cbce24 and READY ext/parity-jump-pads a271… |
| ext/fire-on-run-layer | d733b077b | 11-09 | conflict (4: cinder.json, sable.json, CLIPS.md…) |  | ext/anim-strafe-back | fire-on-run upper body) |
| ext/grimble-parity-verify | d94bc7769 | 11-09 | conflict (2: dredge.json, dredge.md) |  |  | Grimble cooldowns 1.0x of data level 1: hand 18s, anchor 12s, broadside 36s were 0.67/0.58/0.58x; windup 0.38, charge 1.1 and wall-stops-hoo… |
| ext/heal-shield-parity | 42dced79c | 11-09 | conflict (3: juggernaut.json, juggernaut.md, Class-Unbroken.md) |  | ext/parity-antiheal | heal/shield parity table docs/HEAL_PARITY.md linked from KIT_PARITY.md; fix: Kael Cinder Spin Anti-Heal 4s -> 5s; Cinder cloak shield assert… |
| ext/hunter-revamp-af | fa0c9320b | 11-10 | conflict (20: IMPORT.md, breaker.glb, breaker_atlas.jpg.import…) |  |  | hunter revamp A-F complete: Breaker 20.6k tris, a 19k retopo of the shipped scan spliced into the shipped build with no collar; old/new rend… |
| ext/hunter-revamp-go | 4efad09ea | 11-09 | conflict (12: IMPORT.md, hem.glb, hem_atlas.jpg…) |  |  | G-O hunter revamp: Hem 25.1k, Kael 25.0k with 2048 baked normal maps, Ostra 24.7k densified; Warden budget 15k->26k in checks + RIG_CONTRACT… |
| ext/hunter-revamp-pz-rebased | fb240baa2 | 11-09 | conflict (33: breaker_atlas.jpg.import, breaker_emit.jpg.import, hem_atlas_1.jpg.import…) |  |  | SUPERSEDES ext/hunter-revamp-pz fb240baa2: same commit. origin/main d255acbee is already an ancestor, so merging main changed nothing and th… |
| ext/kael-lunge-length-rebased-rebased | 0f1cd8c71 | 11-10 | conflict (48: juggernaut.json, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES READY ext/kael-lunge-length-rebased 00894cd16; on rpc1, escalated from 20261110-210117-a2. origin/main d255acbee was already insi… |
| ext/kael-riposte-knock | bf1f1f2a6 | 11-09 | conflict (3: ARCHETYPES.md, net.gd, dj_ult_check.gd) |  |  | Kael Riposte knock parity) |
| ext/kael-rmb-unlock-rebased | 5b657bea1 | 11-11 | conflict (111: IMPORT.md, archer.json, dolm.json…) |  |  | SUPERSEDES READY ext/kael-rmb-unlock 44f5a64dc; on rpc1. origin/main d255acbee was already inside 44f5a64dc; the listed conflicts (MERGE_REP… |
| ext/kael-tap-ult-1108 | 66423a45d | 11-09 | conflict (3: answer.md, tuning.json, juggernaut_kit.gd) |  | ext/anim-arm-kael +12 | Kael item 11: tap overhead strike (tuning.json kael), live RMB aim in E (90/180 ok), tether breaks past length, ult keeps momentum + vertica… |
| ext/kit-error-sweep | 577c21ec0 | 11-09 | conflict (2: rimewright_kit.gd, thief_ult.gd) |  |  | new --kit-sweep-check: 12 Hunters x slots/recasts x ground/air/glider x dummy/ledge, 0 errors; fixes: kit_status DAZED+GROUNDED timers, Rime… |
| ext/kit-number-sources | eb424bbb1 | 11-09 | conflict (4: ashwick.json, juggernaut.json, rimewright.json…) |  |  | kit number source tags) |
| ext/kit-parity-rows-a | a39c3ec6b | 11-09 | conflict (5: kit_parity.json, ARCHETYPES.md, Rules.md…) |  |  | 83 sourced [D] rows for Vex, Albert, Neve, Kael, Cinder, Tenzo, built on main plus the kit-parity-lock commit cherry-picked since lock is no… |
| ext/kit-parity-rows-b | 61200ccc6 | 11-09 | conflict (5: kit_parity.json, ARCHETYPES.md, Rules.md…) |  |  | 62 --kit-parity-check rows for Sparkle, Grimble, Meeko, Sable, Lace, Motley; 21 FAIL = real kit differences, kits untouched; based on kit-pa… |
| ext/kit-text-clear-fixes | d18df02c4 | 11-09 | conflict (4: dolm.json, dredge.json, gunslinger.json…) |  |  | stale kit text fixes) |
| ext/kit-text-numbers | 9cc9fe9ff | 11-09 | conflict (5: archer.json, juggernaut.json, Class-Red-Stitch.md…) |  |  | --kit-text-check: ability text numbers vs slot data, 0 mismatches; 10 text figures fixed in Lace, Kael, Sparkle, Meeko) |
| ext/knock-mass-parity | 294a1ad1e | 11-09 | conflict (2: MOVEMENT_FEEL.md, move_feel_check.gd) |  |  | Hunters lose per-class mass (source Mass 100 for all): one knock moves every class the same, Kael slam 1.63 m / Albert Shield Charge 3.93 m … |
| ext/lace-hawk-sense | f67042371 | 11-09 | conflict (4: DEBT.md, KIT_PARITY.md, archer.md…) |  |  | Lace Hawk Sense parity) |
| ext/land-squash-lean | 02c941df0 | 11-10 | conflict (5: CLIPS.md, warden_clips.gd, boki_rig.gd…) |  |  | landing squash + run-start/stop lean over every Hero clip (root bone, from HunterAnim land_k/acc lean) and rigged/primitive Boki (LandLean);… |
| ext/level-growth-parity | 051b53e20 | 11-09 | conflict (3: weapon_path.json, Rules.md, style_baseline.json) |  | ext/combat-levelup-refill | WeaponPath level bonuses removed; HP/AP growth kept as the source's ~6%/level; per-level asserts in --level-hud-check) |
| ext/lmb-range-parity | d1aa84b8d | 11-09 | conflict (4: shotgun.json, KIT_PARITY.md, dredge.md…) |  |  | LMB numbers audit of the 11 Hunters vs source, table in docs/KIT_PARITY.md; fixed Grimble fan 30+15 -> 20 rested +10 bloom (30 firing), Meek… |
| ext/meeko-rmb-motion-rebased-rebased-rebased | 14f79f40d | 11-09 | conflict (3: pip.glb, tender.md, care_combo_check.gd) |  |  | supersedes ext/meeko-rmb-motion-rebased-rebased e5587292a and ext/meeko-rmb-motion-rebased d2fa02fa6; deep escalated from 20261109-060218-a4… |
| ext/meeko-rmb-verify-rebased-rebased | 90bda6ee1 | 11-10 | conflict (49: MERGE_REPORT.md, IMPORT.md, pip.glb…) |  |  | SUPERSEDES ext/meeko-rmb-verify-rebased 7c1762cf5; deep on w2, escalated from 20261110-120504-a1. origin/main d255acbee was already inside 7… |
| ext/meeko-root-rebased | 04dfb19f9 | 11-11 | conflict (119: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES ext/meeko-root 57ac42c47; deep on rpc1, escalated from 20261111-000322-a6. origin/main d255acbee was already inside 57ac42c47; th… |
| ext/motley-tune-rebased | a9dbfab08 | 11-11 | conflict (3: ostra.md, Weapons.md, ostra_combo_check.gd) |  |  | supersedes ext/motley-tune 0f6711d51: that branch sits 582 commits ahead of main on stacked work, so only its one commit is carried onto ori… |
| ext/parity-ability-abyss | 880f7c907 | 11-09 | conflict (3: rimewright.md, archer_bulwark_combo_check.gd, dredge_combo_check.gd) |  |  | abyss cast rules) |
| ext/parity-ability-elevation | 27befb05e | 11-09 | conflict (2: arch_kit.gd, bulwark_kit.gd) |  |  | ability height rules) |
| ext/parity-ability-pierce | 76de01e1f | 11-09 | conflict (4: KIT_PARITY.md, archer.md, rimewright.md…) |  |  | ability pierce rules) |
| ext/parity-ability-speeds-a | db9d8235d | 11-09 | conflict (4: tender.json, gunslinger.md, tender.md…) |  |  | ability projectile speeds A) |
| ext/parity-ability-speeds-b | 1398826f9 | 11-09 | conflict (4: dredge.json, thief.json, dredge.md…) |  |  | ability projectile speeds B) |
| ext/parity-abyss-fall | d8f415ad7 | 11-09 | conflict (3: hunter_move.json, Rules.md, check_registry.gd) |  |  | abyss fall feel) |
| ext/parity-ally-effects | a106b5f15 | 11-09 | conflict (2: archer.md, dredge_combo_check.gd) |  |  | ally interaction parity) |
| ext/parity-antiheal | 55a5d0dfc | 11-09 | conflict (10: juggernaut.json, thief.json, ABILITIES.md…) |  |  | Anti-Heal on the source's four only: Kael spin 5s, Cinder cloak 3s, Grimble slugs, Lace Hail Wall; Sable's Encore rim and Lace's cremation r… |
| ext/parity-armour | ac78146f4 | 11-09 | conflict (3: shotgun.json, dredge.md, hunter.gd) |  | ext/combat-armour-xp | armour parity audit docs/ARMOUR_PARITY.md: per-tier DR/durability, taken damage levels, revive on Common, Grimble no-bloom +66% armour; --ar… |
| ext/parity-body-collision | 81bbacb1a | 11-09 | conflict (4: hunter_move.json, HITBOX_SIZE.md, Rules.md…) |  |  | body collision parity) |
| ext/parity-bulwark-crush-rebased | 63cfb4587 | 11-10 | conflict (6: bulwark.json, bulwark.md, Class-Barnacle-Knight.md…) |  |  | SUPERSEDES ext/parity-bulwark-crush 26a64a5b7 and the guardcut b2e942eb4 it sat on: origin/main d255acbee merged in; conflicts resolved to m… |
| ext/parity-cc-lockouts | 123ec0cb8 | 11-09 | conflict (3: DEBT.md, Rules.md, hunter.gd) |  |  | CC lockout table and fixes) |
| ext/parity-dot-ticks | d211db733 | 11-09 | conflict (5: ashwick.json, KIT_PARITY.md, archer.md…) |  |  | DoT tick parity) |
| ext/parity-iframes | 583b7cfd4 | 11-09 | conflict (5: rimewright_kit.gd, displace.gd, fields.gd…) |  |  | invulnerable windows to source) |
| ext/parity-interrupts-a | a65a3b102 | 11-09 | conflict (4: tender.json, tender.md, Class-Dawnfox.md…) |  |  | interrupt rules A) |
| ext/parity-interrupts-b | 1d8cccab7 | 11-09 | conflict (2: rimewright.md, hero_combo_check.gd) |  |  | interrupt rules B) |
| ext/parity-knock-credit | 846c1e170 | 11-09 | conflict (7: gunslinger_kit.gd, juggernaut_kit.gd, match.gd…) |  | ext/summon-kill-credit-rebased | one KnockCredit rule for knock and assist credit, 4 s window, read by Salvage, heals and resets; --knock-credit-check; Kael reset knocker-on… |
| ext/parity-motley-float | f48366abc | 11-09 | conflict (3: KIT_PARITY.md, ostra.md, ostra_combo_check.gd) |  |  | Motley float passive) |
| ext/parity-no-riders-grimble-tenzo | 7b130d5c7 | 11-09 | conflict (6: dolm.json, dredge.json, KIT_PARITY.md…) |  |  | Grimble E no longer Grounds the foe, Kingpin dunk = abyss bonus; Tenzo punch 10.6 flat + knockback 10, no charge scaling; dredge-combo 95/0,… |
| ext/parity-passives-a | 2d4ecc486 | 11-09 | conflict (6: dolm.json, KIT_PARITY.md, archer.md…) |  |  | passive numbers A) |
| ext/parity-passives-b | 278596890 | 11-09 | conflict (4: dredge.json, dredge.md, ostra.md…) |  |  | passive numbers B) |
| ext/parity-recast-windows | bb46589c0 | 11-09 | conflict (4: rimewright.json, KIT_PARITY.md, rimewright.md…) |  |  | recast window numbers) |
| ext/parity-reel-a | 3dad29706 | 11-09 | conflict (9: HERO_VFX.md, README.md, bulwark.mp4…) |  |  | 12 parity reels in docs/parity_reel with a differs list each; tools: --reel-parity) |
| ext/parity-status-stacking | bafa3ff4c | 11-09 | conflict (5: DEBT.md, Rules.md, rimewright_kit.gd…) |  |  | status stacking rules) |
| ext/perf-mob-cap | 0ac256372 | 11-10 | conflict (4: settings.gd, mob.gd, check_registry.gd…) |  |  | monster activity cap per preset low 6/medium 12/high 24/ultra 32 within 60 m, rest sleep, nothing despawns; bots/online use High; --perf-ben… |
| ext/sable-appeal4 | 94a9ff90b | 11-11 | conflict (12: hem_atlas_1.jpg.import, IMPORT.md, sable.glb…) |  |  | for 0.24.4 (release-integ-0244c); cand_6 from job 025118 supersedes 79fa4384d. Deep : in-engine warden-shots for thief at the game camera (f… |
| ext/sable-bola-instant-rebased | 2024f0105 | 11-09 | conflict (4: thief.json, thief.md, Class-Silver-Thief.md…) |  | ext/anim-timing-gunslinger +11 | supersedes ext/sable-bola-instant b31c26641: origin/main merged, only dash_interactions.md conflicted, regenerated via gen_wiki; hero-combo-… |
| ext/sable-marks-resets | 4061d74e4 | 11-09 | conflict (3: thief.json, KIT_PARITY.md, thief.md) |  |  | Sable passive at source shape: flat +16 on 160 per LMB hit, no cap, 4 s assumed; Bola and dagger add no Mark; one vault_back() so Encore and… |
| ext/sable-v2-art | d8d2fce70 | 11-09 | conflict (1: portraits.json) |  |  | owner-locked Sable v2 portrait + splash in game: art/portraits/thief.jpg + thief_splash.jpg via tools/portrait_art.gd --only=thief from the … |
| ext/secondary-motion-settle | 362c30a08 | 11-09 | conflict (3: kael.json, DEBT.md, check_registry.gd) |  |  | secondary motion settle) |
| ext/sfx-hunter-foley | faa7dc8a9 | 11-10 | conflict (9: hollowcrown.json, AUDIO.md, Rules.md…) |  |  | quiet gear foley for all 12 Hunters under steps and dashes: row per Hunter in content/rules/hunter_foley.json, speed-scaled, footstep range,… |
| ext/sfx-hunter-wisp-hum | dddbe266d | 11-10 | conflict (4: wisp_hum.wav, wisp_hum.wav.import, hunter_wisp.gd…) |  |  | Hunter Wisp hum: low positional loop, 20 m, mates louder, pitch rises on revive, fall-away, 6-voice cap; --wisp-hum-check) |
| ext/sfx-kit-placeholders | 7725b94da | 11-09 | conflict (2: mage_kit.gd, tender_kit.gd) |  |  | 15 own <arch>_* sounds for the 8 kits' stock cues: Cinder, Albert, Sparkle, Meeko, Sable, Vex, Tenzo, Grimble) |
| ext/sfx-mob-alert-rebased | 30e6a701c | 11-09 | conflict (1: match_audio_check.gd) |  |  | supersedes ext/sfx-mob-alert: no conflict with current main d255acbee, the commit already sits on it, so same SHA; --match-audio-check, --ch… |
| ext/sfx-mob-attacks | ceb82b274 | 11-09 | conflict (2: AUDIO.md, sfx_set_check.gd) |  | ext/anim-boki-cast-rebased +48 | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/sfx-music-combat | 6076ad6bb | 11-10 | conflict (2: music_dir.gd, check_registry.gd) |  | ext/anim-boki-cast-rebased +38 | SFX_AUDIT row 2: MusicDir drive layer follows your own fights: hit dealt or taken sets drive within 0.33 s, fades after 8 s calm, 2 s minimu… |
| ext/sfx-ult-ready | 3eb005e5f | 11-11 | conflict (3: AUDIO.md, match.gd, match_audio_check.gd) |  |  | ultimate-ready chime: your R coming back plays one short chime ui_ult_ready, own sound in gen_sfx_ui.py at ui level; only for you, never riv… |
| ext/sfx-weapon-fire | 0efbf33a2 | 11-09 | conflict (3: flamethrower.json, AUDIO.md, DEBT.md) |  |  | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/slam-follow-through | 95a835c7e | 11-09 | conflict (4: DEBT.md, CLIPS.md, warden_clips.gd…) |  |  | slam follow-through) |
| ext/split-warden-glb | cdad2bfe4 | 11-09 | conflict (2: warden_glb.gd, style_baseline.json) |  |  | split warden_glb) |
| ext/ui-ability-cards | 9a53f3958 | 11-10 | conflict (5: ashwick.json, dolm.json, dredge.json…) |  |  | hover ability card in Hunter pick, Relic screen, HUD with Tab; --ability-card-check 16/16, health+wiki ok; shots jobq 20261110-100431-07564) |
| ext/ui-ability-text-one | 603d2e4af | 11-09 | conflict (13: ashwick.json, dolm.json, dredge.json…) |  |  | one AbilityText reader for ability name/short/line/full across HUD slot+tooltip, kit card+strip, viewer, E hint, pick loop line; {key:action… |
| ext/ui-ult-ready | ee1a016ca | 11-11 | conflict (4: hud_slot.gd, hunter_ult_tile.gd, check_registry.gd…) |  |  | ultimate tile says ready at a glance: HunterUltTile (R, all 12 heroes, the hero ability colour, through HudSlot) has 4 states: locked (padlo… |
| ext/ult-ranks-rebased | 570a3b590 | 11-10 | conflict (1: net.gd) |  |  | SUPERSEDES ext/ult-ranks a48ec55a0; w2. origin/main d255acbee was already inside the old branch; the listed conflicts came from merge candid… |
| ext/ult-ready-glow | b9a279f72 | 11-10 | conflict (2: match.gd, check_registry.gd) |  |  | ult-ready glow + cast flash; supersedes a807dab3e: shots tool now quits, GPU-checked: shader compiles, glow reads at match zoom incl. on the… |
| ext/utility-parity | df96e53c3 | 11-09 | conflict (18: hollowcrown.json, armor_kit.json, tonic.json…) |  | ext/feel-utility-move +5 | utility belt parity: six slots with 1-2 pinned to tonic/armor kit, keys 5-6, source channel times and heals, lethal Skyfall + fire, Bounty k… |
| ext/utility-parity-2-rebased | bece7ed49 | 11-10 | conflict (21: hollowcrown.json, armor_kit.json, tonic.json…) |  | ext/feel-utility-move +1 | SUPERSEDES ext/utility-parity-2 bece7ed49; on rpc1. origin/main d255acbee is already an ancestor of the branch (via af764b688), so merging m… |
| ext/vex-coin-palm-1108 | 0478765f6 | 11-08 | conflict (11: vex.glb, gunslinger.json, VFX_QUALITY.md…) |  | ext/anim-timing-gunslinger +7 | on w2; on READY ext/vex-coin-palm-1108 0478765f6, which is on ext/vfx-gunslinger: merge those first; no gh on w2, PR: https://github.com/Orr… |
| ext/vex-daze-rebased | a0c7a8dff | 11-11 | conflict (1: archetype_check.gd) |  |  | SUPERSEDES ext/vex-daze 9d4ace3dd; deep on rpc3. ext/vex-daze sat 582 commits ahead of main on stacked work and 0 behind, so merging origin/… |
| ext/vex-greenfire-1108 | 4e67fbbfc | 11-08 | conflict (15: vex.glb, gunslinger.json, tuning.json…) |  | ext/anim-timing-gunslinger +6 | on w2; on READY ext/vex-coin-palm-1108 0478765f6, which is on ext/vfx-gunslinger: merge those first; no gh on w2, PR: https://github.com/Orr… |
| ext/vex-rmb-terrain-rebased | 397ea98f8 | 11-11 | conflict (2: gunslinger_kit.gd, archetype_check.gd) |  |  | SUPERSEDES ext/vex-rmb-terrain 5530e470e. That branch sat 583 commits ahead of main on stacked work, so it could not merge cleanly; this is … |
| ext/vex-yawlock-1109-2248 | 128ff8728 | 11-09 | conflict (4: gunslinger.json, gunslinger.md, Class-Hired-Gun.md…) |  | ext/feel-yaw-lock-12-rebased | Vex E Longneedle strong yaw lock 30deg/s + ArchKit.turn_lock + check; kit audit in report) |
| ext/vfx-cinder-kit | 411090299 | 11-10 | conflict (1: ashwick.json) |  |  | Cinder VFX parity: ram start/hit and air poof lose their burst flares and the ram-end dust, hose hit lights the foe's body with a flame skir… |
| ext/vfx-kael-kit | ffbed0ba6 | 11-10 | conflict (3: juggernaut.json, juggernaut_drop.gd, juggernaut_kit.gd) |  |  | Kael kit VFX at the match camera: white-hot palette, crimson accents; slash arc/reach, wave crescent and lane at the true hit width, lunge l… |
| ext/vfx-lace-impact | 2199382e1 | 11-09 | conflict (3: archer.json, archer.md, pin_fx.gd) |  |  | Heavy Shot impact burst sized to its charge 3.0-5.4 m, wall pin 6.4 m; Spirit Walk ghost shell with bright rim, no burst at dash start/end; … |
| ext/vfx-meeko-kindle | 2a9130278 | 11-09 | conflict (1: tender.gd) |  |  | sheet gap 9: an ember damage number warms one clear step per Kindle stack, cream to amber at 3 to ember at 5, via one optional per-hit "num_… |
| ext/vfx-meeko-weight-rebased-rebased | 8d5ab4e3e | 11-11 | conflict (120: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES ext/vfx-meeko-weight-rebased 8d2b6858e and ext/vfx-meeko-weight 9c4ad7800; deep on w2, escalated from 20261111-000136-a4. origin/… |
| ext/vfx-mob-death | 656241531 | 11-10 | conflict (4: match.gd, check_registry.gd, lair_lock_check.gd…) |  |  | supersedes be7c8b291: shared monster dissolve for 7 mobs + 3 lair bosses, 0.3-0.6 s by size, free-list material pool, staggered camp wipes, … |
| ext/vfx-motley-kit | 55268a5a9 | 11-10 | conflict (6: tether_lantern.json, ostra.md, Weapons.md…) |  |  | supersedes its bbc25c44e READY: same Motley kit VFX parity pass, now seen at the match camera (--zoom=1.0) instead of only asserted. Fix: th… |
| ext/vfx-motley-nightwell | a7c31da62 | 11-09 | conflict (1: ostra_ult_check.gd) |  |  | deep, w2; same sha as the READY above, now with GPU strips SEEN: before jobq 20261109-152623-26327 is a flat dark disc with purple blocks an… |
| ext/vfx-sparkle-storm | e5680b9c2 | 11-09 | conflict (1: vv_fx.gdshader) |  | ext/anim-boki-cast-rebased +48 | Kitefall: edge ring with glowing centre, no pink dome, cursor marker = 2.7 m hit area; Skycall: darker disc held through the countdown, brig… |
| ext/vfx-water-hunters | 672adc6aa | 11-11 | conflict (2: home_water.gd, check_registry.gd) |  |  | Hunter water VFX on the farm, the only shallow water Hunters walk: new scripts/home/water_fx.gd (WaterFx) driven from HomeWater.step, a whit… |
| ext/warden-bob-damp-rebased | 92882bf31 | 11-09 | conflict (2: ANIM_QUALITY_AUDIT.md, anim_shots.gd) |  |  | supersedes ext/warden-bob-damp ba31e5ef6; w2). Merged origin/main d255acbee: clean, no conflicts (only Net.VERSION and release.yml came in);… |
| ext/bot-kit-use | 12d904a0d | 11-09 | light (2: check_registry.gd, style_baseline.json) | ext/bot-kit-use-a |  | --bot-kit-check: 90 s bot-vs-bot fight per Hunter on the flat duel island, counts LMB/RMB/E/R/dash/glide/Fuse + hits, fails unused slots, un… |
| ext/combat-pve-mult | 0cd26a972 | 11-11 | light (1: check_registry.gd) | ext/combat-camp-clear |  | supersedes d5538d7f2 line, now verified: source and hero-ref briefs list NO monster-damage modifier for any of the 12 kits, so none applied,… |
| ext/combat-boss-parity | 11cf16b8c | 11-11 | conflict (2: net.gd, check_registry.gd) | ext/combat-xp-last-hit |  | supersedes 1f8e39159; STACKED on ext/combat-xp-last-hit ea0c47da9, merge that first: its KillXp pays the boss kill to the last-hit squad, so… |
| ext/combat-lair-prize | 19103f816 | 11-11 | conflict (4: Maps.md, net.gd, check_registry.gd…) | ext/ways-out-quests |  | lairs: all 3 live on Skyreach and the Hollow Crown (spawn_points.boss pick 3/3): the seed Sealed Lair is the only exit, the other two are pr… |
| ext/combat-utility-verify | f22981714 | 11-11 | conflict (11: hollowcrown.json, Maps.md, Rules.md…) | ext/utilities-shops |  | utility verify vs SOURCE_UTILITIES: Blight Flask 40s, Skyfall 690, Satchel 68%, Thorn Wall stack 10; --shops-check 82/0 with a row per item;… |
| ext/combat-wisp-hit-rules | 62ec8ba05 | 11-10 | conflict (4: game.gd, net.gd, perf_bench.gd…) | ext/wisp-pve-pvp |  | a downed Hunter Wisp is no target: Hunter.hittable() false while downed, so shots and AoEs pass through; a Boki orbiting wisp was already of… |
| ext/hunter-regen-meshy | 0c50ac56d | 11-10 | conflict (8: breaker_atlas.jpg.import, IMPORT.md, vex.glb…) | ext/warden-detail-pilot |  | Hunter regen step 1: warden budget hero LOD <=80k + 4096 atlas / normal imported at 2048 rules; Vex at 67.7k, 4096 atlas, normal_k 0.6 from … |
| ext/vfx-cinder-polish | 89e74c9cb | 11-08 | conflict (2: VFX_QUALITY.md, hero_vfx_mote.gdshader) | ext/vfx-quality-base | ext/anim-timing-gunslinger +13 | stacked on ext/vfx-quality-base 9a9bb3b79: merge that first; no PR, gh is not on w2: |
| ext/vfx-quality-motley | 06b960779 | 11-09 | conflict (6: tether_lantern.json, VFX_QUALITY.md, Weapons.md…) | ext/vfx-quality-base |  | rpc1; Motley VFX to the bar: LMB orb, trail, charge glow and a visible orb_hit flare/ring/shards in sea teal #2ee6c0, bigger when charged; w… |
| ext/vfx-vex-kit | d2b5bc61e | 11-10 | conflict (15: vex.glb, gunslinger.json, tuning.json…) | ext/vex-greenfire-1108 |  | SUPERSEDES READY ext/vfx-vex-kit d2b5bc61e; . Vex kit VFX parity, stacked on ext/vex-greenfire-1108 (origin/main is an ancestor). New: trace… |

### Wave 4: boki (19)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/boki-cries-el | b76feec7c | 11-10 | clean |  |  | ElevenLabs cry A/B, 3 lines, 13 calls used) |
| ext/boki-cries | f77ce7015 | 11-10 | light (2: AUDIO.md, check_registry.gd) |  |  | Boki cries: one synthesized cry per Boki, one voice per evolution line; BokiCry.play hooked into the Bokidex; preview tools/cries_preview/in… |
| ext/boki-react-clips-rebased | c2b0c9ff9 | 11-09 | conflict (4: RIGGED_BOKI.md, base_race.gd, boki_rig.gd…) |  | ext/anim-garden-games +3 | deep; SUPERSEDES READY ext/boki-react-clips 5aa0b8d70). origin/main d255acbee was already an ancestor (no conflict with main); the base_race… |
| ext/boki-state-clips | 6791e0ddc | 11-09 | conflict (3: boki_rig.gd, kin.gd, check_registry.gd) |  | ext/anim-summon-clips +1 | Boki state coverage) |
| ext/boki-wisp-proto | 6309f6250 | 11-09 | conflict (3: net.gd, perf_bench.gd, wisp_check.gd) |  | ext/anim-boki-cast-rebased +69 | Boki wisp prototype) |
| ext/boki3d-lilybara | 6df99d443 | 11-09 | conflict (3: RIGGED_BOKI.md, build_boki.py, boki_rig_check.gd) |  | ext/anim-timing-gunslinger +11 | ). Boki 3D Soakybara (`lilybara`) from briefs/art-refs/boki/lilybara_turnaround.png. |
| ext/boki3d-umbrathere | 977ef60f7 | 11-09 | conflict (3: RIGGED_BOKI.md, build_boki.py, boki_rig_check.gd) |  | ext/anim-timing-gunslinger +11 | ): Umbrathere rigged Boki from the 7e91f47b5 sheet (passes the sheet check: front/side/back/3-4, whole body, matches the entry; the later in… |
| ext/summon-killed-wisp-rebased | f7eb1d10b | 11-10 | conflict (51: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES ext/summon-killed-wisp 25e86351f; deep on w2, escalated from 20261110-182305-a4. origin/main d255acbee was already inside 25e8635… |
| ext/wisp-cosmetics | a65806c45 | 11-10 | conflict (5: game.gd, net.gd, save.gd…) |  |  | Boki wisp cosmetic line: 3 starter trails + 3 sparkle colours + 2 orbit styles beside each default, data in content/rules/boki_wisp_cosmetic… |
| ext/wisp-gpu-ab-rebased | e08c6817e | 11-10 | conflict (50: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | SUPERSEDES ext/wisp-gpu-ab aa375b024; deep on rpc1, escalated from 20261110-201944-a6. origin/main d255acbee was already inside aa375b024; t… |
| ext/wisp-merge-from-wisp-rebased | a18ad40f3 | 11-10 | conflict (47: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES ext/wisp-merge-from-wisp b390a22d8; on rpc1. origin/main d255acbee was already inside b390a22d8; the listed conflicts (net/settin… |
| ext/wisp-passive-stack-rebased | 33c76b9a9 | 11-10 | conflict (51: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES ext/wisp-passive-stack e293ad7ce; origin/main d255acbee was already inside e293ad7ce, so the 4 listed conflicts (net/settings/per… |
| ext/wisp-pve-pvp | 1022d9719 | 11-10 | conflict (4: game.gd, net.gd, perf_bench.gd…) |  | ext/combat-wisp-hit-rules +1 | Q9 one wisp rule set PvE/PvP: audit table in decision 0045, only the tutorial differs (wisps off there, kept: its steps teach a walking Boki… |
| ext/wisp-steal-rebased | 51b4548a5 | 11-10 | conflict (51: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  | ext/summon-kill-credit-rebased +2 | SUPERSEDES ext/wisp-steal 1e433f875; deep on w2, escalated from 20261110-143906-a4. origin/main d255acbee was already inside 1e433f875; the … |
| ext/wisp-summon-leash-rebased | 115eb0a70 | 11-10 | conflict (51: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES ext/wisp-summon-leash 3c8ebb0c7; on rpc1. origin/main d255acbee was already inside 3c8ebb0c7, so the 4 listed conflicts (net/sett… |
| ext/early-guarded-boki | a0eea91f7 | 11-11 | conflict (6: hollowcrown.json, DEBT.md, Maps.md…) | ext/early-camps-core |  | two rare Boki guarded by Great Camps; STACKED on ext/early-camps-core fa8d228e6 + ext/early-camps-layout 5792fba0f) |
| ext/early-wisp-refund | e0d1fbba6 | 11-11 | conflict (10: hollowcrown.json, AUDIO.md, DEBT.md…) | ext/early-camps-core |  | STACKED on ext/early-camps-core fa8d228e6 + ext/early-camps-layout 5792fba0f + ext/soul-link-integ 3303c3b45, do not merge alone: camp clear… |
| ext/wisp-guardian-rebased-rebased | 3f3d3ce9a | 11-10 | conflict (47: MERGE_REPORT.md, tutorial.json, class_unlock.json…) | ext/wisp-summon |  | SUPERSEDES ext/wisp-guardian-rebased acacda191; deep on rpc1, escalated from 20261110-214133-a6. origin/main d255acbee was already inside ac… |
| ext/wisp-summon-pop | a9f367d43 | 11-09 | conflict (4: game.gd, net.gd, perf_bench.gd…) | ext/wisp-summon | ext/anim-summon-call +13 | SUPERSEDES the b77f2cc77 line: BokiWispPop 0.25 s burst/fold now drives the real summon; STACKED on ext/wisp-summon bbfbf5d9b (which contain… |

### Wave 5: ui (60)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/ghost-dark-split | de3932069 | 11-10 | clean |  |  | Shadow split into Ghost and Dark, PR #35; roster-check 0 fails, merge-form-check 201 PASS + 1 fail already on main (merge/fuse text), health… |
| ext/ui-armour-progress | 5343bf6d1 | 11-10 | clean |  |  | armour progress: thin bar in the current tier colour under the armour strip replaces the 1px hairline, white tick at its head for 0.5 s when… |
| ext/ui-hold-charge | 4c80486bc | 11-09 | clean |  | ext/anim-boki-cast-rebased +39 | hold-charge ring: supersedes 57edbbca1; Kael blast ring now drawn round his body in white as the source arc (hero-ref juggernaut item 8) via… |
| ext/ui-market-declutter | c61e9c1d1 | 11-09 | clean |  | ext/anim-boki-cast-rebased +39 | Black Market Ransom/Captured: card = portrait + time left + price on one line, one highlighted button (Pay, or Offer when you cannot pay or … |
| ext/ui-rank-ready-beam | c020f3e9e | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | level-up: quiet gold beam over each slot that can rank, with the existing + pip, cleared on pick; no burst; RankMarks.beam, asserted in --ra… |
| ext/ui-rebind-conflicts | 042b12b3c | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | Controls: rebinding a key another action owns names the owners and offers Swap or Cancel, owners take the slot's old key; unbound actions re… |
| ext/ui-void-masks-mockups | 954d7b22a | 11-11 | clean |  |  | Void & Masks menu mockup variations, owner 11-10 LATER: briefs/boki-art/batch/ui_mockups.py holds 16 image-gen jobs (01_title/03_settings/10… |
| ext/revive-source-numbers | 6c27f4f57 | 11-09 | light (1: DEATH_AND_REVIVE.md) |  |  | second source pass: no base revive/stomp seconds published anywhere, footage timing is an owner task on hetzner; wiki's full heal on a finis… |
| ext/tester-guide | 106806a04 | 11-09 | light (1: Rules.md) |  | ext/anim-boki-cast-rebased +50 | supersedes 4ca0d4948, adds the missing try_card.gd.uid; docs/TESTER_GUIDE.md + dismissible 'What to try today' title card from content/rules… |
| ext/ui-buff-stack | f4813f45e | 11-10 | light (1: Rules.md) |  | ext/feel-dash-off-ledge-rebased +4 | HUD buff stack on the right edge: BuffStack widget, data rows in content/rules/buff_stack.json; icon + draining ring + stacks, only while ac… |
| ext/ui-death-recap | 82d663574 | 11-09 | light (2: DEATH_AND_REVIVE.md, check_registry.gd) |  |  | death recap and spectate) |
| ext/ui-fusion-hud | 51e1a7e38 | 11-10 | light (1: check_registry.gd) |  |  | Boki box tells the Fusion end to end via one BokiHud.fuse_view: bond %, FUSE with X lit, TOO FAR / RESCUE, form ability + live key + time-le… |
| ext/ui-net-readout | 2fcf6b2da | 11-10 | light (1: DEBT.md) |  |  | DEBT note only: FPS readout already on main via show_fps; Net has no RTT so no ping) |
| ext/ui-spectate-cycle | cabecfaff | 11-10 | light (1: check_registry.gd) |  |  | spectate: LMB/RMB cycle living teammates, bottom strip with vitals+abilities, Give up; camera/minimap/Boki card follow; --spectate-check) |
| ext/ui-void-masks-v3 | cf39070b3 | 11-10 | light (1: style_baseline.json) |  | ext/ui-simplify | UI Void & Masks pass 2: chunky neon frames, cracks/tally/runes, display-type ticket, reveal as one big card with void window + parchment mov… |
| ext/cc-stacking-rule | 864c42255 | 11-09 | conflict (4: fields.gd, hunter.gd, kin.gd…) |  |  | one CC overlap rule in Ent: add_slow/add_stun/add_root; strongest slow sets speed, each slow keeps its own clock, overlaps refresh never add… |
| ext/combo-marks-b | 0bd68fb6d | 11-09 | conflict (3: HUD.md, combo_mark_shots.gd, combo_mark_shots.gd.uid) |  |  | combo tag for Cinder Ignite levels, Neve Chill, Meeko Kindle on ext/combo-marks-a's ComboMark: stacked on a, merge a first; supersedes c8fb5… |
| ext/creator-polish | c35dcbe30 | 11-09 | conflict (2: hatch.gd, empty_shots.gd) |  |  | character creator; MERGES ext/creator-trim 532aad479, merge it first or together; supersedes the 70a4e0627 READY line: wheel zooms to a head… |
| ext/creator-trim | 532aad479 | 11-09 | conflict (2: hatch.gd, empty_shots.gd) |  | ext/creator-polish | creator trim) |
| ext/early-camps-map-ui | 0f023137a | 11-11 | conflict (8: hollowcrown.json, AUDIO.md, DEBT.md…) |  |  | camps on the drop map, minimap, smoke columns) |
| ext/egg-picker-preview | eeea08d25 | 11-09 | conflict (2: dex_view.gd, empty_shots.gd) |  |  | on w2; egg pick cards show each Boki's picture, name and type, mystery egg as silhouette + real type, no name; Bokidex type chip shared; hat… |
| ext/hit-feedback-pass | d6b86ff8d | 11-09 | conflict (7: AUDIO.md, HUD.md, thief_kit.gd…) |  |  | hit feedback, item 96.4: own hit sound per Hunter weapon via HeroSfx.hit_sound + tools/gen_sfx_hits.py, empowered-hit number/thud/tier-3 hol… |
| ext/keybinds-1108 | 65f6cc662 | 11-08 | conflict (9: MOVEMENT_FEEL.md, game.gd, settings.gd…) |  | ext/anim-timing-gunslinger +12 | deep; supersedes the 1369ab73d entry above, adds one commit on it). New: --ultbond-check presses the quick Boki order keys through Match._ga… |
| ext/legendary-spawns | a2607c39d | 11-09 | conflict (4: skyreach.json, Rules.md, dex_view.gd…) |  | ext/sfx-legendary-presence | supersedes the 95706d73a line; legendary Boki: one roll per match with the map's legendary_spawn_chance, default 0.20 in content/rules/legen… |
| ext/menus-more | e4c3b9694 | 11-09 | conflict (4: home.gd, overlay.gd, title.gd…) |  | ext/ui-settings-trim | menus behind More) |
| ext/no-reload-path | 94833fb55 | 11-09 | conflict (10: BOKI_TALK.md, Rules.md, Weapons.md…) |  |  | reload path deleted: reload_t, start_reload, 0.88 slow, roll reload, RELOADING HUD, reload pose + Mag drop, net flag bit 128, Boki 'cover' c… |
| ext/overlay-typed-calls | f2da08d28 | 11-09 | conflict (1: overlay.gd) |  |  | overlay.gd dynamic calls 35 -> 3; 32 lambda .call now typed methods, Match via is-check; 3 has_method kept for Home/Interior screens, no cla… |
| ext/recast-buffer-expired | 83bed4bc3 | 11-09 | conflict (6: tuning.json, ARCHETYPES.md, Rules.md…) |  |  | E/X recast presses buffered 0.15s in ArchKit+HeroUlt, EXPIRED flash 0.6s on closed windows; tuning.json; --recast-buffer-check) |
| ext/recast-hud-cue | 1fd9f80fb | 11-09 | conflict (9: mage_kit.gd, mage_ult.gd, recast_cue.gd…) |  |  | recast cue: ArchKit.recast_left/recast_slot + RecastCue pulse, shrinking ring and big KEY AGAIN on the ability bar for every recast kit; --r… |
| ext/recast-marker-a | 87df6c5c2 | 11-09 | conflict (5: HUD.md, ostra_kit.gd, tender_kit.gd…) |  |  | world marker ring + key on Motley's seed, Meeko's Hearthlight, Albert's hammer, Sable's dagger; 4 combo checks + --recast-marker-check pass;… |
| ext/recast-marker-b | 2e37a3309 | 11-09 | conflict (3: HUD.md, breah_hop.gd, check_registry.gd) |  |  | world marker ring + key on Tenzo's next Rock Hop spot, Neve's Rimelock wall, Sparkle's ult crash point, Cinder's Flue Flight landing; caster… |
| ext/split-ui | be393e41d | 11-09 | conflict (28: HUD.md, hob_offer.gd, home.gd…) |  |  | ui.gd 1077 -> 363 lines: UiText, UiWidgets, UiShell split, callers updated, screenshots identical) |
| ext/ui-banner-queue | acc25db3b | 11-10 | conflict (7: HUD.md, match.gd, bond_hud.gd…) |  |  | in-match NoticeQueue: one banner at a time by priority, fixed band off the reticle; every toast caller incl. ally knocked/revived cards move… |
| ext/ui-belt-six | bf5edc7d2 | 11-10 | conflict (18: hollowcrown.json, armor_kit.json, tonic.json…) |  |  | belt HUD shows all six slots: stack counts, live key caps, ghost of tonic/kit in open 1-2, channel fill, cooldown, Twin Gate gate countdown … |
| ext/ui-boki-next-form | ddd2d57c9 | 11-11 | conflict (9: DEBT.md, evo.gd, game.gd…) |  |  | stacked on READY ext/game-rules-nov8 14a02c652, which has the evolution data and EvoView: Boki card Growth tab Next form block: level, XP ba… |
| ext/ui-colourblind-sides | 7961fefbc | 11-10 | conflict (2: oomph.gd, settings.gd) |  | ext/vfx-last-hit-colour | Settings > Accessibility > Colour vision: standard / red-green / blue-yellow; SideColor is the one source, copies deleted; --colour-vision-c… |
| ext/ui-dex-filters | 4698c1fff | 11-10 | conflict (1: dex_view.gd) |  |  | Field Book filter bar: 18-type chips (two-type matches either), status seen/caught/owned now, Thrives in zone behind More (garden_zones.json… |
| ext/ui-dex-legendary-order | 29f0dcfa8 | 11-10 | conflict (1: dex_view.gd) |  | ext/ui-dex-filters | Field Book: legendaries last sorted by tier minor<boss<ultra<blight, tier badge on cards, seen/caught per type chips; reads legendary_tier f… |
| ext/ui-dex-summon-row | 510395653 | 11-09 | conflict (5: game.gd, net.gd, dex_view.gd…) |  | ext/combat-bots-downed +11 | Field Book card summon row 'Summon 12 s / rest 45 s' + ring icon + Burst/Steady tag (steady_from 13 s in boki_summon.json), read from KinSum… |
| ext/ui-extract-widget | 67842fb47 | 11-09 | conflict (5: HUD.md, Checks.md, main.gd…) |  |  | reposted by coord; landed on stray ext/agent-briefs-rebased b2ebf08 during the 11-09 outage, shots under briefs/shots/ui-extract-widget/ the… |
| ext/ui-gear-reveal | fbbb0f062 | 11-09 | conflict (1: hudref_check.gd) |  |  | supersedes 2b603e4e6: + belt tip guard for a slot emptied under the cursor; hudref 0 failures, uipolish 30/0, health --strict OK, gen_wiki -… |
| ext/ui-hud-reveal-1110 | 1a99e7826 | 11-11 | conflict (10: HUD.md, game.gd, net.gd…) |  |  | staged HUD, design review 11-10 fix 8: deep on rpc3, escalated from 20261111-052154-a1. ext/hud-reveal-1108 was never pushed (CLAIM only), s… |
| ext/ui-knock-callout | 154328e01 | 11-09 | conflict (3: HUD.md, match.gd, hudref_check.gd) |  |  | SUPERSEDES the 29e8d9c2a line: KNOCKED / ELIMINATED <name> callout for 1 s, up to 3 stacked, pink-magenta / rival red, now just under your h… |
| ext/ui-loading-screen | 57437804a | 11-10 | conflict (3: loading.gd, check_registry.gd, style_baseline.json) |  |  | SUPERSEDES fd124cbe0: + title block lifts clear of the bar on short windows (CONDITIONS overlapped it at 720p, fixed, shot jobq 20261110-155… |
| ext/ui-loot-panel | 1121df7ce | 11-09 | conflict (3: HUD.md, hud.gd, loot_full_check.gd) |  |  | box loot window: rarity-coloured names, better/worse arrows with what you wear, Take best key via key_cap; row builder moved out of hud.gd; … |
| ext/ui-pick-declutter | 1423e82d8 | 11-10 | conflict (10: ashwick.json, juggernaut.json, thief.json…) |  | ext/ui-text-size | one Hunter picker: HunterPicker cards = portrait + name + role word, stats/quest on hover, padlock on shut ones, shared by the prematch lobb… |
| ext/ui-portal-boki-card | c78d97a19 | 11-11 | conflict (7: game.gd, net.gd, home.gd…) |  |  | portal Boki card: each Boki on the ride pick shows summon tempo (KinSummon.times, role x size), what its care gives on the run (Care.match_m… |
| ext/ui-safe-area | a75769391 | 11-09 | conflict (5: HUD.md, hud.gd, hud_panels.gd…) |  |  | stacked on READY ext/prematch-declutter-rebased 8f1ccd06a, merge that first; SafeArea margin 12 logical px + HUD rect registry, --safe-area-… |
| ext/ui-settings-trim | 789776b43 | 11-09 | conflict (14: MOVEMENT_FEEL.md, Controls.md, game.gd…) |  |  | settings trim) |
| ext/ui-shop-panel | 3d7617fa1 | 11-11 | conflict (11: hollowcrown.json, Maps.md, Rules.md…) |  |  | shop panel rows: icon, name, one live line (ShopStock.line_of), price as Buy; greyed with "Need N" gems or the reason; header names the fixe… |
| ext/ui-simplify | 0cdcc24bf | 11-10 | conflict (7: home.gd, loading.gd, prematch_view.gd…) |  |  | UI simplify, owner 11-10: fewer tabs/subtitles/chips/boxes on every screen, plain cards in torn panels, lobby grid fits; rebased onto ext/ui… |
| ext/ui-steal-callout | f7af520fa | 11-10 | conflict (2: HUD.md, msg_lane.gd) |  |  | stolen-kill line via MsgLane: loser 'X stole the M' + key mark, stealer 'Stolen: M'; contested boss/elite/key-carrier kills only; Mob.damage… |
| ext/ui-stolen-wisps | 57a87a335 | 11-09 | conflict (5: game.gd, net.gd, team_boki.gd…) |  | ext/combat-bots-downed +11 | stolen wisps in the right-side Boki box: up to 2 rows above it, critter icon in the stolen Bokis colours + thief ring, carry passive at the … |
| ext/ui-tab-scoreboard | dce266c90 | 11-11 | conflict (3: HUD.md, hud.gd, check_registry.gd) |  |  | Tab-hold squad board: new SquadBoard replaces the old Tab table; squads left x/10, alive/downed/out pips per squad, rivals anonymous, your s… |
| ext/ui-xp-tracker | 18241d82e | 11-10 | conflict (1: hud_vitals.gd) |  | ext/ui-hud-reveal-1110 | staged HUD, design review 11-10 fix 8: deep on rpc3, escalated from 20261111-052154-a1. ext/hud-reveal-1108 was never pushed (CLAIM only), s… |
| ext/utilities-shops-rebased | f8af39fa2 | 11-09 | conflict (11: hollowcrown.json, Maps.md, Rules.md…) |  | ext/anim-timing-gunslinger +15 | first-shop hint via Match._tip key shop: "A shop: spend gems on tools for this run. Press <key>." once per save, first vendor in reach >=30 … |
| ext/summon-pve-rules | 970f7d756 | 11-10 | conflict (4: game.gd, net.gd, perf_bench.gd…) | ext/wisp-pve-pvp |  | Q9 PvE rules on top of ext/wisp-pve-pvp 1022d9719, merged in (contains wisp-summon, wisp-steal, summon-killed-wisp): monsters never grab wis… |
| ext/ui-boki-box-summon | b5c1b6fa1 | 11-09 | conflict (4: game.gd, net.gd, perf_bench.gd…) | ext/wisp-summon | ext/combat-bots-downed +13 | SUPERSEDES the dcf23f6df line: Boki box summon UI: ring drains while SUMMONED / fills while RESTING, Settings.key_cap summon key cap, READY … |
| ext/ui-interact-prompt | 81dde2583 | 11-10 | conflict (9: DEBT.md, HUD.md, home.gd…) | ext/ui-interact-pick |  | supersedes d9c1c1b62: one InteractPrompt widget (live key cap, short verb, hold ring, nearest target only) now for match AND farm/town/indoo… |
| ext/ui-ride-pick | 83afadf1f | 11-11 | conflict (7: game.gd, net.gd, home.gd…) | ext/wisp-summon | ext/ui-portal-boki-card | portal Boki card: each Boki on the ride pick shows summon tempo (KinSummon.times, role x size), what its care gives on the run (Care.match_m… |

### Wave 6: tutorial (44)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/tut-armour-hint | d8e239940 | 11-10 | clean |  |  | armour hint: first tier-up shows 'Hitting other Hunters upgrades your armour.', a first Hunter hit with no level XP shows a shorter line if … |
| ext/tut-first-capture | 3024c49de | 11-10 | light (1: check_registry.gd) |  |  | first-time capture hint: name, type, key, marker, named fail cause; --tut-first-capture-check) |
| ext/feel-first-cast-warm-rebased | e6e9db6ae | 11-10 | conflict (50: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES ext/feel-first-cast-warm 27d6f01f4 and its tip 70f3b1989, which adds RockLook spares + KitLooks.prewarm, Burr/Storm Rod/arc warm-… |
| ext/first-hints-check-rebased | 76e877aee | 11-10 | conflict (29: MERGE_REPORT.md, tutorial.json, farm_builder.json…) |  | ext/feel-dash-off-ledge-rebased +9 | supersedes ext/first-hints-check 123f1800d; deep on rpc1, escalated from 20261110-043541-a1). GitHub main d255acbee was already in 123f1800d… |
| ext/hunter-first-hints | ed9725355 | 11-09 | conflict (61: vex.glb, vex_atlas.jpg, vex_atlas.jpg.import…) |  |  | first-time Hunter hints) |
| ext/prologue-canon-2 | bd87c9332 | 11-08 | conflict (2: prologue.gd, prologue_check.gd) |  | ext/anim-timing-gunslinger +11 | supersedes ext/prologue-canon 60d89d26e): prologue captions to canon (Solmere, Malgrave she/her, the Hollowing, Skylands, no Tyrant/Crown-ki… |
| ext/tut-beat-retry | 73d01b6aa | 11-10 | conflict (4: tutorial.json, Rules.md, tutorial.gd…) |  |  | tutorial: down or abyss fall restarts the beat (counters, monsters, healed, back at last stop) with a per-beat one-line tip; downed player/B… |
| ext/tut-context-tips-rebased | 332e40002 | 11-09 | conflict (2: Rules.md, loading.gd) |  |  | SUPERSEDES READY ext/tut-context-tips 332e40002, content unchanged: origin/main d255acbee is already an ancestor, no conflict remains in scr… |
| ext/tut-controls-card | d96d171a5 | 11-09 | conflict (1: keys_check.gd) |  | ext/anim-boki-cast-rebased +39 | Esc menu Controls card: Hunter slots + glide/summon/G/X/ping/crouch, caps from Settings.key_cap; --keys-check 88/0, --uipolish-check 30/0, h… |
| ext/tut-dodge-dummy-rebased | a983192c0 | 11-10 | conflict (15: MERGE_REPORT.md, farm_builder.json, tutorial.json…) |  |  | deep; SUPERSEDES READY ext/tut-dodge-dummy 0d8f29eb9. origin/main d255acbee was already an ancestor; the 8 conflicts came from the base ext/… |
| ext/tut-first-echo | 87082b7dd | 11-11 | conflict (2: echo_steps.gd, echo_steps_check.gd) |  |  | first Echo Steps practice: one slow phrase on a save's first dance, 4 beats at 70 bpm from base_echo.json "practice", each stone shows its S… |
| ext/tut-first-evolve | f6d2689b9 | 11-10 | conflict (2: home.gd, check_registry.gd) |  |  | first-evolution card: old/new form, why line, stat bars with gain, See its page link; later evolutions a toast; one-time 'ready, will change… |
| ext/tut-first-fuse | f53fd3ae3 | 11-10 | conflict (29: MERGE_REPORT.md, tutorial.json, farm_builder.json…) |  | ext/feel-dash-off-ledge-rebased +4 | first-Fuse hint: one prompt with the live Fuse key cap when the bond first allows a Fusion, no slowdown, one rest-timer line after it ends, … |
| ext/tut-first-heartspark-rebased | 57405dac6 | 11-10 | conflict (37: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | supersedes ext/tut-first-heartspark f68245865 and the earlier -rebased READY 53e0badc4; deep on rpc1, finishing partial 20261110-201808-a6. … |
| ext/tut-first-proc | 0f52c74f4 | 11-10 | conflict (38: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | supersedes 5a907b879: first-proc hint now also fires with the wisps off (default): a walking Boki carried by order cues its passive through … |
| ext/tut-first-race-rebased | ef5cfe942 | 11-11 | conflict (2: base_race.gd, race_check.gd) |  |  | SUPERSEDES ext/tut-first-race 06ce66f82; deep escalated from 20261111-003542-a6. Ported, not merged: main has no BaseRace and the old branch… |
| ext/tut-first-shop | fabf665af | 11-11 | conflict (11: hollowcrown.json, Maps.md, Rules.md…) |  |  | first-shop hint via Match._tip key shop: "A shop: spend gems on tools for this run. Press <key>." once per save, first vendor in reach >=30 … |
| ext/tut-first-tumble | 58e36d89e | 11-11 | conflict (4: base_tumble.json, Rules.md, base_tumble.gd…) |  |  | Tumble first-time teach: first Tumble runs one slow practice exchange before the bout via new TumbleTeach (scripts/home/tumble_teach.gd): ca… |
| ext/tut-glide-double-press | 874f77835 | 11-10 | conflict (6: tutorial.json, Rules.md, hunter.gd…) |  |  | glider text taught as double press: jump, then press <Settings.key_cap jump> again in the air; tutorial banner+detail, Training drill, loadi… |
| ext/tut-hints-blight-camp-box | 70078046d | 11-11 | conflict (116: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | first-time hints for the Blight closing within 20 m, the first monster kill (owner XP/armour line) and the first lootable deathbox in reach,… |
| ext/tut-hot-zone-line | 00d5b63ed | 11-10 | conflict (5: hot_zone.json, Rules.md, hot_zone.gd…) |  |  | first drop map with a hot zone shows "Hot zone: better loot, more rivals." under it once per save (flag tutorial.hot_line, no migration), th… |
| ext/tut-hunter-howto-rebased | d45c24c5d | 11-10 | conflict (1: prematch_view.gd) |  |  | SUPERSEDES ext/tut-hunter-howto d45c24c5d; on rpc3. origin/main d255acbee is already an ancestor of the branch, so merging it was a no-op an… |
| ext/tut-move-drills | 2baf57c5d | 11-09 | conflict (3: MOVEMENT_FEEL.md, save.gd, practice.gd) |  |  | Training Area Drills button: gates, glide tap-let-go-hold, dive onto mat, wall kick, mantle; banner line, pass/fail, best times in Save dril… |
| ext/tut-pick-in-action | 6d89d78b7 | 11-09 | conflict (3: farm_builder.json, Rules.md, hob_offer.gd) |  | ext/anim-boki-cast-rebased +48 | second-Relic pick: the Relic in focus loops its LMB, signature ability and dash on the training dummy (AbilityClip reel in HobOffer, signatu… |
| ext/tut-resume | 2b62fae1f | 11-09 | conflict (3: save.gd, tutorial.gd, check_registry.gd) |  |  | combat tutorial resumes at the last finished beat after a quit; save v12 migration; --tutorial-resume-check) |
| ext/tut-skip-check | 9eb47cc91 | 11-09 | conflict (3: farm_tutorial.gd, practice.gd, check_registry.gd) |  |  | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/tut-start-here-rebased | aaa02b4b4 | 11-10 | conflict (5: hunter_pick_row.gd, prematch_view.gd, check_registry.gd…) |  |  | SUPERSEDES ext/tut-start-here 5bf8865de: branch already contains origin/main d255acbee, no conflicts remain; one fix: --prematch-check turns… |
| ext/tut-text-budget | 326714a75 | 11-09 | conflict (3: tutorial.json, Rules.md, check_registry.gd) |  | ext/anim-boki-cast-rebased +48 | --tutorial-text-check + shortened tutorial lines) |
| ext/tut-try-relic | 0a05c817e | 11-09 | conflict (3: Rules.md, hob_offer.gd, practice.gd) |  |  | second-Relic pick: a Try button on each Kael/Cinder/Meeko card opens the Training Grounds as that Hunter for 60 s, then Hob's same card agai… |
| ext/tut-ways-out | e059698f5 | 11-10 | conflict (57: vex.glb, vex_atlas.jpg, vex_atlas.jpg.import…) |  |  | ways-out hints: first time each seat opens, one FirstTimeHint line, once per save, group heart: Lair 'Beat the Sealed Lair: the winners fly … |
| ext/tut-words-page-rebased | a12b16b94 | 11-10 | conflict (1: title_check.gd) |  |  | SUPERSEDES ext/tut-words-page a12b16b94; . origin/main d255acbee is already an ancestor of the branch, so merging it was a no-op: same singl… |
| ext/tut-xp-hint | df87bd619 | 11-10 | conflict (3: save.gd, match.gd, check_registry.gd) |  |  | two XP first-time lines through Match._tip: first kill that pays your squad, first rival steal of a kill your squad was hitting; XpHints mod… |
| ext/tutorial-any-starter | 37068e652 | 11-10 | conflict (5: tutorial.json, Rules.md, tutorial.gd…) |  |  | match tutorial as Vex/Lace/Kael: bow shoot line 'Hold to draw, let go to shoot', strayed dummies culled and replaced, driver taps melee/draw… |
| ext/tutorial-beats-5-6-rebased-rebased | de02ab832 | 11-11 | conflict (44: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | deep on w2, escalated from 20261110-233042-a1; SUPERSEDES READY ext/tutorial-beats-5-6-rebased 420d46d9e. origin/main d255acbee was already … |
| ext/tutorial-beats-7-8-rebased | 50b76931b | 11-10 | conflict (29: MERGE_REPORT.md, tutorial.json, farm_builder.json…) |  | ext/anim-boki-cast-rebased +45 | deep; SUPERSEDES ext/tutorial-beats-7-8 590b36028 and so its stack ext/tutorial-combat-v2 + ext/tutorials-cut. origin/main d255acbee was alr… |
| ext/tutorial-idle-check | 19a355ea6 | 11-09 | conflict (3: tutorial.gd, check_registry.gd, tutorial_idle_check.gd) |  |  | --tutorial-idle-check: 10 s of doing nothing at each match step (22) and farm step (12): banner or Boki lead by 8 s, marker kept, nag inside… |
| ext/tutorial-prologue-rebased-rebased | 7537e251d | 11-08 | conflict (44: vex.glb, vex_atlas.jpg, vex_atlas.jpg.import…) |  | ext/anim-boki-cast-rebased +49 | supersedes ext/tutorial-prologue-rebased 5c26e95a1; ). The old branch carried the whole ext/mc-20261108-0830 line: merging origin/main d255a… |
| ext/tut-belt-hint | acd17d0dd | 11-10 | conflict (63: vex.glb, vex_atlas.jpg, vex_atlas.jpg.import…) | ext/tut-event-hints |  | belt item hints through FirstTimeHint: first ground pickup of a belt item shows '<name> on <key cap>: <first sentence of its desc>', once pe… |
| ext/tut-dive-hint | b734bc357 | 11-10 | conflict (29: MERGE_REPORT.md, tutorial.json, farm_builder.json…) | ext/first-hints-check-rebased |  | glide dive hint: first glide with 15 m+ of drop and no dive shows "Hold <crouch key> to dive faster", once per save, real matches only (not … |
| ext/tut-duel-ring | 37b951a92 | 11-10 | conflict (18: DEBT.md, Arena-and-Training.md, Classes.md…) | ext/duel-ring-online |  | Duel ring first-visit hint: once per save, within 8 m of the pad shows 'press F, then pick Find a duel / Fight a bot' plus a tall beam over … |
| ext/tut-first-games | 829de8e01 | 11-10 | conflict (11: base_shove.json, base_volley.json, RIGGED_BOKI.md…) | ext/tut-first-race |  | first practice round for Stump Shove, Seek, Spark Volley via shared FirstRound with the Dash; stacked on ext/tut-first-race) |
| ext/tut-signature-drills | 1caf92597 | 11-10 | conflict (4: Rules.md, gunslinger_kit.gd, mage_kit.gd…) | ext/tutorial-kit-drill |  | kit drill gets a 6th step per Hunter: its signature tech with live key caps, dummy rig and source tags, done by the kit own CombatBus.tech e… |
| ext/tut-summon-station | 9f03935eb | 11-10 | conflict (19: DEBT.md, Arena-and-Training.md, Classes.md…) | ext/tut-dodge-dummy |  | Training Area Summon pad: stand on it for the wisp card (round vs critter, live Summon key cap), summon on the range dummies, ring/cooldown,… |
| ext/tut-wall-kick-hint | 3ebfed312 | 11-10 | conflict (29: MERGE_REPORT.md, tutorial.json, farm_builder.json…) | ext/first-hints-check-rebased |  | first wall-kick hint: first time a player jumps into a wall too tall for the ledge rise and does not kick, one line "Press <jump key> again … |

### Wave 7: garden (72)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/garden-decor-tags | 194dcead8 | 11-11 | clean |  |  | GARDEN_MODERN 5 rank 7 decor with a purpose: one comfort tag per build-catalog decoration in HomeLayout.CATALOG (cosy rugs/bed/bench, bright… |
| ext/garden-hub-perf0 | 926aa4377 | 11-10 | clean |  |  | garden hub step 0: bench of today's garden, M5 + rp1-0 + rp2-1; briefs/PERF_AUDIT.md section only, no code; draws ~700 (M5 1065) vs 350 targ… |
| ext/spec-chao-core-garden | 078c68674 | 11-10 | clean |  |  | design spec docs/specs/CHAO_CORE_GARDEN.md + build list CHAO_CORE_GARDEN_TASKS.jsonl: garden core always on, farm-sim moves to Hob's optiona… |
| ext/sfx-loot-open | fdc03c70a | 11-10 | light (2: ASSET_CREDITS.md, AUDIO.md) |  |  | opening a chest or deathbox: LootOpenSfx rides the existing hold in Match._update_interact, keyed positional loop (loot_creak chest, loot_la… |
| ext/anim-garden-games | d002faa49 | 11-10 | conflict (8: RIGGED_BOKI.md, base_race.gd, base_volley.gd…) |  | ext/vfx-garden-games +1 | garden minigame motion) |
| ext/cursor-confine | 0610255d3 | 11-09 | conflict (4: settings.gd, home.gd, overlay.gd…) |  |  | windowed fights keep the cursor in the window: CursorMode helper, Controls 'Keep cursor in window' default on, --cursor-mode-check 0 failure… |
| ext/duel-ring-online | 2d6734699 | 11-09 | conflict (18: DEBT.md, Arena-and-Training.md, Classes.md…) |  | ext/tut-duel-ring | Training Grounds duel ring: Find a duel (online queue, searching + Cancel) and Fight a bot; no Fight a friend, no 1v1 invite exists. Built o… |
| ext/extra-grounds-expanse | 69b0be9fe | 11-10 | conflict (5: Classes.md, Maps.md, home.gd…) |  |  | Training Area: open ground 616 -> 4807 tiles (7.8x, floor 3033 + Movement Fields), 216 map; Movement Fields: two dash lanes 91/96 m with Mul… |
| ext/extra-photo-mode | 12ffcfc74 | 11-10 | conflict (2: home.gd, check_registry.gd) |  | ext/feel-dash-off-ledge-rebased +4 | farm photo mode: pause-menu link, HUD off, orbit/pan, Capture saves PNG; --photo-mode-check 13/13 on GPU) |
| ext/farm-boki-sex-rebased | e29a16728 | 11-09 | conflict (1: boki_rig.gd) |  |  | w2; SUPERSEDES READY ext/farm-boki-sex e29a16728: same commit. origin/main d255acbee is already an ancestor, so merging main changes nothing… |
| ext/farm-carry-boki | a101fa587 | 11-10 | conflict (4: home.gd, boki_rig.gd, hunter_anim.gd…) |  |  | lift a Boki with interact, carry it, set it down; wiggle/nuzzle/sulk, trust +0.6 per 30 s, poses; --boki-carry-check) |
| ext/farm-feed-bowl | 747307b74 | 11-10 | conflict (5: Rules.md, evo.gd, farm_unlocks.gd…) |  |  | feeding bowl: base-mode catalog item, hungry Boki walk over, bold push in, timid wait, rivals huff, each eater gets the food lean; --feed-bo… |
| ext/farm-food-journal | 753a845a2 | 11-10 | conflict (4: save.gd, home.gd, overlay.gd…) |  |  | a food shows "Effect: ?" in the feed menu, inventory and stall until any Boki is fed it once; the first feed reveals it for every Boki with … |
| ext/farm-home-hatch | ec4b52a7a | 11-10 | conflict (2: home.gd, check_registry.gd) |  |  | nest egg hatch at home as a small moment: wobble in last 20 s, Boki gather to watch, auto-hatch when you are near, any key rushes it; --home… |
| ext/farm-homecoming | 5d75868e9 | 11-10 | conflict (6: base_life.json, BASE_LIFE.md, Rules.md…) |  |  | STACKED on READY ext/garden-base-life-main ebde0fac5, merge that first: the base life Fsm is not on main. Coming home: BaseLife.come_home, B… |
| ext/farm-mood-icons | 900bb8f9f | 11-10 | conflict (3: home.gd, check_registry.gd, style_baseline.json) |  |  | GARDEN.md cause visible: new KinMood, from Care needs: hungry/sleepy/wants to play/sulky (joy<15)/happy (joy>=80)/missed you (you back after… |
| ext/farm-sick-recover | 541e99cf2 | 11-10 | conflict (5: answer.md, Rules.md, care.gd…) |  |  | Boki sick/weak recovery: card line says what helps, slow droop walk + perk-up, fed/nap/friend/Puffcorn cure; --sick-recover-check; includes … |
| ext/farm-stat-causes | eabef2620 | 11-10 | conflict (2: home.gd, check_registry.gd) |  |  | GARDEN lever 2: StatCause.gain writes a journal line per stat gain, Boki card Training tab shows 4 bars + level cap mark + last change with … |
| ext/farm-tut-batch-1108 | 1c2b08ca2 | 11-08 | conflict (6: 0011-farm-builder-tutorial.md, care.gd, farm_guide.gd…) |  | ext/anim-boki-cast-rebased +49 | +e8b276b10 (PR #20, ). Owner playtest 11-08 items 27-31. **Stacked on the unpushed ext/farm-tut-spotlight 37f8bbf13** (first commit of the b… |
| ext/farm-tut-batch-1108-deep | dcc04a947 | 11-08 | conflict (4: tuning.json, care.gd, farm_guide.gd…) |  | ext/anim-timing-gunslinger +12 | , PR #23. Escalation of 20261108-180818-a1, owner items 27-31. Supersedes PR #20: the force push to rebase its branch was blocked, so this i… |
| ext/farm-tut-tools-cam-rebased | b6db84431 | 11-09 | conflict (6: farm_tutorial.json, Rules.md, save.gd…) |  | ext/anim-timing-gunslinger +11 | on w2). Supersedes ext/farm-tut-tools-cam: same commits; origin/main d255acbee merged as already up to date, no conflict in content/rules/fa… |
| ext/fsm-m1 | be74f3daa | 11-09 | conflict (2: Rules.md, hunter.gd) |  |  | Fsm M1 hardening; on w2, built on ext/movement-unify 1240289a9 which it contains: merge that first or this brings it along. Fsm guard_from, … |
| ext/garden-burrow-swap | 449d74852 | 11-09 | conflict (4: Rules.md, kinbox.gd, home.gd…) |  | ext/anim-boki-cast-rebased +39 | Burrow quick panel: who is out/asleep with portrait, mood, level; two-click swap; swapped Boki walk through the Burrow door; cap 6 from cont… |
| ext/garden-cinderstep | a2bb1bcb2 | 11-10 | conflict (12: garden_zones.json, 0022-garden-zones.md, Rules.md…) |  |  | garden step 7b Cinderstep: cinder theme, own zone layout, MultiMesh terraces and cracks, warm stone, post, patch snacks Fire/Rock/Steel/Drag… |
| ext/garden-horizon | 02077956a | 11-10 | conflict (14: garden_zones.json, market.json, 0022-garden-zones.md…) |  |  | garden hub step 9: five sky islands, lit/misty from Save.d zones, 5 draws; based on ext/garden-unlock; hub bench part added; hub total 430 d… |
| ext/garden-hub-theme | 7f1ba9db4 | 11-10 | conflict (10: base_race.gd, base_volley.gd, home_build.gd…) |  |  | Garden 7a Glasswater, final: all checks pass; shots and perf-bench zone done, see report) |
| ext/garden-integrated-rebased | b1102554e | 11-10 | conflict (49: MERGE_REPORT.md, cinder.glb, hem.glb…) |  | ext/garden-nav-sweep-rebased +1 | SUPERSEDES ext/garden-integrated 58686d0b6; deep escalated from 20261110-130819-a4. origin/main d255acbee was already inside 58686d0b6; the … |
| ext/garden-kite-1 | 04fb6499f | 11-11 | conflict (13: lean.json, snack_patch.json, Rules.md…) |  | ext/garden-kite-2 | Kite Tow part 1, GARDEN_MODERN 4.2 game 7: scripts/home/base_kite.gd + content/rules/base_kite.json; kite stand by the Training post on a ri… |
| ext/garden-kite-2 | df01d8830 | 11-11 | conflict (16: garden_prizes.json, lean.json, snack_patch.json…) |  |  | Kite Tow part 2: Space flaps 3 +1 per 25 Guard over 6 high rings, 2 updraft vents refund a spent flap, each lap races the Gale Kite = your s… |
| ext/garden-lantern-match | aa0f08971 | 11-11 | conflict (8: garden_items.json, garden_prizes.json, Rules.md…) |  |  | supersedes 27fcaadda: adds Glowmoss Sprig, so Lantern Match now gives all three design prizes. Worn aura, one at a time: rec.aura defaulted … |
| ext/garden-lantern-zone | 0555ccae0 | 11-10 | conflict (10: garden_zones.json, 0022-garden-zones.md, base_feed.gd…) |  | ext/garden-lantern-zone-hub | Hushwood zone, GARDEN.md 10.7 step 7c: own island on Save zones[id].layout via ZoneLook, dusk sky, lantern moss MultiMesh, dig+snack patch m… |
| ext/garden-lantern-zone-hub | 356960c0a | 11-10 | conflict (10: garden_zones.json, 0022-garden-zones.md, base_feed.gd…) |  |  | Garden 10.7 step 7c Hushwood: ext/garden-lantern-zone 0555ccae0 merged with ext/garden-hub-fixtures 88225f47a (clean merge), supersedes the … |
| ext/garden-nav-sweep-rebased | 13993323f | 11-11 | conflict (49: MERGE_REPORT.md, cinder.glb, hem.glb…) |  |  | SUPERSEDES ext/garden-nav-sweep d583ba443; deep escalated from 20261110-214023-a5. origin/main d255acbee was already inside d583ba443; the l… |
| ext/garden-path-meter | c1275d53a | 11-10 | conflict (4: Rules.md, evo.gd, home_toys.gd…) |  |  | GARDEN_MODERN 3 path meter: content/rules/evo_paths.json + EvoPath pips/winner (tie -> stat lead -> undecided), Growth-tab tug bar with silh… |
| ext/garden-ridge | e769da604 | 11-10 | conflict (12: lean.json, snack_patch.json, Rules.md…) |  | ext/garden-hub-theme +3 | Garden 7d Kitewind Ridge: ridge THEMES entry (storm flora scatter), Updraft vent toy, ridge patch snacks incl. new Sound food, second Dash c… |
| ext/garden-rivals | f2efd626d | 11-10 | conflict (6: Rules.md, save.gd, base_life.gd…) |  | ext/garden-tag | GARDEN 4-5 rivals: second loss to the same Boki in Dash/Shove/Seek/Volley marks a rival on the existing bonds + rec.grudge (lazy key, no Sav… |
| ext/garden-seasons | 595d3c0b4 | 11-11 | conflict (5: base_race.gd, base_seek.gd, base_volley.gd…) |  |  | GARDEN_MODERN 5 rank 9 seasons: GardenSeasons (scripts/home/garden_seasons.gd) + content/rules/garden_seasons.json; one of five zones in sea… |
| ext/garden-sleepovers | a15ae34de | 11-11 | conflict (2: save.gd, check_registry.gd) |  |  | sleepovers: Boki visits a friend's garden for a day, save v13, trade evolution; merges ext/garden-integrated since main lacks base_life.gd) |
| ext/garden-tag | d59f3c617 | 11-10 | conflict (6: Rules.md, save.gd, base_life.gd…) |  |  | GARDEN 4 tag: BaseTag (scripts/home/base_tag.gd) takes the PlayWith state out of base_life.gd; only friends (bond >= friend_at) start, 10-20… |
| ext/garden-trait-drift | 04173974a | 11-09 | conflict (7: BASE_LIFE.md, Rules.md, base_drift.gd…) |  |  | GARDEN.md 3 lever 3: BaseDrift once per in-game day at home, each trait closes 3% of the gap to its friends' average (bond >= friend_at, riv… |
| ext/garden-unlock | aa64a9c30 | 11-10 | conflict (9: garden_zones.json, market.json, 0022-garden-zones.md…) |  | ext/garden-horizon | garden zones step 6: Wayseed drop + trader + wake at Waystone; based on ext/garden-hub-zones e6d5e1989, not garden-integrated) |
| ext/garden-voice-ambience-rebased | 405870580 | 11-11 | conflict (116: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES ext/garden-voice-ambience ea25128ea; on rpc1. origin/main d255acbee was already in ea25128ea, so the 5 conflicts (AUDIO.md, home.… |
| ext/grimble-hook-arm-v2-rebased | bac62de38 | 11-08 | conflict (38: MERGE_REPORT.md, CAMERA_DEPTH.md, after_a_edge.png…) |  |  | supersedes ext/grimble-hook-arm-v2 315cdf2af) |
| ext/kin-type-trail | 8aa66c856 | 11-10 | conflict (3: moon_mark.json, Rules.md, check_registry.gd) |  |  | stacked on READY ext/boki-type-vfx 22a8ddb56, merge that first; moving summoned and wild Boki shed type-coloured motes via KinTypeTrail: 4 s… |
| ext/no-hardcoded-keys | 41597c5f9 | 11-09 | conflict (1: prematch_view.gd) |  |  | hard-coded key reads moved to Controls actions) |
| ext/no-rolling-rebased | 9b7b53152 | 11-09 | conflict (9: home.gd, main.gd, blight_dir.gd…) |  | ext/anim-timing-gunslinger +11 | SUPERSEDES ext/no-rolling daa669ea1): ext/no-rolling merged with origin/main d255acbee. Conflicts only in match.gd: kept main's item-163 Dro… |
| ext/reset-cue-rebased | 0fc62a451 | 11-09 | conflict (20: MERGE_REPORT.md, IMPORT.md, breaker.glb…) |  |  | supersedes ext/reset-cue 1dd752d4d; origin/main d255acbee was already in it, the real conflict was with READY ext/albert-size-boop-rebased d… |
| ext/sfx-garden-games-rebased | f6e990951 | 11-10 | conflict (47: MERGE_REPORT.md, cinder.glb, hem.glb…) |  |  | SUPERSEDES ext/sfx-garden-games d5aaad268; deep escalated from 20261110-080340-a4. origin/main d255acbee was already inside it; the conflict… |
| ext/sfx-hatch | c9055db1b | 11-10 | conflict (3: AUDIO.md, hatch.gd, check_registry.gd) |  |  | hatch sounds: wobble tick, two rising cracks, pop, first chirp per starter type venom/prism/spore (other types keep kin_happy), own darker s… |
| ext/solo-drop-20261109-2319 | 5f3dc384e | 11-09 | conflict (5: README.md, Checks.md, Rules.md…) |  |  | Solo/Trios expedition picker restored, ExpMode; check flag --solo-drop-check; also fixes a stray line that broke home.gd parsing) |
| ext/soul-link-integ-rebased | 35815307a | 11-10 | conflict (50: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  | ext/combat-bots-downed +4 | SUPERSEDES ext/soul-link-integ 3303c3b45; deep on w2, escalated from 20261110-132135-a4. INTEG T2, do not merge alone. origin/main d255acbee… |
| ext/soul-link-t3-rebased | d88fdee59 | 11-10 | conflict (50: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  | ext/soul-link-t4-rebased +1 | SUPERSEDES ext/soul-link-t3 37cb73338; deep on w2, escalated from 20261110-182454-a4. SOUL-LINK T3 (killed summon flies home / loose only wh… |
| ext/soul-link-t4-rebased | 295c0f0f1 | 11-10 | conflict (50: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | SUPERSEDES ext/soul-link-t4 410724c68; deep on rpc1, escalated from 20261110-182634-a4. SOUL-LINK T4 (R/E from the Boki wisp, decision 0038 … |
| ext/spike-slam-rebased | ce08349df | 11-11 | conflict (120: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES ext/spike-slam f0b10ce78; origin/main d255acbee has not moved and spike-slam sits on it cleanly, so the 6 conflicts were against … |
| ext/stuck-integ-950a5444 | c3b547945 | 11-08 | conflict (61: MERGE_REPORT.md, CAMERA_DEPTH.md, after_a_edge.png…) |  | ext/anim-timing-gunslinger +5 | supersedes: ext/cinder-flame-queen c3f4f1729, ext/grimble-v2-model 54df2f18a, ext/ryzz-v2-model 6355dee78, ext/text-relic-renames d6ec7954e … |
| ext/stuck-integ-b7a5717c | 58e2df0da | 11-10 | conflict (119: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  | ext/meeko-root-rebased +3 | supersedes: stuck-integ-b7a5717c 586fb5124 and all it carries, ext/lace-playtest-1108 b79ec35c5, ext/game-rules-nov8 14a02c652 incl roster-1… |
| ext/stuck-integ-cb5c1c27 | da83863db | 11-09 | conflict (7: warden_stance.json, DEBT.md, Rules.md…) |  | ext/albert-size-boop-rebased +2 | supersedes: ext/art1-kael-2 fd33d2045; . NO new merge: the branch = ext/mc-20261109-0030 tip (contains origin/main). art1-kael-2 is v1 Kael … |
| ext/stuck-integ-e28956f8 | 73b2cdcee | 11-09 | conflict (9: MERGE_REPORT.md, warden_stance.json, DEBT.md…) |  | ext/albert-size-boop-rebased +1 | supersedes: ext/art1-kael-2 fd33d2045, ext/kit-kael-113 6e18b8be7; . NO new merge: the branch = ext/mc-20261109-0503 tip (contains origin/ma… |
| ext/summon-kill-credit-rebased | b874902e1 | 11-10 | conflict (52: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES ext/summon-kill-credit 810a5976a; deep on rpc1, escalated from 20261110-204243-a6. origin/main d255acbee was already inside 810a5… |
| ext/train-moving-dummies-rebased | 2bc9dff7c | 11-10 | conflict (15: MERGE_REPORT.md, farm_builder.json, tutorial.json…) |  | ext/anim-boki-cast-rebased +40 | deep; SUPERSEDES READY ext/train-moving-dummies 6e50e4b23, and so its base ext/training-area-1108 too. origin/main d255acbee was already an … |
| ext/train-rank-controls | ca6395264 | 11-09 | conflict (14: DEBT.md, Arena-and-Training.md, Classes.md…) |  |  | Training Area Esc menu Practice page: Max all, Pick your max, Reset; PracticeRanks module + arena-check asserts; branched from ext/training-… |
| ext/trios-10x3-1108 | 83d314b98 | 11-09 | conflict (7: Rules.md, data.gd, home.gd…) |  | ext/anim-timing-gunslinger +11 | 2 commits on a3's 976b31f71, off main d255acbee; no gh on rpc1, PR: https://github.com/OrriBogdan2/project-boki/pull/new/ext/trios-10x3-1108… |
| ext/tut-first-breed | f7a1de0dd | 11-10 | conflict (6: Checks.md, care.gd, save.gd…) |  |  | first-breed prompt: when a pair meets every Nook gate, one of them walks to the Nook, waits and looks back; centred card on arrival with one… |
| ext/tut-garden-first-day-rebased | e2cb3036d | 11-10 | conflict (49: MERGE_REPORT.md, cinder.glb, hem.glb…) |  |  | SUPERSEDES ext/tut-garden-first-day 71eb276c0; deep escalated from 20261110-213808-a5. Old first-day branch + MERGES ext/garden-integrated-r… |
| ext/types-standard-names-rebased | 8b43b206f | 11-09 | conflict (1: moon_mark.json) |  | ext/anim-timing-gunslinger +15 | supersedes 1b445d3bf; stacked on READY ext/types-standard-names-rebased 8b43b206f, merge that first; one cast accent per Boki type via KinTy… |
| ext/ui-base-hud | 467239ce8 | 11-09 | conflict (1: home.gd) |  |  | supersedes e46107664: --base-hud-shots now reveals past the boot splash (the e46107664 shots were only the splash); same HUD code, MERGED ex… |
| ext/util-tonic-lamp | 65688c265 | 11-10 | conflict (21: hollowcrown.json, armor_kit.json, tonic.json…) |  | ext/feel-utility-move | Hearth Lamp revive sickness as a status: heart icon with seconds left on the plate and the squad row, carried as an "sk" pair in the hunter … |
| ext/vfx-garden-games | 671c4c5af | 11-10 | conflict (11: RIGGED_BOKI.md, base_race.gd, base_seek.gd…) |  | ext/vfx-garden-games-2 | garden games world cues: Dash marks+finish line, Shove push meter, Seek scent trail, Volley landing ring+spike flash; based on ext/anim-gard… |
| ext/vfx-garden-games-2 | ab3b49739 | 11-11 | conflict (17: BASE_LIFE.md, RIGGED_BOKI.md, Rules.md…) |  |  | supersedes the "(probe)" line above, posted by mistake. Garden games cues 2 in the Boki type colour: Echo Steps beat, hit and miss rings, Tu… |
| ext/clans-slice-2 | a67f4984b | 11-10 | conflict (4: DEBT.md, save.gd, social.gd…) | ext/clans-slice-1 |  | clans slice 2: clan base via ferry, member corners from profile snapshots, showcase wall, Social.clean_clanbase, --clan-check; stacked on ex… |
| ext/garden-save-trip | 4d826d114 | 11-09 | conflict (1: snack_patch.gd) | ext/garden-integrated | ext/garden-rivals +1 | --garden-save-check: every garden field round-trips in a fresh process + v11 main fixture migrates; fixes snack patch timer lost on reload a… |
| ext/garden-snacks-all-types | 01d2749a3 | 11-10 | conflict (8: base_race.gd, home_build.gd, home_layout.gd…) | ext/garden-ridge | ext/garden-hub-theme | GARDEN_MODERN 8: eight new type snacks in content/rules/snacks.json (Frost drop ice, Pebble nut rock, Scale pepper dragon, Dusk plum dark, P… |

### Wave 8: sfx (49)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/sfx-flyby | 0219fbf6a | 11-10 | clean |  |  | rival shot flyby whoosh by family within 2 m, --flyby-check) |
| ext/sfx-occlusion | 811d4164f | 11-10 | clean |  |  | positional sounds behind terrain play through a new SFXMuffled bus, 700 Hz low-pass and -4 dB: SfxOcclusion heightmap line test per voice, 1… |
| ext/sfx-armour-break | 5c57b6917 | 11-10 | light (1: AUDIO.md) |  |  | armour break: crack at the victim louder for them, attacker-only push tick, once per break; --armor-break-sfx-check) |
| ext/sfx-knock-confirm | a6e397ff7 | 11-10 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +37 | SFX_AUDIT row 4: knock_confirm now plays for the attacker's squad, finishing a Hunter plays new elim_confirm (tools/sfx_combat.py), both on … |
| ext/sfx-ready-cues | 9176cee38 | 11-10 | light (2: AUDIO.md, check_registry.gd) |  | ext/sfx-ready-cues-summon | quiet ready cues for R, Boki ability and an emptied dash via HudSlot hook; --ready-cue-check; wisp brighten and a real Boki summon slot not … |
| ext/sfx-status-cues | 962cd1fab | 11-10 | light (3: AUDIO.md, Rules.md, style_baseline.json) |  |  | status sounds: positional start cue for Ignite, Chill, Static (pitch per stack), Slow, Stun, Root, Ground, Daze, Anti-Heal; Ignite crackle +… |
| ext/dredge-auto-rebased | d40a4edab | 11-11 | conflict (9: dredge.json, shotgun.json, dredge.md…) |  |  | SUPERSEDES ext/dredge-auto 1744e565b; on rpc1. origin/main d255acbee was already an ancestor of dredge-auto, so the 6 cron conflicts came fr… |
| ext/early-camps-layout | 5792fba0f | 11-11 | conflict (5: hollowcrown.json, DEBT.md, net.gd…) |  | ext/early-camps-map-ui +3 | 28 camps on the 2x map, layout check) |
| ext/early-drop-height | d97cf5ece | 11-11 | conflict (4: DEBT.md, net.gd, drop_check.gd…) |  | ext/early-camps-layout +4 | 110 m drop, faster dive, dive view, clouds) |
| ext/early-hard-landing | b7afc92a5 | 11-11 | conflict (6: hollowcrown.json, AUDIO.md, DEBT.md…) |  | ext/early-camps-map-ui | Hard Landing: 6 m stagger + 30 damage on monsters) |
| ext/hit-spark-targets | 01303bff4 | 11-09 | conflict (1: sfx_set_check.gd) |  |  | hit sparks by target) |
| ext/recast-sounds | 82a248d91 | 11-09 | conflict (6: AUDIO.md, arch_kit.gd, ashwick_kit.gd…) |  |  | recast open chime + 0.5s close tick for every recast kit, caster-only UI sounds pitched by slot; --recast-sound-check 12/12, --sfx-set-check… |
| ext/scrapking-lmb | d5891bd37 | 11-08 | conflict (8: dredge.json, shotgun.json, dredge.md…) |  | ext/anim-timing-gunslinger +13 | PR #19, on main d255acbee). Scrap King LMB: the fixed three lines are now two edge lines that breathe with the real spread (#e0b040, spring … |
| ext/sfx-ambience | 7012c20f6 | 11-09 | conflict (3: AUDIO.md, match_audio_check.gd, sfx_set_check.gd) |  |  | SFX_AUDIT rows 2 and 21: new beds amb_meadow, amb_cliffs, amb_water, amb_gust, amb_blight, amb_title from tools/gen_ambience.py (rain reuses… |
| ext/sfx-armour-tier-up | f9a33f03f | 11-10 | conflict (2: ASSET_CREDITS.md, sfx.gd) |  |  | armour tier-up cue: metallic rise pitched by tier, positional for rivals, fuller for own Hunter; equal-check extended) |
| ext/sfx-belt-items | 4a9e8d6d7 | 11-09 | conflict (5: AUDIO.md, Rules.md, utility_use.gd…) |  | ext/feel-utility-move +3 | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/sfx-boki-type-cues | ebb7c17d6 | 11-09 | conflict (3: AUDIO.md, sfx.gd, sfx_set_check.gd) |  |  | Boki cast cue keyed by the 18 standard types: 12 new k_<type> cues, 6 renamed, mobs/bosses/blight keep working via k_rock/k_sound/k_poison; … |
| ext/sfx-boki-types | feedefebb | 11-09 | conflict (6: moon_mark.json, AUDIO.md, Rules.md…) |  |  | Boki type cast cues) |
| ext/sfx-boki-voices | 9c51f0a84 | 11-09 | conflict (4: home.gd, kin_companion.gd, kin_voice.gd…) |  | ext/garden-voice-ambience-rebased +1 | 21 rigged Boki species get their own voices bk_<species>_<mood> x happy/alert/unsure/sleepy/hurt x 2 takes, tools/gen_sfx_boki.py: pitch fro… |
| ext/sfx-boki-wire | dd32b83b4 | 11-09 | conflict (1: sfx_set_check.gd) |  | ext/garden-voice-ambience-rebased | Boki downed/revive/eat/sleep/fuse/unfuse sounds wired to their events, positional via Sfx; assert in --sfx-set-check; sfx-set, boki-system, … |
| ext/sfx-downed-muffle | 4d04d2f50 | 11-09 | conflict (2: music_dir.gd, match_audio_check.gd) |  |  | downed/out muffle: SFXWorld bus low-pass 1200 Hz + -6 dB duck, 0.3 s ramp, switched only by Sfx.set_muffle from music_dir tick, off in reset… |
| ext/sfx-extract-cues | d8e785a5c | 11-09 | conflict (5: AUDIO.md, main.gd, exits.gd…) |  |  | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/sfx-fusion-evolve | 9e270ce22 | 11-09 | conflict (2: AUDIO.md, sfx_set_check.gd) |  |  | 18 per-type Fusion enter cues, release afterglow, tired timeout and gentle evolve sounds wired in MergeXform/home; listening checklist: in a… |
| ext/sfx-gloves | ae71a7811 | 11-09 | conflict (2: AUDIO.md, sfx_set_check.gd) |  |  | 13 glove actives get their own synthesised sounds, tools/gen_sfx_gloves.py: 21 gl_* cues named in content/gear/<id>.json, read by Effects.sn… |
| ext/sfx-heartspark | aed05a9fc | 11-10 | conflict (6: heart.json, Rules.md, heart.gd…) |  |  | Heartspark cues: rising positional charge hum (70 m), take sting, map-wide reveal sting, carrier heartbeat loop, gate-open and extract cues … |
| ext/sfx-hit-targets | 03ecb2fcb | 11-09 | conflict (1: sfx_set_check.gd) |  | ext/hit-spark-targets | hit sound by target) |
| ext/sfx-legendary-presence | 7b5a26d63 | 11-10 | conflict (5: skyreach.json, AUDIO.md, Rules.md…) |  |  | legendary Boki presence sounds: one distant roar every player hears, panned toward it on a new SFXPan bus and themed titan/swarm/tempest wit… |
| ext/sfx-lobby-pick | 2b07caa2b | 11-10 | conflict (6: AUDIO.md, exits.gd, prematch_view.gd…) |  |  | lobby sounds: pick, 12 Hunter lock-in stings, teammate cue, last-10s ticks via UiSfx; includes ext/pick-order + ext/ui-sfx-set merged in) |
| ext/sfx-low-hp | 44dfb9f3f | 11-09 | conflict (2: HUD.md, sfx_set_check.gd) |  | ext/sfx-low-hp-filter-rebased | low-health heartbeat + red edge pulse, local player only: starts under 25% of max health+armour (content/rules/low_hp.json), faster as it dr… |
| ext/sfx-low-hp-filter-rebased | 53550c420 | 11-10 | conflict (4: HUD.md, music_dir.gd, match_audio_check.gd…) |  |  | supersedes ext/sfx-low-hp-filter; same commit: origin/main is still d255acbee, the branch already sits on it, merging origin/main is "Alread… |
| ext/sfx-match-shop | 54ad055a9 | 11-11 | conflict (12: hollowcrown.json, Maps.md, Rules.md…) |  |  | in-match shop sounds, one family tools/gen_sfx_shop.py + content/sfx/shop.json, via new ShopSfx: positional lantern bell on coming within re… |
| ext/sfx-mix-pass | 0591bb141 | 11-09 | conflict (3: Rules.md, match_audio_check.gd, sfx_set_check.gd) |  |  | reposted by coord: worker post lost 11-09 when ready-post was mis-installed) |
| ext/sfx-nook | f93b61589 | 11-10 | conflict (9: Checks.md, care.gd, home.gd…) |  |  | Nook pairing sounds: size-pitched two-note chime, nuzzle+settle layered with each parent's chirp, egg settle, unstable wobble, via NookSfx a… |
| ext/sfx-pickups | 0bb0bffab | 11-09 | conflict (2: AUDIO.md, sfx_set_check.gd) |  |  | SFX_AUDIT row 12 + 14: 5 pickup sounds by item category from data (armour/boots, active glove, treasure+gems, belt items, generic) via Picku… |
| ext/sfx-pickups-gloves | d9a23794f | 11-09 | conflict (3: AUDIO.md, loot.gd, sfx_set_check.gd) |  |  | pickup and glove sounds) |
| ext/sfx-pilot-1110 | 202f9c1f7 | 11-11 | conflict (1: jug_riposte.wav) |  |  | SFX pilot follow-up: dodge in new content/sfx/combat.json so --sfx-set-check covers it, all sets pass; pin_patter planned (0.2 s trim cap, 8… |
| ext/sfx-reverb-zones | 5d8b2e421 | 11-09 | conflict (5: hollowcrown.json, sfx.gd, make_hollowcrown.py…) |  |  | reverb send SFXRoom, room/arch presets, sound_zones in map JSON for Hollow Crown + Skyreach, audio check extended) |
| ext/sfx-strike-sync | 61619d99d | 11-09 | conflict (3: AUDIO.md, bulwark_kit.gd, dolm_kit.gd) |  |  | SFX on strike frames) |
| ext/sfx-summon-end | f99e9402d | 11-10 | conflict (15: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | two soft species-chirp notes 2 s before a summon window ends: own Boki in your ear -8 dB, others positional -20 dB; skipped if sent back or … |
| ext/sfx-utility-items-rebased | 82befd1f0 | 11-10 | conflict (21: hollowcrown.json, armor_kit.json, tonic.json…) |  | ext/feel-utility-move +2 | SUPERSEDES ext/sfx-utility-items 82befd1f0; on rpc1. origin/main d255acbee is already an ancestor of the branch (via merge af764b688), so me… |
| ext/sfx-warnings-boki | 83bb59a92 | 11-09 | conflict (4: AUDIO.md, exits.gd, hunter.gd…) |  | ext/sfx-extract-cues | low-HP, countdown, Blight and Boki sounds) |
| ext/sfx-water | 5641d7e9b | 11-11 | conflict (10: hollowcrown.json, AUDIO.md, DEBT.md…) |  |  | water movement sounds, SFX_AUDIT row 1; BASED ON ext/step-sounds-unified 8dd5161cf (the footstep surface lookup is not on main yet: merge th… |
| ext/sfx-wisp-proc | 331af7049 | 11-10 | conflict (15: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | wisp proc chirp: each WispProc cue of a carried Boki passive (heal/shield/damage/speed) plays one quiet bk_<species>_happy chirp on the wisp… |
| ext/sfx-wisps | 6baa2d6b7 | 11-09 | conflict (6: AUDIO.md, game.gd, net.gd…) |  | ext/combat-bots-downed +12 | Boki wisp sounds: wisp_chirp_small/medium/large pitched by body size, bloom, shrink, ready chime, grab cue; wired in KinSummon positional so… |
| ext/sfx-xp-steal | a8f0f70ab | 11-10 | conflict (4: ASSET_CREDITS.md, AUDIO.md, sfx.gd…) |  |  | kill XP tick + steal won/lost stings via KillCues on Match.on_mob_dead; Mob.damage_by per team (moved from Boss); mobdead event carries top … |
| ext/step-sounds-unified-rebased | 83dfbf1aa | 11-11 | conflict (121: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | SUPERSEDES ext/step-sounds-unified 8dd5161cf; on rpc1. origin/main d255acbee was already in 8dd5161cf, so the AUDIO.md/sfx.gd/match_audio_ch… |
| ext/ui-sfx-set | 8661028ec | 11-09 | conflict (4: AUDIO.md, exits.gd, ui.gd…) |  | ext/sfx-lobby-pick | SFX: one UiSfx helper for hover/press/back/error; new synth cues ui_capture, ui_extract_start, ui_extract_fail. Listen for: Boki scan finish… |
| ext/sfx-ready-cues-summon | d196b69bf | 11-10 | conflict (6: AUDIO.md, game.gd, net.gd…) | ext/wisp-summon |  | follow-up to ext/sfx-ready-cues 9176cee38: the Boki summon coming back plays ready_boki once on your own HUD, and the wisp brightens with a … |
| ext/sfx-summon | 29d9d520f | 11-09 | conflict (6: AUDIO.md, game.gd, net.gd…) | ext/wisp-summon-pop | ext/combat-bots-downed +11 | summon_burst/end/killed_<size> small/medium/large from kin_v2 size, species chirp layered in KinSummon.cue, positional reach 35 so a rival s… |

### Wave 9: vfx (57)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/boki3d-meshy-pilot-rebased | 1956f2a31 | 11-10 | clean |  |  | SUPERSEDES ext/boki3d-meshy-pilot f4aab6300; deep . f4aab630 already contained origin/main d255acbee; its conflicts (boki_rig.gd, boki_rig_c… |
| ext/spec-party-queue | 0c3034d77 | 11-10 | clean |  |  | docs/specs/PARTY.md: party of 3, invite code, leader mode, atomic matchmaker seating, disconnect+tutorial rules, 3 build jobs) |
| ext/verify-starter-trio | d52e49f42 | 11-10 | clean |  |  | Vex/Kael/Lace parity re-check on ext/release-integ-0244-fix ec3c9dafb: dated column in docs/KIT_PARITY.md, doc-only + wiki Rules.md regen; n… |
| ext/vfx-barrier-hits | 02d8bb526 | 11-10 | clean |  | ext/anim-boki-cast-rebased +37 | supersedes 99e3153af: shared pooled hit ripple on Albert shield / Tenzo rock / Neve Rimewall faces in the barrier colour, bigger white flash… |
| ext/vfx-dot-body | b14f6e858 | 11-10 | clean |  | ext/anim-boki-cast-rebased +39 | DoT body look: shared low burn-colour flicker plus a tick pulse on every burning body, steady tint on Low; --dot-look-check; strip jobq 2026… |
| ext/vfx-shield-expiry | 5e90240e5 | 11-10 | clean |  |  | shield shell fades/thins with amount left, one pulse in last 0.5 s; --shield-expiry-check) |
| ext/cancel-matrix-c | b5679fb88 | 11-09 | light (1: tender.md) |  |  | Cancels sections in docs/heroes dredge/tender/thief/ostra: second press per phase, source/ours/verdict/evidence; no kit change, no source li… |
| ext/party-client | 086e9f9e7 | 11-10 | light (1: check_registry.gd) |  | ext/ui-party-trios | party client: NetMatchmaker HTTP + Party state machine + /queue ticket poll -> Net.server_addr/start; --party-client-check against a fake ma… |
| ext/ui-cooldown-text | 152f317eb | 11-10 | light (1: check_registry.gd) |  | ext/feel-dash-off-ledge-rebased +4 | tests only, supersedes b02c07adb: main already draws seconds left (whole s, tenths under 1 s) on every cooling slot incl. dash and the Boki … |
| ext/ui-party-trios | ff9239bc2 | 11-11 | light (1: check_registry.gd) |  |  | party screen on ext/party-client: PartyView scripts/ui/party_view.gd, 3 seats name/Hunter/Ready/Leader, make+join by code, Ready, leader Fin… |
| ext/vfx-rescore | 13b167304 | 11-09 | light (1: VFX_QUALITY.md) |  |  | docs/VFX_QUALITY.md: all 12 Hunters re-scored from GPU reel strips, 23-29 after vs 14-28 before, weakest ability per hero, strips in docs/ar… |
| ext/vfx-shot-min-size | adc37e80d | 11-09 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +39 | supersedes 3e6c6925d, deep : LMB projectile floor via ShotFloor, a hot white core >= 6 px at 720p / 9 px at 1080p sized at the farthest poin… |
| ext/vfx-wall-stun-impact | d1758b37b | 11-10 | light (1: check_registry.gd) |  |  | wall stun impact: crack decal + dust puff ~0.6 s at the contact point, stone with the attacker hero-colour rim, pool of 6, no ground ring; C… |
| ext/art1-clip-port | 0494c83a6 | 11-09 | conflict (8: breaker.glb, claire.glb, hem.glb…) |  |  | SUPERSEDES READY ext/art1-clip-port 0494c83a6; hit-reaction keys in tools/art1 breaker_anims, hem, claire, sable, ryzz clip scripts, re-bake… |
| ext/boki-type-vfx | 22a8ddb56 | 11-09 | conflict (3: moon_mark.json, Rules.md, check_registry.gd) |  | ext/kin-type-trail | stacked on READY ext/boki-type-vfx 22a8ddb56, merge that first; moving summoned and wild Boki shed type-coloured motes via KinTypeTrail: 4 s… |
| ext/cancel-matrix-b | 107436fd0 | 11-09 | conflict (1: dolm.json) |  |  | Cancels sections in docs/heroes bulwark/rimewright/dolm/mage: second press per phase, source/ours/verdict/evidence; one fix: Tenzo punch rec… |
| ext/extra-mastery-look | d5e7d2d2d | 11-10 | conflict (2: class_unlock.json, Rules.md) |  | ext/anim-boki-cast-rebased +37 | mask takes hold slice 1: mastery features on your own character at home, content-driven (class_unlock.json looks): Vex green eye glow at mas… |
| ext/grimble-fist-vfx-rebased | ae8ccc107 | 11-09 | conflict (10: dredge.json, shotgun.json, HERO_VFX.md…) |  |  | SUPERSEDES READY ext/grimble-fist-vfx 48466a85f; Grimble E Anchor Drop giant scrap fist + HeroVfx fixed_dt + _dredge_e reel part, unchanged.… |
| ext/loot-rarity-vfx | 2c7798f17 | 11-09 | conflict (2: life.gd, style_baseline.json) |  | ext/vfx-loot-glow | loot rarity looks) |
| ext/particle-budget | 3d9f8186a | 11-09 | conflict (12: tuning.json, Rules.md, kin_tactics.gd…) |  | ext/vfx-lowpreset-read | particle budget) |
| ext/party-mm-core | 981dadcf8 | 11-10 | conflict (5: README.md, api.py, config.py…) |  |  | matchmaker party core: mm/party.py, party routes + X-Boki-Member header, whole-unit pick, party-first assign_slots, TRIO_SLOTS=30; 70 tests … |
| ext/perf-model-drawcalls | 411b9d481 | 11-09 | conflict (3: check_registry.gd, perf_bench.gd, warden_glb_check.gd) |  | ext/perf-owner-hw +1 | fewer draw calls per model) |
| ext/perf-render-presets-1108b | a90208db9 | 11-09 | conflict (4: settings.gd, check_registry.gd, perf_bench.gd…) |  | ext/anim-timing-gunslinger +11 | ## 2026-11-09 deep (w2): READY ext/perf-render-presets-1108b @ a90208db9 (supersedes ext/perf-render-presets-1108; escalated from 20261108-2… |
| ext/perf-tex-compress | 02a0b2907 | 11-10 | conflict (7: breaker_scan_albedo_key.jpg.import, breaker_scan_normal.jpg.import, gil_Image_0.png.import…) |  |  | texture budget: 39 3D textures lossless->VRAM compressed + mipmaps (31 Boki/Warden atlases and normals from perf-texture-import, plus 4 vend… |
| ext/side-cue-telegraphs | 11f0ce0bf | 11-09 | conflict (2: oomph.gd, clarity_check.gd) |  |  | side cue on telegraphs) |
| ext/split-models-rebased | c029fd6a3 | 11-10 | conflict (44: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES ext/split-models fc0129e7d; deep on w2, escalated from 20261110-120607-a4. fc0129e7d already sits on origin/main d255acbee; its m… |
| ext/status-body-looks | bfddc6570 | 11-09 | conflict (5: Rules.md, kit_status.gd, dolm_kit.gd…) |  | ext/parity-antiheal | body looks for burning, Chill, slow, stun, root, Grounded, Daze, Static, Anti-Heal, resurrection sickness in one data-driven StatusLooks; re… |
| ext/ui-text-chat-rebased | fe6a83505 | 11-10 | conflict (9: 0019-prematch-lobby.md, Rules.md, game.gd…) |  |  | SUPERSEDES READY ext/ui-text-chat f22b4ca56; deep on w2, escalated from 20261110-194612-a1. origin/main d255acbee was already inside f22b4ca… |
| ext/ui-text-size | 69324cfa3 | 11-10 | conflict (19: ashwick.json, juggernaut.json, thief.json…) |  |  | Settings > Accessibility 'Text size' 100/125/150%: UI.fs through the menu theme, UI.label/keycap/section and TextCache; settings from before… |
| ext/vfx-armour-break | 5123a0898 | 11-09 | conflict (4: HERO_VFX.md, HUD.md, ent.gd…) |  |  | re-checked, no -rebased branch needed: branch already contains origin/main d255acbee and merges clean; the conflicts in docs/HERO_VFX.md, sc… |
| ext/vfx-armour-tier-up | 0a0552c45 | 11-10 | conflict (4: HERO_VFX.md, hero_vfx.gd, hero_vfx_check.gd…) |  |  | armour tier-up: one pooled body sheen in the new ARMOR_TIERS colour climbs the Hunter in 0.4 s for everyone (HeroVfx.tier_up, new sheen mode… |
| ext/vfx-capture-read | 25fb0f106 | 11-09 | conflict (1: capture.gd) |  | ext/anim-boki-cast-rebased +39 | scan reads from 20 m: beam in scanner's ability colour, fill in side colour for all viewers, pop vs grey fizzle; --capture-read-check) |
| ext/vfx-dredge | 794ca0e37 | 11-08 | conflict (6: DEBT.md, VFX_QUALITY.md, dredge.md…) |  | ext/vfx-origin-v2-rebased +1 | Grimble's LMB/hold, hook/RMB, E and X moved from LDFx to HeroVfx data (content/vfx/dredge.json) in coin gold #ffc832: muzzle flash + slug tr… |
| ext/vfx-evolve-moment | 0307b4627 | 11-09 | conflict (2: home.gd, check_registry.gd) |  | ext/anim-evolve-moment +2 | evolve moment at home; supersedes 623430563: new form now grows to home's own size, hatchling 0.82 -> full, no snap at the end; freed watche… |
| ext/vfx-fusion-event | 323211c75 | 11-09 | conflict (3: moon_mark.json, Rules.md, check_registry.gd) |  |  | Fusion enter/release/afterglow: type accents + light column replace the ground rings and bursts via KinTypeFx.fusion on the shared Fx pools;… |
| ext/vfx-gunslinger | 1bb6c7bcd | 11-08 | conflict (4: VFX_QUALITY.md, gunslinger.md, gunslinger_kit.gd…) |  | ext/anim-timing-gunslinger +17 | . |
| ext/vfx-hawk-sense | 98cfb3dae | 11-11 | conflict (2: archer.md, archer_kit.gd) |  |  | Lace Hawk Sense reads like the source: rivals under the HP line within 22 m are seen by her side past rocks/fog (Match.can_see asks HawkSens… |
| ext/vfx-heal-shield-read | 3756af9af | 11-10 | conflict (1: utility_use.gd) |  |  | heal/shield receiver cue, supersedes b5a7bd0b8: cue shell now mix-blended (shaders/receiver_cue.gdshader) with a heal band climbing the body… |
| ext/vfx-miss-impacts | e922033b0 | 11-10 | conflict (2: dj_fx.gd, check_registry.gd) |  |  | missed LMB/RMB shots end in a pooled puff in the kit colour: small at a wall, wider fade at max range; MissFx + Sable's Bola; --miss-fx-chec… |
| ext/vfx-occlusion-outline | 6f1deba09 | 11-10 | conflict (2: settings.gd, check_registry.gd) |  |  | cover outline: you, squad and their Bokis always, rivals only while in sight (red, SideColor), one overlay pass, off on Low; --occlusion-out… |
| ext/vfx-pass | b7d8bf3c0 | 11-09 | conflict (44: dolm.json, mage.json, tender.json…) |  | ext/vfx-origin-v2-rebased | VFX lane pass: merges the 13 READY 11-08 VFX branches (quality-base, gunslinger, archer, cinder-polish, kael-polish, dolm, dredge, tender, t… |
| ext/vfx-revive-read-rebased | c403f1ddb | 11-10 | conflict (43: MERGE_REPORT.md, tutorial.json, class_unlock.json…) |  |  | SUPERSEDES ext/vfx-revive-read a4cf0bdaa; . origin/main d255acbee was already inside it; the conflicts (docs/DEATH_AND_REVIVE.md, scripts/ma… |
| ext/vfx-summon-ring | e068d5655 | 11-10 | conflict (15: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  |  | supersedes 3c90f97ef: same summon time-left ring, now with a GPU strip that shows it. Shots reframed on the summons, no tips, plus a close-u… |
| ext/vfx-summon-side | af2f8cb11 | 11-09 | conflict (4: game.gd, net.gd, perf_bench.gd…) |  | ext/combat-bots-downed +11 | : a summoned or stolen Boki reads as someone else's, not wild or yours. SideRings.kin paints its ground ring and glow-shell outline in the s… |
| ext/vfx-telegraph-lead-rebased | f3f674581 | 11-10 | conflict (119: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | supersedes ext/vfx-telegraph-lead 392e2685a; . 392e2685a already sits on origin/main d255acbee and merges there clean; its conflicts were wi… |
| ext/vfx-telegraph-timing-rebased | 7cbc2cae1 | 11-10 | conflict (119: MERGE_REPORT.md, IMPORT.md, ryzz_atlas.jpg…) |  |  | supersedes ext/vfx-telegraph-timing 0b8572c2d; deep on w2, escalated from 20261110-213653-a4. 0b8572c2d already sits on origin/main d255acbe… |
| ext/vfx-tender | cfbdc5abe | 11-08 | conflict (8: tender.json, tender.json, VFX_QUALITY.md…) |  | ext/anim-timing-gunslinger +13 | no PR yet: gh is not on w2, open one from https://github.com/OrriBogdan2/project-boki/pull/new/ext/vfx-tender into ext/vfx-quality-base). Me… |
| ext/vfx-tenzo-impacts | 7b34673dc | 11-09 | conflict (3: breah_slam.gd, breah_spine.gd, dolm_kit.gd) |  |  | Tenzo blue impact weight sized by damage on boulder, rock burst, LMB punch, RMB and glide slam, plus a blue ring on each Stone Row/R rock ri… |
| ext/vfx-utility-read | 892f367d5 | 11-10 | conflict (18: hollowcrown.json, armor_kit.json, tonic.json…) |  |  | supersedes fa10d56c7: readable looks for Skyfall fuse ring + warhead, Blight Flask edge, Twin Gate portals + link, Thorn Wall spikes, Warp S… |
| ext/vfx-wisp-proc | 8f2531e0e | 11-10 | conflict (15: ryzz_atlas.jpg, ryzz_atlas.jpg.import, sable_atlas.jpg…) |  | ext/sfx-wisp-proc +1 | wisp proc look: a carried passive acting (heal, shield/armor/damage cut, damage bonus on a shot, run boost) gives its wisp one small flash i… |
| ext/vfx-bulwark | f612a5702 | 11-08 | conflict (10: bulwark.json, HERO_VFX.md, VFX_QUALITY.md…) | ext/vfx-quality-base | ext/anim-timing-gunslinger +13 | stacked on ext/vfx-quality-base 9a9bb3b79: merge that first; no PR, gh is not on w2: |
| ext/vfx-dolm | 9871872fa | 11-08 | conflict (3: dolm.json, VFX_QUALITY.md, dolm.md) | ext/vfx-quality-base | ext/anim-timing-gunslinger +13 | PR #27, stacked on ext/vfx-quality-base). Tenzo slam/RMB/hop landings/Basalt Spine moved to content/vfx/dolm.json (HeroVfx, cobalt): crack c… |
| ext/vfx-last-hit-colour | 31df9be3f | 11-10 | conflict (2: oomph.gd, settings.gd) | ext/ui-colourblind-sides |  | monster and lair-boss death flash + dissolving body glow in the killer side's SideColor colour (your squad vs rival squad, colour-vision pal… |
| ext/vfx-loot-glow | 4349018ac | 11-11 | conflict (2: life.gd, style_baseline.json) | ext/loot-rarity-vfx |  | on w2; STACKED on ext/loot-rarity-vfx 2c7798f17 (halo on every drop, not on main: merge it first, it already holds LootGlow + --loot-glow-ch… |
| ext/vfx-lowpreset-read | e0dc73584 | 11-09 | conflict (17: tuning.json, archer.json, juggernaut.json…) | ext/particle-budget |  | Very Low vs High read of all 12 Hunters' abilities: rings, zones, telegraphs, recast markers and hit flashes all survive (meshes, no preset … |
| ext/vfx-neve-crash | 23d171858 | 11-09 | conflict (3: rimewright.md, ult_look.gd, care_ult_check.gd) | ext/vfx-rimewright-quality |  | Neve parity VFX: Rimelock crash = 34 long ice shards + brighter light column; bud = six petals about 1.9 m closing over her, rink drawn as t… |
| ext/vfx-stolen-wisps-rebased | ac8f0a107 | 11-10 | conflict (5: Rules.md, game.gd, net.gd…) | ext/wisp-summon | ext/anim-boki-cast-rebased +39 | SUPERSEDES ext/vfx-stolen-wisps 1be7dce25; origin/main d255acbee was already inside 1be7dce25, so the 4 listed conflicts came from merge can… |

### Wave 10: net/server (7)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/squad-intro-skyship | 510caa2a9 | 11-10 | light (1: DEBT.md) |  |  | squad intro 5s skippable + procedural skyship w/ deck squad, wisps, shadow, trail, engine/wind; checks pass; shots /home/boki/jobq/done/2026… |
| ext/demo-record-ready-1109 | 5e0493be1 | 11-09 | conflict (5: arch.gd, match.gd, goal_tracker.gd…) |  | ext/anim-timing-gunslinger +11 | off origin/main d255acbee; supersedes the 70960e039 READY above; no ext/mc candidate on origin to add). |
| ext/leave-match-warning-1108 | 8a8f66a42 | 11-08 | conflict (2: overlay.gd, check_registry.gd) |  | ext/anim-timing-gunslinger +11 | off main d255acbee; not merged; no PR: gh is not on w2, compare https://github.com/OrriBogdan2/project-boki/compare/ext/leave-match-warning-… |
| ext/misc-ready-integ | 55446e046 | 11-08 | conflict (29: archer.jpg, dolm.jpg, dredge.jpg…) |  | ext/anim-timing-gunslinger +5 | supersedes: ext/portraits-unified 51c79fc89, ext/tg-text 666ba8d8f, ext/parity-bulwark-guardcut b2e942eb4, ext/lace-dash-charges 7b83eae8, e… |
| ext/net-rejoin | b0f9ee82e | 11-10 | conflict (2: net.gd, check_registry.gd) |  |  | rejoin a match within 90 s: relay holds the dropped Hunter, title 'Rejoin match' restores Hunter/health/Boki; Net.VERSION 0.25.1; --rejoin-c… |
| ext/status-net-check | 8051a4361 | 11-09 | conflict (4: DEBT.md, kit_status.gd, net.gd…) |  |  | status replication) |
| ext/wisp-summon-net-rebased | 78f2803ad | 11-10 | conflict (51: MERGE_REPORT.md, ryzz_atlas.jpg, ryzz_atlas.jpg.import…) |  |  | SUPERSEDES READY ext/wisp-summon-net 5d4c33fc6; deep on rpc1, escalated from 20261110-204813-a5. origin/main d255acbee was already inside 5d… |

### Wave 11: perf (7)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/perf-visibility-ranges-rebased | 4d8db78f2 | 11-09 | light (1: check_registry.gd) |  | ext/anim-boki-cast-rebased +41 | deep, rpc1; SUPERSEDES READY ext/perf-visibility-ranges 5397d3341). origin/main d255acbee was already an ancestor of 5397d334 (no conflict w… |
| ext/expedition-fps-1108 | 62ad7d14f | 11-08 | conflict (8: tuning.json, kin_tactics.gd, settings.gd…) |  | ext/anim-timing-gunslinger +15 | no gh on w2, PR: https://github.com/OrriBogdan2/project-boki/pull/new/ext/expedition-fps-1108). Expedition FPS, PARTIAL (targets not met). P… |
| ext/perf-fight-pools | 907d1f4e4 | 11-09 | conflict (2: fx.gd, perf_bench.gd) |  | ext/perf-owner-hw +1 | pooled fight nodes) |
| ext/perf-occluders | 352163646 | 11-09 | conflict (1: settings.gd) |  | ext/perf-owner-hw +1 | baked occluders) |
| ext/perf-owner-hw | 546cce212 | 11-10 | conflict (9: DEBT.md, boki_rig.gd, bot.gd…) |  |  | round 2 on 90dd3e317: layered shader warm-up on drivers that keep a shader cache, PC first-launch loading 16.4->13.5 s with 0 compiles in pl… |
| ext/perf-train-0245 | 3a49c8144 | 11-10 | conflict (8: DEBT.md, boki_rig.gd, bot.gd…) |  | ext/perf-owner-hw | supersedes c14728951: same branch, PERF_TRAIN.md now has the M5 base: ride/drop/land medians 29/43/34 -> 21/28/25 ms, drop frames over 50 ms… |
| ext/perf-merged-drops | 5d059cdcd | 11-10 | clean | ext/perf-merge-drops |  | merged drops: gem/seed drops within 3 m of the same kind join one pile, online via existing gone+drop events (no Net change), gem nodes pool… |

### Wave 12: tools/docs (4)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/checks-out-of-main | 26941068c | 11-09 | light (3: DEBT.md, check_registry.gd, style_baseline.json) |  |  | 16 inline --*-check branches out of main.gd into tools/check_registry.gd, airheal fall-through fixed, main.gd 3956 -> 3821 lines; moved chec… |
| ext/clip-cadence-check | 9e3438417 | 11-09 | conflict (4: pip.json, sable.json, warden_clips.gd…) |  |  | clip vs cadence check) |
| ext/tenzo-playtest-1108 | dc6e4c5ba | 11-08 | conflict (7: dolm.json, tuning.json, dolm.md…) |  | ext/vfx-telegraph-timing-rebased | ## READY ext/tenzo-playtest-1108 @ dc6e4c5ba (2026-11-09): Tenzo playtest items 21, 22 (owner 11-08) |
| ext/warden-check-heights | 84f9aa9d1 | 11-08 | conflict (1: warden_model_check.gd) |  | ext/anim-timing-gunslinger +11 | 4538174a8. --warden-model-check expected heights follow the owner-approved hero heights: archer 1.07, gunslinger 1.09, mage 1.08/3d 1.18, th… |

### Wave 13: misc (31)

| Branch | sha | date | trial | stack on | carried by | what |
|---|---|---|---|---|---|---|
| ext/spec-early-camps | d45ae33aa | 11-10 | clean |  |  | spec: Levels as strategy, kill-only XP + last-hit share, catch-up, steals, XP bar; 17 tasks, 11 for 0.24.4) |
| ext/spec-steal-counterplay | bc3e84698 | 11-10 | clean |  |  | docs only: docs/specs/STEAL_COUNTERPLAY.md; source facts, 3 options, default B finale window at 20% HP using existing stagger, steal callout… |
| ext/ttk-matrix-rebased | 753ccf402 | 11-10 | clean |  | ext/combat-summon-share +5 | SUPERSEDES ext/ttk-matrix 5387b0051: same TTK matrix, renamed so it lands beside ext/ttk-table without conflicts: --ttk-matrix-check, tools/… |
| ext/air-cast-a | c5f1e3899 | 11-09 | light (4: ashwick.md, gunslinger.md, juggernaut.md…) |  |  | In the air tables for Vex, Kael, Lace, Cinder, Meeko, Tenzo; --air-limits-check asserts them; no gameplay change; six combo checks 0 failure… |
| ext/air-cast-b | 0d6243446 | 11-09 | light (2: bulwark.md, thief.md) |  |  | In the air tables in the six Hunters-B docs; Motley's seed and Nightwell now cast from a jump, fall or glide, planted on the floor under him… |
| ext/flow-hold-rows | 125245956 | 11-09 | light (1: dash_interactions.md) |  |  | dash-flow hold rows of Lace, Sparkle, Tenzo: Tenzo hold.rmb.jump sourced to Breah jump-while-charging leap, the other 14 Not determinable wi… |
| ext/flow-rows-source | dd2c83be5 | 11-09 | light (2: KIT_PARITY.md, dash_interactions.md) |  |  | 14 unsourced hold rows of Kael, Cinder, Albert, Neve, Meeko now carry a source citing file:line and frames checked; all Not determinable, no… |
| ext/gaps-thief | 61390af6d | 11-09 | light (1: thief.md) |  |  | Sable footage gaps Nov 9 re-check: table of the 11 dancer.md rows in docs/heroes/thief.md, all closed on main, rows 1/5/8 with LMB range, co… |
| ext/geodemole-broken | b6103c46c | 11-10 | light (2: Rules.md, check_registry.gd) |  |  | supersedes 1a42f682e: Geodemole intact + cracked second form = damaged state <40% hp in match or sick at home, evolution noted as alternativ… |
| ext/heal-knock-source-rebased | 44f88a2c9 | 11-09 | light (2: dredge.md, thief.md) |  | ext/anim-timing-gunslinger +11 | supersedes ext/heal-knock-source; origin/main merged, no conflicts left; dancer/juggernaut/dredge/ashwick combo checks, --check, health --st… |
| ext/shadow-renames-arch | 17737fb9f | 11-09 | light (1: style_baseline.json) |  |  | shadow renames arch/heroes) |
| ext/snag-audit | 0ea717354 | 11-09 | light (2: MOVEMENT_FEEL.md, check_registry.gd) |  |  | --snag-check: 12 Hunters x 50 seeded run/dash/glide paths on The Hollow Crown, stall = under half wanted speed for over 0.15 s with keys hel… |
| ext/step-smooth-rebased | 0a96e4b98 | 11-09 | light (2: MOVEMENT_FEEL.md, check_registry.gd) |  |  | SUPERSEDES ext/step-smooth 0a96e4b98: branch already contains origin/main d255acbee, no conflicts remain; --step-smooth-check 0 failures, --… |
| ext/telegraph-one-system | f24474927 | 11-09 | light (1: AIMKIT.md) |  |  | ArchKit fuse + charge ring on AimKit, tele_circle/tele_lane deleted, -32 net lines in arch_kit; Fx.telegraph_* kept: non-kit users remain, D… |
| ext/clans-slice-1 | f76a9e117 | 11-10 | conflict (2: DEBT.md, save.gd) |  | ext/clans-slice-2 | clans slice 1: clanroster doc, Save.d clan v12 migration, member roll, --clan-check) |
| ext/creator-sex-distinct | 59701cf8f | 11-08 | conflict (3: warden_stance.json, Rules.md, empty_shots.gd) |  | ext/albert-size-boop-rebased +3 | PR #29, on main d255acbee; not merged). Owner 11-08 hatch playtest: the male and female Empty now read apart at a glance. Every shroud cut i… |
| ext/early-camps-core | fa8d228e6 | 11-11 | conflict (2: net.gd, style_baseline.json) |  | ext/early-camps-layout +5 | camps pay XP and one reward; XP rules in data) |
| ext/fight-hitch | 08712bc58 | 11-09 | conflict (3: DEBT.md, spawn_plan.gd, perf_bench.gd) |  | ext/perf-owner-hw +1 | fight hitch fixes) |
| ext/grimble-nose-1109 | 5e98228d5 | 11-09 | conflict (3: dredge.glb, dredge_atlas.jpg, dredge_atlas.jpg.import) |  |  | hetzner). Grimble's head matches the owner's 11-09 turnaround ("correct nose"): the in-game head had no nose (the old canon); it now has the… |
| ext/grimble-stretch-v2-rebased | 88c75bf31 | 11-09 | conflict (5: dredge.glb, DEBT.md, grimble_clips.py…) |  |  | supersedes ext/grimble-stretch-v2 ba158402c: same Grimble skin-stretch fix (skin_relax.reweigh, rebaked dredge.glb, --stretch-check) with or… |
| ext/landing-recovery | b1927cf07 | 11-09 | conflict (5: hunter_move.json, MOVEMENT_FEEL.md, Rules.md…) |  |  | landing recovery vs the source: no lock anywhere, none added; STACKED on READY ext/drop-parity 8a7cbce24 and READY ext/parity-jump-pads a271… |
| ext/level-pace | d0960b1c4 | 11-09 | conflict (2: match.gd, check_registry.gd) |  |  | XP gains to level_growth.json xp; median L2/4/6/10 37/61/126/376 s -> 43/71/209/548 s over 3x30-hunter sims; docs/LEVEL_PACE.md) |
| ext/mantle-press-rules | 6b892567a | 11-10 | conflict (5: dash_interactions.md, dash_flow.gd, hunter.gd…) |  |  | presses in a ledge rise go by one shared table, content/rules/mantle_press.json, routed once in DashFlow for all 12 Hunters: dash fires mid-… |
| ext/rank-paths-fit | 18b081c64 | 11-10 | conflict (13: archer.json, bulwark.json, dolm.json…) |  |  | rank paths from data: kit JSON dash.rank_cuts + rmb/e rank_dmg; Lace -1s x2, Spin Dash -1.5s x2, Trade -1.5s x2, Snap +20% x2, seed +10% x2,… |
| ext/sneak-speed-source | 178d0d384 | 11-09 | conflict (3: hunter_move.json, Rules.md, hunter.gd) |  |  | sneak speed 0.5 from hunter_move.json, inline 0.55 removed, asserted in --move-feel-check) |
| ext/split-exits | 3687cf511 | 11-09 | conflict (2: exits.gd, style_baseline.json) |  |  | exits.gd split into exits/exits_flow/exits_look, no behaviour change) |
| ext/split-lairs | 1605c9185 | 11-09 | conflict (2: lairs.gd, style_baseline.json) |  |  | split lairs) |
| ext/telegraph-audit-b-rebased | d42fe2ce6 | 11-09 | conflict (7: archer.md, rimewright.md, breah_spine.gd…) |  | ext/anim-timing-gunslinger +11 | supersedes ext/telegraph-audit-b 20810cf25: origin/main merged in; conflicts in archer.md, rimewright_kit.gd, pin_bjorn_ult_check.gd resolve… |
| ext/telegraph-audit-c-rebased | 32742080e | 11-09 | conflict (8: thief.json, bjorn_fx.gd, bulwark_kit.gd…) |  | ext/anim-timing-gunslinger +6 | supersedes ext/telegraph-audit-c 498b60d09: origin/main merged in; mage_kit/mage_ult conflicts resolved keeping main's PINK palette plus the… |
| ext/tenzo-cone-grow | dafcc39dc | 11-09 | conflict (2: dolm.json, dolm_kit.gd) |  |  | Tenzo Tremor Sense cone 18 -> 25 m over the 2 s sneak grow, passive.len [start,end] in dolm.json, telegraph and foe test read it each tick, … |
| ext/zone1-batch1 | fb1efdd2a | 11-10 | conflict (2: DEBT.md, evo.gd) |  |  | zone 1 + suite-fast vs main: 166 flags, no new red after reruns; swim/hob/market load flakes pass on rerun; boki-dash +8 kin inherit main-re… |

## Held (11)

| Branch | sha | why |
|---|---|---|
| ext/agent-briefs-rebased | 347830615 | built on ext/agent-briefs history (1483 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/anim-uthana-rank | 8eb9e732a | excluded by coordinator (NO-GO verdict) |
| ext/garden-zones-decision | c312e6c57 | text: review only |
| ext/meeko-rmb-motion-rebased-rebased | e5587292a | built on ext/agent-briefs history (1536 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/parity-snowglide-rebased-rebased | 4a2175eec | built on ext/agent-briefs history (1539 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/review-design-1110 | 3ffb86565 | built on ext/agent-briefs history (5150 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/review-design-1110-fun | c4ea93c71 | built on ext/agent-briefs history (5121 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/sable-wings | 6f81ccee9 | excluded by coordinator (owner pick) |
| ext/spec-limited-way-outs | f44528b31 | built on ext/agent-briefs history (4447 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/spec-ways-out-zone | 31c118f4f | built on ext/agent-briefs history (4448 commits ahead), git refuses the merge; docs only, port by hand if wanted |
| ext/warden-detail-pilot | b73419fd9 | text: owner pick |

## Stale (2)

| Branch | sha | why |
|---|---|---|
| ext/art1-integ-4 | 9a6ac1f34 | 2026-11-05, conflicts in 36 files |
| ext/mc-fix-1109 | da033386b | sha not found on origin |

## Superseded (148)

| Branch | sha | winner |
|---|---|---|
| ext/agent-briefs | af480ffa8 | ext/agent-briefs-rebased |
| ext/albert-size-boop | 3d7539d7b | ext/albert-size-boop-rebased |
| ext/anim-boki-cast | a9e410abe | ext/anim-boki-cast-rebased |
| ext/anim-carry-pose | 9235196c2 | ext/anim-carry-pose-rebased |
| ext/anim-fusion-states | a67fd5c03 | ext/anim-fusion-states-rebased-rebased |
| ext/anim-fusion-states-rebased | df3fa0479 | ext/anim-fusion-states-rebased-rebased |
| ext/anim-hand-tenzo | f44d76294 | ext/anim-hand-tenzo-rebased |
| ext/anim-idle-walk-gap | b0a1e9843 | ext/anim-idle-walk-gap-rebased |
| ext/anim-mob-states | aabf4cfc5 | ext/anim-mob-states-rebased |
| ext/anim-pilot-loops-cm | 5eb0c8789 | ext/anim-pilot-loops-cm-v2 |
| ext/anim-react-2 | 2eea0e098 | ext/anim-react-2-rebased |
| ext/anim-rooted-legs | ab8f843d4 | ext/anim-rooted-legs-rebased |
| ext/anim-time-cinder | 584aa5241 | ext/anim-time-cinder-rebased |
| ext/anim-time-mossy | 162a420fb | ext/stuck-integ-b7a5717c |
| ext/anim-time-sable | 53f658240 | ext/anim-time-sable-rebased |
| ext/anim-time-sparkle | 4c7b70c9c | ext/stuck-integ-b7a5717c |
| ext/anim-time-tenzo | 5aafba874 | ext/tutorial-prologue-rebased-rebased |
| ext/barrier-block-parity | e77b75102 | ext/combat-wall-surfaces |
| ext/body-hitbox-parity | b9f481fa0 | ext/body-hitbox-parity-rebased |
| ext/boki-downed-pose | 8a2487d76 | ext/boki-downed-pose-rebased |
| ext/boki-react-clips | 5aa0b8d70 | ext/boki-react-clips-rebased |
| ext/boki3d-meshy-pilot | f4aab6300 | ext/boki3d-meshy-pilot-rebased |
| ext/cinder-sable-polish | 6952af96d | ext/cinder-sable-polish-rebased |
| ext/combat-friendly-fire | e77ba7f26 | ext/combat-friendly-fire-rebased |
| ext/dash-buffer-window | 77fa3ffde | ext/dash-buffer-window-rebased |
| ext/farm-boki-sex | e29a16728 | ext/farm-boki-sex-rebased |
| ext/farm-tut-tools-cam | b6db84431 | ext/farm-tut-tools-cam-rebased |
| ext/feel-cast-move | aed445785 | ext/feel-cast-move-rebased |
| ext/feel-dash-no-input | b5c84f6d2 | ext/feel-dash-no-input-rebased |
| ext/feel-dash-off-ledge | 04c0748b2 | ext/feel-dash-off-ledge-rebased |
| ext/feel-facing-turn | d5333f969 | ext/feel-facing-turn-rebased |
| ext/feel-first-cast-warm | 27d6f01f4 | ext/feel-first-cast-warm-rebased |
| ext/feel-impact-tiers | 371e736ab | ext/feel-impact-tiers-rebased |
| ext/feel-knock-override | 1c92b024b | ext/feel-knock-override-rebased |
| ext/feel-summon-press | 410591940 | ext/feel-summon-press-rebased |
| ext/feel-yaw-lock-12 | 6d7ceae7b | ext/feel-yaw-lock-12-rebased |
| ext/first-hints-check | 123f1800d | ext/first-hints-check-rebased |
| ext/fix-cinder-art-check | cb8131be9 | ext/stuck-integ-b7a5717c |
| ext/game-rules-nov8 | 14a02c652 | ext/stuck-integ-b7a5717c |
| ext/gaps-juggernaut | b4f362a74 | ext/kael-lunge-length-rebased-rebased |
| ext/garden-hub-move | 8fe040176 | ext/garden-hub-zones (already in release/main) |
| ext/garden-voice-ambience | ea25128ea | ext/garden-voice-ambience-rebased |
| ext/garden-zone-cinderstep | d9b03de0d | ext/garden-cinderstep-zone (already in release/main) |
| ext/grimble-fist-vfx | 48466a85f | ext/grimble-fist-vfx-rebased |
| ext/grimble-stretch-v2 | ba158402c | ext/grimble-stretch-v2-rebased |
| ext/heal-knock-source | f66273fcd | ext/stuck-integ-b7a5717c |
| ext/hitstop-parity | c9315676d | ext/feel-impact-tiers-rebased |
| ext/hunter-revamp-pz | fb240baa2 | ext/hunter-revamp-pz-rebased |
| ext/idle-archer | 8437593bb | ext/idle-archer-rebased |
| ext/idle-bulwark | 53c963ec5 | ext/idle-bulwark-rebased |
| ext/idle-dredge | b3fdeeeff | ext/idle-dredge-rebased |
| ext/idle-gunslinger | fa16ce7ef | ext/idle-gunslinger-rebased |
| ext/idle-mage | 9d6d41c02 | ext/idle-mage-rebased |
| ext/idle-tender | be19bd8bf | ext/idle-tender-rebased |
| ext/idle-thief | 619b8dc32 | ext/idle-thief-rebased |
| ext/kael-lunge-length | b4ffaa6ed | ext/kael-lunge-length-rebased-rebased |
| ext/kael-lunge-length-rebased | 00894cd16 | ext/kael-lunge-length-rebased-rebased |
| ext/kael-ult-reset | f1192cb93 | ext/tutorial-prologue-rebased-rebased |
| ext/kael-ult-reset-rebased | d32c621e6 | ext/stuck-integ-b7a5717c |
| ext/lace-dash-charges | 7b83eae87 | ext/misc-ready-integ |
| ext/lace-hail-wisps | d93205aaa | ext/lace-hail-wisps-rebased |
| ext/lace-playtest-1108 | b79ec35c5 | ext/stuck-integ-b7a5717c |
| ext/meeko-rmb-motion | 8801461cc | ext/meeko-rmb-motion-rebased-rebased-rebased |
| ext/meeko-rmb-motion-rebased | d2fa02fa6 | ext/meeko-rmb-motion-rebased-rebased-rebased |
| ext/meeko-rmb-verify | eba7147eb | ext/meeko-rmb-verify-rebased-rebased |
| ext/meeko-rmb-verify-rebased | 7c1762cf5 | ext/meeko-rmb-verify-rebased-rebased |
| ext/mossy-narrow | cc74a32e0 | ext/stuck-integ-b7a5717c |
| ext/move-sfx-positional | 0e4199c4f | ext/step-sounds-unified-rebased |
| ext/no-dash-bursts-audit | 9ef878c5f | ext/no-dash-bursts-audit-rebased-rebased |
| ext/no-dash-bursts-audit-rebased | 76cd0bbac | ext/no-dash-bursts-audit-rebased-rebased |
| ext/no-rolling | daa669ea1 | ext/no-rolling-rebased |
| ext/ostra-gait | 89acba32b | ext/ostra-gait-rebased |
| ext/parity-bulwark-crush | 26a64a5b7 | ext/parity-bulwark-crush-rebased |
| ext/parity-bulwark-guardcut | b2e942eb4 | ext/tutorial-prologue-rebased-rebased |
| ext/parity-kael-clips | abacc4d18 | ext/kael-kit-integ (already in release/main) |
| ext/parity-snowglide-rebased | 0e6c6ee69 | ext/parity-snowglide-rebased-rebased |
| ext/perf-actors-1108 | 5649214b1 | ext/perf-actors-1108-rebased (already in release/main) |
| ext/perf-visibility-ranges | 5397d3341 | ext/perf-visibility-ranges-rebased |
| ext/prologue-canon | 60d89d26e | ext/prologue-canon-2 |
| ext/rank-parity-b | d911bdfb4 | ext/tutorial-prologue-rebased-rebased |
| ext/release-integ-0243-rebased | 517a0d109 | ext/release-integ-0245 (older release integration) |
| ext/release-integ-0243-rebased-rebased | f9a818e77 | ext/release-integ-0245 (older release integration) |
| ext/reset-cue | 1dd752d4d | ext/reset-cue-rebased |
| ext/sable-bola-instant | b31c26641 | ext/sable-bola-instant-rebased |
| ext/sfx-low-hp-filter | 53550c420 | ext/sfx-low-hp-filter-rebased |
| ext/sfx-mob-alert | 30e6a701c | ext/sfx-mob-alert-rebased |
| ext/sfx-move-weight | 366c29d3f | ext/step-sounds-unified-rebased |
| ext/sfx-step-surfaces | 92976bde2 | ext/step-sounds-unified-rebased |
| ext/sfx-utility-items | 82befd1f0 | ext/sfx-utility-items-rebased |
| ext/soul-link-integ | 3303c3b45 | ext/soul-link-integ-rebased |
| ext/soul-link-t3 | 37cb73338 | ext/soul-link-t3-rebased |
| ext/soul-link-t4 | 410724c68 | ext/soul-link-t4-rebased |
| ext/sparkle-dash-feel | 8876174f9 | ext/stuck-integ-b7a5717c |
| ext/spike-slam | f0b10ce78 | ext/spike-slam-rebased |
| ext/split-models | fc0129e7d | ext/split-models-rebased |
| ext/step-smooth | 0a96e4b98 | ext/step-smooth-rebased |
| ext/step-sounds-unified | 8dd5161cf | ext/step-sounds-unified-rebased |
| ext/stuck-integ-d4379965 | 88f56dfd4 | ext/stuck-integ-b7a5717c |
| ext/stuck-integ-e2561d23 | 7e87fcf67 | ext/tutorial-prologue-rebased-rebased |
| ext/summon-kill-credit | 810a5976a | ext/summon-kill-credit-rebased |
| ext/summon-killed-wisp | 25e86351f | ext/summon-killed-wisp-rebased |
| ext/supervive-impact | ac32fb465 | ext/feel-impact-tiers-rebased |
| ext/telegraph-audit-b | 20810cf25 | ext/stuck-integ-b7a5717c |
| ext/telegraph-audit-c | 498b60d09 | ext/stuck-integ-b7a5717c |
| ext/tender-gait | 4f9fd219f | ext/tender-gait-rebased |
| ext/train-moving-dummies | 6e50e4b23 | ext/train-moving-dummies-rebased |
| ext/training-area-1108 | 7ad4602ac | ext/train-moving-dummies-rebased |
| ext/training-grounds | 4a9c400d5 | ext/misc-ready-integ |
| ext/ttk-matrix | 5387b0051 | ext/ttk-matrix-rebased |
| ext/tut-context-tips | 332e40002 | ext/tut-context-tips-rebased |
| ext/tut-dodge-dummy | 0d8f29eb9 | ext/tut-dodge-dummy-rebased |
| ext/tut-first-heartspark | f68245865 | ext/tut-first-heartspark-rebased |
| ext/tut-first-race | 06ce66f82 | ext/tut-first-race-rebased |
| ext/tut-hunter-howto | d45c24c5d | ext/tut-hunter-howto-rebased |
| ext/tut-start-here | 5bf8865de | ext/tut-start-here-rebased |
| ext/tut-station-goals | 283401bb1 | ext/train-moving-dummies-rebased |
| ext/tut-station-goals-rebased | 0ea4d7506 | ext/train-moving-dummies-rebased |
| ext/tut-words-page | a12b16b94 | ext/tut-words-page-rebased |
| ext/tutorial-beats-5-6 | d844c0aed | ext/tutorial-beats-5-6-rebased-rebased |
| ext/tutorial-beats-5-6-rebased | 420d46d9e | ext/tutorial-beats-5-6-rebased-rebased |
| ext/tutorial-beats-7-8 | 590b36028 | ext/tutorial-beats-7-8-rebased |
| ext/tutorial-combat-v2 | 6e32b64eb | ext/tutorial-beats-5-6-rebased-rebased |
| ext/tutorial-dialogue | 53e56a9e0 | ext/misc-ready-integ |
| ext/tutorial-prologue | 4347c61b8 | ext/tutorial-prologue-rebased-rebased |
| ext/tutorial-prologue-rebased | 5c26e95a1 | ext/tutorial-prologue-rebased-rebased |
| ext/tutorials-cut | 37dc18d84 | ext/first-hints-check-rebased |
| ext/types-standard-names | 8b43b206f | ext/types-standard-names-rebased |
| ext/ui-text-chat | f22b4ca56 | ext/ui-text-chat-rebased |
| ext/ult-ranks | a48ec55a0 | ext/ult-ranks-rebased |
| ext/utilities-shops | e94360ee6 | ext/utilities-shops-rebased |
| ext/utility-parity-2 | bece7ed49 | ext/utility-parity-2-rebased |
| ext/vex-dash-parity | efbd6af96 | ext/stuck-integ-b7a5717c |
| ext/vfx-mage | 43524c781 | ext/stuck-integ-b7a5717c |
| ext/vfx-meeko-weight | 9c4ad7800 | ext/vfx-meeko-weight-rebased-rebased |
| ext/vfx-meeko-weight-rebased | 8d2b6858e | ext/vfx-meeko-weight-rebased-rebased |
| ext/vfx-origin-v2 | 53e5acdc4 | ext/vfx-origin-v2-rebased |
| ext/vfx-revive-read | a4cf0bdaa | ext/vfx-revive-read-rebased |
| ext/vfx-stolen-wisps | 1be7dce25 | ext/vfx-stolen-wisps-rebased |
| ext/vfx-telegraph-lead | 392e2685a | ext/vfx-telegraph-lead-rebased |
| ext/warden-bob-damp | ba31e5ef6 | ext/warden-bob-damp-rebased |
| ext/wisp-gpu-ab | aa375b024 | ext/wisp-gpu-ab-rebased |
| ext/wisp-guardian | a75873697 | ext/anim-guardian-stance |
| ext/wisp-guardian-rebased | acacda191 | ext/anim-guardian-stance |
| ext/wisp-merge-from-wisp | b390a22d8 | ext/wisp-merge-from-wisp-rebased |
| ext/wisp-passive-stack | e293ad7ce | ext/wisp-passive-stack-rebased |
| ext/wisp-summon | bbfbf5d9b | ext/anim-guardian-stance |
| ext/wisp-summon-leash | 3c8ebb0c7 | ext/wisp-summon-leash-rebased |
| ext/wisp-summon-net | 5d4c33fc6 | ext/wisp-summon-net-rebased |

