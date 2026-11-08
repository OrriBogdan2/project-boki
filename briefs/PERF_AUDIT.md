# Expedition performance audit (perf-expedition-1108, 2026-11-08)

Sources: real-GPU `--perf-bench` on mac-Naruto-Founder (M5) and rp1-0 / pc-MRROBOTO via jobq (a2's fps-* runs
and pexp-* runs), plus a local software profile with per-section step timers. 30 hunters, Hollow Crown.
Bench used to render at 640x360, which hid fill cost; it now takes `--bench-view=WxH` (pexp runs: 2560x1440)
and logs `gpu_ms`, window size and 3D scale.

## Top 10 costs (biggest first)

| # | Cost | Evidence | Owner / status |
|---|------|----------|----------------|
| 1 | Native-res 3D fill on retina/4K windows (hidpi on, MSAA, SSAO, volfog all at full pixels) | M5 at 40 ms in the real game vs ~22 ms script+render cpu in a 640x360 bench | **fixed here**: per-preset render-height cap `px` + FSR (Very Low 540, Low 720, Medium 1080, High/Ultra native) |
| 2 | Match script: hunter/bot/kin brains every frame | 17-27 ms on M5, 31-54 ms on rp1-0 at 30 hunters; hunters 6.3, bots 4.6, kins 4.1 ms locally | a2 (expedition-fps-1108): anim_lod, bot, kin, kin_follow, kin_tactics |
| 3 | Mobs step every frame even far from everyone | mobs 3.8 ms locally | not ported: 20 Hz far-camp step exists on ext/map-2x-flat2 (7539d2204, mob.gd); land that branch or cherry-pick it |
| 4 | Sun shadow atlas 4096 on every preset | Low/Medium spent full shadow fill for a 2-split low preset | **fixed here**: `atlas` knob (1024 / 2048 / 2048 / 4096 / 4096) |
| 5 | 15-17 omni/spot lights live with no distance fade | `lights 15-17` in match scene on all runs | **fixed here**: `light_m` fade (40 / 50 / 70 m on VL / Low / Med; High keeps each lamp's own) |
| 6 | 160-180 emitting particle systems | `emitters` 161-183 in match scene; 45 in a local medium run | open: per-preset emitter budget (fx knob only scales amount now); new bench `_emitters()` lists the top parents |
| 7 | Draw calls 850-1000, objects 1900-2450 | match scene line | partly done earlier (MultiMesh scatter, LODs, ShadowPolicy); chests (lid/lock/key as separate meshes) and `Match/@Node3D` props are the heaviest leftovers |
| 8 | No really light preset for integrated GPUs | Low still had shadows, SSAO-class effects and full-res on 1440p laptops | **fixed here**: Very Low (no shadows/SSAO/glow/fog/shafts/clouds, draw 0.45, grass 0.15, 540p cap) |
| 9 | Auto-detect picked heavy presets on weak GPUs; one slow benchmark only dropped one step | quality_found sticky from earlier versions | **fixed here**: integrated/Intel -> Low, software -> Very Low, Apple -> Medium; 45 ms bench drops two steps; video_v 4 migration re-measures auto |
| 10 | p99 spikes 95-200 ms (shader compiles, spawns) | p99 column on every run | claimed by the loading/hitches job (shaders), not touched here |

## Numbers
Before/after table: see READY entry for perf-expedition-1108 in EXT_TO_MAIN.md.

## Before/after (pc-MRROBOTO, RTX 4070 SUPER, gl_compatibility, 2560x1440, 60 s, Hollow Crown)
| preset | 3d scale before -> after | GPU ms before -> after | wall avg ms | p99 ms |
|---|---|---|---|---|
| medium | 1.00 -> 0.75 | 14.70 -> 11.56 (-21%) | 44.1 -> 44.6 | 82.2 -> 85.5 |
| low | 0.80 -> 0.50 | 10.76 -> 7.77 (-28%) | 45.2 -> 42.1 | 94.3 -> 81.5 |
| very low (new) | - -> 0.38 | - -> 6.25 | 42.6 | 93.5 |
Wall time here is script-bound (match script ~23-25 ms, cost #2), so GPU savings show as headroom, not fps,
until a2's script work lands. Mac (M5) numbers are missing: mac-Naruto-Founder fails every job since 21:44
with rc 126 (`godot-nf`: GodotBG.app missing under the temp HOME). Rerun the pexp-* labels once it is fixed.
