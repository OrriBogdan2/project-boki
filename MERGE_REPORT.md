# Merge candidate 20261109-0503 (built by cron, no Claude usage)

Headline: NEW-RED 35, WORSE 15, FIXED 0 of 186 checks; 86 merged, 130 skipped; release exports pass; GPU jobs not finished: 0

Base: origin/main d255acbe. Health: HEALTH FAIL: style ratchet (docs/STYLE.md) (god files: move new logic into a focused module, see AGENTS.md; style: see docs/STYLE.md)
Suite scope: affected checks only, 186 of 165 (smoke set always on; FULL_SUITE=1 for everything). Why: affected.why on the box.
Capacity plan: alive=pc-MRROBOTO flags=186 cached=0 to_run=186 unknown=14 server_min=50 with_workers_min=25 decision=RUN
- UNCOVERED scripts/arch/kits/ice_body.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/demo.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/fsm.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/locomotion.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_free_arm.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_gait.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_rest.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/home/farm_spotlight.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/kin/kin_fence.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/match/clutter.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)

## Suite vs main: NEW-RED 35, WORSE 15, FIXED 0 of 186 checks
- WORSE --air-control-check main=124/0 cand=0/3
- NEW-RED --airdash-glide-check main=0/0 cand=0/1
- NEW-RED --archetype-check main=0/0 cand=1/2
- NEW-RED --arena-check main=0/0 cand=0/3
- NEW-RED --ashwick-combo-check main=0/0 cand=1/4
- NEW-RED --boss-check main=0/0 cand=0/3
- NEW-RED --bulwark-combo-check main=0/0 cand=1/1
- NEW-RED --capture-check main=0/0 cand=1/3
- NEW-RED --check main=0/0 cand=0/3
- NEW-RED --class-unlock-check main=0/0 cand=0/5
- NEW-RED --clip-check main=0/0 cand=1/2
- NEW-RED --crouch-check main=0/0 cand=1/3
- NEW-RED --dash-flow-check main=0/0 cand=0/3
- WORSE --dash-slot-check main=1/3 cand=0/4
- WORSE --demo-check main=124/0 cand=1/8
- WORSE --demo-quick-check main=124/0 cand=1/306
- NEW-RED --farm-tutorial-check main=0/0 cand=0/11
- WORSE --feed-check main=124/0 cand=0/6
- NEW-RED --gunslinger-combo-check main=0/0 cand=1/47
- WORSE --hatch-check main=0/10 cand=0/16
- NEW-RED --hero-check main=0/0 cand=124/4
- NEW-RED --hero-combo-check main=0/0 cand=1/1
- NEW-RED --hob-check main=0/0 cand=0/610
- NEW-RED --hunter-unlock-check main=0/0 cand=0/5
- WORSE --incubator-check main=124/2 cand=124/3
- NEW-RED --juggernaut-combo-check main=0/0 cand=1/1
- WORSE --kin-indoors-check main=124/3 cand=124/4
- WORSE --kit-parity-check main=124/0 cand=1/1
- NEW-RED --market-check main=0/0 cand=1/6
- NEW-RED --mask-lag-check main=0/0 cand=124/4
- NEW-RED --match-audio-check main=0/0 cand=1/4
- NEW-RED --motley-live-check main=0/0 cand=1/1
- NEW-RED --music-leave-check main=0/0 cand=1/5
- NEW-RED --ostra-combo-check main=0/0 cand=1/201
- WORSE --perf-budget-check main=124/0 cand=1/1
- NEW-RED --rank-ui-check main=0/0 cand=1/1
- NEW-RED --rig-standard-check main=0/0 cand=1/1
- NEW-RED --rolling-check main=0/0 cand=1/1
- WORSE --stretch-check main=124/0 cand=1/454
- NEW-RED --support-check main=0/0 cand=1/1
- NEW-RED --swim-check main=0/0 cand=124/4
- NEW-RED --tender-combo-check main=0/0 cand=1/1
- WORSE --title-check main=0/11 cand=124/14
- NEW-RED --truce-check main=0/0 cand=0/3
- NEW-RED --tutorial-hud-check main=0/0 cand=1/1
- NEW-RED --uipolish-check main=0/0 cand=0/5
- NEW-RED --unmasked-check main=0/0 cand=0/1
- WORSE --warden-glb-check main=0/1 cand=0/3
- WORSE --warden-rest-check main=124/0 cand=1/1
- WORSE --warm-stamp-check main=124/0 cand=1/1

