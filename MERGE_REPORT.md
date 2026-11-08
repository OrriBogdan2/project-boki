# Merge candidate 20261108-0830 (built by cron, no Claude usage)

Headline: NEW-RED 17, WORSE 6, FIXED 0 of 164 checks; 61 merged, 50 skipped; release exports pass; GPU jobs not finished: 0

Base: origin/main 7907d9af. Health: HEALTH FAIL: style ratchet (docs/STYLE.md) (god files: move new logic into a focused module, see AGENTS.md; style: see docs/STYLE.md)
Suite scope: affected checks only, 164 of 152 (smoke set always on; FULL_SUITE=1 for everything). Why: affected.why on the box.
Capacity plan: alive=pc-MRROBOTO flags=164 cached=0 to_run=164 unknown=28 server_min=27 with_workers_min=14 decision=RUN
- UNCOVERED scripts/core/background_work.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/feedback.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/voice_chat.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/home/hob_model.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/home/hob_offer.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/home/hob_talk.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/depth_cues.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/glide_dive.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/grounds.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/hot_zone.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)

## Suite vs main: NEW-RED 17, WORSE 6, FIXED 0 of 164 checks
- NEW-RED --archer-combo-check main=0/0 cand=1/2
- NEW-RED --archetype-check main=0/0 cand=1/2
- NEW-RED --box-revive-check main=0/0 cand=0/3
- NEW-RED --cinder-art-check main=0/0 cand=1/1
- NEW-RED --clip-check main=0/0 cand=1/2
- NEW-RED --dancer-combo-check main=0/0 cand=0/1
- NEW-RED --dash-frames-check main=0/0 cand=1/5
- WORSE --farm-start-check main=124/29 cand=124/31
- WORSE --grounds-check main=124/0 cand=0/1
- NEW-RED --gunslinger-combo-check main=0/0 cand=1/2
- NEW-RED --hatch-check main=0/0 cand=0/7
- NEW-RED --hero-combo-check main=0/0 cand=1/2
- WORSE --hitch-check main=1/2 cand=1/4
- WORSE --hob-check main=124/0 cand=1/1
- NEW-RED --hudref-check main=0/0 cand=1/2
- NEW-RED --keys-check main=0/0 cand=0/1
- WORSE --mantle-look-check main=0/2 cand=0/3
- NEW-RED --move-feel-check main=0/0 cand=0/2
- WORSE --title-check main=0/8 cand=0/10
- NEW-RED --truce-check main=0/0 cand=0/5
- NEW-RED --wall-size-check main=0/0 cand=0/1
- NEW-RED --warden-glb-check main=0/0 cand=0/1
- NEW-RED --warden-model-check main=0/0 cand=0/17

