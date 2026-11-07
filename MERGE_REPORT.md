# Merge candidate 20261107-1230 (built by cron, no Claude usage)

Headline: NEW-RED 4, WORSE 1, FIXED 0 of 161 checks; 17 merged, 17 skipped; release exports pass; GPU jobs not finished: 0

Base: origin/main 7907d9af. Health: HEALTH OK
Suite scope: affected checks only, 161 of 152 (smoke set always on; FULL_SUITE=1 for everything). Why: affected.why on the box.
- UNCOVERED scripts/core/feedback.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/air_limits.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/drop_launch.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/hunter_wisp.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/mantle_carry.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/wisp_look.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/ui/rate_card.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED shaders/wisp_core.gdshader (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED shaders/wisp_halo.gdshader (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED tools/air_limits_check.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)

## Suite vs main: NEW-RED 4, WORSE 1, FIXED 0 of 161 checks
- NEW-RED --boki-system-check main=0/0 cand=1/2
- NEW-RED --cinder-art-check main=0/0 cand=124/2
- NEW-RED --hatch-check main=0/0 cand=0/7
- NEW-RED --hudref-check main=0/0 cand=1/2
- WORSE --teammate-check main=1/1 cand=1/2

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
- merged   ext/vfx-cinder 7ed30d5b
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
- merged   ext/downed-wisp 3da5e9ac
- merged   ext/ravel-v2-model fc36532f
- merged*  ext/phys-163-drop bb211b35 (registry/credits/generated auto-resolved)
- merged   ext/kit-parity-audit f23bb03e
- merged   ext/boki-50-integ caa52d73

Exclusions: ~/bin/merge-exclude.txt on the hetzner box.

## Real-GPU performance (Mac GPU worker, main vs candidate)

| hook | main rc / FAIL / secs | candidate rc / FAIL / secs |
|---|---|---|
| `--hitch-check` | 1 / 8 / 53 (pc-MRROBOTO) | 1 / 7 / 63 (pc-MRROBOTO) |
| `--load-check` | 1 / 1 / 24 (pc-MRROBOTO) | 1 / 1 / 83 (mac-Naruto-Founder) |
| `--perf-bench` | 0 / 0 / 295 (pc-MRROBOTO) | 0 / 0 / 288 (pc-MRROBOTO) |
| `--title-check` | 124 / 8 / 1501 (pc-MRROBOTO) | 124 / 8 / 1501 (pc-MRROBOTO) |

Frame-time lines from the logs (lines that mention ms or fps; first 12 per run):

**`--hitch-check` main** (job 20261107-144247-25415)
```
Quality: auto picked low (load benchmark 39.1 ms a frame)
HITCH loading screen 16018 ms over 278 frames, worst 447 ms, 283 shader compiles; build steps: build.warm_up 6678, build.hunters 3035, world.terrain 671, build.generate 545, world.walls 423, build.spa
HITCH phase first      16 frames  median     23 ms  worst     65 ms  shader compiles 4
HITCH phase planning   25 frames  median     18 ms  worst     47 ms  shader compiles 0
HITCH phase ride      103 frames  median     23 ms  worst    204 ms  shader compiles 5
HITCH phase drop      124 frames  median     32 ms  worst     98 ms  shader compiles 2
HITCH phase land      180 frames  median     38 ms  worst    105 ms  shader compiles 1
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=11.35): 68 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 65 ms
HITCH       204 ms  ride     t= 4.92  sim 28.9 (+118.2 x6)  vis 2.9  other 5.3  render 33.2  rest 15.1  draws 2467  shader compiles 2  sim sections: bots 18.5, hunters 7.1, mobs 1.1, interact 0.6
HITCH       168 ms  ride     t= 4.72  sim 5.1 (+145.3 x6)  vis 2.0  other 3.6  render 5.6  rest 6.0  draws 2372  shader compiles 0
HITCH       156 ms  ride     t= 4.82  sim 23.7 (+112.4 x6)  vis 2.3  other 3.9  render 5.8  rest 7.7  draws 2442  shader compiles 0  sim sections: bots 20.4, mobs 1.1, interact 0.8, kins 0.4
```

**`--hitch-check` cand** (job 20261107-144247-09293)
```
Quality: auto picked low (load benchmark 35.7 ms a frame)
HITCH loading screen 16783 ms over 273 frames, worst 468 ms, 283 shader compiles; build steps: build.warm_up 6830, build.hunters 3592, world.terrain 659, build.generate 534, build.spawns 510, world.wa
HITCH phase first      16 frames  median     24 ms  worst     61 ms  shader compiles 4
HITCH phase planning   25 frames  median     23 ms  worst     58 ms  shader compiles 0
HITCH phase ride      103 frames  median     27 ms  worst    158 ms  shader compiles 4
HITCH phase drop      255 frames  median     29 ms  worst    121 ms  shader compiles 3
HITCH phase land      180 frames  median     37 ms  worst     81 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=17.98): 66 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 61 ms
HITCH       158 ms  ride     t= 5.22  sim 24.3 (+82.9 x6)  vis 1.9  other 4.1  render 33.2  rest 11.2  draws 2679  shader compiles 2  sim sections: bots 12.8, hunters 8.4, mobs 1.0, interact 0.5
HITCH       136 ms  ride     t= 4.72  sim 5.4 (+104.6 x6)  vis 2.1  other 4.0  render 7.7  rest 12.5  draws 2603  shader compiles 0
HITCH       134 ms  ride     t= 5.02  sim 20.2 (+88.0 x6)  vis 1.8  other 4.4  render 5.8  rest 13.4  draws 2583  shader compiles 0  sim sections: bots 16.1, mobs 1.1, hunters 0.9, interact 0.6
```

**`--load-check` main** (job 20261107-144247-13580)
```
Quality: auto picked low (load benchmark 36.3 ms a frame)
LOAD total 15952 ms over 280 frames; longest frame 447 ms (444 ms outside drawing); 16 frames over 100 ms
LOAD       447     444       2    333     0  c0   Spawning                 [slice 439 ms]
LOAD       423     421       2    333     0  c0   Spawning                 [slice 417 ms]
LOAD       324     323       1     67     0  c0   Spawning                 [slice 320 ms]
LOAD       267     265       2     67     0  c0   Spawning                 [slice 262 ms]
LOAD       231     229       1    333     0  c0   Spawning                 [slice 226 ms]
LOAD       226     225       2     67     0  c0   Spawning                 [slice 222 ms]
LOAD       219     217       2    333     0  c0   Spawning                 [slice 213 ms]
LOAD       204     202       2    205     0  c0   Spawning                 [slice 196 ms]
LOAD       197     195       2    453     0  c0   Spawning                 [slice 190 ms]
LOAD       183     181       2    211     0  c0   Spawning                 [slice 172 ms]
```

**`--load-check` cand** (job 20261107-144247-30343)
```
Quality: auto picked low (load benchmark 62.1 ms a frame)
LOAD total 20031 ms over 317 frames; longest frame 568 ms (524 ms outside drawing); 43 frames over 100 ms
LOAD       568     524      44     59     0  c0   Building the map         [slice 3625 ms]  [slice 50 ms]
LOAD       264     260       3     85     0  c0   Spawning                 [slice 259 ms]
LOAD       262     258       4    273     0  c0   Spawning                 [slice 256 ms]
LOAD       247     239       8     85     0  c0   Spawning                 [slice 237 ms]
LOAD       238     235       3    273     0  c0   Spawning                 [slice 232 ms]
```

**`--perf-bench` main** (job 20261107-144247-12906)
```
BENCH match: 1849 frames, wall avg 23.8 ms, p99 46.0 ms (1% low 10.8 fps)
BENCH match cpu: match script avg 12.20 ms p99 26.20 ms, process 45.40 ms, hud 3.30 ms, render cpu 3.86 ms
BENCH farm: 1200 frames, wall avg 8.4 ms, p99 10.7 ms (1% low 6.4 fps)
BENCH farm cpu: match script avg 98.48 ms p99 1303.30 ms, process 98.48 ms, hud 1.23 ms, render cpu 2.79 ms
```

**`--perf-bench` cand** (job 20261107-144247-03869)
```
BENCH hitch t=57.27 164 ms (script 13.7), new nodes: { "Node3D:MergeLook": 1, "MeshInstance3D:Aura": 1, "MeshInstance3D:@MeshInstance3D": 15, "CPUParticles3D:@CPUParticles3D": 1, "Node3D:MergeParts": 
BENCH match: 1859 frames, wall avg 26.0 ms, p99 61.9 ms (1% low 8.2 fps)
BENCH match cpu: match script avg 13.45 ms p99 39.14 ms, process 52.55 ms, hud 3.53 ms, render cpu 4.16 ms
BENCH farm: 1200 frames, wall avg 7.3 ms, p99 9.4 ms (1% low 23.9 fps)
BENCH farm cpu: match script avg 27.52 ms p99 127.78 ms, process 27.52 ms, hud 2.16 ms, render cpu 3.03 ms
```

**`--title-check` main** (job 20261107-144247-15979)
```
TITLE ok   [high] frame budget: 7.20 ms average, 7.06 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 7.25 ms average, 7.12 ms p95 (budget 12 ms)
```

**`--title-check` cand** (job 20261107-144247-26724)
```
TITLE ok   [high] frame budget: 7.44 ms average, 7.03 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 7.25 ms average, 7.06 ms p95 (budget 12 ms)
```

## Release dry-run (Windows and macOS exports, release templates 4.6.2.stable)

| project | preset | result | size / first ERROR |
|---|---|---|---|
| game | Windows | pass | 432M |
| game | macOS | pass | 287M |
| launcher | Windows | pass | 101M |
| launcher | macOS | pass | 63M |

All exports passed.