## Branches
- SKIPPED  ext/kit-kael-113 6e18b8be conflicts: scripts/match/hunter.gd tools/combo51_shots.gd
- SKIPPED  ext/art1-kael-2 fd33d204 conflicts: art/kin/hivara/hivara_hivara_eye.webp.import art/kin/pebbit/pebbit_pebbit_eye.webp.import art/kin/wisplet/wisplet_wisplet_face.webp.import art/kin/zapple/zapple_zapple_eye.webp.import art/wardens/kael/IMPORT.md art/wardens/kael/kael.glb art/wardens/kael/kael_Image_2.jpg.import art/wardens/kael/kael_atlas.jpg art/wardens/kael/kael_atlas.jpg.import art/wardens/kael/kael_head.jpg.import art/wardens/src/kael_rig.json content/archetypes/juggernaut.json content/rules/warden_anim/kael.json content/rules/warden_look.json docs/RIG_STANDARD.md docs/art/wardens/CLIPS.md scripts/match/hunter.gd tools/art1/kael_clips.py tools/art1/kael_finish.py tools/art1/kael_paint.py tools/art1/kael_pieces.py tools/art1/kael_source.py tools/combo51_shots.gd tools/warden_model_check.gd
- merged   ext/camera-depth 5404e06f
- merged   ext/props-vex 8e7bcab6
- merged   ext/props-sable 628195e5
- SKIPPED  ext/tutorial-dialogue 53e56a9e conflicts: content/rules/farm_builder.json scripts/home/farm_hob.gd scripts/home/home.gd tools/farm_tutorial_check.gd
- merged   ext/relic-art-adds 88bab293
- merged   ext/matchmaker-map-2x 7ca33e1c
- SKIPPED  ext/parity-phasewalk 51468416 conflicts: docs/ABILITIES.md scripts/arch/kits/pin_spirit.gd
- merged   ext/source-utilities 86ff3a35
- SKIPPED  ext/parity-kael-clips abacc4d1 conflicts: art/wardens/kael/IMPORT.md art/wardens/kael/kael.glb content/rules/warden_anim/kael.json content/rules/warden_look.json tools/art1/kael_retarget.py
- merged   ext/parity-neve-skate-home 9b65ea7f
- merged   ext/map-regions 0588099b
- merged   ext/vex-e-turn 27859acf
- SKIPPED  ext/fix-cinder-art-check cb8131be conflicts: tools/cinder_art_check.gd
- SKIPPED  ext/anim-time-cinder 584aa524 conflicts: docs/art/wardens/CLIPS.md
- merged   ext/anim-time-vex 712242c3
- SKIPPED  ext/kael-ult-reset f1192cb9 conflicts: scripts/arch/kits/juggernaut_ult.gd
- SKIPPED  ext/parity-bulwark-guardcut b2e942eb conflicts: docs/ABILITIES.md scripts/arch/arch_kit.gd scripts/match/arena_demo.gd scripts/ui/hud.gd scripts/ui/hud_vitals.gd scripts/ui/kit_card.gd
- SKIPPED  ext/lace-dash-charges 7b83eae8 conflicts: content/archetypes/archer.json tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/lace-tall-climb 8b684f25 conflicts: docs/heroes/archer.md
- SKIPPED  ext/dash-refresh-assist 398f4a9c conflicts: scripts/match/dash_reset.gd
- merged   ext/tenzo-ally-hop 61809889
- merged   ext/neve-dart-homing 8904d37b
- merged   ext/rank-parity-slice 003a3cfe
- SKIPPED  ext/rank-parity-b d911bdfb conflicts: content/archetypes/dredge.json scripts/arch/arch_kit.gd
- SKIPPED  ext/meeko-rmb-motion 8801461c conflicts: art/wardens/pip/pip.glb scripts/arch/kits/tender_kit.gd
- merged   ext/rank-parity-c 29ce1049
- merged   ext/meeko-ult-cancels d4b9d81f
- SKIPPED  ext/meeko-carry-drop 6a773c04 conflicts: content/archetypes/tender.json docs/heroes/tender.md scripts/arch/kits/tender_kit.gd
- merged   ext/mossy-dash-refund 347408a2
- merged   ext/mossy-shield-bash edfaf87c
- merged*  ext/sable-lmb-range 5bd83bbc (registry/credits/generated auto-resolved)
- SKIPPED  ext/sable-bola-instant b31c2664 conflicts: docs/heroes/dash_interactions.md
- merged   ext/anim-time-meeko bc9a71dc
- SKIPPED  ext/anim-time-tenzo 5aafba87 conflicts: scripts/heroes/warden_clips.gd tools/warden_clips_check.gd
- SKIPPED  ext/agent-briefs af480ffa conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png
- merged   ext/anim-time-neve 1ea57e41
- SKIPPED  ext/anim-time-grimble 76dd4b36 conflicts: docs/heroes/dredge.md
- SKIPPED  ext/anim-time-mossy 162a420f conflicts: docs/heroes/bulwark.md scripts/heroes/warden_clips.gd
- SKIPPED  ext/anim-time-sparkle 4c7b70c9 conflicts: docs/art/wardens/CLIPS.md
- SKIPPED  ext/anim-time-sable 53f65824 conflicts: scripts/heroes/warden_clips.gd
- SKIPPED  ext/body-hitbox-parity b9f481fa conflicts: content/archetypes/dolm.json content/archetypes/gunslinger.json content/archetypes/juggernaut.json docs/HITBOX_SIZE.md tools/warden_model_check.gd
- SKIPPED  ext/telegraph-audit-a 456a56d4 conflicts: scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/ashwick_kit.gd scripts/arch/kits/juggernaut_kit.gd scripts/arch/kits/tender_kit.gd
- SKIPPED  ext/telegraph-audit-b 20810cf2 conflicts: docs/heroes/archer.md docs/heroes/rimewright.md scripts/arch/kits/rimewright_kit.gd tools/pin_bjorn_ult_check.gd
- SKIPPED  ext/telegraph-audit-c 498b60d0 conflicts: scripts/arch/kits/mage_kit.gd scripts/arch/kits/mage_ult.gd
- SKIPPED  ext/anim-time-motley 305a79cb conflicts: tools/warden_model_check.gd
- SKIPPED  ext/airdash-rule-audit a3a45b2a conflicts: content/dash_flow/dolm.json docs/heroes/dash_interactions.md scripts/arch/kits/juggernaut_kit.gd
- merged   ext/kit-parity-lock 76783a36
- SKIPPED  ext/dash-buffer-window 77fa3ffd conflicts: content/dash_flow/rimewright.json docs/decisions/0010-dash-ability-flow.md
- SKIPPED  ext/heal-knock-source f66273fc conflicts: docs/heroes/thief.md
- merged   ext/neve-chill-shatter cd2f3f29
- SKIPPED  ext/idle-dolm 9ce102a7 conflicts: art/wardens/tarek/tarek.glb
- merged   ext/idle-juggernaut 2c700e15
- SKIPPED  ext/idle-ostra 2a99a091 conflicts: art/wardens/ostra/ostra.glb
- SKIPPED  ext/idle-gunslinger fa16ce7e conflicts: art/wardens/vex/vex.glb tools/art1/posekit.py
- SKIPPED  ext/idle-bulwark 53c963ec conflicts: scripts/heroes/warden_mood.gd
- SKIPPED  ext/idle-tender be19bd8b conflicts: art/wardens/pip/pip.glb content/rules/warden_anim/pip.json scripts/heroes/warden_glb.gd tools/art1/posekit.py
- SKIPPED  ext/idle-thief 619b8dc3 conflicts: art/wardens/sable/sable.glb tools/art1/posekit.py
- SKIPPED  ext/idle-ashwick eeb4f3ae conflicts: art/wardens/cinder/cinder.glb content/rules/warden_anim/cinder.json tools/art1/cinder_clips.py
- merged   ext/depth-tiers 3c5f9207
- SKIPPED  ext/idle-mage 9d6d41c0 conflicts: art/wardens/ryzz/ryzz.glb content/rules/warden_anim/ryzz.json
- SKIPPED  ext/tutorial-prologue 4347c61b conflicts: content/rules/farm_builder.json scripts/home/farm_hob.gd scripts/home/home.gd scripts/ui/prologue.gd scripts/ui/prologue_boki.gd tools/farm_tutorial_check.gd tools/prologue_check.gd tools/teammate_check.gd
- SKIPPED  ext/idle-rimewright 6d2e7ca5 conflicts: art/wardens/claire/claire.glb
- SKIPPED  ext/idle-dredge b3fdeeef conflicts: tools/art1/posekit.py
- SKIPPED  ext/idle-archer 8437593b conflicts: art/wardens/hem/IMPORT.md art/wardens/hem/hem.glb tools/art1/posekit.py
- SKIPPED  ext/heartspark 3e359d1f conflicts: scripts/core/net.gd scripts/ui/full_map.gd scripts/ui/hud.gd
- SKIPPED  ext/mossy-narrow cc74a32e conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/tender.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/warden-check-heights 84f9aa9d conflicts: tools/warden_model_check.gd
- SKIPPED  ext/prologue-canon 60d89d26 conflicts: scripts/ui/prologue.gd tools/prologue_check.gd
- SKIPPED  ext/no-rolling daa669ea conflicts: scripts/match/match.gd
- SKIPPED  ext/prologue-canon-2 bd87c933 conflicts: scripts/ui/prologue.gd tools/prologue_check.gd
- SKIPPED  ext/misc-ready-integ 55446e04 conflicts: content/archetypes/archer.json content/rules/farm_builder.json docs/heroes/bulwark.md scripts/arch/arch_kit.gd scripts/arch/kits/bulwark_kit.gd scripts/home/farm_hob.gd scripts/home/home.gd scripts/match/arena_demo.gd scripts/ui/hud.gd scripts/ui/hud_vitals.gd scripts/ui/kit_card.gd tools/farm_tutorial_check.gd
- SKIPPED  ext/portraits-unified 51c79fc8 conflicts: art/portraits/ashwick.jpg art/portraits/bulwark.jpg art/portraits/gunslinger.jpg art/portraits/ostra.jpg art/portraits/rimewright.jpg docs/heroes/dash_interactions.md scripts/arch/arch.gd scripts/match/hero_kit.gd
- merged*  ext/tg-text 666ba8d8 (registry/credits/generated auto-resolved)
- SKIPPED  ext/stuck-integ-950a5444 c3b54794 conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/ashwick.json content/archetypes/ostra.json content/archetypes/tender.json content/rules/lore.json content/rules/warden_anim/pip.json content/vfx/ashwick.json docs/ABILITIES.md docs/art/gen/stories/archer.md docs/art/gen/stories/ostra.md docs/art/wardens/PIPELINE.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/care_look.gd scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/heroes/warden_glb.gd scripts/home/home.gd tools/ashwick_combo_check.gd tools/cinder_art_check.gd tools/combo51_shots.gd tools/hero_title_check.gd tools/warden_model_check.gd
- SKIPPED  ext/utilities-shops e94360ee conflicts: content/maps/hollowcrown.json scripts/core/net.gd tools/make_hollowcrown.py
- SKIPPED  ext/ravel-v2-pass3 e4b5f2ea conflicts: content/archetypes/archer.json
- SKIPPED  ext/cinder-sable-polish 6952af96 conflicts: art/wardens/sable/sable.glb tools/art1/sable_paint.py
- SKIPPED  ext/parity-snowglide-rebased 0e6c6ee6 conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/ashwick.json content/archetypes/ostra.json content/archetypes/tender.json content/rules/lore.json content/rules/warden_anim/pip.json content/vfx/ashwick.json docs/ABILITIES.md docs/art/gen/stories/archer.md docs/art/gen/stories/ostra.md docs/art/wardens/PIPELINE.md docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/ashwick_jet.gd scripts/arch/kits/care_look.gd scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/heroes/warden_glb.gd scripts/home/home.gd tools/ashwick_combo_check.gd tools/cinder_art_check.gd tools/combo51_shots.gd tools/hero_title_check.gd tools/warden_model_check.gd
- SKIPPED  ext/kael-ult-reset-rebased d32c621e conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/tender.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/juggernaut_ult.gd scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/grimble-hook-arm-v2-rebased bac62de3 conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/tender.json docs/ABILITIES.md docs/art/wardens/PIPELINE.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd scripts/match/hunter.gd tools/combo51_shots.gd tools/pin_bjorn_owner_check.gd
- SKIPPED  ext/tutorial-prologue-rebased 5c26e95a conflicts: MERGE_REPORT.md briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png content/archetypes/archer.json content/archetypes/tender.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/ui/prologue.gd scripts/ui/prologue_boki.gd tools/combo51_shots.gd tools/lineup_shot.gd tools/pin_bjorn_owner_check.gd tools/prologue_check.gd
- SKIPPED  ext/release-integ-0243-rebased 517a0d10 conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json scripts/heroes/warden_clips.gd scripts/home/home.gd
- SKIPPED  ext/meeko-rmb-motion-rebased d2fa02fa conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json scripts/heroes/warden_clips.gd scripts/home/home.gd
- merged   ext/hunter-order-v2 85421155
- SKIPPED  ext/map-2x-flat2 269d1201 conflicts: content/maps/hollowcrown.json scripts/core/net.gd tools/lineup_shot.gd tools/make_hollowcrown.py
- merged   ext/linux-server-preset 6f212ebe
- merged   ext/albert-v2-rel 8a738e4d
- already  ext/breaker-v2-model
- merged   ext/sparkle-hair-lower 6e5ad2b9
- merged   ext/sable-wing-bone 7f7453f6
- SKIPPED  ext/tutorial-prologue-rebased-rebased 7537e251 conflicts: scripts/heroes/warden_clips.gd server/README.md server/matchmaker/mm/config.py tools/hero_combo_check.gd
- merged   ext/parity-phasewalk-rebased 2178ea31
- merged   ext/lace-tall-climb-rebased b3c955ab
- merged   ext/anim-quality-audit e70ec15c
- merged   ext/meeko-v2 f3c4e0e2
- SKIPPED  ext/anim-time-cinder-rebased 940d54f2 conflicts: content/rules/warden_anim/cinder.json docs/art/wardens/CLIPS.md scripts/heroes/warden_clips.gd
- merged   ext/motley-rework f935a96e
- merged   ext/tutorial-declutter c613689f
- merged   ext/meeko-carry-drop-rebased 5851463a
- merged   ext/farm-tut-spotlight d0f02745
- merged   ext/vfx-quality-base 9a9bb3b7
- merged   ext/ui-void-masks 6afeee56
- merged   ext/glide-no-hold faf4819d
- merged*  ext/feed-kibble-fix 84c71973 (registry/credits/generated auto-resolved)
- merged   ext/void-jester-dash a45fb9e9
- SKIPPED  ext/farm-tut-batch-1108 1c2b08ca conflicts: docs/decisions/0011-farm-builder-tutorial.md scripts/home/farm_spotlight.gd tools/farm_tutorial_check.gd
- merged   ext/neve-lmb-celeste 7e6a64d7
- merged   ext/grimble-stretch d6e54648
- already  ext/ui-void-masks-2
- merged*  ext/movement-unify 1240289a (registry/credits/generated auto-resolved)
- merged*  ext/demo-presets-1108 c61f8c0e (registry/credits/generated auto-resolved)
- merged   ext/motley-rework-2 68dbfa88
- SKIPPED  ext/vfx-ostra-abilities d21f7a53 conflicts: docs/VFX_QUALITY.md
- SKIPPED  ext/vfx-dolm 9871872f conflicts: docs/VFX_QUALITY.md
- merged*  ext/vfx-dolm-shots 81250270 (registry/credits/generated auto-resolved)
- SKIPPED  ext/vfx-tender cfbdc5ab conflicts: docs/heroes/tender.md
- merged*  ext/vfx-strips-tender e371e874 (registry/credits/generated auto-resolved)
- merged   ext/bot-names-1108 d8744495
- SKIPPED  ext/vfx-gunslinger 1bb6c7bc conflicts: docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd
- SKIPPED  ext/vfx-gunslinger-strips 516916a3 conflicts: docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd
- SKIPPED  ext/lace-playtest-1108 b79ec35c conflicts: content/rules/tuning.json docs/heroes/archer.md
- merged   ext/vfx-archer ba59ff09
- merged*  ext/vfx-archer-strips 11d36ea9 (registry/credits/generated auto-resolved)
- SKIPPED  ext/farm-tut-tools-cam b6db8443 conflicts: content/rules/farm_tutorial.json
- merged   ext/tutorial-low-cds be2507ed
- SKIPPED  ext/keybinds-1108 65f6cc66 conflicts: scripts/core/game.gd scripts/match/hunter.gd scripts/match/match.gd scripts/ui/loading.gd
- SKIPPED  ext/vfx-dredge 794ca0e3 conflicts: docs/VFX_QUALITY.md
- SKIPPED  ext/scrapking-lmb d5891bd3 conflicts: tools/hero_vfx_reel.gd
- merged*  ext/scrapking-lmb-clips 1cc8f5a5 (registry/credits/generated auto-resolved)
- merged   ext/pick-countdown-30s-1108 45ca2bc6
- SKIPPED  ext/vex-coin-palm-1108 0478765f conflicts: art/wardens/vex/vex.glb docs/VFX_QUALITY.md docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd tools/hero_combo_check.gd
- merged   ext/perf-expedition-1108 69cbd574
- merged*  ext/recast-clarity-1108 fd0836b1 (registry/credits/generated auto-resolved)
- SKIPPED  ext/vfx-mage 43524c78 conflicts: docs/VFX_QUALITY.md scripts/match/hunter.gd tools/hero_combo_check.gd
- SKIPPED  ext/sparkle-dash-feel 8876174f conflicts: scripts/match/hunter.gd tools/airdash_glide_check.gd
- merged*  ext/vfx-mage-strips b76a2e99 (registry/credits/generated auto-resolved)
- merged   ext/creator-sex-distinct 59701cf8
- merged*  ext/creator-sex-distinct-shots 0e0fa57a (registry/credits/generated auto-resolved)
- SKIPPED  ext/leave-match-warning-1108 8a8f66a4 conflicts: scripts/ui/overlay.gd
- SKIPPED  ext/expedition-fps-1108 62ad7d14 conflicts: content/rules/tuning.json scripts/core/settings.gd scripts/match/world.gd tools/perf_bench.gd
- SKIPPED  ext/trios-10x3-1108 83d314b9 conflicts: scripts/home/home.gd
- SKIPPED  ext/vex-dash-parity efbd6af9 conflicts: content/rules/tuning.json scripts/arch/kits/gunslinger_kit.gd
- merged   ext/vfx-kael-polish 2500aca8
- SKIPPED  ext/vfx-bulwark f612a570 conflicts: docs/VFX_QUALITY.md
- SKIPPED  ext/vfx-cinder-polish 89e74c9c conflicts: docs/VFX_QUALITY.md
- SKIPPED  ext/tutorials-cut 37dc18d8 conflicts: content/archetypes/tender.json content/rules/tutorial.json docs/ABILITIES.md docs/heroes/archer.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd server/README.md server/matchmaker/mm/config.py tools/archer_bulwark_combo_check.gd tools/hero_combo_check.gd tools/support_check.gd
- merged*  ext/perf-load-shaders-1108 1cb9cca3 (registry/credits/generated auto-resolved)
- merged   ext/evolution-rules-1108 4bd4a4cf
- SKIPPED  ext/vex-greenfire-1108 4e67fbbf conflicts: art/wardens/vex/vex.glb content/rules/tuning.json docs/VFX_QUALITY.md docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd scripts/heroes/warden_clips.gd tools/hero_combo_check.gd tools/venator_parity_check.gd
- SKIPPED  ext/airdash-anims-1108 2d9f6794 conflicts: content/rules/tuning.json content/rules/warden_anim/pip.json docs/art/wardens/CLIPS.md scripts/heroes/warden_clips.gd tools/hero_vfx_reel.gd
- SKIPPED  ext/mystery-egg-basket 434c6d34 conflicts: tools/empty_shots.gd
- SKIPPED  ext/demo-record-ready-1109 5e0493be conflicts: scripts/ui/goal_tracker.gd
- SKIPPED  ext/islands-deeper-1108 897738f4 conflicts: content/rules/tuning.json scripts/match/hunter.gd scripts/match/world.gd
- SKIPPED  ext/farm-tut-batch-1108-deep dcc04a94 conflicts: content/rules/tuning.json
- SKIPPED  ext/expedition-fps-1108-r2 d821569d conflicts: content/rules/tuning.json scripts/core/settings.gd scripts/match/world.gd tools/perf_bench.gd
- merged   ext/perf-render-presets-1108 42716149
- SKIPPED  ext/loading-screen-1108 5e26967a conflicts: scripts/match/match.gd
- merged   ext/boki-caecilith-v2 2c763f2e
- SKIPPED  ext/perf-actors-1108 5649214b conflicts: content/rules/tuning.json scripts/core/settings.gd scripts/match/world.gd tools/perf_bench.gd
- merged*  ext/map-perf-1108 f4209d74 (registry/credits/generated auto-resolved)
- SKIPPED  ext/tenzo-playtest-1108 dc6e4c5b conflicts: content/archetypes/dolm.json content/rules/tuning.json
- SKIPPED  ext/boki3d-lilybara 6df99d44 conflicts: docs/art/kin/RIGGED_BOKI.md tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/boki3d-umbrathere 977ef60f conflicts: docs/art/kin/RIGGED_BOKI.md tools/boki/build_boki.py tools/boki_rig_check.gd
- SKIPPED  ext/perf-render-presets-1108b a90208db conflicts: scripts/core/settings.gd tools/quality_check.gd
- merged   ext/expedition-pick-simplify-1108-r2 3243ec18
- SKIPPED  ext/sable-bola-instant-rebased 2024f010 conflicts: docs/heroes/dash_interactions.md
- merged   ext/anim-time-grimble-rebased 35429b5a
- merged   ext/hunter-art-1108 d60c3aec
- SKIPPED  ext/grimble-stretch-v2 ba158402 conflicts: art/wardens/dredge/dredge.glb tools/art1/grimble_clips.py tools/art1/skin_relax.py
- SKIPPED  ext/anim-time-sable-rebased 990e2874 conflicts: scripts/heroes/warden_clips.gd
- SKIPPED  ext/agent-briefs-rebased 34783061 conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_b_step.png briefs/camera_depth/after_c_low.png
- merged   ext/dash-refresh-assist-rebased 5ef12c32
- SKIPPED  ext/body-hitbox-parity-rebased 4988bb2e conflicts: art/wardens/breaker/IMPORT.md content/archetypes/gunslinger.json docs/ARCHETYPES.md
- SKIPPED  ext/heal-knock-source-rebased 44f88a2c conflicts: docs/heroes/thief.md
- SKIPPED  ext/telegraph-audit-b-rebased d42fe2ce conflicts: docs/heroes/rimewright.md scripts/arch/kits/breah_spine.gd scripts/arch/kits/dolm_kit.gd scripts/arch/kits/pin_ult.gd tools/care_ult_check.gd
- merged   ext/telegraph-audit-a-rebased 8a901503
- SKIPPED  ext/telegraph-audit-c-rebased 32742080 conflicts: scripts/arch/kits/mage_kit.gd scripts/arch/kits/ostra_kit.gd
- SKIPPED  ext/idle-tender-rebased 8cec5357 conflicts: art/wardens/pip/pip.glb tools/art1/posekit.py
- merged   ext/airdash-rule-audit-rebased 9120d94f
- SKIPPED  ext/idle-gunslinger-rebased 4b0767ca conflicts: art/wardens/vex/vex.glb tools/art1/posekit.py
- merged   ext/idle-dolm-rebased f2cb1fa9
- SKIPPED  ext/dash-buffer-window-rebased aae4f850 conflicts: docs/heroes/dash_interactions.md tools/gen_wiki.py
- merged   ext/idle-ashwick-rebased e557cd71
- merged*  ext/boki-agency de278d0d (registry/credits/generated auto-resolved)
- SKIPPED  ext/idle-dredge-rebased b217d2ec conflicts: art/wardens/dredge/dredge.glb tools/art1/grimble_clips.py tools/art1/posekit.py
- SKIPPED  ext/idle-mage-rebased 3e4ac3e0 conflicts: art/wardens/ryzz/ryzz.glb
- merged   ext/idle-rimewright-rebased 3306d774
- SKIPPED  ext/idle-archer-rebased a94bdd7d conflicts: tools/art1/posekit.py
- SKIPPED  ext/idle-thief-rebased 97945e28 conflicts: art/wardens/sable/sable.glb tools/art1/posekit.py
- merged   ext/anim-free-arm-relax a518863d
- SKIPPED  ext/idle-bulwark-rebased ccea3879 conflicts: art/wardens/breaker/breaker.glb docs/art/IDLE_AUDIT.md
- SKIPPED  ext/kael-tap-ult-1108 66423a45 conflicts: answer.md content/rules/tuning.json scripts/arch/kits/juggernaut_kit.gd
- merged   ext/suite-reds-0243 dc6e22d0
- SKIPPED  ext/tender-gait 4f9fd219 conflicts: docs/art/ANIM_QUALITY_AUDIT.md
- SKIPPED  ext/map-2x-flat2-rebased d200abbf conflicts: content/maps/hollowcrown.json tools/make_hollowcrown.py
- SKIPPED  ext/heartspark-rebased 2a2a5d00 conflicts: scripts/ui/full_map.gd scripts/ui/hud.gd
- merged   ext/loading-screen-1108-r2 72934056
- SKIPPED  ext/game-rules-nov8 14a02c65 conflicts: scripts/home/home.gd scripts/kin/kin_spec.gd scripts/match/boki_rig.gd
- SKIPPED  ext/rimewright-skate 9e4710f6 conflicts: art/wardens/claire/claire.glb
- SKIPPED  ext/no-rolling-rebased 9b7b5315 conflicts: scripts/home/home.gd scripts/main.gd scripts/match/match.gd tools/style_baseline.json
- merged   ext/kael-ult-reset-rebased-rebased 76a5d931
- SKIPPED  ext/warden-bob-damp ba31e5ef conflicts: docs/art/ANIM_QUALITY_AUDIT.md
- SKIPPED  ext/meeko-rmb-motion-rebased-rebased e5587292 conflicts: art/wardens/pip/pip.glb briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd tools/archer_bulwark_combo_check.gd tools/care_combo_check.gd tools/support_check.gd
- SKIPPED  ext/parity-snowglide-rebased-rebased 4a2175ee conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd
- merged*  ext/stuck-integ-cb5c1c27 da83863d (registry/credits/generated auto-resolved)
- merged   ext/anim-time-motley-rebased a8828080
- SKIPPED  ext/utilities-shops-rebased f8af39fa conflicts: content/maps/hollowcrown.json tools/make_hollowcrown.py
- merged   ext/ravel-v2-pass3-rebased fdf76e24
- SKIPPED  ext/release-integ-0243-rebased-rebased f9a818e7 conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd tools/archer_bulwark_combo_check.gd tools/support_check.gd
- SKIPPED  ext/anim-idle-walk-gap b0a1e984 conflicts: tools/anim_shots.gd
- merged   ext/anim-slide-tune 7a782345
- already  ext/stuck-integ-e28956f8
- SKIPPED  ext/cinder-sable-polish-rebased f3bf0403 conflicts: art/wardens/sable/sable.glb tools/art1/sable_paint.py
- merged   ext/dex-branch-forms 8713093c
- SKIPPED  ext/types-standard-names 8b43b206 conflicts: content/abilities_v2/moon_mark.json
- SKIPPED  ext/vex-dash-parity-rebased bee6851e conflicts: docs/VFX_QUALITY.md docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd
- SKIPPED  ext/ostra-gait 89acba32 conflicts: art/wardens/ostra/IMPORT.md art/wardens/ostra/ostra.glb docs/art/ANIM_QUALITY_AUDIT.md tools/anim_shots.gd tools/art1/ostra_clips.py