## Branches
- merged   ext/kit-kael-113 6e18b8be
- merged   ext/vfx-cinder 3b549347
- merged   ext/vfx-claire 6699df02
- SKIPPED  ext/vfx-pip 93b5e23f conflicts: scripts/arch/kits/care_look.gd
- already  ext/vfx-core
- SKIPPED  ext/kit-kael-113b 03668028 conflicts: tools/combo51_shots.gd
- SKIPPED  ext/art1-kael-2 fd33d204 conflicts: tools/combo51_shots.gd
- merged   ext/fix-kael-sword-131b 77368bca
- merged   ext/boki-species-integ 9c8a6e20
- already  ext/vfx-core-rebased
- merged   ext/phys-185-boki-dash eae133e9
- already  ext/vfx-claire-rebased
- SKIPPED  ext/vfx-pip-rebased 93b5e23f conflicts: scripts/arch/kits/care_look.gd
- merged   ext/matchmaker-feedback 89d0a11a
- merged   ext/ui-rate-189 364b593d
- SKIPPED  ext/phys-integrated ceab95f4 conflicts: scripts/match/hunter.gd tools/combo51_shots.gd
- merged*  ext/phys-151-layout fca0115f (registry/credits/generated auto-resolved)
- merged   ext/vex-v2-model 24e4f2d6
- SKIPPED  ext/kael-v2-model ca52dc64 conflicts: content/rules/warden_look.json docs/art/wardens/PIPELINE.md tools/art1/vex_paint.py
- SKIPPED  ext/ryzz-v2-model 6355dee7 conflicts: docs/art/wardens/PIPELINE.md tools/warden_model_check.gd
- SKIPPED  ext/grimble-v2-model 54df2f18 conflicts: docs/art/wardens/PIPELINE.md scripts/heroes/warden_glb.gd
- SKIPPED  ext/phys-185b-mantle cc3212ae conflicts: scripts/match/hunter.gd tools/combo51_shots.gd
- SKIPPED  ext/text-relic-renames d6ec7954 conflicts: tools/combo51_shots.gd
- merged   ext/downed-wisp bdca844e
- merged   ext/ravel-v2-model 91c6905b
- SKIPPED  ext/phys-163-drop bb211b35 conflicts: scripts/match/hunter.gd tools/combo51_shots.gd
- merged   ext/kit-parity-audit f23bb03e
- merged   ext/boki-50-integ 7751f51c
- merged   ext/camera-depth 2af88a10
- merged   ext/phys-150-botnav e44f34b2
- SKIPPED  ext/cinder-flame-queen c3f4f172 conflicts: scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/ashwick_kit.gd tools/cinder_art_check.gd tools/combo51_shots.gd
- SKIPPED  ext/sable-v2-model 3e1816a6 conflicts: docs/art/wardens/PIPELINE.md
- SKIPPED  ext/text-relic-renames-rebased e9f0f984 conflicts: tools/combo51_shots.gd
- merged*  ext/s7-mask-hob-83-89-fix 6b433e54 (registry/credits/generated auto-resolved)
- SKIPPED  ext/parity-dash-scale 2f24ae36 conflicts: scripts/arch/kits/ashwick_kit.gd scripts/arch/kits/dredge_kit.gd
- SKIPPED  ext/parity-move-feel 64e6c681 conflicts: docs/MOVEMENT_FEEL.md scripts/match/hunter.gd tools/move_feel_check.gd
- merged   ext/parity-lace 4aa011a4
- merged   ext/parity-dashlmb 4e788af6
- merged   ext/lace-ult-arrows dfaeae38
- merged   ext/sparkle-orb-pickup 3f03c9dc
- SKIPPED  ext/parity-snowglide ea140cf5 conflicts: docs/decisions/0016-the-unmasked.md docs/heroes/dash_interactions.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd
- merged   ext/parity-mossy-cadence 9c336682
- merged   ext/parity-idle-audit 8b2217e8
- merged   ext/parity-grimble-airdash 0a5b33f4
- merged   ext/parity-ostra-bomb 5b9a528d
- SKIPPED  ext/cinder-v2-palms 766b44cd conflicts: docs/art/wardens/PIPELINE.md scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/ashwick_kit.gd tools/cinder_art_check.gd
- merged   ext/prematch-lobby 861e4654
- merged   ext/gameplay-media e6881d69
- merged*  ext/hero-heights 4538174a (registry/credits/generated auto-resolved)
- merged   ext/props-vex 8e7bcab6
- SKIPPED  ext/props-claire c34a7803 conflicts: docs/art/wardens/PIPELINE.md
- SKIPPED  ext/props-sable 628195e5 conflicts: docs/art/wardens/PIPELINE.md
- SKIPPED  ext/tutorial-dialogue 53e56a9e conflicts: content/rules/farm_builder.json scripts/home/farm_hob.gd scripts/home/home.gd tools/farm_tutorial_check.gd
- merged   ext/relic-art-adds 88bab293
- SKIPPED  ext/art-2d-swap f63c8b86 conflicts: art/portraits/gunslinger.jpg
- SKIPPED  ext/map-2x 6d0936c0 conflicts: scripts/core/net.gd scripts/match/bot.gd
- merged   ext/matchmaker-map-2x 1511aeef
- merged   ext/parity-glide-dive 45f26a5b
- SKIPPED  ext/parity-jump-flowrows 0f70d1a8 conflicts: docs/KIT_PARITY.md
- merged   ext/ostra-v2-model 76f58938
- merged   ext/parity-phasewalk 51468416
- merged   ext/source-utilities 86ff3a35
- merged   ext/training-grounds 5ebc3550
- SKIPPED  ext/parity-kael-clips abacc4d1 conflicts: content/rules/warden_look.json
- merged   ext/parity-neve-skate-home 9b65ea7f
- merged*  ext/lore-factions 9732ab9b (registry/credits/generated auto-resolved)
- merged   ext/pip-companions-v2 399f2b01
- SKIPPED  ext/parity-no-riders 3bcb50ec conflicts: docs/heroes/rimewright.md
- SKIPPED  ext/hero-names 5e42b4b5 conflicts: content/archetypes/bulwark.json content/sfx/bulwark.json tools/hero_title_check.gd tools/portrait_check.gd
- merged   ext/map-regions 6a0a5ea6
- merged   ext/vex-e-turn 6249e006
- SKIPPED  ext/fix-cinder-art-check cb8131be conflicts: content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/portrait_check.gd tools/prologue_check.gd
- SKIPPED  ext/anim-time-lace 048e54d9 conflicts: content/archetypes/archer.json docs/heroes/archer.md tools/pin_bjorn_ult_check.gd
- SKIPPED  ext/parity-lace-focus ffa20b0f conflicts: content/archetypes/archer.json docs/ABILITIES.md docs/ARCHETYPES.md docs/heroes/archer.md scripts/arch/kits/pin_spirit.gd tools/archer_bulwark_combo_check.gd
- merged   ext/anim-time-cinder 584aa524
- SKIPPED  ext/fix-albert-blade-clip b2375851 conflicts: content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/portrait_check.gd tools/prologue_check.gd
- merged   ext/anim-time-vex 712242c3
- SKIPPED  ext/kael-ult-reset f1192cb9 conflicts: scripts/arch/kits/juggernaut_ult.gd
- SKIPPED  ext/parity-bulwark-guardcut b2e942eb conflicts: docs/ABILITIES.md
- SKIPPED  ext/s7-mask-hob-83-89-fix-rebased a5be26e6 conflicts: content/archetypes/rimewright.json content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/combo51_shots.gd tools/hero_title_check.gd tools/portrait_check.gd tools/prologue_check.gd
- merged   ext/lace-dash-charges 7b83eae8
- SKIPPED  ext/feel-integ bed04e50 conflicts: content/archetypes/ashwick.json content/archetypes/tender.json content/rules/class_unlock.json content/rules/dash_feel.json content/rules/hunter_move.json content/rules/warden_anim/pip.json docs/art/gen/index.md docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/hunter.gd scripts/match/hunter_move.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/pin_bjorn_owner_check.gd tools/portrait_check.gd tools/prologue_check.gd
- SKIPPED  ext/mc-20261108-0030 88b1ac50 conflicts: content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/pin_bjorn_owner_check.gd tools/portrait_check.gd tools/prologue_check.gd
- merged   ext/lace-tall-climb 8b684f25
- merged   ext/dash-refresh-assist 398f4a9c
- SKIPPED  ext/text-lore-integ 930f01e0 conflicts: content/rules/warden_anim/pip.json docs/heroes/dash_interactions.md scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/models-v2-integ 5ec44812 conflicts: content/archetypes/tender.json content/rules/class_unlock.json docs/art/wardens/CLIPS.md docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/pin_bjorn_owner_check.gd tools/portrait_check.gd tools/prologue_check.gd
- SKIPPED  ext/grimble-hook-arm-v2 315cdf2a conflicts: docs/art/wardens/CLIPS.md docs/art/wardens/PIPELINE.md scripts/arch/kits/ld_fx.gd tools/hero_vfx_reel.gd
- SKIPPED  ext/claire-v2-model 7b2165a7 conflicts: docs/art/wardens/PIPELINE.md
- merged   ext/tarek-v2-model fa5c036a
- SKIPPED  ext/map-parity-integ f243f76a conflicts: content/archetypes/archer.json content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json docs/ABILITIES.md docs/ARCHETYPES.md docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/pin_bjorn_owner_check.gd tools/portrait_check.gd tools/prologue_check.gd
- SKIPPED  ext/kael-v2-integ 36c5f7ea conflicts: content/archetypes/tender.json content/rules/class_unlock.json content/rules/warden_anim/pip.json content/rules/warden_look.json docs/decisions/0016-the-unmasked.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dash_interactions.md docs/heroes/dolm.md docs/heroes/mage.md docs/heroes/rimewright.md docs/heroes/tender.md scripts/home/home.gd scripts/home/mask_offer.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/ui/ability_clip.gd scripts/ui/hunter_viewer.gd scripts/ui/mask_moment.gd scripts/ui/mask_relic.gd scripts/ui/prologue.gd tools/ashwick_combo_check.gd tools/breah_combo_check.gd tools/care_combo_check.gd tools/class_unlock_check.gd tools/combo51_shots.gd tools/empty_shots.gd tools/hero_title_check.gd tools/pin_bjorn_owner_check.gd tools/portrait_check.gd tools/prologue_check.gd
- merged   ext/tenzo-ally-hop 61809889
- merged   ext/neve-dart-homing 8904d37b
- SKIPPED  ext/rank-parity-slice 003a3cfe conflicts: content/archetypes/archer.json
- SKIPPED  ext/release-integ-0243 6cfef799 conflicts: content/archetypes/archer.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md scripts/arch/kits/pin_spirit.gd scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/rank-parity-b d911bdfb conflicts: content/archetypes/dredge.json
- SKIPPED  ext/meeko-rmb-motion 8801461c conflicts: art/wardens/pip/pip.glb
- merged   ext/rank-parity-c 29ce1049
- merged   ext/meeko-ult-cancels d4b9d81f
- merged   ext/meeko-carry-drop 6a773c04
- merged   ext/mossy-dash-refund 347408a2
- merged   ext/mossy-shield-bash edfaf87c
- merged   ext/sable-lmb-range 5bd83bbc
- merged   ext/sable-bola-instant b31c2664
- merged   ext/anim-time-meeko 5a6864ab
- SKIPPED  ext/anim-time-tenzo 5aafba87 conflicts: tools/warden_clips_check.gd
- merged   ext/agent-briefs ac70b1d3
- merged   ext/anim-time-neve 1ea57e41
- merged   ext/anim-time-grimble 76dd4b36
- SKIPPED  ext/anim-time-mossy 162a420f conflicts: docs/heroes/bulwark.md tools/archer_bulwark_combo_check.gd
- SKIPPED  ext/stuck-integ-9e20dcba 6cfef799 conflicts: content/archetypes/archer.json content/archetypes/tender.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/anim-time-sparkle 4c7b70c9 conflicts: docs/art/wardens/CLIPS.md
- merged   ext/anim-time-sable 53f65824

