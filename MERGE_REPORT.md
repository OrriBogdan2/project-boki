# Merge candidate 20261108-0030 (built by cron, no Claude usage)

Headline: NEW-RED 2, WORSE 4, FIXED 0 of 162 checks; 31 merged, 24 skipped; release exports pass; GPU jobs not finished: 0

Base: origin/main 7907d9af. Health: HEALTH FAIL: style ratchet (docs/STYLE.md) (god files: move new logic into a focused module, see AGENTS.md; style: see docs/STYLE.md)
Suite scope: full (FULL_SUITE=1 or check-map unavailable)
Capacity plan: alive=pc-MRROBOTO flags=162 cached=0 to_run=162 unknown=26 server_min=26 with_workers_min=13 decision=RUN

## Suite vs main: NEW-RED 2, WORSE 4, FIXED 0 of 162 checks
- NEW-RED --cinder-art-check main=0/0 cand=1/1
- NEW-RED --clip-check main=0/0 cand=1/1
- WORSE --dash-frames-check main=1/1 cand=1/2
- WORSE --farm-tutorial-check main=1/6 cand=1/7
- WORSE --warden-model-check main=0/1 cand=0/18
- WORSE --wisp-check main=124/0 cand=0/1

## Branches
- SKIPPED  ext/boki-cindle 7ded8605 conflicts: art/kin/cindle/cindle.glb art/kin/cindle/cindle_cindle_atlas.webp art/kin/cindle/cindle_cindle_atlas.webp.import
- SKIPPED  ext/boki-rimeshrew 5763ca81 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-zephyrak e29baa56 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-pebbit 136f8511 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-cairnback 8cae62dc conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-wisplet 38ac73e9 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-gloamshell e7b1885e conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-selenfin ba573892 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-zapple 00cd0153 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki-hivara 1cdebed5 conflicts: docs/art/kin/RIGGED_BOKI.md scripts/match/boki_rig.gd tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/kit-kael-113 ae7f8b6b conflicts: scripts/arch/kits/juggernaut_chain.gd scripts/arch/kits/juggernaut_drop.gd scripts/arch/kits/juggernaut_kit.gd scripts/arch/kits/juggernaut_ult.gd scripts/match/hunter.gd tools/combo51_shots.gd
- merged   ext/vfx-cinder 3b549347
- merged   ext/vfx-claire 6699df02
- SKIPPED  ext/vfx-pip 93b5e23f conflicts: scripts/arch/kits/care_look.gd
- already  ext/vfx-core
- merged   ext/kit-kael-113b 03668028
- SKIPPED  ext/art1-kael-2 fd33d204 conflicts: tools/combo51_shots.gd
- merged   ext/fix-kael-sword-131b 77368bca
- merged   ext/boki-species-integ 9c8a6e20
- already  ext/vfx-core-rebased
- merged   ext/phys-185-boki-dash eae133e9
- already  ext/vfx-claire-rebased
- SKIPPED  ext/vfx-pip-rebased 93b5e23f conflicts: scripts/arch/kits/care_look.gd
- merged   ext/matchmaker-feedback 89d0a11a
- merged   ext/ui-rate-189 364b593d
- merged   ext/phys-integrated ceab95f4
- merged*  ext/phys-151-layout fca0115f (registry/credits/generated auto-resolved)
- merged   ext/vex-v2-model 24e4f2d6
- SKIPPED  ext/ryzz-v2-model 6355dee7 conflicts: docs/art/wardens/PIPELINE.md tools/warden_model_check.gd
- SKIPPED  ext/grimble-v2-model 54df2f18 conflicts: docs/art/wardens/PIPELINE.md scripts/heroes/warden_glb.gd
- merged   ext/phys-185b-mantle cc3212ae
- SKIPPED  ext/text-relic-renames d6ec7954 conflicts: tools/combo51_shots.gd
- merged   ext/downed-wisp bdca844e
- merged   ext/ravel-v2-model 91c6905b
- merged*  ext/phys-163-drop bb211b35 (registry/credits/generated auto-resolved)
- merged   ext/kit-parity-audit f23bb03e
- merged   ext/boki-50-integ 7751f51c
- merged   ext/camera-depth 2af88a10
- merged   ext/phys-150-botnav e44f34b2
- SKIPPED  ext/cinder-flame-queen c3f4f172 conflicts: scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/ashwick_kit.gd tools/cinder_art_check.gd tools/combo51_shots.gd
- SKIPPED  ext/sable-v2-model 3e1816a6 conflicts: docs/art/wardens/PIPELINE.md
- merged*  ext/text-relic-renames-rebased e9f0f984 (registry/credits/generated auto-resolved)
- SKIPPED  ext/s7-mask-hob-83-89-fix 6b433e54 conflicts: docs/decisions/0016-the-unmasked.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd tools/class_unlock_check.gd tools/empty_shots.gd
- SKIPPED  ext/parity-dash-scale 2f24ae36 conflicts: content/rules/dash_feel.json scripts/arch/kits/ashwick_kit.gd scripts/arch/kits/dredge_kit.gd
- SKIPPED  ext/parity-move-feel 64e6c681 conflicts: docs/MOVEMENT_FEEL.md scripts/match/hunter.gd tools/move_feel_check.gd
- merged   ext/parity-lace 4aa011a4
- SKIPPED  ext/parity-dashlmb 4e788af6 conflicts: docs/heroes/dash_interactions.md
- merged   ext/lace-ult-arrows dfaeae38
- merged   ext/sparkle-orb-pickup 3f03c9dc
- merged*  ext/parity-snowglide ea140cf5 (registry/credits/generated auto-resolved)
- merged   ext/parity-mossy-cadence 9c336682
- merged   ext/parity-idle-audit 8b2217e8
- merged   ext/parity-grimble-airdash 0a5b33f4
- merged   ext/parity-ostra-bomb 5b9a528d
- SKIPPED  ext/cinder-v2-palms 766b44cd conflicts: docs/art/wardens/PIPELINE.md scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/ashwick_kit.gd tools/cinder_art_check.gd
- merged   ext/prematch-lobby 861e4654
- merged   ext/gameplay-media e6881d69
- merged*  ext/hero-heights 4538174a (registry/credits/generated auto-resolved)