Exclusions: ~/bin/merge-exclude.txt on the hetzner box.

## Real-GPU performance (Mac GPU worker, main vs candidate)

| hook | main rc / FAIL / secs | candidate rc / FAIL / secs |
|---|---|---|
| `--hitch-check` | 1 / 29 / 92 (mac-Naruto-Founder) | 1 / 10 / 132 (rp1-1) |
| `--load-check` | 1 / 1 / 229 (pc-MRROBOTO) | 1 / 1 / 228 (pc-MRROBOTO) |
| `--perf-bench` | 0 / 0 / 152 (rp1-0) | 0 / 3 / 1184 (rp2-0) |
| `--title-check` | 124 / 8 / 1503 (mac-Naruto-Founder) | 124 / 12 / 1505 (rp1-1) |

Frame-time lines from the logs (lines that mention ms or fps; first 12 per run):

**`--hitch-check` main** (job 20261109-075947-10183)
```
Quality: auto picked low (load benchmark 56.0 ms a frame)
HITCH loading screen 23873 ms over 313 frames, worst 741 ms, 0 shader compiles; build steps: build.warm_up 15711, build.hunters 2662, world.terrain 407, build.generate 326, build.spawns 295, world.wal
HITCH phase first      16 frames  median     19 ms  worst    116 ms  shader compiles 0
HITCH phase planning   25 frames  median     19 ms  worst     28 ms  shader compiles 0
HITCH phase ride       98 frames  median     21 ms  worst    217 ms  shader compiles 0
HITCH phase drop      256 frames  median     65 ms  worst    203 ms  shader compiles 0
HITCH phase land      180 frames  median     49 ms  worst    159 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=17.52): 112 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 116 ms
HITCH       217 ms  ride     t= 5.42  sim 10.9 (+36.9 x6)  vis 0.8  other 1.9  render 162.5  rest 3.9  draws 2649  shader compiles 0
HITCH       203 ms  drop     t=10.37  sim 10.8 (+47.1 x3)  vis 44.7  other 5.6  render 75.9  rest 18.5  draws 2651  shader compiles 0  visual sections: hunters 42.4, kins_mobs 1.2, vision 0.1, camera 
HITCH       195 ms  ride     t= 5.82  sim 8.1 (+44.2 x6)  vis 1.3  other 2.4  render 126.7  rest 12.8  draws 2835  shader compiles 0
```