Exclusions: ~/bin/merge-exclude.txt on the hetzner box.

## Real-GPU performance (Mac GPU worker, main vs candidate)

| hook | main rc / FAIL / secs | candidate rc / FAIL / secs |
|---|---|---|
| `--hitch-check` | 1 / 3 / 42 (mac-Naruto-Founder) | 1 / 101 / 1134 (pc-MRROBOTO) |
| `--load-check` | 1 / 1 / 34 (mac-Naruto-Founder) | 1 / 1 / 26 (mac-Naruto-Founder) |
| `--perf-bench` | 0 / 0 / 231 (pc-MRROBOTO) | 0 / 0 / 1020 (mac-Naruto-Founder) |
| `--title-check` | 0 / 8 / 6 (mac-Naruto-Founder) | 0 / 10 / 8 (mac-Naruto-Founder) |

Frame-time lines from the logs (lines that mention ms or fps; first 12 per run):

**`--hitch-check` main** (job 20261108-104424-19990)
```
Quality: auto picked low (load benchmark 56.9 ms a frame)
HITCH loading screen 17657 ms over 293 frames, worst 464 ms, 0 shader compiles; build steps: build.warm_up 11229, build.hunters 1790, world.terrain 355, build.generate 279, world.walls 221, build.spaw
HITCH phase first      16 frames  median     18 ms  worst    106 ms  shader compiles 0
HITCH phase planning   25 frames  median     16 ms  worst     26 ms  shader compiles 0
HITCH phase ride      103 frames  median     18 ms  worst    240 ms  shader compiles 0
HITCH phase drop      124 frames  median     35 ms  worst     77 ms  shader compiles 0
HITCH phase land      180 frames  median     27 ms  worst     56 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=11.35): 43 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 106 ms
HITCH       240 ms  ride     t= 4.92  sim 15.1 (+60.3 x6)  vis 0.9  other 1.8  render 155.4  rest 6.7  draws 2466  shader compiles 0
HITCH       189 ms  ride     t= 6.32  sim 8.2 (+30.1 x6)  vis 1.2  other 1.9  render 140.9  rest 6.8  draws 2749  shader compiles 0
HITCH       110 ms  ride     t= 4.82  sim 13.2 (+62.9 x6)  vis 1.0  other 1.8  render 27.2  rest 4.1  draws 2471  shader compiles 0
```