Exclusions: ~/bin/merge-exclude.txt on the hetzner box.

## Real-GPU performance (Mac GPU worker, main vs candidate)

| hook | main rc / FAIL / secs | candidate rc / FAIL / secs |
|---|---|---|
| `--hitch-check` | 1 / 7 / 319 (pc-MRROBOTO) | 1 / 3 / 52 (mac-Naruto-Founder) |
| `--load-check` | 1 / 1 / 31 (mac-Naruto-Founder) | 1 / 1 / 23 (mac-Naruto-Founder) |
| `--perf-bench` | 0 / 0 / 49 (mac-Naruto-Founder) | 0 / 0 / 53 (mac-Naruto-Founder) |
| `--title-check` | 0 / 8 / 6 (mac-Naruto-Founder) | 0 / 8 / 17 (mac-Naruto-Founder) |

Frame-time lines from the logs (lines that mention ms or fps; first 12 per run):

**`--hitch-check` main** (job 20261108-023436-02716)
```
Quality: auto picked low (load benchmark 40.3 ms a frame)
HITCH loading screen 16259 ms over 263 frames, worst 481 ms, 283 shader compiles; build steps: build.warm_up 6372, build.hunters 3394, world.terrain 678, build.generate 592, build.spawns 425, world.wa
HITCH phase first      16 frames  median     23 ms  worst     73 ms  shader compiles 4
HITCH phase planning   25 frames  median     18 ms  worst     48 ms  shader compiles 0
HITCH phase ride      103 frames  median     23 ms  worst    191 ms  shader compiles 5
HITCH phase drop      124 frames  median     34 ms  worst     97 ms  shader compiles 2
HITCH phase land      180 frames  median     38 ms  worst     82 ms  shader compiles 1
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=11.35): 67 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 73 ms
HITCH       191 ms  ride     t= 4.92  sim 29.0 (+108.4 x6)  vis 2.0  other 4.1  render 34.4  rest 13.1  draws 2463  shader compiles 2  sim sections: bots 18.9, hunters 7.1, mobs 1.0, interact 0.6
HITCH       155 ms  ride     t= 4.82  sim 22.8 (+111.7 x6)  vis 2.9  other 4.0  render 6.1  rest 8.1  draws 2438  shader compiles 0  sim sections: bots 19.6, mobs 1.1, interact 0.7, kins 0.5
HITCH       148 ms  ride     t= 4.72  sim 5.1 (+124.5 x6)  vis 1.8  other 3.8  render 6.9  rest 6.0  draws 2368  shader compiles 0
```