**`--hitch-check` cand** (job 20261109-075947-00044)
```
Quality: auto picked very_low (load benchmark 69.7 ms a frame)
HITCH loading screen 29193 ms over 313 frames, worst 2078 ms, 96 shader compiles; build steps: build.warm_up 8103, build.hunters 2388, build.generate 1271, world.terrain 1211, build.spawns 1057, world
HITCH phase first      16 frames  median     43 ms  worst    115 ms  shader compiles 0
HITCH phase planning   25 frames  median     40 ms  worst     68 ms  shader compiles 0
HITCH phase ride      182 frames  median     46 ms  worst    188 ms  shader compiles 0
HITCH phase drop      258 frames  median     55 ms  worst    132 ms  shader compiles 1
HITCH phase land      180 frames  median     76 ms  worst    148 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=25.90): 113 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 115 ms
HITCH       188 ms  ride     t= 4.72  sim 10.2 (+137.0 x6)  vis 4.1  other 6.9  render 10.7  rest 18.8  draws 2105  shader compiles 0
HITCH       179 ms  ride     t= 4.82  sim 25.4 (+120.0 x6)  vis 4.2  other 6.9  render 9.9  rest 12.6  draws 2100  shader compiles 0  sim sections: bots 17.8, hunters 3.5, mobs 1.0, kins 0.9
HITCH       173 ms  ride     t= 5.22  sim 21.8 (+105.5 x6)  vis 4.4  other 6.9  render 11.7  rest 22.7  draws 2083  shader compiles 0  sim sections: bots 14.8, hunters 3.3, kins 0.8, mobs 0.8
```