**`--hitch-check` cand** (job 20261108-104424-03531)
```
Quality: auto picked low (load benchmark 80.1 ms a frame)
HITCH loading screen 36428 ms over 343 frames, worst 847 ms, 295 shader compiles; build steps: build.warm_up 15123, build.hunters 6701, world.terrain 1519, build.generate 1187, world.walls 945, build.
HITCH phase first      16 frames  median     48 ms  worst    101 ms  shader compiles 4
HITCH phase planning   25 frames  median     36 ms  worst     82 ms  shader compiles 0
HITCH phase ride      178 frames  median     55 ms  worst    313 ms  shader compiles 8
HITCH phase drop       99 frames  median     74 ms  worst    144 ms  shader compiles 2
HITCH phase land      180 frames  median     99 ms  worst    158 ms  shader compiles 2
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=17.97): 158 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 101 ms
HITCH       313 ms  ride     t=12.82  sim 18.1 (+108.9 x6)  vis 4.0  other 8.7  render 151.3  rest 22.4  draws 2673  shader compiles 4
HITCH       246 ms  ride     t= 4.22  sim 8.2 (+201.2 x6)  vis 3.9  other 10.0  render 9.9  rest 13.1  draws 2305  shader compiles 0
HITCH       237 ms  ride     t=11.92  sim 26.7 (+158.7 x6)  vis 4.1  other 8.7  render 16.1  rest 22.8  draws 2711  shader compiles 0  sim sections: bots 14.0, hunters 4.2, kins 3.1, mobs 1.8
```