**`--hitch-check` cand** (job 20261108-023436-07971)
```
Quality: auto picked low (load benchmark 53.4 ms a frame)
HITCH loading screen 18638 ms over 302 frames, worst 577 ms, 0 shader compiles; build steps: build.warm_up 11863, build.hunters 1943, world.terrain 338, build.generate 272, build.spawns 238, world.wal
HITCH phase first      16 frames  median     19 ms  worst    242 ms  shader compiles 0
HITCH phase planning   25 frames  median     17 ms  worst     26 ms  shader compiles 0
HITCH phase ride      103 frames  median     20 ms  worst    215 ms  shader compiles 0
HITCH phase drop      255 frames  median     39 ms  worst     96 ms  shader compiles 0
HITCH phase land      180 frames  median     33 ms  worst     89 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=17.98): 44 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 242 ms
HITCH       242 ms  first    t= 0.00  sim 0.1 (+0.0 x1)  vis 5.4  other 1.8  render 227.0  rest 7.5  draws 3128  shader compiles 0
HITCH       215 ms  ride     t= 6.32  sim 6.7 (+32.9 x6)  vis 1.1  other 2.0  render 164.5  rest 7.6  draws 2876  shader compiles 0
HITCH       171 ms  ride     t= 4.52  sim 5.2 (+10.0 x6)  vis 0.9  other 1.8  render 150.2  rest 2.6  draws 2564  shader compiles 0
```

**`--load-check` main** (job 20261108-023436-20005)
```
Quality: auto picked low (load benchmark 57.1 ms a frame)
LOAD total 17393 ms over 293 frames; longest frame 458 ms (264 ms outside drawing); 31 frames over 100 ms
LOAD       268     264       4    258     0  c0   Spawning                 [slice 262 ms]
LOAD       249     246       3     88     0  c0   Spawning                 [slice 244 ms]
LOAD       229     226       3    258     0  c0   Spawning                 [slice 223 ms]
```

**`--load-check` cand** (job 20261108-023436-09252)
```
Quality: auto picked low (load benchmark 54.2 ms a frame)
LOAD total 17712 ms over 301 frames; longest frame 460 ms (265 ms outside drawing); 36 frames over 100 ms
LOAD       268     265       3     87     0  c0   Spawning                 [slice 263 ms]
LOAD       257     254       3    278     0  c0   Spawning                 [slice 251 ms]
LOAD       253     244       9     87     0  c0   Spawning                 [slice 242 ms]
LOAD       229     226       3    278     0  c0   Spawning                 [slice 222 ms]
```

**`--perf-bench` main** (job 20261108-023436-28463)
```
BENCH hitch t=8.73 149 ms (script 5.6), new nodes: {  }
BENCH hitch t=9.13 121 ms (script 5.7), new nodes: {  }
BENCH match: 1855 frames, wall avg 18.8 ms, p99 69.2 ms (1% low 6.3 fps)
BENCH match cpu: match script avg 6.49 ms p99 11.43 ms, process 42.84 ms, hud 1.07 ms, render cpu 6.57 ms
BENCH farm: 1200 frames, wall avg 5.0 ms, p99 8.7 ms (1% low 10.9 fps)
BENCH farm cpu: match script avg 126.36 ms p99 492.06 ms, process 126.36 ms, hud 0.45 ms, render cpu 3.04 ms
```

**`--perf-bench` cand** (job 20261108-023436-31663)
```
BENCH hitch t=9.27 170 ms (script 13.6), new nodes: { "Node3D:DJFx": 1, "Node3D:@Node3D": 2, "Node3D:Head": 2, "MeshInstance3D:@MeshInstance3D": 14, "MeshInstance3D:Trail": 2 }
BENCH hitch t=9.77 381 ms (script 17.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 1 }
BENCH hitch t=11.93 145 ms (script 6.1), new nodes: {  }
BENCH hitch t=18.73 155 ms (script 5.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 2 }
BENCH match: 1824 frames, wall avg 21.0 ms, p99 79.1 ms (1% low 4.6 fps)
BENCH match cpu: match script avg 6.06 ms p99 14.02 ms, process 60.63 ms, hud 1.07 ms, render cpu 10.32 ms
BENCH farm: 1200 frames, wall avg 5.0 ms, p99 8.6 ms (1% low 10.8 fps)
BENCH farm cpu: match script avg 99.29 ms p99 501.28 ms, process 99.29 ms, hud 2.12 ms, render cpu 3.10 ms
```

**`--title-check` main** (job 20261108-023436-29280)
```
TITLE ok   [high] frame budget: 1.32 ms average, 1.85 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 1.21 ms average, 1.29 ms p95 (budget 12 ms)
```

**`--title-check` cand** (job 20261108-023436-01520)
```
TITLE ok   [high] frame budget: 1.32 ms average, 1.84 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 1.21 ms average, 1.27 ms p95 (budget 12 ms)
```

## Release dry-run (Windows and macOS exports, release templates 4.6.2.stable)

| project | preset | result | size / first ERROR |
|---|---|---|---|
| game | Windows | pass | 433M |
| game | macOS | pass | 287M |
| launcher | Windows | pass | 101M |
| launcher | macOS | pass | 63M |

All exports passed.