**`--load-check` main** (job 20261109-075947-21972)
```
Quality: auto picked low (load benchmark 80.5 ms a frame)
LOAD total 36249 ms over 336 frames; longest frame 1053 ms (1051 ms outside drawing); 39 frames over 100 ms
LOAD      1053    1051       3    209     0  c0   Spawning                 [slice 1044 ms]
LOAD       816     813       3    494     0  c0   Spawning                 [slice 801 ms]
LOAD       700     696       4    209     0  c0   Spawning                 [slice 692 ms]
LOAD       700     697       3    478     0  c0   Spawning                 [slice 688 ms]
LOAD       530     527       3   1073     0  c0   Spawning                 [slice 521 ms]
LOAD       517     514       3    720     0  c0   Spawning                 [slice 505 ms]
LOAD       474     471       3    536     0  c0   Spawning                 [slice 461 ms]
LOAD       458     455       3    553     0  c0   Spawning                 [slice 448 ms]
LOAD       454     452       3    478     0  c0   Spawning                 [slice 444 ms]
LOAD       396     393       3    720     0  c0   Spawning                 [slice 385 ms]
```

**`--load-check` cand** (job 20261109-075947-10579)
```
Quality: auto picked very_low (load benchmark 86.4 ms a frame)
LOAD total 53494 ms over 604 frames; longest frame 1597 ms (381 ms outside drawing); 51 frames over 100 ms
LOAD       384     381       3    184     0  c0   Spawning                 [slice 367 ms]
LOAD       383     379       4    213     0  c0   Spawning                 [slice 373 ms]
LOAD       347     345       2    213     0  c0   Spawning                 [slice 337 ms]
LOAD       319     316       3    403     0  c0   Spawning                 [slice 309 ms]
LOAD       260     253       8    204     1  c0   Building the map         [slice 19699 ms]  [slice 61 ms]
LOAD       260     257       2    204     1  c0   Building the map         [slice 76 ms]
LOAD       240     237       3    403     0  c0   Spawning                 [slice 228 ms]
```