**`--load-check` main** (job 20261108-104424-18753)
```
Quality: auto picked low (load benchmark 57.8 ms a frame)
LOAD total 18326 ms over 294 frames; longest frame 517 ms (264 ms outside drawing); 32 frames over 100 ms
LOAD       268     264       4    266     0  c0   Spawning                 [slice 262 ms]
LOAD       265     257       7     88     0  c0   Spawning                 [slice 256 ms]
LOAD       256     252       4     88     0  c0   Spawning                 [slice 251 ms]
LOAD       230     227       3    266     0  c0   Spawning                 [slice 224 ms]
```

**`--load-check` cand** (job 20261108-104424-24800)
```
Quality: auto picked low (load benchmark 62.1 ms a frame)
LOAD total 19136 ms over 311 frames; longest frame 472 ms (294 ms outside drawing); 38 frames over 100 ms
LOAD       298     294       4     89     0  c0   Spawning                 [slice 293 ms]
LOAD       265     261       4    308     0  c0   Spawning                 [slice 259 ms]
LOAD       262     254       9     89     0  c0   Spawning                 [slice 251 ms]
```

**`--perf-bench` main** (job 20261108-104424-01674)
```
BENCH match: 1833 frames, wall avg 47.4 ms, p99 85.0 ms (1% low 6.8 fps)
BENCH match cpu: match script avg 25.60 ms p99 51.00 ms, process 73.80 ms, hud 6.58 ms, render cpu 7.12 ms
BENCH farm: 1200 frames, wall avg 8.1 ms, p99 10.3 ms (1% low 36.2 fps)
BENCH farm cpu: match script avg 31.02 ms p99 185.23 ms, process 31.02 ms, hud 2.53 ms, render cpu 5.69 ms
```

**`--perf-bench` cand** (job 20261108-104424-01468)
```
BENCH hitch t=9.40 164 ms (script 7.8), new nodes: { "MeshInstance3D:@MeshInstance3D": 13, "Node3D:@Node3D": 1, "Node3D:Spin": 1 }
BENCH match: 1898 frames, wall avg 22.9 ms, p99 75.9 ms (1% low 5.5 fps)
BENCH match cpu: match script avg 6.23 ms p99 11.78 ms, process 49.30 ms, hud 1.19 ms, render cpu 10.41 ms
BENCH farm: 1200 frames, wall avg 4.9 ms, p99 8.5 ms (1% low 16.3 fps)
BENCH farm cpu: match script avg 114.40 ms p99 523.16 ms, process 114.40 ms, hud 1.97 ms, render cpu 3.06 ms
```

**`--title-check` main** (job 20261108-104424-23008)
```
TITLE ok   [high] frame budget: 1.31 ms average, 1.74 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 1.23 ms average, 1.29 ms p95 (budget 12 ms)
```

**`--title-check` cand** (job 20261108-104424-11625)
```
TITLE ok   [high] frame budget: 1.38 ms average, 1.70 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 1.25 ms average, 1.33 ms p95 (budget 12 ms)
```

## Release dry-run (Windows and macOS exports, release templates 4.6.2.stable)

| project | preset | result | size / first ERROR |
|---|---|---|---|
| game | Windows | pass | 3.9G |
| game | macOS | pass | 3.6G |
| launcher | Windows | pass | 101M |
| launcher | macOS | pass | 63M |

All exports passed.
