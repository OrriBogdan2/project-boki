# Performance plan, 11-11 (owner order: find the biggest issues, think past the obvious)

Base: ext/release-integ-0245. The 0.24.6 perf wave (docs/MERGE_PLAN_0246.md Wave 11: perf-train, perf-owner-hw,
visibility ranges, fight pools, occluders, merged drops) is not in it yet. Its numbers are in docs/PERF_OWNER_HW.md
(on ext/perf-owner-hw). This plan measures 0245 itself, ranks what is left after that wave, and fixes what the wave
does not touch.

Targets: 1080p60 held on the owner's Mac M5 and PC MRROBOTO (RTX 4070 SUPER): big fights, drop-in, garden, first
launch.

## How it was measured
Every number comes from the owner's machines as jobq GPU workers (`--only pc-MRROBOTO`, `--only mac-Naruto-Founder`).
Both run gl_compatibility, Medium (the bench's default), with a 1920x1080 window.
- **Bench**: `--perf-bench --bench-secs=40 --bench-farm=10 --bench-base=30 --bench-view=1920x1080 --bench-zone=all`.
  0245's bench has a 6-Hunter match with a fight at 8 s, then the farm, the base, the hub and the three built garden
  zones (9 Boki each). It has no warm-up, so its match "max" is a shader compile. The 30-Hunter real match
  (`--bench-real --bench-teams`) is only on the Wave 11 branches. Those numbers are quoted from PERF_OWNER_HW.md.
- **Drop-in**: `--hitch-check`: an 18-Hunter expedition as a player gets it (loading, ride, drop, landing by a pack).
- **Loading**: `--warm-twice --hitch-check --load-check`: a first launch from an empty user dir, then a second one.
- Jobs: base bench 20261111-105529-03164 (PC), -105559-18283 (Mac); load -105544-29978 (PC), -105612-22126 (Mac);
  hitch -110606-14587 (Mac), -110619-27156 (PC). The branch's jobs are in the fix table below.

## What 0245 costs (real GPU)

| | PC 4070 SUPER | Mac M5 |
|---|---|---|
| match, 6 Hunters + fight: avg / p99 | 25.9 / 51.5 ms | 25.7 / 95.7 ms |
| match: script / HUD / render CPU / GPU | 13.0 / 3.3 / 4.1 / 7.3 ms | 6.0 / 1.3 / 11.3 / (no timer) ms |
| match: draws / objects / frames over 50 ms | 838 / 2211 / 18 | 815 / 2054 / 28 |
| match step sections (ms/frame) | hunters 2.7, kins 2.2, mobs 1.5, separate 1.2, bots 1.1 | hunters 1.2, kins 0.9, mobs 0.7 |
| 20-Hunter real match, Wave 11 applied (PERF_OWNER_HW) | 27.7 / 60.7 ms, sim ~19 ms script | 22.8 / 42.7 ms, render CPU 10.5-11.5 |
| garden zones, 9 Boki: avg (render CPU) | 7.0 ms (2.2-2.4) | **21.3-22.0 ms (15.6-16.3)** |
| hub, 1 Boki / base, 6 Boki | 6.9 / 7.0 ms | 8.4 / 13.9 ms (render CPU 8.0) |
| loading: 1st / 2nd launch | - / 12.9 s (warm-up 1.3 s) | **38.0 s (warm-up 29.0) / 23.5 s (16.3)** |
| drop-in: ride / drop / land median | 25 / 26 / 36 ms | 23 / 32 / 33 ms |
| drop-in: worst frame, landing stall | 95 ms, 73 ms | 137 ms, 102 ms (hitch-check FAIL) |
| drop-in: shader compiles in play (cold) | 31 | 0 counted (GL over Metal reports none) |
| memory: textures / buffers | 410-438 MB / 100-190 MB | same textures / 66-151 MB |

Over budget in the garden: hub draws 592-597 (budget 200), Bramblebank 471-478 (budget 350), Cinderstep 369-399.

## Top 10, ranked by ms saved x how often a player feels it

1. **Mac: every skinned rig re-skins every frame, ~1.3 ms of render CPU a Boki rig** (GL over Metal: hiding the
   9 garden rigs takes a zone from 21 to 8.5 ms). Felt in the whole garden and in every fight. Boki rigs carry 4-5
   skinned surfaces (2 with face morphs). Warden rigs carry 5-11, so the same cost hits Hunters on screen.
   **Fixed here** (fixes 1-3).
2. **Mac loading: 23.5 s every launch, 38 s the first time**, 16-29 s of it the shader warm-up (108 stand-ins x
   4 light setups). The Mac's GL keeps no shader cache, so WarmStamp never trusts it. Felt on every launch.
   Not fixed: see the creative list (Metal renderer, shader consolidation) and the owner's open decision in
   PERF_OWNER_HW.md.
3. **PC fight: the sim is CPU-bound.** 13 ms of script for 6 Hunters, ~19 ms for 20 (Hunter.sim 6.6, bots 2.2,
   Boki 1.8, pickups 1.7). The GPU sits at 7-9 ms. Wave 11 (HunterPace, KinPace, the train) takes the first 3-7 ms.
   What is left is spread thin: the kits' per-step tick (~35%) and movement and collision (~25%).
4. **Shader compiles in play on a PC's first match: 31 in the drop-in**, each a 40-95 ms frame. The warm-up only
   sees what is in the tree at load. Missed: the landing FX (`ld_arm`, `ld_fx`, `ld_fx_glow`), the exit beams
   (`seat_beam`), pin trails (`PinFx/Trail`), care FX (`care_disc`, `care_glow`), `kin_aura`, `warden_halo`, a
   Warden's companion (`hero_toon` and `warden_mood_atlas` on Meeko's cloud, Pip's skinned `outline`), and the bush
   grass MultiMesh. Felt once per install (and again after every driver update).
5. **Fight node churn**: a fight creates ~2,100 MeshInstance3D (effects made per use). An effect's first use builds
   its meshes in the sim step (30-70 ms PC frames). Wave 11's fight pools take rings and beams. Kit effects are next.
6. **Drop-in spikes from script**: landing "visuals: hunters 34.2 ms" in one frame (PC), a drop step with
   "shots 19.8 ms" (PC). Both are once per drop. Not yet profiled to a function.
7. **HUD 3.3 ms a frame on the PC** (1.3 on the Mac): world labels ~1 ms every frame, the 20 Hz panels ~1.5 ms on
   average. Already culled and throttled (LabelCull, HudPanels). The next step is caching shaped text per plate.
8. **Loading slices over budget**: "Spawning" slices of 146-179 ms and "Building the map" of 117-150 ms (PC), and
   one 712 ms "Preparing graphics" frame. The spinner keeps drawing, so these read as stutter, not a freeze.
9. **Mac textures**: 101 imports use `compress/high_quality` (BPTC), which the M5's GL lacks. They are decompressed
   at load: more load time and 4x their VRAM. Textures total 410-438 MB in every part.
10. **Garden draws over budget** (hub 592 / 200, Bramblebank 471 / 350). Fixtures are unmerged (Stall ~44 meshes,
    Burrow 40, house 86, hub Deco 52), and each Boki rig is 4-5 draws plus its shadow. The PC doesn't feel it
    (7 ms). The Mac pays it in render CPU after fix 1 (8 ms left in a zone).

Smaller, seen on the way: 29 locked chests each carry two padlocks of 5 unmerged parts, and the floating
padlock's bob tween runs forever, far away or not. Chest lids are 2.6k triangles each (105 lids, 279k
triangles in the match's mesh list).

## Fixed on ext/perf-lead-1111 (before -> after on the Mac M5, same bench args)

| fix | what | Mac before -> after |
|---|---|---|
| 1 | A Boki's face writes a blend shape or the eyes' look only when it changes; a held expression lands exactly on its goal | (in the rows below) |
| 2 | BokiRig steps its own rig (`BokiRig.advance`: clip, then BokiDna's skeleton modifier). The modifier used to re-pose, and so re-skin, every rig every frame, stepped or not. On GL over Metal below Ultra a seen rig steps every 2nd frame with the held time | garden zones **21.3 / 21.3 / 22.0 -> 13.7 / 13.3 / 14.1 ms**, render CPU 15.6-16.3 -> 8.2-8.5 ms; base 13.9 -> 11.1 ms |
| 3 | `RigPace` (scripts/perf/rig_pace.gd): one rule for both kinds of rig. Warden rigs (`WardenGlb.Sync`) follow it too, except the one at the camera's focus (your own) and previews with no play camera | match render CPU **11.3 -> 8.7 ms** (2054 -> 2069 objects: a like-for-like scene), avg 25.7 -> 23.7 ms, p99 95.7 -> 91.4 ms; drop-in (2 runs each) ride/drop/land median **23/31-32/32-33 -> 20/26-27/28 ms**, drop's worst frame **136-145 -> 75-78 ms**; landing worst and landing stall unchanged within noise (93-137 vs 87-112 ms) |

- Off the Mac, and on Ultra, every rig still steps every frame. Fix 1 (fewer face writes) applies everywhere. The
  PC's garden is at 7 ms either way.
- Jobs: after fix 2, 20261111-110440-14415. After fix 3: bench 20261111-112358-31462, hitch 20261111-112410-16934,
  repeat pair (base, branch) 20261111-113430-26307 / -113444-26676.
- The match rows are noisy: the fight's scene changes between runs (683-876 draws). The fix-2-only run had a
  smaller scene (render CPU 7.4 ms on 1674 objects), so it is left out of the table.
- The trade: on the Mac below Ultra, a Boki and a rival's Warden animate at half the frame rate (30 Hz at 60 fps).
  Your own Warden doesn't. A kit effect that leaves a rival's hand reads the hand from the last posed frame, at most
  one frame old.
- Merging with Wave 11: ext/perf-owner-hw adds `AnimLod.Gate` to BokiRig (off screen every 4th frame, far every
  2nd) and to WardenGlb. Keep its gate and pass its dt through `pace.step` (RigPace's Metal rule then applies to
  near, on-screen rigs only). BokiRig's `player.advance(dt)` becomes `advance(dt)`, which steps the skeleton's
  modifiers too.

## Creative ideas: fit, expected gain, risk

| idea | fits us? | expected gain | risk |
|---|---|---|---|
| Rig update rate by driver cost (done: RigPace) and by distance and visibility (Wave 11 AnimLod) | yes: skinning is the Mac's render cost | Mac garden -8 ms, fight -3 ms+ | half-rate animation on the Mac's rivals and Boki |
| **One skinned surface per Boki** (build_boki.py joins the body parts onto one atlas; the face stays apart for its morphs) | yes: 4-5 skins and draws -> 2 | Mac ~0.5 ms a Boki, garden draws -27 for 9 Boki | art pipeline re-run per species |
| Same for Wardens (5-11 skinned surfaces -> 2-3 by atlas) | yes | Mac ~1 ms per on-screen Hunter, draws -5 each | look check per Warden, the outline pass per surface |
| **Shader consolidation**: fold the one-off VFX shaders (ld_fx, ld_fx_glow, ld_arm, care_disc, care_glow, seat_beam, kin_aura, warden_halo) into a few parametric FX shaders | yes: 108 stand-ins; each distinct shader is ~250 ms of Mac warm-up | Mac loading -5 to -10 s, fewer PC first-match compiles | VFX look regressions; needs side-by-side shots |
| **Mac on Godot's Metal renderer** (Mobile) instead of GL over Metal | yes for the Mac build | a pipeline cache between launches, GPU skinning without transform feedback | renderer switch: look and perf re-check on the Mac |
| Warm-up from a recorded list: write every shader key drawn in play to user:// and warm those on the next launch | yes | closes item 4 for good | stale keys after content changes (key on Net.VERSION) |
| Precompiled pipeline cache shipped with the build | no: GL drivers cache per driver and machine; nothing shippable | - | - |
| Impostors or billboards for far Hunters and Boki | weak: the camera is 27 m up and close, so a far Hunter is off screen; visibility ranges cover it | small | pop-in |
| MultiMesh for drops, gems and seeds | yes, after merged drops (Wave 11) | draws -50 to -150 in loot-heavy fights | pickup bob and glow per instance |
| Static fixture merge in the garden (World._merge_static pattern) | yes | hub draws 592 -> ~300 | outside refs to fixture parts |
| Bot and AI tick LOD (HunterPace, KinPace, SimLod) | done in Wave 11; next: far Hunters at 20 Hz (FAR_EVERY 3) | PC ~2 ms at 20 Hunters | coarser far movement |
| Server-auth sim budgets and snapshot size | not measured as a cost; the relay is not the bottleneck | - | Net shape changes |
| Dynamic resolution | no: neither machine is GPU-bound (PC GPU 7 ms, the Mac's frame is render CPU) | - | - |
| Job threading (WorkerThreadPool for bot pathing and vision) | later: GDScript state is shared | PC 2-4 ms | races |
| Physics layer pruning | low: `separate` is 1.2 ms, not physics | <0.5 ms | - |
| Worst-case caps on VFX (Wave 11 VfxBudget) | yes | bounds the 30-player fight | effects dropped at the cap |
| Render thread | no: crashes on Compatibility in 4.6 | - | - |

## Backlog (task-ready)
- [ ] perf: warm-up stand-ins for what spawns after load. Build one hidden instance each of the landing FX (LDFx
  `ld_arm`/`ld_fx`/`ld_fx_glow`), the exit seat beam, PinFx trails, CareLook disc and glow, kin_aura, warden_halo
  and Warden companions in WarmUp's stand-in list. The bush MultiMesh is drawn in the ground view. Check: PC cold
  `--hitch-check` shows 0 compiles in play (31 today).
- [ ] perf: Mac loading. Pick (a) shader consolidation for the one-off FX shaders or (b) the Metal renderer for the
  Mac build (owner decision, PERF_OWNER_HW "For the owner to decide" 2). Target: under 15 s on every launch
  (23.5 s today, 38 s on the first).
- [ ] perf: one skinned surface per Boki (tools/boki/build_boki.py: join the body parts on one atlas, the face apart).
  Measure the garden zone render CPU on the Mac (8.2-8.5 ms after this branch).
- [ ] perf: Warden surfaces per rig 5-11 -> 2-3 (bake_warden atlas). Measure the match render CPU on the Mac.
- [ ] perf: drop-in script spikes. Profile the landing frame (visuals: hunters 34 ms) and the drop's shots step
  (19.8 ms) on the PC (`--hitch-check` with --perf-log) and fix the first-use builds.
- [ ] perf: kit effects pooled (FxPool, after Wave 11 fight pools). Target: "created in the fight" from ~2,100
  MeshInstance3D to under 300.
- [ ] perf: loading slices. Split the Spawning and Building-the-map slices to at most 100 ms each (146-179 ms today).
- [ ] perf: Mac textures. `compress/high_quality=false` (S3TC, which the Mac's GL reads) on the 101 BPTC imports, or
  `import_etc2_astc` if the Mac moves to Metal. Measure load time and VRAM first, and check the PC look.
- [ ] perf: garden fixtures merged (Stall, Burrow, house, hub Deco) with material_override. Hub draws to ~300.
- [ ] perf: locked chests. Merge each padlock's 5 parts (Models.merge_static), and run the floating padlock's bob
  only while the chest is on screen.
- [ ] perf: HUD world labels. Cache each plate's shaped text and layout by its content (PC 1 ms a frame).
- [ ] perf: after Wave 11 lands, re-run the 30-Hunter real match (`--bench-real --bench-teams=10 --bench-squad=3
  --bench-warm`) on both machines with this branch merged, and update this table.