**`--perf-bench` main** (job 20261109-075947-21733)
```
BENCH hitch t=1.37 247 ms (script 52.9), new nodes: { "Node3D:ember": 1, "MeshInstance3D:@MeshInstance3D": 6, "Node3D:Tail": 1, "Node3D:HeroVfx": 1 }
BENCH hitch t=1.40 391 ms (script 79.1), new nodes: {  }
BENCH hitch t=1.47 453 ms (script 89.4), new nodes: { "MeshInstance3D:@MeshInstance3D": 2, "GPUParticles3D:@GPUParticles3D": 1 }
BENCH hitch t=8.07 306 ms (script 39.5), new nodes: { "Node3D:@Node3D": 13, "Node3D:Body": 6, "Node3D:JawL": 3, "MeshInstance3D:@MeshInstance3D": 116, "Node3D:Leg0-": 3, "Node3D:Leg1-": 3, "Node3D:Leg
BENCH hitch t=8.77 222 ms (script 30.7), new nodes: { "Node3D:@Node3D": 1, "MeshInstance3D:Body": 1, "MeshInstance3D:@MeshInstance3D": 3 }
BENCH hitch t=13.33 177 ms (script 24.4), new nodes: { "Node3D:@Node3D": 1, "MeshInstance3D:Body": 1, "MeshInstance3D:@MeshInstance3D": 2 }
BENCH hitch t=18.90 168 ms (script 148.1), new nodes: { "Node3D:@Node3D": 4, "Node3D:Body": 2, "Node3D:Puff": 1, "Node3D:FinL": 1, "MeshInstance3D:@MeshInstance3D": 31, "Node3D:FinR": 1, "Node3D:Spark
BENCH match: 1820 frames, wall avg 44.8 ms, p99 77.8 ms (1% low 2.2 fps)
BENCH match cpu: match script avg 22.58 ms p99 48.35 ms, process 81.43 ms, hud 5.41 ms, render cpu 3.16 ms
BENCH farm: 1200 frames, wall avg 8.1 ms, p99 11.0 ms (1% low 10.7 fps)
BENCH farm cpu: match script avg 39.64 ms p99 984.96 ms, process 39.64 ms, hud 11.12 ms, render cpu 2.39 ms
```

