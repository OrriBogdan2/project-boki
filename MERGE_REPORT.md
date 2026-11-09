# Merge candidate 20261109-1352 (built by cron, no Claude usage)

Headline: NEW-RED 20, WORSE 19, FIXED 9 of 209 checks; 172 merged, 343 skipped; release exports pass; GPU jobs not finished: 0

Base: origin/main d255acbe. Health: HEALTH FAIL: style ratchet (docs/STYLE.md) (god files: move new logic into a focused module, see AGENTS.md; style: see docs/STYLE.md)
Suite scope: affected checks only, 209 of 165 (smoke set always on; FULL_SUITE=1 for everything). Why: affected.why on the box.
Capacity plan: alive=pc-MRROBOTO flags=209 cached=0 to_run=209 unknown=20 server_min=51 with_workers_min=25 decision=RUN
- UNCOVERED scripts/arch/kits/ice_body.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/arch/ult_cue.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/boki_quirks.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/demo.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/fsm.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/core/locomotion.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_free_arm.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_gait.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/heroes/warden_rest.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)
- UNCOVERED scripts/home/base_race.gd (changed .gd/scene in no flag's deps; only the smoke set covers it)

## Suite vs main: NEW-RED 20, WORSE 19, FIXED 9 of 209 checks
- NEW-RED --ability-check main=0/0 cand=0/48
- NEW-RED --aimkit-check main=0/0 cand=0/3
- WORSE --air-control-check main=124/0 cand=0/19
- NEW-RED --air-limits-check main=0/0 cand=0/24
- NEW-RED --airdash-glide-check main=0/0 cand=0/25
- NEW-RED --airheal-check main=0/0 cand=0/6
- NEW-RED --archer-combo-check main=0/0 cand=0/36
- NEW-RED --archetype-check main=0/0 cand=1/117
- NEW-RED --arena-check main=0/0 cand=0/45
- NEW-RED --ashwick-combo-check main=0/0 cand=1/33
- NEW-RED --backpack-check main=0/0 cand=0/2
- NEW-RED --balloon-check main=0/0 cand=0/2
- NEW-RED --base-check main=0/0 cand=0/4
- NEW-RED --biome-check main=0/0 cand=0/4
- NEW-RED --blight-check main=0/0 cand=0/42
- WORSE --boki-agency-check main=124/0 cand=0/80
- WORSE --boki-dash-check main=0/13 cand=0/204
- NEW-RED --boki-follow-check main=0/0 cand=0/50
- WORSE --boki-quirks-check main=124/0 cand=124/2
- WORSE --boki-react-check main=124/0 cand=0/2
- NEW-RED --boki-system-check main=0/0 cand=0/59
- NEW-RED --boss-check main=0/0 cand=1/22
- WORSE --bot-names-check main=124/0 cand=0/30
- NEW-RED --bot-sanity-check main=0/0 cand=1/27
- NEW-RED --box-revive-check main=0/0 cand=0/6
- NEW-RED --breakables-check main=0/0 cand=0/1
- WORSE --build-hold-check main=1/224 cand=0/14061
- FIXED --cam-framing-check main=127/ cand=0/0
- WORSE --clip-check main=127/0 cand=127/1
- WORSE --clip-live-sable-check main=127/0 cand=127/1
- FIXED --clutter-check main=127/ cand=0/0
- WORSE --crouch-check main=127/0 cand=127/2
- FIXED --dead-kmoves-check main=127/ cand=0/0
- FIXED --evo-check main=127/ cand=0/0
- FIXED --far-props-check main=127/ cand=0/0
- WORSE --hitch-check main=127/6 cand=127/13
- WORSE --kit-parity-check main=127/0 cand=127/1
- WORSE --mantle-check main=127/0 cand=127/1
- WORSE --mantle-look-check main=127/2 cand=127/3
- FIXED --mesh-arrays-check main=127/ cand=0/0
- WORSE --motley-live-check main=127/0 cand=127/1
- FIXED --nook-check main=127/ cand=0/0
- FIXED --quality-check main=127/ cand=0/0
- FIXED --race-check main=127/ cand=0/0
- WORSE --rank-ui-check main=127/0 cand=127/1
- WORSE --title-check main=127/8 cand=127/10
- WORSE --warden-glb-check main=127/0 cand=127/1
- WORSE --warden-model-check main=127/0 cand=127/3

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
- merged   ext/mystery-egg-basket 434c6d34
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
- SKIPPED  ext/game-rules-nov8 14a02c65 conflicts: scripts/home/home.gd scripts/kin/kin_spec.gd scripts/match/boki_rig.gd scripts/ui/hatch.gd
- SKIPPED  ext/rimewright-skate 9e4710f6 conflicts: art/wardens/claire/claire.glb
- SKIPPED  ext/no-rolling-rebased 9b7b5315 conflicts: scripts/home/home.gd scripts/main.gd scripts/match/match.gd tools/style_baseline.json
- merged   ext/kael-ult-reset-rebased-rebased 76a5d931
- SKIPPED  ext/warden-bob-damp ba31e5ef conflicts: docs/art/ANIM_QUALITY_AUDIT.md
- SKIPPED  ext/meeko-rmb-motion-rebased-rebased e5587292 conflicts: art/wardens/pip/pip.glb briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd tools/archer_bulwark_combo_check.gd tools/care_combo_check.gd tools/support_check.gd
- SKIPPED  ext/parity-snowglide-rebased-rebased 4a2175ee conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd
- SKIPPED  ext/stuck-integ-cb5c1c27 da83863d conflicts: tools/empty_shots.gd
- merged   ext/anim-time-motley-rebased a8828080
- SKIPPED  ext/utilities-shops-rebased f8af39fa conflicts: content/maps/hollowcrown.json tools/make_hollowcrown.py
- merged   ext/ravel-v2-pass3-rebased fdf76e24
- SKIPPED  ext/release-integ-0243-rebased-rebased f9a818e7 conflicts: briefs/CAMERA_DEPTH.md briefs/camera_depth/after_a_edge.png briefs/camera_depth/after_a_edge.png.import briefs/camera_depth/after_b_step.png briefs/camera_depth/after_b_step.png.import briefs/camera_depth/after_c_low.png briefs/camera_depth/after_c_low.png.import content/archetypes/archer.json content/archetypes/tender.json content/rules/warden_anim/cinder.json docs/ABILITIES.md docs/art/wardens/CLIPS.md docs/heroes/archer.md docs/heroes/dash_interactions.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/heroes/warden_clips.gd scripts/home/home.gd scripts/match/dash_reset.gd tools/archer_bulwark_combo_check.gd tools/support_check.gd
- SKIPPED  ext/anim-idle-walk-gap b0a1e984 conflicts: tools/anim_shots.gd
- merged   ext/anim-slide-tune 7a782345
- SKIPPED  ext/stuck-integ-e28956f8 73b2cdce conflicts: tools/empty_shots.gd
- SKIPPED  ext/cinder-sable-polish-rebased f3bf0403 conflicts: art/wardens/sable/sable.glb tools/art1/sable_paint.py
- merged   ext/dex-branch-forms 8713093c
- SKIPPED  ext/types-standard-names 8b43b206 conflicts: content/abilities_v2/moon_mark.json
- SKIPPED  ext/vex-dash-parity-rebased bee6851e conflicts: docs/VFX_QUALITY.md docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd
- SKIPPED  ext/ostra-gait 89acba32 conflicts: art/wardens/ostra/IMPORT.md art/wardens/ostra/ostra.glb docs/art/ANIM_QUALITY_AUDIT.md tools/anim_shots.gd tools/art1/ostra_clips.py
- SKIPPED  ext/training-area-1108 7ad4602a conflicts: scripts/home/home.gd scripts/match/arena.gd scripts/ui/hud.gd scripts/ui/overlay.gd scripts/ui/title.gd tools/farm_start_check.gd tools/wall_size_check.gd
- SKIPPED  ext/farm-tut-tools-cam-rebased b6db8443 conflicts: content/rules/farm_tutorial.json
- SKIPPED  ext/tender-gait-rebased cdeada2b conflicts: docs/art/ANIM_QUALITY_AUDIT.md
- merged   ext/boki-caecilith-v3 07cc5327
- SKIPPED  ext/grimble-stretch-v2-rebased 88c75bf3 conflicts: art/wardens/dredge/dredge.glb tools/art1/grimble_clips.py tools/art1/skin_relax.py
- SKIPPED  ext/anim-idle-walk-gap-rebased bed93d5d conflicts: docs/art/ANIM_QUALITY_AUDIT.md tools/anim_shots.gd
- SKIPPED  ext/warden-bob-damp-rebased 92882bf3 conflicts: docs/art/ANIM_QUALITY_AUDIT.md tools/anim_shots.gd
- SKIPPED  ext/types-standard-names-rebased 8b43b206 conflicts: content/abilities_v2/moon_mark.json
- SKIPPED  ext/rimewright-skate-rebased 4012ef0c conflicts: art/wardens/claire/claire.glb
- SKIPPED  ext/ostra-gait-rebased b1940393 conflicts: art/wardens/ostra/IMPORT.md art/wardens/ostra/ostra.glb docs/art/ANIM_QUALITY_AUDIT.md tools/anim_shots.gd tools/art1/ostra_clips.py
- SKIPPED  ext/grimble-nose-1109 5e98228d conflicts: art/wardens/dredge/dredge.glb
- merged   ext/text-lore-pronouns bb53dc23
- SKIPPED  ext/albert-size-boop 3d7539d7 conflicts: art/wardens/breaker/breaker.glb docs/heroes/bulwark.md tools/archer_bulwark_combo_check.gd tools/style_baseline.json
- SKIPPED  ext/meeko-rmb-motion-rebased-rebased-rebased 14f79f40 conflicts: art/wardens/pip/pip.glb tools/care_combo_check.gd
- SKIPPED  ext/motley-seed-fizzle 9f521695 conflicts: docs/heroes/ostra.md
- merged   ext/sable-dagger-barriers aea633f6
- SKIPPED  ext/ui-sfx-set 8661028e conflicts: scripts/ui/ui.gd
- merged   ext/boki-net-roundtrip 3a4766db
- merged   ext/audio-ult-telegraphs c5a6d4ac
- merged   ext/dash-curve-fit d2adc51b
- SKIPPED  ext/hit-feedback-pass d6b86ff8 conflicts: docs/HUD.md tools/archer_bulwark_combo_check.gd
- SKIPPED  ext/reset-cue 1dd752d4 conflicts: scripts/arch/kits/bulwark_kit.gd scripts/arch/kits/juggernaut_kit.gd
- merged   ext/ult-ranks-spec 8bca2384
- SKIPPED  ext/overlay-typed-calls f2da08d2 conflicts: scripts/ui/overlay.gd
- merged   ext/abilities-one-version 4f5a660e
- merged   ext/hit-shape-check 831e2a6a
- SKIPPED  ext/perf-actors-1108-rebased 1fe0f809 conflicts: content/rules/tuning.json scripts/match/world.gd
- SKIPPED  ext/grimble-parity-verify d94bc776 conflicts: content/archetypes/dredge.json docs/heroes/dredge.md
- SKIPPED  ext/no-dash-bursts-audit 9ef878c5 conflicts: scripts/arch/kits/ostra_kit.gd
- SKIPPED  ext/flow-rows-source dd2c83be conflicts: docs/heroes/dash_interactions.md
- SKIPPED  ext/legendary-spawns a2607c39 conflicts: scripts/ui/dex_view.gd
- merged   ext/vision-spec d9d41aa6
- SKIPPED  ext/mc-fix-1109 b0aec3ec conflicts: tools/anim_shots.gd
- SKIPPED  ext/recast-sounds 82a248d9 conflicts: docs/AUDIO.md scripts/arch/arch_kit.gd scripts/arch/kits/ashwick_kit.gd scripts/arch/kits/bulwark_kit.gd scripts/arch/kits/mage_kit.gd scripts/arch/kits/ostra_kit.gd
- SKIPPED  ext/move-sfx-positional 0e4199c4 conflicts: tools/match_audio_check.gd
- merged   ext/sparkle-e-verify 63b2b614
- SKIPPED  ext/sfx-strike-sync 61619d99 conflicts: docs/AUDIO.md scripts/arch/kits/dolm_kit.gd
- SKIPPED  ext/ability-bar-charges 82671dee conflicts: docs/HUD.md
- SKIPPED  ext/meeko-rmb-verify eba7147e conflicts: art/wardens/pip/pip.glb content/rules/tuning.json content/rules/warden_anim/pip.json scripts/heroes/warden_clips.gd tools/care_combo_check.gd
- merged*  ext/anim-crouch-rest 40fa4d29 (registry/credits/generated auto-resolved)
- merged   ext/cc-plate-timer eba4ad3d
- SKIPPED  ext/menus-more e4c3b969 conflicts: scripts/home/home.gd scripts/ui/overlay.gd scripts/ui/title.gd
- SKIPPED  ext/anim-arm-sable a176bc76 conflicts: scripts/heroes/warden_clips.gd
- merged   ext/loot-open-times a72d6028
- SKIPPED  ext/arrival-declutter f0414bde conflicts: scripts/ui/results.gd
- SKIPPED  ext/creator-trim 532aad47 conflicts: scripts/ui/hatch.gd tools/empty_shots.gd
- merged   ext/anim-arm-sparkle 816d9405
- merged   ext/farm-loop aa4ec457
- SKIPPED  ext/perf-fight-pools 907d1f4e conflicts: scripts/match/fx.gd tools/perf_bench.gd
- SKIPPED  ext/recast-marker-b 2e37a330 conflicts: docs/HUD.md scripts/arch/kits/breah_hop.gd
- SKIPPED  ext/vfx-quality-motley 06b96077 conflicts: docs/VFX_QUALITY.md scripts/arch/kits/kit_looks.gd scripts/arch/kits/ostra_kit.gd
- SKIPPED  ext/anim-hand-tenzo f44d7629 conflicts: art/wardens/tarek/tarek.glb content/rules/warden_anim/tarek.json docs/art/ANIM_QUALITY_AUDIT.md
- SKIPPED  ext/egg-picker-preview eeea08d2 conflicts: scripts/ui/dex_view.gd tools/empty_shots.gd
- merged   ext/combo-marks-a 08dfc092
- SKIPPED  ext/recast-marker-a 87df6c5c conflicts: docs/HUD.md scripts/arch/kits/ostra_kit.gd scripts/arch/kits/tender_kit.gd scripts/arch/kits/thief_kit.gd
- SKIPPED  ext/anim-arm-kael 7707b024 conflicts: answer.md content/rules/tuning.json content/rules/warden_anim/kael.json docs/art/ANIM_QUALITY_AUDIT.md docs/art/wardens/CLIPS.md scripts/arch/kits/juggernaut_kit.gd scripts/heroes/warden_clips.gd
- merged   ext/kael-chain-length b763a57c
- SKIPPED  ext/anim-time-kael bfe9512d conflicts: docs/art/wardens/CLIPS.md scripts/heroes/warden_clips.gd
- SKIPPED  ext/kit-parity-refresh-1 4791eb5c conflicts: docs/KIT_PARITY.md
- SKIPPED  ext/split-ui be393e41 conflicts: docs/HUD.md scripts/home/home.gd scripts/home/home_black_market.gd scripts/home/home_market.gd scripts/home/home_trade.gd scripts/home/hunter_pick_row.gd scripts/social/town.gd scripts/ui/about_view.gd scripts/ui/dex_view.gd scripts/ui/hatch.gd scripts/ui/incubator_view.gd scripts/ui/kin_reveal.gd scripts/ui/overlay.gd scripts/ui/prematch_view.gd scripts/ui/ui.gd scripts/ui/work_view.gd tools/style_baseline.json
- merged   ext/supervive-movement 161907a5
- SKIPPED  ext/kit-parity-refresh-2 f1efc51a conflicts: docs/KIT_PARITY.md
- SKIPPED  ext/vfx-origin-v2 53e5acdc conflicts: scripts/arch/kits/thief_kit.gd
- SKIPPED  ext/cooldown-parity-verify 2be9877c conflicts: content/archetypes/ashwick.json content/archetypes/dredge.json content/archetypes/juggernaut.json content/archetypes/rimewright.json docs/heroes/juggernaut.md docs/heroes/thief.md
- SKIPPED  ext/anim-mantle-2 097e8054 conflicts: art/wardens/claire/claire.glb art/wardens/dredge/dredge.glb art/wardens/hem/hem.glb art/wardens/tarek/tarek.glb tools/anim_shots.gd
- merged   ext/lace-phasewalk-verify 728a6c83
- SKIPPED  ext/anim-mantle-3 c55ef02e conflicts: art/wardens/breaker/breaker.glb art/wardens/ostra/ostra.glb art/wardens/ryzz/ryzz.glb art/wardens/sable/sable.glb tools/anim_shots.gd
- SKIPPED  ext/supervive-impact ac32fb46 conflicts: scripts/heroes/warden_clips.gd scripts/match/ent.gd
- merged   ext/ui-first15-audit d0e20ae4
- SKIPPED  ext/train-rank-controls ca639526 conflicts: scripts/home/home.gd scripts/match/arena.gd scripts/ui/hud.gd scripts/ui/overlay.gd scripts/ui/title.gd tools/farm_start_check.gd tools/wall_size_check.gd
- SKIPPED  ext/vfx-pass b7d8bf3c conflicts: docs/heroes/bulwark.md docs/heroes/dredge.md docs/heroes/gunslinger.md docs/heroes/tender.md docs/heroes/thief.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd scripts/arch/kits/kit_looks.gd scripts/arch/kits/mage_kit.gd scripts/arch/kits/thief_kit.gd scripts/match/hunter.gd scripts/match/match.gd tools/dancer_jug_check.gd tools/hero_combo_check.gd
- SKIPPED  ext/remove-hex 16e00c03 conflicts: scripts/arch/kits/tender_kit.gd
- SKIPPED  ext/albert-parity-verify b69c6ca3 conflicts: docs/heroes/bulwark.md scripts/arch/kits/bulwark_kit.gd
- merged*  ext/remove-class-ults e7455a85 (registry/credits/generated auto-resolved)
- SKIPPED  ext/anim-react-audit 807d9386 conflicts: art/wardens/breaker/breaker.glb art/wardens/claire/claire.glb art/wardens/hem/hem.glb art/wardens/ryzz/ryzz.glb art/wardens/sable/sable.glb tools/anim_shots.gd
- SKIPPED  ext/combo-marks-b 0bd68fb6 conflicts: tools/combo_mark_shots.gd
- merged*  ext/remove-downed-crawl 0af36e37 (registry/credits/generated auto-resolved)
- SKIPPED  ext/anim-mantle-1 218d107f conflicts: art/wardens/cinder/cinder.glb art/wardens/kael/kael.glb art/wardens/pip/pip.glb art/wardens/vex/vex.glb content/rules/warden_anim/cinder.json docs/art/wardens/CLIPS.md tools/anim_shots.gd
- merged*  ext/boki-quirks a56585dc (registry/credits/generated auto-resolved)
- SKIPPED  ext/anim-hand-albert 2182efdc conflicts: art/wardens/breaker/breaker.glb docs/art/ANIM_QUALITY_AUDIT.md
- merged   ext/boki-wisp-look b50ee9a4
- SKIPPED  ext/particle-budget 3d9f8186 conflicts: content/rules/tuning.json scripts/core/settings.gd scripts/match/world.gd tools/perf_bench.gd
- merged   ext/gaps-gunslinger 9960559b
- merged   ext/perf-texture-import 93e254d1
- merged   ext/gaps-archer 82dd65e1
- merged   ext/gaps-ashwick 148f071b
- SKIPPED  ext/gaps-juggernaut b4f362a7 conflicts: tools/dancer_jug_check.gd
- merged   ext/cancel-matrix-a 8c7ac1d8
- SKIPPED  ext/flow-hold-rows 12524595 conflicts: docs/heroes/dash_interactions.md
- SKIPPED  ext/prematch-declutter 6fa7df1f conflicts: scripts/ui/prematch_view.gd tools/prematch_check.gd tools/prematch_shots.gd
- SKIPPED  ext/knock-mass-parity 294a1ad1 conflicts: tools/move_feel_check.gd
- merged   ext/ult-lock-parity 5a1cdb43
- merged   ext/gaps-bulwark 628060d6
- merged   ext/gaps-mage ac71b638
- merged   ext/gaps-dredge a7b27a3b
- merged   ext/fire-move-parity 3715c5ca
- merged   ext/gaps-rimewright f9995df0
- SKIPPED  ext/dash-curves-b d7e92419 conflicts: tools/move_feel_check.gd
- merged   ext/gaps-tender 025ef9ff
- merged   ext/gaps-dolm 3cd4fd12
- SKIPPED  ext/cancel-matrix-c b5679fb8 conflicts: docs/heroes/tender.md
- SKIPPED  ext/cancel-matrix-b 107436fd conflicts: content/archetypes/dolm.json
- merged   ext/gaps-ostra fa2b3347
- SKIPPED  ext/gaps-thief 61390af6 conflicts: docs/heroes/thief.md
- SKIPPED  ext/fire-on-run-layer d733b077 conflicts: docs/art/wardens/CLIPS.md
- SKIPPED  ext/glide-dive-land e4081da3 conflicts: docs/MOVEMENT_FEEL.md scripts/match/glide_dive.gd scripts/match/hunter.gd tools/move_feel_check.gd
- merged   ext/hp-parity 32b81c98
- SKIPPED  ext/damage-ratio-audit a89a84be conflicts: content/archetypes/rimewright.json
- merged   ext/hair-typed-calls c60bae22
- merged   ext/anim-gait-albert 4cbdf0d2
- SKIPPED  ext/parity-no-riders-meeko 0d617787 conflicts: docs/heroes/tender.md
- merged   ext/neve-scarf-ribbon fd5c099d
- SKIPPED  ext/checks-out-of-main 26941068 conflicts: tools/style_baseline.json
- SKIPPED  ext/dash-glide-all 07957d14 conflicts: docs/heroes/dash_interactions.md scripts/match/hunter.gd tools/airdash_glide_check.gd
- SKIPPED  ext/parity-no-riders-grimble-tenzo 7b130d5c conflicts: content/archetypes/dolm.json content/archetypes/dredge.json docs/heroes/dolm.md docs/heroes/dredge.md
- merged   ext/cc-parity 61ecea13
- SKIPPED  ext/hitstop-parity c9315676 conflicts: scripts/heroes/warden_clips.gd scripts/match/ent.gd
- SKIPPED  ext/heal-shield-parity 42dced79 conflicts: content/archetypes/juggernaut.json
- SKIPPED  ext/sable-marks-resets 4061d74e conflicts: docs/heroes/thief.md
- merged   ext/input-mode-matrix d24364ed
- merged   ext/boki-lines-only 7744bce2
- merged   ext/cursor-clamp-parity f506a47c
- SKIPPED  ext/lmb-range-parity d1aa84b8 conflicts: docs/KIT_PARITY.md docs/heroes/tender.md
- SKIPPED  ext/move-sfx-positional-rebased 0e4199c4 conflicts: tools/match_audio_check.gd
- SKIPPED  ext/anim-glide-pose 6a1a62f0 conflicts: content/rules/warden_anim/hem.json content/rules/warden_anim/pip.json content/rules/warden_anim/vex.json docs/art/wardens/CLIPS.md scripts/heroes/warden_clips.gd
- SKIPPED  ext/barrier-block-parity e77b7510 conflicts: docs/heroes/rimewright.md scripts/combat/verbs.gd
- SKIPPED  ext/cast-move-a d2c55518 conflicts: content/archetypes/juggernaut.json scripts/arch/kits/juggernaut_kit.gd tools/dancer_jug_check.gd
- SKIPPED  ext/anim-jump-land 7cf10446 conflicts: docs/art/wardens/CLIPS.md
- merged   ext/cast-move-b dc3918bf
- SKIPPED  ext/vfx-rescore 13b16730 conflicts: docs/VFX_QUALITY.md
- merged   ext/wallkick-all bee700ed
- merged   ext/prematch-declutter-rebased 8f1ccd06
- merged   ext/wisp-ability-spec e4cdee4b
- SKIPPED  ext/anim-blend-snap e84d7794 conflicts: content/rules/warden_anim/claire.json content/rules/warden_anim/pip.json content/rules/warden_anim/vex.json docs/MOVEMENT_FEEL.md scripts/heroes/warden_clips.gd
- SKIPPED  ext/sneak-speed-source 178d0d38 conflicts: content/rules/hunter_move.json
- merged   ext/ads-camera-spec aa3b039d
- SKIPPED  ext/air-cast-b 0d624344 conflicts: docs/heroes/bulwark.md docs/heroes/thief.md
- SKIPPED  ext/cooldown-start-parity ef38f084 conflicts: content/archetypes/dolm.json docs/KIT_PARITY.md
- merged   ext/consumable-parity 8e174b79
- merged   ext/dead-kmoves eb4ac257
- SKIPPED  ext/telegraph-one-system f2447492 conflicts: docs/AIMKIT.md
- SKIPPED  ext/air-cast-a c5f1e389 conflicts: docs/heroes/ashwick.md docs/heroes/gunslinger.md docs/heroes/juggernaut.md docs/heroes/tender.md
- SKIPPED  ext/anim-stomp-drink-2 197cb1d6 conflicts: art/wardens/claire/claire.glb art/wardens/dredge/dredge.glb art/wardens/pip/pip.glb art/wardens/tarek/tarek.glb scripts/heroes/warden_clips.gd
- SKIPPED  ext/revive-source-numbers 6c27f4f5 conflicts: docs/DEATH_AND_REVIVE.md
- merged*  ext/revive-online c71a5e5f (registry/credits/generated auto-resolved)
- SKIPPED  ext/anim-stomp-drink-1 26c04bc1 conflicts: art/wardens/cinder/cinder.glb art/wardens/hem/hem.glb art/wardens/kael/kael.glb art/wardens/vex/vex.glb content/rules/warden_anim/cinder.json content/rules/warden_anim/kael.json
- SKIPPED  ext/parity-interrupts-b 1d8cccab conflicts: docs/heroes/rimewright.md tools/hero_combo_check.gd
- SKIPPED  ext/level-growth-parity 051b53e2 conflicts: tools/style_baseline.json
- SKIPPED  ext/parity-interrupts-a a65a3b10 conflicts: content/archetypes/tender.json docs/heroes/tender.md scripts/arch/kits/tender_kit.gd
- SKIPPED  ext/parity-ability-speeds-a db9d8235 conflicts: docs/heroes/gunslinger.md
- SKIPPED  ext/blight-damage-source 894e1f29 conflicts: scripts/core/net.gd scripts/match/match.gd scripts/ui/full_map.gd scripts/ui/hud.gd
- SKIPPED  ext/parity-recast-windows bb46589c conflicts: content/archetypes/rimewright.json docs/KIT_PARITY.md docs/heroes/rimewright.md
- SKIPPED  ext/parity-passives-a 2d4ecc48 conflicts: content/archetypes/dolm.json docs/heroes/archer.md docs/heroes/gunslinger.md docs/heroes/tender.md tools/support_check.gd
- SKIPPED  ext/parity-passives-b 27859689 conflicts: content/archetypes/dredge.json docs/heroes/ostra.md tools/care_combo_check.gd
- SKIPPED  ext/status-body-looks bfddc657 conflicts: scripts/arch/kit_status.gd scripts/arch/kits/dolm_kit.gd tools/hero_vfx_check.gd
- SKIPPED  ext/parity-cc-lockouts 123ec0cb conflicts: scripts/match/hunter.gd
- SKIPPED  ext/parity-iframes 583b7cfd conflicts: scripts/arch/kits/rimewright_kit.gd scripts/combat/fields.gd tools/archer_bulwark_combo_check.gd
- SKIPPED  ext/edge-knock-parity 0286f0cf conflicts: docs/MOVEMENT_FEEL.md
- SKIPPED  ext/parity-ability-speeds-b 1398826f conflicts: docs/heroes/rimewright.md
- merged   ext/parity-aegis-block e17eaf4b
- merged   ext/hold-pose-audit 54d5cb16
- SKIPPED  ext/parity-status-stacking bafa3ff4 conflicts: scripts/arch/kits/rimewright_kit.gd scripts/match/ent.gd tools/style_baseline.json
- SKIPPED  ext/parity-dot-ticks d211db73 conflicts: content/archetypes/ashwick.json docs/KIT_PARITY.md docs/heroes/archer.md docs/heroes/ashwick.md
- SKIPPED  ext/parity-ally-effects a106b5f1 conflicts: tools/dredge_combo_check.gd
- SKIPPED  ext/parity-motley-float f48366ab conflicts: docs/KIT_PARITY.md docs/heroes/ostra.md tools/ostra_combo_check.gd
- SKIPPED  ext/anim-stop-start 6e24c8d2 conflicts: docs/art/ANIM_QUALITY_AUDIT.md scripts/heroes/warden_clips.gd tools/anim_shots.gd
- SKIPPED  ext/anim-stomp-drink-3 fb4769a7 conflicts: art/wardens/breaker/breaker.glb art/wardens/ostra/ostra.glb art/wardens/ryzz/ryzz.glb art/wardens/sable/sable.glb scripts/heroes/warden_clips.gd tools/anim_shots.gd
- merged*  ext/parity-glide-spike 6e73f977 (registry/credits/generated auto-resolved)
- SKIPPED  ext/parity-ability-pierce 76de01e1 conflicts: docs/KIT_PARITY.md docs/heroes/archer.md docs/heroes/rimewright.md
- SKIPPED  ext/parity-ability-elevation 27befb05 conflicts: scripts/arch/arch_kit.gd
- SKIPPED  ext/docs-heroes-sweep 19fb5b69 conflicts: docs/heroes/archer.md docs/heroes/ashwick.md docs/heroes/bulwark.md docs/heroes/dredge.md docs/heroes/juggernaut.md docs/heroes/rimewright.md docs/heroes/tender.md docs/heroes/thief.md
- SKIPPED  ext/kit-text-clear-fixes d18df02c conflicts: content/archetypes/dolm.json content/archetypes/dredge.json content/archetypes/gunslinger.json content/archetypes/rimewright.json
- SKIPPED  ext/parity-jump-hold 3df49503 conflicts: content/rules/hunter_move.json docs/MOVEMENT_FEEL.md scripts/match/hunter.gd scripts/match/hunter_move.gd tools/move_feel_check.gd
- SKIPPED  ext/parity-ability-abyss 880f7c90 conflicts: docs/heroes/rimewright.md tools/archer_bulwark_combo_check.gd tools/dredge_combo_check.gd
- SKIPPED  ext/dash-interactions-refresh 9577cce4 conflicts: docs/KIT_PARITY.md docs/heroes/dash_interactions.md
- SKIPPED  ext/kit-number-sources eb424bbb conflicts: content/archetypes/ashwick.json content/archetypes/juggernaut.json content/archetypes/rimewright.json content/archetypes/thief.json
- SKIPPED  ext/vfx-origin-v2-rebased 82998a01 conflicts: content/vfx/rimewright.json docs/HERO_VFX.md docs/heroes/bulwark.md docs/heroes/dredge.md docs/heroes/gunslinger.md docs/heroes/tender.md docs/heroes/thief.md scripts/arch/kits/gunslinger_kit.gd scripts/arch/kits/gunslinger_ult.gd scripts/arch/kits/kit_looks.gd scripts/arch/kits/mage_kit.gd scripts/arch/kits/mage_sky.gd scripts/arch/kits/thief_kit.gd scripts/match/hunter.gd scripts/match/match.gd tools/dancer_jug_check.gd tools/hero_combo_check.gd tools/hero_vfx_check.gd
- SKIPPED  ext/parity-body-collision 81bbacb1 conflicts: content/rules/hunter_move.json docs/HITBOX_SIZE.md scripts/match/match.gd
- SKIPPED  ext/anim-dash-travel bf0ee5b7 conflicts: content/rules/warden_anim/claire.json docs/art/wardens/CLIPS.md scripts/heroes/warden_clips.gd
- SKIPPED  ext/strike-reach-heights 75a9a854 conflicts: art/wardens/breaker/breaker.glb
- merged*  ext/anim-dash-directional 8f377ea5 (registry/credits/generated auto-resolved)
- SKIPPED  ext/no-reload-path 94833fb5 conflicts: docs/BOKI_TALK.md scripts/core/kin_speak.gd scripts/core/net.gd scripts/match/hunter.gd scripts/match/hunter_anim.gd scripts/match/kin_voice.gd tools/ashwick_combo_check.gd
- SKIPPED  ext/anim-prop-handoff 98b984dd conflicts: docs/KIT_PARITY.md tools/dancer_jug_check.gd
- merged*  ext/parity-camera-framing 575798bd (registry/credits/generated auto-resolved)
- SKIPPED  ext/parity-abyss-fall d8f415ad conflicts: content/rules/hunter_move.json
- SKIPPED  ext/dash-nd-rows-b 7b951f8f conflicts: docs/KIT_PARITY.md docs/heroes/dash_interactions.md
- SKIPPED  ext/dash-nd-rows-a 34fe3667 conflicts: docs/KIT_PARITY.md docs/heroes/dash_interactions.md
- merged   ext/grimble-unspread-bonus 1592226f
- SKIPPED  ext/anim-key-pose-read c2d9b1d8 conflicts: art/wardens/cinder/cinder.glb art/wardens/claire/claire.glb art/wardens/pip/pip.glb art/wardens/ryzz/ryzz.glb
- SKIPPED  ext/boki-wisp-proto 6309f625 conflicts: scripts/core/net.gd tools/perf_bench.gd
- SKIPPED  ext/lace-hawk-sense f6704237 conflicts: docs/heroes/archer.md scripts/arch/kits/archer_kit.gd
- SKIPPED  ext/parity-jump-pads a2715040 conflicts: content/rules/hunter_move.json scripts/match/hunter.gd
- SKIPPED  ext/side-cue-telegraphs 11f0ce0b conflicts: scripts/arch/oomph.gd tools/clarity_check.gd
- SKIPPED  ext/status-net-check 8051a436 conflicts: scripts/arch/kit_status.gd scripts/core/net.gd
- merged   ext/perf-merge-drops 12cd2ac4
- merged   ext/archetypes-cant-list cc018210
- merged*  ext/ledge-walkoff-check b1303f94 (registry/credits/generated auto-resolved)
- SKIPPED  ext/input-latency-check 7618748a conflicts: docs/MOVEMENT_FEEL.md
- merged   ext/parity-bench 8b51d963
- SKIPPED  ext/air-cast-poses cf02665e conflicts: content/rules/warden_anim/cinder.json content/rules/warden_anim/claire.json content/rules/warden_anim/pip.json content/rules/warden_anim/sable.json content/rules/warden_anim/vex.json docs/art/wardens/CLIPS.md
- SKIPPED  ext/kael-riposte-knock bf1f1f2a conflicts: docs/ARCHETYPES.md scripts/core/net.gd tools/dj_ult_check.gd
- SKIPPED  ext/clip-cadence-check 9e343841 conflicts: content/rules/warden_anim/pip.json content/rules/warden_anim/sable.json scripts/heroes/warden_clips.gd
- SKIPPED  ext/perf-model-drawcalls 411b9d48 conflicts: tools/perf_bench.gd
- SKIPPED  ext/split-kmoves-pin-bjorn 89302ce3 conflicts: docs/heroes/archer.md tools/style_baseline.json
- SKIPPED  ext/shadow-renames-arch 17737fb9 conflicts: tools/style_baseline.json
- SKIPPED  ext/kit-parity-rows-a a39c3ec6 conflicts: content/rules/kit_parity.json docs/ARCHETYPES.md tools/kit_parity_check.gd
- SKIPPED  ext/drop-parity 8a7cbce2 conflicts: docs/MOVEMENT_FEEL.md scripts/match/hunter.gd
- SKIPPED  ext/fsm-m1 be74f3da conflicts: scripts/match/hunter.gd
- SKIPPED  ext/kit-parity-rows-b 61200ccc conflicts: content/rules/kit_parity.json docs/ARCHETYPES.md tools/kit_parity_check.gd
- merged   ext/decisions-hero-asserts a6d97027
- SKIPPED  ext/glider-heat-parity e8de9552 conflicts: scripts/match/hunter.gd scripts/match/hunter_move.gd tools/glider_heat_check.gd
- SKIPPED  ext/perf-occluders 35216364 conflicts: scripts/core/settings.gd
- SKIPPED  ext/secondary-motion-settle 362c30a0 conflicts: content/rules/warden_anim/kael.json
- SKIPPED  ext/slam-follow-through 95a835c7 conflicts: scripts/heroes/warden_clips.gd
- SKIPPED  ext/split-warden-glb cdad2bfe conflicts: tools/style_baseline.json
- SKIPPED  ext/anim-foot-plant 78034f12 conflicts: tools/perf_bench.gd
- SKIPPED  ext/split-lairs 1605c918 conflicts: scripts/match/lairs.gd tools/style_baseline.json
- SKIPPED  ext/kit-text-numbers 9cc9fe9f conflicts: content/archetypes/archer.json content/archetypes/juggernaut.json
- SKIPPED  ext/recast-buffer-expired 83bed4bc conflicts: content/rules/tuning.json docs/ARCHETYPES.md scripts/arch/arch_kit.gd scripts/arch/kits/ashwick_kit.gd scripts/arch/kits/mage_kit.gd
- merged   ext/garden-base-mode 08480be9
- merged*  ext/remote-anim-check faf7ebfe (registry/credits/generated auto-resolved)
- SKIPPED  ext/hero-docs-sync-b 03f75a8f conflicts: docs/heroes/archer.md docs/heroes/dredge.md docs/heroes/tender.md
- SKIPPED  ext/camp-parity b761adb7 conflicts: scripts/match/mob.gd tools/perf_bench.gd
- SKIPPED  ext/hero-docs-sync-a 40512360 conflicts: docs/heroes/bulwark.md docs/heroes/dolm.md docs/heroes/gunslinger.md docs/heroes/rimewright.md
- merged*  ext/bot-kit-use-a 0d9d0a5b (registry/credits/generated auto-resolved)
- SKIPPED  ext/wisp-summon bbfbf5d9 conflicts: scripts/core/net.gd tools/perf_bench.gd
- SKIPPED  ext/sfx-boki-wire dd32b83b conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/sfx-boki-type-cues ebb7c17d conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/glide-cast-rules f8f23597 conflicts: docs/heroes/dash_interactions.md tools/gen_wiki.py
- SKIPPED  ext/garden-away-card b0d47480 conflicts: scripts/ui/results.gd
- SKIPPED  ext/duel-ring-online 4b27b61b conflicts: export_presets.cfg scripts/home/home.gd scripts/match/arena.gd scripts/ui/hud.gd scripts/ui/overlay.gd scripts/ui/title.gd tools/arena_check.gd tools/farm_start_check.gd tools/wall_size_check.gd
- merged*  ext/online-displace-100ms 86dc2ae7 (registry/credits/generated auto-resolved)
- SKIPPED  ext/bot-kit-use-b a2dc282d conflicts: docs/BOT_KIT_USE.md scripts/arch/kits/archer_kit.gd
- merged*  ext/garden-toys e4cd252c (registry/credits/generated auto-resolved)
- SKIPPED  ext/garden-lean-foods fe4476cf conflicts: scripts/core/evo.gd
- SKIPPED  ext/wisp-summon-pop a9f367d4 conflicts: scripts/core/net.gd tools/perf_bench.gd
- SKIPPED  ext/garden-race 248a5e90 conflicts: scripts/home/home.gd
- merged*  ext/boki-hit-react 85a8d245 (registry/credits/generated auto-resolved)
- SKIPPED  ext/garden-base-life fa2f391b conflicts: scripts/core/fsm.gd scripts/home/home.gd
- SKIPPED  ext/sfx-low-hp 44dfb9f3 conflicts: docs/HUD.md tools/sfx_set_check.gd
- SKIPPED  ext/sfx-pickups 0bb0bffa conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/sfx-gloves ae71a781 conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/sfx-ambience 7012c20f conflicts: docs/AUDIO.md tools/match_audio_check.gd tools/sfx_set_check.gd
- SKIPPED  ext/kit-error-sweep 577c21ec conflicts: scripts/arch/kits/rimewright_kit.gd
- SKIPPED  ext/online-feel-100ms 0bf60cf9 conflicts: docs/ONLINE_FEEL.md
- SKIPPED  ext/glide-text-fix d0a0d906 conflicts: content/rules/tutorial.json scripts/ui/loading.gd
- merged   ext/ui-team-boki-icons 4e063362
- SKIPPED  ext/perf-visibility-ranges 5397d334 conflicts: scripts/match/world.gd
- SKIPPED  ext/anim-hand-tenzo-rebased f3e36f0e conflicts: content/rules/warden_anim/tarek.json docs/art/ANIM_QUALITY_AUDIT.md
- SKIPPED  ext/tutorial-combat-v2 6e32b64e conflicts: content/archetypes/tender.json content/rules/tutorial.json docs/ABILITIES.md docs/DEATH_AND_REVIVE.md docs/decisions/0022-knock-dash-refresh-assists.md docs/heroes/archer.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/core/care.gd scripts/core/save.gd scripts/heroes/warden_clips.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/match/kin_voice.gd server/README.md server/matchmaker/mm/config.py tools/archer_bulwark_combo_check.gd tools/hero_combo_check.gd tools/kill_reset_check.gd tools/support_check.gd
- SKIPPED  ext/grimble-fist-vfx c9330d01 conflicts: docs/heroes/dredge.md scripts/arch/kits/dredge_kit.gd tools/hero_vfx_reel.gd
- SKIPPED  ext/parity-reel-a 3dad2970 conflicts: tools/hero_vfx_reel.gd
- merged   ext/perf-multimesh e8fc401e
- SKIPPED  ext/albert-size-boop-rebased dc95e0d1 conflicts: docs/heroes/bulwark.md tools/empty_shots.gd
- merged   ext/hunter-wisp-outline 563a1d5b
- SKIPPED  ext/garden-stump-shove 01fff216 conflicts: scripts/home/home.gd
- SKIPPED  ext/garden-base-life-main ebde0fac conflicts: scripts/core/fsm.gd scripts/core/save.gd scripts/home/home.gd
- merged   ext/garden-nook 13e40763
- SKIPPED  ext/ui-safe-area a7576939 conflicts: scripts/ui/hud_panels.gd tools/style_baseline.json
- SKIPPED  ext/kael-lunge-length b4ffaa6e conflicts: content/archetypes/juggernaut.json content/rules/dash_feel.json docs/heroes/juggernaut.md tools/dancer_jug_check.gd
- SKIPPED  ext/tutorial-idle-check 19a355ea conflicts: scripts/match/tutorial.gd
- merged   ext/tutorial-idle-check-stacked 5eb5d26d
- SKIPPED  ext/ui-loot-panel 1121df7c conflicts: tools/loot_full_check.gd
- SKIPPED  ext/garden-journal a9369b3d conflicts: scripts/core/evo.gd scripts/core/game.gd scripts/home/home.gd scripts/ui/overlay.gd
- SKIPPED  ext/garden-trust c2cf2a8f conflicts: scripts/core/care.gd scripts/home/home.gd
- merged   ext/sparkle-rmb-knock 4696270e
- merged*  ext/garden-race-main 9ab5f8fa (registry/credits/generated auto-resolved)
- SKIPPED  ext/tenzo-cone-grow dafcc39d conflicts: content/archetypes/dolm.json scripts/arch/kits/dolm_kit.gd
- SKIPPED  ext/ui-knock-callout 29e8d9c2 conflicts: docs/HUD.md scripts/match/match.gd
- merged   ext/parity-reel-b fdda9e82
- SKIPPED  ext/boki-type-vfx 1b445d3b conflicts: content/abilities_v2/moon_mark.json
- SKIPPED  ext/hot-zone 4fd803ae conflicts: scripts/core/net.gd scripts/match/biome_run.gd scripts/match/hot_zone.gd tools/hot_zone_check.gd
- merged   ext/glide-steer-parity b512c864
- SKIPPED  ext/aim-height 3e886ea0 conflicts: docs/MOVEMENT_FEEL.md
- SKIPPED  ext/level-pace d0960b1c conflicts: scripts/match/match.gd
- SKIPPED  ext/recast-hud-cue 1fd9f80f conflicts: scripts/arch/kits/mage_kit.gd scripts/arch/kits/mage_ult.gd scripts/ui/recast_cue.gd tools/recast_cue_check.gd tools/recast_cue_shots.gd
- SKIPPED  ext/sfx-boki-types feedefeb conflicts: content/abilities_v2/moon_mark.json scripts/core/sfx.gd tools/sfx_set_check.gd
- merged   ext/levelup-vfx 621d7308
- SKIPPED  ext/ui-settings-trim 789776b4 conflicts: docs/MOVEMENT_FEEL.md scripts/core/game.gd scripts/home/home.gd scripts/match/hunter.gd scripts/match/match.gd scripts/ui/loading.gd scripts/ui/overlay.gd scripts/ui/title.gd
- SKIPPED  ext/sfx-hit-targets 03ecb2fc conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/ui-death-recap 82d66357 conflicts: docs/DEATH_AND_REVIVE.md
- SKIPPED  ext/hunter-first-hints ed972535 conflicts: content/archetypes/ashwick.json content/archetypes/dredge.json content/archetypes/juggernaut.json content/archetypes/tender.json content/archetypes/thief.json content/rules/tutorial.json docs/ABILITIES.md docs/DEATH_AND_REVIVE.md docs/decisions/0022-knock-dash-refresh-assists.md docs/heroes/archer.md docs/heroes/dredge.md docs/heroes/tender.md scripts/arch/kits/pin_spirit.gd scripts/arch/kits/tender_kit.gd scripts/core/care.gd scripts/core/save.gd scripts/heroes/warden_clips.gd scripts/match/dash_reset.gd scripts/match/hunter.gd scripts/match/kin_voice.gd scripts/match/tutorial.gd server/README.md server/matchmaker/mm/config.py tools/archer_bulwark_combo_check.gd tools/hero_combo_check.gd tools/kill_reset_check.gd tools/support_check.gd
- SKIPPED  ext/anim-arm-motley b450797a conflicts: docs/art/ANIM_QUALITY_AUDIT.md
- merged*  ext/first-match-guide a574ed65 (registry/credits/generated auto-resolved)
- SKIPPED  ext/boki-state-clips 186f29a2 conflicts: scripts/match/boki_rig.gd scripts/match/kin.gd
- SKIPPED  ext/sfx-pickups-gloves d9a23794 conflicts: tools/sfx_set_check.gd
- merged   ext/tutorial-wisp-spec e8d99c58
- SKIPPED  ext/landing-recovery b1927cf0 conflicts: content/rules/hunter_move.json docs/MOVEMENT_FEEL.md scripts/match/hunter.gd
- SKIPPED  ext/split-exits 3687cf51 conflicts: tools/style_baseline.json
- SKIPPED  ext/no-hardcoded-keys 41597c5f conflicts: scripts/ui/prematch_view.gd
- merged*  ext/remote-smooth 78afc5ab (registry/credits/generated auto-resolved)
- SKIPPED  ext/sable-v2-art d8d2fce7 conflicts: art/portraits/thief.jpg art/portraits/thief_splash.jpg content/rules/portraits.json
- SKIPPED  ext/art1-clip-port 0494c83a conflicts: art/wardens/breaker/breaker.glb art/wardens/claire/claire.glb art/wardens/hem/hem.glb art/wardens/ryzz/ryzz.glb art/wardens/sable/sable.glb tools/anim_shots.gd
- SKIPPED  ext/hit-spark-targets e07148de conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/sfx-warnings-boki 83bb59a9 conflicts: tools/sfx_set_check.gd
- SKIPPED  ext/bot-kit-use 12d904a0 conflicts: tools/style_baseline.json
- merged   ext/ui-inventory 61db0289
- SKIPPED  ext/train-moving-dummies 4c80dbdd conflicts: scripts/home/home.gd scripts/main.gd scripts/match/arena.gd scripts/ui/hud.gd scripts/ui/overlay.gd scripts/ui/title.gd tools/farm_start_check.gd tools/wall_size_check.gd
- merged   ext/ttk-table 9333571d

Exclusions: ~/bin/merge-exclude.txt on the hetzner box.

## Real-GPU performance (Mac GPU worker, main vs candidate)

| hook | main rc / FAIL / secs | candidate rc / FAIL / secs |
|---|---|---|
| `--hitch-check` | 1 / 31 / 328 (pc-MRROBOTO) | 1 / 1635 / 80 (mac-Naruto-Founder) |
| `--load-check` | 1 / 1 / 270 (mac-Naruto-Founder) | 1 / 19 / 78 (rp1-0) |
| `--perf-bench` | 0 / 0 / 126 (pc-MRROBOTO) | 0 / 4714 / 60 (mac-Naruto-Founder) |
| `--title-check` | 124 / 8 / 1509 (rp1-1) | 124 / 12 / 1506 (rp1-0) |

Frame-time lines from the logs (lines that mention ms or fps; first 12 per run):

**`--hitch-check` main** (job 20261109-152828-08992)
```
Quality: auto picked low (load benchmark 83.0 ms a frame)
HITCH loading screen 36270 ms over 336 frames, worst 970 ms, 280 shader compiles; build steps: build.warm_up 14972, build.hunters 6977, world.terrain 1393, build.generate 1070, build.spawns 1040, worl
HITCH phase first      16 frames  median     48 ms  worst    112 ms  shader compiles 4
HITCH phase planning   25 frames  median     47 ms  worst     99 ms  shader compiles 0
HITCH phase ride       98 frames  median     53 ms  worst    324 ms  shader compiles 5
HITCH phase drop      256 frames  median     58 ms  worst    188 ms  shader compiles 3
HITCH phase land      180 frames  median     81 ms  worst    134 ms  shader compiles 0
HITCH landing stall (worst frame in the first 1.5 s on the ground, landed at t=17.52): 87 ms
HITCH start-of-match stall (worst frame from the reveal to the first second of the ride): 112 ms
HITCH       324 ms  ride     t= 4.92  sim 40.7 (+246.5 x6)  vis 3.2  other 7.9  render 13.8  rest 11.6  draws 2580  shader compiles 0  sim sections: bots 33.3, mobs 2.2, interact 1.2, hunters 1.2
HITCH       313 ms  ride     t= 5.02  sim 41.2 (+222.2 x6)  vis 3.6  other 9.6  render 11.6  rest 24.8  draws 2558  shader compiles 0  sim sections: bots 33.7, mobs 2.3, interact 1.3, hunters 1.2
HITCH       301 ms  ride     t= 5.12  sim 50.3 (+212.6 x6)  vis 4.8  other 8.0  render 11.2  rest 13.8  draws 2551  shader compiles 0  sim sections: bots 42.3, mobs 2.5, interact 1.3, hunters 1.2
```

**`--hitch-check` cand** (job 20261109-152828-05402)
```
Quality: auto picked very_low (load benchmark 50.6 ms a frame)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
              [5] _process (res://tools/hitch_check.gd:187)
```

**`--load-check` main** (job 20261109-152828-10487)
```
Quality: auto picked low (load benchmark 53.2 ms a frame)
LOAD total 18568 ms over 301 frames; longest frame 479 ms (279 ms outside drawing); 35 frames over 100 ms
LOAD       295     247      48    333     0  c0   Spawning                 [slice 244 ms]
LOAD       283     279       3     85     0  c0   Spawning                 [slice 278 ms]
LOAD       257     253       4    261     0  c0   Spawning                 [slice 250 ms]
LOAD       229     211      18    333     0  c0   Spawning                 [slice 209 ms]
```

**`--load-check` cand** (job 20261109-152828-06627)
```
Quality: auto picked very_low (load benchmark 73.3 ms a frame)
LOAD total 33685 ms over 304 frames; longest frame 3894 ms (1034 ms outside drawing); 37 frames over 100 ms
LOAD      1070    1034      37     36     0  c9   Building the map         [slice 12444 ms]  [slice 198 ms]
LOAD       786     756      30    464     0  c5   Spawning                 [slice 726 ms]
LOAD       466     453      13    464     0  c4   Spawning                 [slice 449 ms]
LOAD       361     358       3    118     0  c1   Spawning                 [slice 344 ms]
```

**`--perf-bench` main** (job 20261109-152828-26371)
```
BENCH match: 1827 frames, wall avg 48.4 ms, p99 91.5 ms (1% low 6.8 fps)
BENCH match cpu: match script avg 26.47 ms p99 58.72 ms, process 75.85 ms, hud 6.15 ms, render cpu 7.76 ms
BENCH farm: 1200 frames, wall avg 7.6 ms, p99 9.5 ms (1% low 98.0 fps)
BENCH farm cpu: match script avg 30.85 ms p99 187.00 ms, process 30.85 ms, hud 3.12 ms, render cpu 5.46 ms
```

**`--perf-bench` cand** (job 20261109-152828-23187)
```
BENCH hitch t=1.37 180 ms (script 13.9), new nodes: { "Node3D:KitLooks": 1, "Node3D:@Node3D": 1, "MeshInstance3D:Spin": 1, "MeshInstance3D:@MeshInstance3D": 4, "PanelContainer:@PanelContainer": 1, "La
BENCH hitch t=2.67 145 ms (script 13.1), new nodes: { "Node3D:VVFx": 1, "MeshInstance3D:@MeshInstance3D": 2 }
BENCH hitch t=9.40 226 ms (script 13.8), new nodes: { "MeshInstance3D:@MeshInstance3D": 10, "PanelContainer:@PanelContainer": 1, "Label:@Label": 1, "Node3D:@Node3D": 7, "MeshInstance3D:Head": 7, "Mesh
BENCH hitch t=9.72 143 ms (script 15.4), new nodes: { "MeshInstance3D:@MeshInstance3D": 11, "Node3D:@Node3D": 1, "MeshInstance3D:Body": 1, "GPUParticles3D:@GPUParticles3D": 1 }
BENCH hitch t=11.68 128 ms (script 6.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 1 }
BENCH hitch t=11.78 131 ms (script 6.8), new nodes: { "MeshInstance3D:@MeshInstance3D": 8 }
BENCH hitch t=12.75 175 ms (script 10.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 8, "Node3D:Wisp": 1, "MeshInstance3D:Body": 1, "AudioStreamPlayer:@AudioStreamPlayer": 1 }
BENCH hitch t=14.78 117 ms (script 3.5), new nodes: { "MeshInstance3D:@MeshInstance3D": 2 }
BENCH match: 1848 frames, wall avg 21.1 ms, p99 83.4 ms (1% low 4.7 fps)
BENCH match cpu: match script avg 6.37 ms p99 14.62 ms, process 61.94 ms, hud 1.12 ms, render cpu 9.02 ms, gpu 0.00 ms
BENCH farm: 1200 frames, wall avg 8.5 ms, p99 15.0 ms (1% low 28.9 fps)
BENCH farm cpu: match script avg 35.50 ms p99 165.49 ms, process 35.50 ms, hud 0.35 ms, render cpu 0.66 ms, gpu 0.00 ms
```

**`--title-check` main** (job 20261109-152828-20727)
```
TITLE ok   [high] frame budget: 3.68 ms average, 4.37 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 5.02 ms average, 6.28 ms p95 (budget 12 ms)
```

**`--title-check` cand** (job 20261109-152828-10632)
```
TITLE ok   [high] frame budget: 3.92 ms average, 4.62 ms p95 (budget 12 ms)
TITLE ok   [low] frame budget: 5.24 ms average, 5.96 ms p95 (budget 12 ms)
```

## Release dry-run (Windows and macOS exports, release templates 4.6.2.stable)

| project | preset | result | size / first ERROR |
|---|---|---|---|
| game | Windows | pass | 487M |
| game | macOS | pass | 317M |
| launcher | Windows | pass | 101M |
| launcher | macOS | pass | 63M |

All exports passed.