**`--perf-bench` cand** (job 20261109-075947-27622)
```
BENCH hitch t=1.43 248 ms (script 21.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 4, "PanelContainer:@PanelContainer": 1, "Label:@Label": 1 }
BENCH hitch t=2.08 181 ms (script 13.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 14, "Node3D:@Node3D": 4, "Node3D:Key": 1, "Node3D:Icon": 1, "Sprite3D:@Sprite3D": 1, "Node:@Node": 1 }
BENCH hitch t=7.93 207 ms (script 19.1), new nodes: { "Node3D:@Node3D": 2, "MeshInstance3D:Halo": 2, "MeshInstance3D:Core": 2 }
BENCH hitch t=8.40 396 ms (script 22.6), new nodes: { "MeshInstance3D:@MeshInstance3D": 1 }
BENCH hitch t=8.73 312 ms (script 32.9), new nodes: { "MeshInstance3D:@MeshInstance3D": 2, "Node3D:@Node3D": 7, "MeshInstance3D:Head": 7, "MeshInstance3D:Trail": 7 }
BENCH hitch t=8.87 435 ms (script 33.6), new nodes: { "MeshInstance3D:@MeshInstance3D": 2, "GPUParticles3D:@GPUParticles3D": 1 }
BENCH hitch t=10.52 192 ms (script 29.9), new nodes: { "MeshInstance3D:@MeshInstance3D": 12, "Node3D:@Node3D": 1 }
BENCH hitch t=10.55 265 ms (script 56.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 10, "Node3D:Grounded": 1, "Node3D:DazeStars": 1 }
BENCH hitch t=13.43 266 ms (script 19.9), new nodes: { "MeshInstance3D:@MeshInstance3D": 1 }
BENCH hitch t=16.08 268 ms (script 39.6), new nodes: { "MeshInstance3D:@MeshInstance3D": 10, "PanelContainer:@PanelContainer": 1, "Label:@Label": 1, "Node3D:Wisp": 1, "Node3D:Tilt": 1, "MeshInstance3D
BENCH hitch t=57.93 140 ms (script 126.0), new nodes: { "Node3D:@Node3D": 10, "MeshInstance3D:@MeshInstance3D": 28, "Node3D:Spin": 1, "Node3D:Icon": 1, "Sprite3D:@Sprite3D": 1, "Node:@Node": 1 }
BENCH match: 1873 frames, wall avg 42.0 ms, p99 100.5 ms (1% low 2.0 fps)
```

**`--title-check` main** (job 20261109-075947-14013)
```
TITLE ok   [high] frame budget: 8.41 ms average, 14.07 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 9.59 ms average, 14.45 ms p95 (budget 12 ms)
```

**`--title-check` cand** (job 20261109-075947-11909)
```
TITLE ok   [high] frame budget: 3.95 ms average, 4.40 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 4.75 ms average, 4.13 ms p95 (budget 12 ms)
```

## Release dry-run (Windows and macOS exports, release templates 4.6.2.stable)

| project | preset | result | size / first ERROR |
|---|---|---|---|
| game | Windows | pass | 421M |
| game | macOS | pass | 290M |
| launcher | Windows | pass | 101M |
| launcher | macOS | pass | 63M |

All exports passed.
