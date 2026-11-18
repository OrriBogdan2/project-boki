# Stuck-branch triage, ext/stuck-integ-b771bcef (2026-11-18)

Base: ext/mc-20261117-1720 + origin/main 2fe9f2772c. Each listed branch that still exists (508 of 772 names), its newest READY sha (else its tip), against this base.

Classes: IN-BASE 8 LANDED-ELSEWHERE 19 MERGED 3 NEEDS-PORT 181 NEEDS-REDO 1 OBSOLETE-ART 3 OWNED 45 STALE-SYSTEM 193 SUPERSEDED 55

LANDED-ELSEWHERE = 90%+ of its added text lines are already in the base (its intent landed by a port). STALE-SYSTEM = most of its added lines go to files main has since deleted. NEEDS-PORT = real missing work; port it onto main in a fresh branch, never merge the old tip (each one conflicts with main). Nothing is deleted here.

| branch | class |
|---|---|
| ext/agent-briefs | IN-BASE (nothing to merge) |
| ext/airdash-anims-1108 | OWNED by an open integration READY: ext/stuck-integ-b7a5717c@586fb5124:False ext/stuck-integ-09e533a4@7aca15496:False ext/stuck-integ-f60f9dd7@b764e6e38:Fal |
| ext/albert-size-boop-rebased | SUPERSEDED by a landed integration READY: ext/reset-cue-rebased@0fc62a451:False ext/albert-size-boop@c117f697d:True |
| ext/anim-boki-cast-rebased | NEEDS-PORT (123miss lines missing, 44% landed; top: scripts/match/kin.gd:32 tools/boki_system_check.gd:19) |
| ext/anim-boki-hit-faint | STALE-SYSTEM (most added lines go to files main deleted: 161gone vs 126miss) |
| ext/anim-boki-idle | SUPERSEDED (checked by hand: all of it on main) |
| ext/anim-boki-react-three | STALE-SYSTEM (most added lines go to files main deleted: 3922gone vs 1733miss) |
| ext/anim-boki-slide-starters | SUPERSEDED by a landed integration READY: ext/anim-boki-run-reach@93a3abb83:True |
| ext/anim-boki-state-cover | LANDED-ELSEWHERE (96% of its lines on the base, 7miss) |
| ext/anim-boki-stop-turn | NEEDS-PORT (192miss lines missing, 13% landed; top: tools/boki_anim_audit.gd:89 scripts/match/boki_rig.gd:67) |
| ext/anim-bul-guard-remote | NEEDS-PORT (91miss lines missing, 18% landed; top: tools/archer_bulwark_combo_check.gd:27 docs/heroes/bulwark.md:26) |
| ext/anim-cancel-blend | NEEDS-PORT (395miss lines missing, 7% landed; top: tools/clip_check.gd:136 scripts/heroes/warden_clips.gd:70) |
| ext/anim-clip-checks-data | NEEDS-REDO (checked by hand: clip_data refactor of a check main rewrote; TRI_BUDGET 15000 vs 80000) |
| ext/anim-clip-checks-data-w0246 | NEEDS-PORT (5091miss lines missing, 81% landed; top: tools/clip_check.gd:221 scripts/ui/mask_beat.gd:139) |
| ext/anim-dash-clips-motley-grimble | NEEDS-PORT (94miss lines missing, 68% landed; top: tools/art1/grimble_clips.py:22 docs/ANIM_COVERAGE.md:21) |
| ext/anim-dir-all-1112 | OWNED by an open integration READY: ext/anim-loco-slip@a57292b83:False ext/anim-loco-slip@ce2acdf18:False |
| ext/anim-dirloops-pelvis | SUPERSEDED by a landed integration READY: ext/anim-dirloops-cinder-sable-2@b26ac5af1:True |
| ext/anim-downed | STALE-SYSTEM (most added lines go to files main deleted: 105gone vs 57miss) |
| ext/anim-empty-garden | LANDED-ELSEWHERE (91% of its lines on the base, 99miss) |
| ext/anim-fusion-remote | SUPERSEDED by a landed integration READY: ext/fusion-states-fix@098c4cf25:True |
| ext/anim-gait-speed | STALE-SYSTEM (most added lines go to files main deleted: 221gone vs 72miss) |
| ext/anim-gil-clips | SUPERSEDED by a landed integration READY: ext/gil-train-1112@268cb4076:True |
| ext/anim-gil-grabbag | SUPERSEDED by a landed integration READY: ext/gil-train-1112@268cb4076:True |
| ext/anim-grimble-hook-prop | STALE-SYSTEM (most added lines go to files main deleted: 3481gone vs 3103miss) |
| ext/anim-guardian-stance | STALE-SYSTEM (most added lines go to files main deleted: 2213gone vs 1071miss) |
| ext/anim-hazard-moves | STALE-SYSTEM (most added lines go to files main deleted: 5156gone vs 4465miss) |
| ext/anim-land-beat | STALE-SYSTEM (most added lines go to files main deleted: 3460gone vs 3171miss) |
| ext/anim-loco-dir-albert | STALE-SYSTEM (most added lines go to files main deleted: 497gone vs 464miss) |
| ext/anim-loco-dir-grimble-sparkle | STALE-SYSTEM (most added lines go to files main deleted: 528gone vs 465miss) |
| ext/anim-loco-dir-kael-crouch | STALE-SYSTEM (most added lines go to files main deleted: 538gone vs 466miss) |
| ext/anim-loco-dir-last | STALE-SYSTEM (most added lines go to files main deleted: 576gone vs 546miss) |
| ext/anim-loco-snap-startstop | STALE-SYSTEM (most added lines go to files main deleted: 735gone vs 578miss) |
| ext/anim-loco-starts | STALE-SYSTEM (most added lines go to files main deleted: 703gone vs 487miss) |
| ext/anim-meeko-crouch-stride | OWNED by an open integration READY: ext/stuck-integ-c2a69297@bdf4194b4:False |
| ext/anim-meeko-stride | STALE-SYSTEM (most added lines go to files main deleted: 495gone vs 476miss) |
| ext/anim-meeko-tiptoe | OBSOLETE-ART (glb clips, pre-v95) |
| ext/anim-react-2-rebased | STALE-SYSTEM (most added lines go to files main deleted: 513gone vs 83miss) |
| ext/anim-react-settle-neve-tenzo | STALE-SYSTEM (most added lines go to files main deleted: 592gone vs 170miss) |
| ext/anim-release-sync-meeko-motley | STALE-SYSTEM (most added lines go to files main deleted: 3655gone vs 3157miss) |
| ext/anim-remote-stomp | OWNED by an open integration READY: ext/anim-rocket-ride@7fadb612d:False ext/anim-rocket-ride@676084ad8:False |
| ext/anim-result-poses | NEEDS-PORT (119miss lines missing, 17% landed; top: scripts/heroes/warden_beats.gd:43 tools/clip_check.gd:14) |
| ext/anim-results-stage-beats | STALE-SYSTEM (most added lines go to files main deleted: 3447gone vs 3051miss) |
| ext/anim-revive-12 | STALE-SYSTEM (most added lines go to files main deleted: 161gone vs 137miss) |
| ext/anim-rocket-ride | STALE-SYSTEM (most added lines go to files main deleted: 673gone vs 606miss) |
| ext/anim-skin-relax-b | OWNED by an open integration READY: ext/stretch-reds@4b1068002:False ext/anim-skin-relax-slice@0070f1c96:False ext/skin-relax-four@15a5d398e:False |
| ext/anim-skin-relax-slice | OWNED by an open integration READY: ext/anim-skin-relax-b@408431967:False ext/skin-relax-slice@75c5ddf2e:False |
| ext/anim-stomp-batch-a | STALE-SYSTEM (most added lines go to files main deleted: 684gone vs 464miss) |
| ext/anim-stomp-batch-b | STALE-SYSTEM (most added lines go to files main deleted: 1249gone vs 579miss) |
| ext/anim-stomp-per-hunter | STALE-SYSTEM (most added lines go to files main deleted: 583gone vs 425miss) |
| ext/anim-stop-on-stride | STALE-SYSTEM (most added lines go to files main deleted: 3460gone vs 3291miss) |
| ext/anim-stop-start | NEEDS-PORT (172miss lines missing, 29% landed; top: docs/art/ANIM_QUALITY_AUDIT.md:44 tools/anim_audit.gd:41) |
| ext/anim-strafe-back | NEEDS-PORT (249miss lines missing, 65% landed; top: tools/anim_audit.gd:69 docs/art/ANIM_QUALITY_AUDIT.md:39) |
| ext/anim-stretch-starters | SUPERSEDED by a landed integration READY: ext/anim-skin-relax-slice@0070f1c96:False ext/anim-skin-relax-c@391066c95:True |
| ext/anim-summon-clips | STALE-SYSTEM (most added lines go to files main deleted: 495gone vs 118miss) |
| ext/anim-swim-reds | STALE-SYSTEM (most added lines go to files main deleted: 5159gone vs 4487miss) |
| ext/anim-tenzo-boulder-sync | STALE-SYSTEM (most added lines go to files main deleted: 3653gone vs 3120miss) |
| ext/anim-timing-gunslinger | OWNED by an open integration READY: ext/stuck-integ-b7a5717c@58e2df0da:False |
| ext/anim-utility-poses-2 | STALE-SYSTEM (most added lines go to files main deleted: 1503gone vs 176miss) |
| ext/anim-w0246-blender-rows | STALE-SYSTEM (most added lines go to files main deleted: 3584gone vs 3261miss) |
| ext/art1-kael-2 | SUPERSEDED by a landed integration READY: ext/stuck-integ-e28956f8@73b2cdcee:False ext/stuck-integ-e2561d23@7e87fcf67:False ext/stuck-integ-d4379965@d13794ed3:Tru |
| ext/barrier-block-parity | SUPERSEDED by a landed integration READY: ext/combat-wall-surfaces@356eb1854:True |
| ext/belt-move-port | OWNED by an open integration READY: ext/ui-loot-compare@6098f8e96:False |
| ext/blight-nests | LANDED-ELSEWHERE (96% of its lines on the base, 33miss) |
| ext/body6-picks-apply | OBSOLETE-ART (pre-v95 model) |
| ext/boki-downed-port | STALE-SYSTEM (most added lines go to files main deleted: 90gone vs 63miss) |
| ext/boki-downed-pose-rebased | STALE-SYSTEM (most added lines go to files main deleted: 347gone vs 145miss) |
| ext/boki-gait | SUPERSEDED by a landed integration READY: ext/boki-gait-audit@ff954be2f:True |
| ext/bot-hazard-route | STALE-SYSTEM (most added lines go to files main deleted: 5006gone vs 4244miss) |
| ext/bot-kael-1111 | NEEDS-PORT (248miss lines missing, 26% landed; top: tools/dancer_jug_check.gd:59 scripts/arch/kits/juggernaut_kit.gd:57) |
| ext/bot-stomp-1111 | STALE-SYSTEM (most added lines go to files main deleted: 486gone vs 359miss) |
| ext/bots-human-1111-feel | STALE-SYSTEM (most added lines go to files main deleted: 640gone vs 385miss) |
| ext/cancel-blend-port | NEEDS-PORT (5410miss lines missing, 80% landed; top: tools/clip_check.gd:363 scripts/ui/mask_beat.gd:139) |
| ext/carry-out-slot | NEEDS-PORT (213miss lines missing, 1% landed; top: scripts/match/capture.gd:54 tools/capture_check.gd:37) |
| ext/carry-two-1111 | STALE-SYSTEM (most added lines go to files main deleted: 229gone vs 172miss) |
| ext/carry-two-in | STALE-SYSTEM (most added lines go to files main deleted: 194gone vs 56miss) |
| ext/cc-stacking-rule | STALE-SYSTEM (most added lines go to files main deleted: 151gone vs 81miss) |
| ext/char-creator-v2-1111 | STALE-SYSTEM (most added lines go to files main deleted: 1295gone vs 422miss) |
| ext/cinder-flue-clips | NEEDS-PORT (15miss lines missing, 28% landed; top: tools/ashwick_ult_check.gd:6 docs/heroes/ashwick.md:3) |
| ext/clarity-1112 | STALE-SYSTEM (most added lines go to files main deleted: 388gone vs 207miss) |
| ext/combat-blight-endgame | LANDED-ELSEWHERE (94% of its lines on the base, 42miss) |
| ext/combat-bots-downed | STALE-SYSTEM (most added lines go to files main deleted: 3054gone vs 1904miss) |
| ext/combat-daze-status | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@e4bd8b05b:True ext/stuck-integ-62ec7ba9@d05ab3bec:True ext/stuck-integ-f1f63a7a@ddae66af6:True |
| ext/combat-grimble-ult-clarity | NEEDS-PORT (127miss lines missing, 73% landed; top: scripts/match/body_tell.gd:80 tools/clarity_check.gd:11) |
| ext/combat-hazard-ward-stack | STALE-SYSTEM (most added lines go to files main deleted: 4811gone vs 3894miss) |
| ext/combat-mob-boss-fsm | NEEDS-PORT (330miss lines missing, 7% landed; top: scripts/match/mob.gd:137 scripts/match/boss.gd:122) |
| ext/combat-mob-camp-root | NEEDS-PORT (2072miss lines missing, 60% landed; top: docs/KIT_PARITY.md:127 tools/drop_check.gd:88) |
| ext/combat-motley-swept | NEEDS-PORT (2075miss lines missing, 60% landed; top: docs/KIT_PARITY.md:127 tools/drop_check.gd:88) |
| ext/combat-neve-lmb-torn | SUPERSEDED by a landed integration READY: ext/stuck-integ-c2a69297@bdf4194b4:False ext/stuck-integ-62ec7ba9@e4bd8b05b:True ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/combat-ostra-seed-burn | SUPERSEDED by a landed integration READY: ext/stuck-integ-c2a69297@bdf4194b4:False ext/stuck-integ-62ec7ba9@e4bd8b05b:True ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/combat-sable-lmb-hits | NEEDS-PORT (696miss lines missing, 28% landed; top: scripts/match/body_tell.gd:77 scripts/arch/kits/mage_kit.gd:70) |
| ext/combat-steal-boss-bonus | NEEDS-PORT (654miss lines missing, 25% landed; top: tools/camps_check.gd:235 scripts/match/drop_feel.gd:113) |
| ext/combat-ttk-parity-1112 | NEEDS-PORT (302miss lines missing, 40% landed; top: tools/ttk_check.gd:71 docs/TTK.md:45) |
| ext/combat-vex-cone-net | NEEDS-PORT (220miss lines missing, 4% landed; top: scripts/arch/kits/gunslinger_kit.gd:99 tools/remote_anim_check.gd:89) |
| ext/combat-w0246-bot-reds | NEEDS-PORT (2078miss lines missing, 60% landed; top: docs/KIT_PARITY.md:127 tools/drop_check.gd:88) |
| ext/combat-w0246-support-reds | NEEDS-PORT (2563miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:237) |
| ext/combat-zone-stage-dmg | STALE-SYSTEM (most added lines go to files main deleted: 904gone vs 241miss) |
| ext/cooldown-gate-1111 | STALE-SYSTEM (most added lines go to files main deleted: 1206gone vs 435miss) |
| ext/creator-sex-distinct-shots | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/cursor-confine | LANDED-ELSEWHERE (96% of its lines on the base, 4miss) |
| ext/dash-momentum-1111 | STALE-SYSTEM (most added lines go to files main deleted: 222gone vs 64miss) |
| ext/dash-no-rings-reel | NEEDS-PORT (2573miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/docs-decision-numbers | STALE-SYSTEM (most added lines go to files main deleted: 577gone vs 74miss) |
| ext/dredge-auto-rebased | STALE-SYSTEM (most added lines go to files main deleted: 100gone vs 70miss) |
| ext/early-camps-0244 | NEEDS-PORT (1075miss lines missing, 15% landed; top: tools/drop_check.gd:327 scripts/match/drop_feel.gd:119) |
| ext/early-camps-bots-a3 | STALE-SYSTEM (most added lines go to files main deleted: 940gone vs 602miss) |
| ext/early-camps-bots-c | STALE-SYSTEM (most added lines go to files main deleted: 1322gone vs 1127miss) |
| ext/early-camps-map-ui | NEEDS-PORT (1064miss lines missing, 15% landed; top: tools/drop_check.gd:327 tools/camps_check.gd:136) |
| ext/early-drop-height | NEEDS-PORT (473miss lines missing, 28% landed; top: scripts/match/drop_feel.gd:113 tools/camps_check.gd:111) |
| ext/early-guarded-boki | NEEDS-PORT (626miss lines missing, 23% landed; top: tools/camps_check.gd:151 scripts/match/drop_feel.gd:113) |
| ext/early-hard-landing | OWNED by an open integration READY: ext/feel-landing-recovery@79806c95d:False |
| ext/early-steal-window | NEEDS-PORT (638miss lines missing, 21% landed; top: tools/camps_check.gd:173 scripts/match/drop_feel.gd:113) |
| ext/early-wisp-refund | STALE-SYSTEM (most added lines go to files main deleted: 1956gone vs 1634miss) |
| ext/extra-kin-v2-dedupe | NEEDS-PORT (3792miss lines missing, 0% landed; top: content/kin/floenatee.json:79 content/kin/heatherhorn.json:78) |
| ext/farm-boki-xp-curve | NEEDS-PORT (517miss lines missing, 68% landed; top: tools/evo_check.gd:131 scripts/core/evo.gd:82) |
| ext/farm-build-polish-1111 | STALE-SYSTEM (most added lines go to files main deleted: 1343gone vs 487miss) |
| ext/farm-carry-arrival | STALE-SYSTEM (most added lines go to files main deleted: 271gone vs 185miss) |
| ext/farm-carry-boki | STALE-SYSTEM (most added lines go to files main deleted: 326gone vs 48miss) |
| ext/farm-carry-trail-0245 | NEEDS-PORT (57miss lines missing, 5% landed; top: tools/carry_boki_check.gd:45 scripts/home/home_carry.gd:6) |
| ext/farm-feed-bowl | NEEDS-PORT (123miss lines missing, 37% landed; top: scripts/home/feed_bowl.gd:96 scripts/core/evo.gd:6) |
| ext/farm-feed-bowl-port | STALE-SYSTEM (most added lines go to files main deleted: 3253gone vs 1452miss) |
| ext/farm-games-picker-base | NEEDS-PORT (65miss lines missing, 31% landed; top: tools/minigame_hub_check.gd:28 scripts/home/minigame_hub.gd:26) |
| ext/farm-garden-default | STALE-SYSTEM (most added lines go to files main deleted: 550gone vs 35miss) |
| ext/farm-greet-home | NEEDS-PORT (112miss lines missing, 6% landed; top: tools/base_life_check.gd:65 scripts/home/base_life.gd:18) |
| ext/farm-new-toy | NEEDS-PORT (281miss lines missing, 40% landed; top: tools/garden_day_check.gd:231 docs/GARDEN.md:20) |
| ext/farm-respec | NEEDS-PORT (79miss lines missing, 5% landed; top: tools/garden_items_check.gd:37 scripts/core/garden_items.gd:17) |
| ext/farm-sick-recover-port | STALE-SYSTEM (most added lines go to files main deleted: 3253gone vs 1537miss) |
| ext/farm-soul-echo | STALE-SYSTEM (most added lines go to files main deleted: 5860gone vs 4180miss) |
| ext/farm-unmasked-feet | SUPERSEDED by a landed integration READY: ext/anim-unmasked-feet@9ad351002:True |
| ext/farm-w0246-flakes | STALE-SYSTEM (most added lines go to files main deleted: 3265gone vs 1572miss) |
| ext/feel-buffers-leftovers | OWNED by an open integration READY: ext/feel-buffers-tuning@8e477fe7a:False ext/stuck-integ-1324d019@71c53a6dc:False |
| ext/feel-buffers-tuning | OWNED by an open integration READY: ext/feel-buffers-leftovers@4bf174a71:False ext/stuck-integ-1324d019@71c53a6dc:False |
| ext/feel-cam-mode | NEEDS-PORT (2630miss lines missing, 67% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/feel-cast-lock-buffer | OWNED by an open integration READY: ext/stuck-integ-be6ffab8@d4ec3f8b9:False |
| ext/feel-chain-sweep-1111 | STALE-SYSTEM (most added lines go to files main deleted: 708gone vs 668miss) |
| ext/feel-cinder-poof-cancel | NEEDS-PORT (2561miss lines missing, 69% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/feel-dash-wall-slide-rebased | NEEDS-PORT (164miss lines missing, 72% landed; top: tools/dash_wall_check.gd:84 tools/wall_slide_check.gd:31) |
| ext/feel-gil-sweeps | SUPERSEDED by a landed integration READY: ext/gil-train-1112@268cb4076:True |
| ext/feel-glide-state | NEEDS-PORT (2791miss lines missing, 67% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:240) |
| ext/feel-home-fixed-step | NEEDS-PORT (193miss lines missing, 71% landed; top: tools/move_rate_check.gd:98 scripts/home/farm_step.gd:47) |
| ext/feel-home-mantle-shared | STALE-SYSTEM (most added lines go to files main deleted: 359gone vs 198miss) |
| ext/feel-landing-recovery | NEEDS-PORT (4777miss lines missing, 64% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:297) |
| ext/feel-one-tuning-home | NEEDS-PORT (570miss lines missing, 3% landed; top: content/rules/tuning.json:235 tools/move_feel_check.gd:74) |
| ext/feel-online-kitefall | SUPERSEDED by a landed integration READY: ext/feel-kitefall-net@262171752:True |
| ext/feel-ranges-on-screen | STALE-SYSTEM (most added lines go to files main deleted: 565gone vs 250miss) |
| ext/feel-remote-move-clear | NEEDS-PORT (56miss lines missing, 19% landed; top: tools/remote_anim_check.gd:33 scripts/arch/arch_kit.gd:19) |
| ext/feel-reversal-2 | NEEDS-PORT (2621miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:240) |
| ext/feel-sparkle-wirerun-glide | NEEDS-PORT (2581miss lines missing, 69% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/feel-summon-on-g | NEEDS-PORT (230miss lines missing, 59% landed; top: tools/cast_predict_check.gd:56 scripts/match/kin_summon.gd:29) |
| ext/feel-tenzo-hop-glide | NEEDS-PORT (2565miss lines missing, 69% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/feel-trigger-edge | NEEDS-PORT (89miss lines missing, 5% landed; top: docs/DASHES_AND_ABILITY_FEEL.md:75 tools/archer_bulwark_combo_check.gd:5) |
| ext/feel-ui-focus | NEEDS-PORT (199miss lines missing, 3% landed; top: scripts/home/home.gd:49 scripts/social/town.gd:21) |
| ext/feel-vex-e-recovery | NEEDS-PORT (115miss lines missing, 19% landed; top: tools/venator_parity_check.gd:42 tools/hero_combo_check.gd:19) |
| ext/feel-w0246-camera | NEEDS-PORT (2607miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/feel-w0246-combo-reds | OWNED by an open integration READY: ext/w0246-feel@2cfa95239:False |
| ext/feel-w0246-frame-reds | NEEDS-PORT (2705miss lines missing, 67% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:237) |
| ext/feel-w0246-glide-reds | NEEDS-PORT (2582miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:239) |
| ext/feel-w0246-knock-reds | NEEDS-PORT (2586miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:243) |
| ext/fold-anim-boki-1112 | NEEDS-PORT (475miss lines missing, 60% landed; top: scripts/match/boki_rig.gd:100 tools/boki_anim_audit.gd:91) |
| ext/fold-anim-time-1112 | NEEDS-PORT (427miss lines missing, 42% landed; top: tools/mage_anim_time_check.gd:135 tools/vex_anim_time_check.gd:125) |
| ext/fps-feel | STALE-SYSTEM (most added lines go to files main deleted: 169gone vs 30miss) |
| ext/fsm-m1 | NEEDS-PORT (40miss lines missing, 58% landed; top: tools/fsm_check.gd:19 docs/wiki/Rules.md:6) |
| ext/gait-speed-port | NEEDS-PORT (141miss lines missing, 7% landed; top: tools/anim_audit.gd:57 scripts/heroes/warden_gait.gd:45) |
| ext/garden-care-prompt | STALE-SYSTEM (most added lines go to files main deleted: 5243gone vs 3897miss) |
| ext/garden-cinderstep | NEEDS-PORT (128miss lines missing, 6% landed; top: scripts/home/garden_zones.gd:34 tools/shove_check.gd:18) |
| ext/garden-cinderstep-zone-rebased | LANDED-ELSEWHERE (91% of its lines on the base, 769miss) |
| ext/garden-fresh-hour | NEEDS-PORT (376miss lines missing, 6% landed; top: tools/garden_day_check.gd:363 scripts/home/home_market.gd:6) |
| ext/garden-hub-move | NEEDS-PORT (206miss lines missing, 50% landed; top: tools/garden_zones_check.gd:109 scripts/home/garden_zones.gd:34) |
| ext/garden-hub-theme | STALE-SYSTEM (most added lines go to files main deleted: 123gone vs 83miss) |
| ext/garden-integrated-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1388gone vs 1040miss) |
| ext/garden-items-form | STALE-SYSTEM (most added lines go to files main deleted: 3253gone vs 1537miss) |
| ext/garden-nav-sweep-rebased | LANDED-ELSEWHERE (90% of its lines on the base, 692miss) |
| ext/garden-play-0246 | OWNED by an open integration READY: ext/stuck-integ-c2a69297@bdf4194b4:False |
| ext/garden-race-ghost | STALE-SYSTEM (most added lines go to files main deleted: 196gone vs 178miss) |
| ext/garden-ridge-rebased | NEEDS-PORT (129miss lines missing, 9% landed; top: tools/race_check.gd:33 scripts/home/base_race.gd:23) |
| ext/garden-sick-recover | STALE-SYSTEM (most added lines go to files main deleted: 3253gone vs 1514miss) |
| ext/garden-soak-zones | NEEDS-PORT (213miss lines missing, 34% landed; top: tools/garden_day_check.gd:165 docs/GARDEN.md:20) |
| ext/garden-voice-ambience-rebased | NEEDS-PORT (31miss lines missing, 88% landed; top: tools/sfx_set_check.gd:16 tools/gen_sfx_boki.py:5) |
| ext/garden-zone-cinderstep | NEEDS-PORT (263miss lines missing, 33% landed; top: tools/perf_bench.gd:39 tools/race_check.gd:33) |
| ext/glider-heat-parity | NEEDS-PORT (47miss lines missing, 62% landed; top: tools/glider_heat_check.gd:34 scripts/match/hunter.gd:6) |
| ext/grimble-fist-vfx-rebased | NEEDS-PORT (282miss lines missing, 3% landed; top: shaders/hero_vfx.gdshader:69 tools/gen_sfx_grimble.py:56) |
| ext/grimble-hook-arm-v2-rebased | SUPERSEDED by a landed integration READY: ext/stuck-integ-d4379965@d13794ed3:True |
| ext/grimble-nose-1109 | OBSOLETE-ART (pre-v95 model) |
| ext/grimble-parity-verify | OWNED by an open integration READY: ext/stuck-integ-c2a69297@b19e256f4:False |
| ext/hatch-mask-polish-1111 | SUPERSEDED by a landed integration READY: ext/sfx-mask-puton@38b346a1c:True ext/sfx-mask-puton@df5e5c4ba:True |
| ext/hero-portraits-a-1114 | IN-BASE (nothing to merge) |
| ext/herovfx-mode-clash | STALE-SYSTEM (most added lines go to files main deleted: 2678gone vs 1724miss) |
| ext/hires-splash-rotation | STALE-SYSTEM (most added lines go to files main deleted: 4862gone vs 3736miss) |
| ext/hitstop-parity | OWNED by an open integration READY: ext/feel-impact-tiers@371e736ab:False |
| ext/hud-g-armor-1111 | STALE-SYSTEM (most added lines go to files main deleted: 36gone vs 26miss) |
| ext/hud-ref-copy-2 | NEEDS-PORT (424miss lines missing, 2% landed; top: scripts/ui/hud_vitals.gd:130 scripts/ui/hud_style.gd:68) |
| ext/hunter-3d-vex-sparkle-1115 | NEEDS-PORT (102miss lines missing, 0% landed; top: art/wardens/src/ryzz_v95.json:49 art/wardens/src/vex_v95.json:34) |
| ext/hunter-first-hints | STALE-SYSTEM (most added lines go to files main deleted: 170gone vs 20miss) |
| ext/hunter-regen-meshy | STALE-SYSTEM (most added lines go to files main deleted: 32gone vs 27miss) |
| ext/hunter-revamp-go | NEEDS-PORT (137miss lines missing, 10% landed; top: tools/art1/kael_source.py:26 tools/art1/kael_finish.py:24) |
| ext/hunters3d-0246 | NEEDS-PORT (108miss lines missing, 88% landed; top: art/wardens/sable/IMPORT.md:31 docs/art/wardens/V95_SWAP.md:26) |
| ext/hushwood-port | STALE-SYSTEM (most added lines go to files main deleted: 3265gone vs 1505miss) |
| ext/idle-archer-rebased | NEEDS-PORT (25miss lines missing, 85% landed; top: tools/art1/posekit.py:20 art/wardens/hem/IMPORT.md:2) |
| ext/idle-bulwark-rebased | NEEDS-PORT (169miss lines missing, 1% landed; top: tools/art1/breaker_anims.py:89 tools/art1/anim_kit.py:47) |
| ext/idle-dredge-rebased | NEEDS-PORT (29miss lines missing, 81% landed; top: tools/art1/posekit.py:20 tools/art1/grimble_clips.py:4) |
| ext/idle-gunslinger-rebased | NEEDS-PORT (32miss lines missing, 83% landed; top: tools/art1/posekit.py:20 docs/art/IDLE_AUDIT.md:6) |
| ext/idle-ostra | NEEDS-PORT (136miss lines missing, 3% landed; top: tools/art1/ostra_clips.py:76 tools/art1/anim_kit.py:23) |
| ext/idle-tender-rebased | NEEDS-PORT (40miss lines missing, 77% landed; top: tools/pip_live_check.gd:17 docs/art/IDLE_AUDIT.md:11) |
| ext/idle-thief-rebased | NEEDS-PORT (210miss lines missing, 0% landed; top: tools/art1/sable_clips.py:189 docs/art/IDLE_AUDIT.md:14) |
| ext/impact-castlock-port | NEEDS-PORT (2690miss lines missing, 67% landed; top: docs/heroes/dash_interactions.md:306 docs/MOVEMENT_FEEL.md:243) |
| ext/impact-strike-port | NEEDS-PORT (2675miss lines missing, 66% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:237) |
| ext/integ-1113-A1 | STALE-SYSTEM (most added lines go to files main deleted: 721gone vs 466miss) |
| ext/integ-1113-D2 | NEEDS-PORT (894miss lines missing, 80% landed; top: tools/style_baseline.json:113 tools/match_audio_check.gd:84) |
| ext/integ-1113-D3 | NEEDS-PORT (1462miss lines missing, 80% landed; top: content/vfx/gil.json:122 tools/style_baseline.json:113) |
| ext/integ-ways-out-0245 | NEEDS-PORT (1111miss lines missing, 19% landed; top: tools/drop_check.gd:328 scripts/match/drop_feel.gd:119) |
| ext/kael-cancels-1111 | NEEDS-PORT (377miss lines missing, 13% landed; top: docs/heroes/juggernaut.md:99 tools/hero_vfx_reel.gd:79) |
| ext/kael-chainlunge-cleanup | NEEDS-PORT (293miss lines missing, 25% landed; top: tools/art1/glb_add_clips.py:67 tools/dancer_jug_check.gd:60) |
| ext/kael-drop-down | NEEDS-PORT (281miss lines missing, 31% landed; top: tools/dancer_jug_check.gd:71 tools/hero_vfx_reel.gd:52) |
| ext/kael-lunge-length-rebased-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1388gone vs 1123miss) |
| ext/kael-owner-1111 | OWNED by an open integration READY: ext/kael-chainlunge-cleanup@d1b9e111b:False ext/vfx-kael-hold-arc@ee0d74669:False |
| ext/kael-rmb-dash-turn | OWNED by an open integration READY: ext/stuck-integ-1324d019@71c53a6dc:False |
| ext/kael-rmb-line-1111 | NEEDS-PORT (177miss lines missing, 20% landed; top: scripts/arch/kits/juggernaut_kit.gd:67 tools/dancer_jug_check.gd:59) |
| ext/knock-moment | NEEDS-PORT (58miss lines missing, 2% landed; top: scripts/match/juice.gd:26 tools/kill_reset_check.gd:23) |
| ext/landing-recovery | OWNED by an open integration READY: ext/feel-landing-recovery@79806c95d:False |
| ext/mantle-look-one-home | SUPERSEDED (checked by hand: main 8085eb5 did the same gender move) |
| ext/mantle-port-a | STALE-SYSTEM (most added lines go to files main deleted: 2042gone vs 1754miss) |
| ext/mantle-port-b | STALE-SYSTEM (most added lines go to files main deleted: 3457gone vs 3180miss) |
| ext/match-cam-wide-1112 | OWNED by an open integration READY: ext/feel-ranges-on-screen@23eac5342:False |
| ext/mc-integ-1112d | LANDED-ELSEWHERE (92% of its lines on the base, 2549miss) |
| ext/meeko-loops-rebake | STALE-SYSTEM (most added lines go to files main deleted: 3566gone vs 3140miss) |
| ext/meeko-rmb-verify-rebased-rebased | STALE-SYSTEM (most added lines go to files main deleted: 200gone vs 125miss) |
| ext/merge-batch-15-1113 | STALE-SYSTEM (most added lines go to files main deleted: 2774gone vs 1867miss) |
| ext/merge-batch-19-1113 | STALE-SYSTEM (most added lines go to files main deleted: 329gone vs 208miss) |
| ext/merge-batch-20-1113 | STALE-SYSTEM (most added lines go to files main deleted: 1951gone vs 1249miss) |
| ext/merge-batch-24-1113 | NEEDS-PORT (291miss lines missing, 89% landed; top: scripts/match/merge_moves.gd:78 tools/remote_anim_check.gd:27) |
| ext/merge-batch-25-1113 | STALE-SYSTEM (most added lines go to files main deleted: 1281gone vs 661miss) |
| ext/merge-batch-6-1113 | STALE-SYSTEM (most added lines go to files main deleted: 1937gone vs 1800miss) |
| ext/merge-lane-boki3d-1114 | MERGED here |
| ext/merge-lane-garden1-1114 | NEEDS-PORT (749miss lines missing, 70% landed; top: tools/race_check.gd:139 tools/garden_day_check.gd:137) |
| ext/merge-lane-hunt4-1115r2 | LANDED-ELSEWHERE (90% of its lines on the base, 748miss) |
| ext/merge-lane-hunters2-1114-b | STALE-SYSTEM (most added lines go to files main deleted: 1076gone vs 635miss) |
| ext/merge-lane-hunters5-1114-b | IN-BASE (nothing to merge) |
| ext/merge-lane-hunters8-1114 | IN-BASE (nothing to merge) |
| ext/merge-lane-tutorial-1114 | IN-BASE (nothing to merge) |
| ext/merge-lane-uihud-1114 | IN-BASE (nothing to merge) |
| ext/merge-lane-vfx2-1114 | IN-BASE (nothing to merge) |
| ext/merge-lane-vfxsfx2-1115 | MERGED here |
| ext/misc-ready-integ | OWNED by an open integration READY: ext/stuck-integ-b7a5717c@586fb5124:False |
| ext/modes-solos-1111 | OWNED by an open integration READY: ext/ui-solos-hud@fb6faf1dd:False ext/ui-solos-hud@cce014039:False |
| ext/momentum-1111 | LANDED-ELSEWHERE (94% of its lines on the base, 15miss) |
| ext/move-feel-1111 | STALE-SYSTEM (most added lines go to files main deleted: 336gone vs 116miss) |
| ext/move-rule-guard-0246 | NEEDS-PORT (2562miss lines missing, 69% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:238) |
| ext/neve-cancels-1111 | STALE-SYSTEM (most added lines go to files main deleted: 416gone vs 100miss) |
| ext/no-dash-bursts-audit-rebased-rebased | LANDED-ELSEWHERE (94% of its lines on the base, 11miss) |
| ext/no-hardcoded-keys | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/no-natural-death-1108 | STALE-SYSTEM (most added lines go to files main deleted: 91gone vs 61miss) |
| ext/online-dash-sweep | NEEDS-PORT (89miss lines missing, 8% landed; top: tools/online_displace_check.gd:59 docs/ONLINE_FEEL.md:30) |
| ext/ostra-gait-rebased | NEEDS-PORT (54miss lines missing, 23% landed; top: tools/art1/ostra_clips.py:29 docs/art/ANIM_QUALITY_AUDIT.md:15) |
| ext/parity-albert-blow-stun | NEEDS-PORT (94miss lines missing, 2% landed; top: docs/heroes/bulwark.md:13 tools/archer_bulwark_combo_check.gd:13) |
| ext/parity-bulwark-guardcut | OWNED by an open integration READY: ext/misc-ready-integ@55446e046:False ext/stuck-integ-e2561d23@7e87fcf67:False ext/stuck-integ-b7a5717c@586fb5124:False |
| ext/parity-kael-clips | SUPERSEDED by a landed integration READY: ext/kael-v2-integ@36c5f7ea7:True ext/kael-kit-integ@36c5f7ea7:True ext/stuck-integ-e2561d23@7e87fcf67:False |
| ext/parity-neve-dart-burst | NEEDS-PORT (65miss lines missing, 10% landed; top: tools/care_combo_check.gd:35 scripts/arch/kits/rimewright_kit.gd:13) |
| ext/parity-pin-kael-drop | SUPERSEDED by a landed integration READY: ext/stuck-integ-c2a69297@b19e256f4:False ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/parity-rider-sweep-0246 | STALE-SYSTEM (most added lines go to files main deleted: 5670gone vs 4335miss) |
| ext/parity-sable-cartwheel-curve | NEEDS-PORT (2593miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:237) |
| ext/parity-sable-e-range | SUPERSEDED by a landed integration READY: ext/stuck-integ-f1f63a7a@42ff6e882:True ext/stuck-integ-f1f63a7a@ddae66af6:True |
| ext/parity-snowglide-rebased-rebased | LANDED-ELSEWHERE (97% of its lines on the base, 604miss) |
| ext/parity-stranded-0246 | STALE-SYSTEM (most added lines go to files main deleted: 5670gone vs 4305miss) |
| ext/parity-verify-0245-slice | NEEDS-PORT (1130miss lines missing, 23% landed; top: tools/drop_check.gd:328 scripts/match/drop_feel.gd:119) |
| ext/particle-budget | NEEDS-PORT (81miss lines missing, 81% landed; top: docs/PERF.md:29 scripts/core/settings.gd:17) |
| ext/perf-owner-hw-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1270gone vs 618miss) |
| ext/perf-train-0245-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1108gone vs 504miss) |
| ext/physics-unify-1111 | STALE-SYSTEM (most added lines go to files main deleted: 476gone vs 65miss) |
| ext/pick-relic-1111 | STALE-SYSTEM (most added lines go to files main deleted: 970gone vs 500miss) |
| ext/portraits-unified | OWNED by an open integration READY: ext/misc-ready-integ@55446e046:False |
| ext/predictable-camps-1111 | NEEDS-PORT (526miss lines missing, 8% landed; top: content/maps/hollowcrown.json:138 scripts/match/camps.gd:125) |
| ext/prematch-safe-720 | NEEDS-PORT (99miss lines missing, 4% landed; top: scripts/ui/prematch_view.gd:84 tools/prematch_check.gd:14) |
| ext/react-2-port | NEEDS-PORT (5094miss lines missing, 80% landed; top: tools/clip_check.gd:221 scripts/ui/mask_beat.gd:139) |
| ext/recast-buffer-expired | STALE-SYSTEM (most added lines go to files main deleted: 157gone vs 33miss) |
| ext/release-integ-0243-rebased-rebased | LANDED-ELSEWHERE (97% of its lines on the base, 618miss) |
| ext/release-integ-0244-a4alt | NEEDS-PORT (4167miss lines missing, 87% landed; top: scripts/home/base_race.gd:316 docs/heroes/dash_interactions.md:99) |
| ext/remote-smooth-reds | NEEDS-PORT (201miss lines missing, 31% landed; top: tools/remote_smooth_check.gd:90 scripts/match/net_smooth.gd:89) |
| ext/rimewright-skate-rebased | NEEDS-PORT (47miss lines missing, 47% landed; top: tools/art1/claire_clips.py:33 docs/art/ANIM_QUALITY_AUDIT.md:11) |
| ext/sable-appeal4 | LANDED-ELSEWHERE (94% of its lines on the base, 42miss) |
| ext/scrapking-lmb-clips | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/select-loading-1111 | NEEDS-PORT (313miss lines missing, 26% landed; top: scripts/ui/prematch_view.gd:192 scripts/ui/loading.gd:66) |
| ext/series-boki-1112 | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/sfx-ability-ready | STALE-SYSTEM (most added lines go to files main deleted: 2738gone vs 1801miss) |
| ext/sfx-beat-resync | NEEDS-PORT (5088miss lines missing, 80% landed; top: tools/clip_check.gd:216 scripts/ui/mask_beat.gd:139) |
| ext/sfx-biome-beds | NEEDS-PORT (282miss lines missing, 5% landed; top: tools/match_audio_check.gd:88 tools/gen_ambience.py:80) |
| ext/sfx-boki-ability-impacts | NEEDS-PORT (85miss lines missing, 76% landed; top: tools/sfx_set_check.gd:24 tools/sfx_silence_audit.gd:24) |
| ext/sfx-boki-state-cues | STALE-SYSTEM (most added lines go to files main deleted: 5931gone vs 3265miss) |
| ext/sfx-boki-state-cues-wisp | STALE-SYSTEM (most added lines go to files main deleted: 6274gone vs 5073miss) |
| ext/sfx-boki-voices-3 | SUPERSEDED by a landed integration READY: ext/sfx-boki-voices-rest@f02f6391c:True |
| ext/sfx-boon-cue | NEEDS-PORT (704miss lines missing, 25% landed; top: tools/camps_check.gd:229 scripts/match/drop_feel.gd:113) |
| ext/sfx-camp-idle | NEEDS-PORT (625miss lines missing, 21% landed; top: tools/camps_check.gd:181 scripts/match/drop_feel.gd:113) |
| ext/sfx-carry-cues | STALE-SYSTEM (most added lines go to files main deleted: 303gone vs 230miss) |
| ext/sfx-coverage-world | NEEDS-PORT (318miss lines missing, 2% landed; top: tools/gen_sfx_heart.py:30 tools/sfx_set_check.gd:26) |
| ext/sfx-creator-clans | SUPERSEDED by a landed integration READY: ext/sfx-ui-controls@a048a824b:True |
| ext/sfx-dash-per-hunter-rebased | SUPERSEDED by a landed integration READY: ext/stuck-integ-f1f63a7a@42ff6e882:True |
| ext/sfx-extract-cues | STALE-SYSTEM (most added lines go to files main deleted: 70gone vs 41miss) |
| ext/sfx-falloff-wide-cam | STALE-SYSTEM (most added lines go to files main deleted: 454gone vs 233miss) |
| ext/sfx-garden-games-3 | NEEDS-PORT (476miss lines missing, 72% landed; top: tools/gen_sfx_garden.py:126 tools/kite_check.gd:39) |
| ext/sfx-garden-zone-music | NEEDS-PORT (141miss lines missing, 3% landed; top: tools/compose.py:44 tools/garden_audio_check.gd:43) |
| ext/sfx-heartspark | NEEDS-PORT (54miss lines missing, 66% landed; top: tools/heart_check.gd:25 scripts/match/heart_sfx.gd:13) |
| ext/sfx-hunter-foley | NEEDS-PORT (351miss lines missing, 14% landed; top: tools/match_audio_check.gd:118 scripts/core/sfx.gd:48) |
| ext/sfx-hunter-wisp-hum | NEEDS-PORT (41miss lines missing, 81% landed; top: tools/gen_wisp_sfx.py:27 content/rules/wisp_hum.json:3) |
| ext/sfx-incoming-hit-dir | STALE-SYSTEM (most added lines go to files main deleted: 381gone vs 294miss) |
| ext/sfx-interrupt-cut | STALE-SYSTEM (most added lines go to files main deleted: 95gone vs 89miss) |
| ext/sfx-kit-placeholders-2 | NEEDS-PORT (414miss lines missing, 3% landed; top: tools/sfx_set_check.gd:54 tools/gen_sfx_kael.py:32) |
| ext/sfx-listener-hunter | STALE-SYSTEM (most added lines go to files main deleted: 78gone vs 53miss) |
| ext/sfx-match-shop | STALE-SYSTEM (most added lines go to files main deleted: 4961gone vs 3855miss) |
| ext/sfx-mix-pass | IN-BASE (nothing to merge) |
| ext/sfx-mob-attacks | STALE-SYSTEM (most added lines go to files main deleted: 102gone vs 60miss) |
| ext/sfx-neve-skate | STALE-SYSTEM (most added lines go to files main deleted: 322gone vs 81miss) |
| ext/sfx-pick-taken | NEEDS-PORT (132miss lines missing, 16% landed; top: tools/class_unlock_check.gd:23 tools/hatch_check.gd:23) |
| ext/sfx-ready-cues-summon | STALE-SYSTEM (most added lines go to files main deleted: 198gone vs 107miss) |
| ext/sfx-solos-quiet | STALE-SYSTEM (most added lines go to files main deleted: 219gone vs 194miss) |
| ext/sfx-steals | STALE-SYSTEM (most added lines go to files main deleted: 638gone vs 588miss) |
| ext/sfx-steps-dirloops | NEEDS-PORT (427miss lines missing, 59% landed; top: tools/art1/hunter_dir_gait.py:120 tools/clip_check.gd:51) |
| ext/sfx-stomp-1111 | STALE-SYSTEM (most added lines go to files main deleted: 464gone vs 302miss) |
| ext/sfx-stomp-break | STALE-SYSTEM (most added lines go to files main deleted: 484gone vs 382miss) |
| ext/sfx-strike-resync | STALE-SYSTEM (most added lines go to files main deleted: 6183gone vs 4804miss) |
| ext/sfx-summon-end | STALE-SYSTEM (most added lines go to files main deleted: 1655gone vs 1053miss) |
| ext/sfx-swim-ice-moves | STALE-SYSTEM (most added lines go to files main deleted: 5239gone vs 4529miss) |
| ext/sfx-terrain-hazards | STALE-SYSTEM (most added lines go to files main deleted: 5076gone vs 4321miss) |
| ext/sfx-utilities-2 | STALE-SYSTEM (most added lines go to files main deleted: 2608gone vs 424miss) |
| ext/sfx-voice-cap | NEEDS-PORT (142miss lines missing, 6% landed; top: tools/match_audio_check.gd:49 scripts/core/sfx_voices.gd:45) |
| ext/sfx-water | STALE-SYSTEM (most added lines go to files main deleted: 402gone vs 381miss) |
| ext/sfx-wisp-proc | STALE-SYSTEM (most added lines go to files main deleted: 1737gone vs 1061miss) |
| ext/skin-relax-four | SUPERSEDED by a landed integration READY: ext/anim-skin-relax-b@408431967:False ext/anim-skin-relax-c@391066c95:True |
| ext/skin-relax-slice | OWNED by an open integration READY: ext/anim-skin-relax-slice@abfbb1aa6:False |
| ext/slam-follow-through | NEEDS-PORT (35miss lines missing, 87% landed; top: docs/art/SLAM_FOLLOW.md:15 scripts/heroes/warden_clips.gd:13) |
| ext/soul-link-t4-rebased | STALE-SYSTEM (most added lines go to files main deleted: 3105gone vs 2074miss) |
| ext/spike-on-glidespike | STALE-SYSTEM (most added lines go to files main deleted: 83gone vs 59miss) |
| ext/split-models-rebased | STALE-SYSTEM (most added lines go to files main deleted: 3201gone vs 124miss) |
| ext/split-rimewright-spear | OWNED by an open integration READY: ext/stuck-integ-aeb8eb0f@176c4167b:False |
| ext/step-sounds-unified-rebased | NEEDS-PORT (284miss lines missing, 21% landed; top: tools/match_audio_check.gd:54 scripts/core/sfx.gd:52) |
| ext/stretch-reds | OWNED by an open integration READY: ext/anim-skin-relax-b@408431967:False ext/skin-relax-four@15a5d398e:False ext/skin-relax-slice@75c5ddf2e:False |
| ext/stuck-integ-09e533a4 | NEEDS-PORT (281miss lines missing, 14% landed; top: tools/airdash_glide_check.gd:78 tools/step_smooth_check.gd:36) |
| ext/stuck-integ-1324d019 | OWNED by an open integration READY: ext/stuck-integ-38a28c4e@cbb26d25d:False |
| ext/stuck-integ-1833c7c4 | OWNED by an open integration READY: ext/stuck-integ-1324d019@749f30752:False |
| ext/stuck-integ-42241ff1 | STALE-SYSTEM (most added lines go to files main deleted: 10671gone vs 9245miss) |
| ext/stuck-integ-5b12f708 | LANDED-ELSEWHERE (92% of its lines on the base, 488miss) |
| ext/stuck-integ-606e9a98 | OWNED by an open integration READY: ext/stuck-integ-be6ffab8@6db102ca6:False ext/stuck-integ-be6ffab8@d4ec3f8b9:False |
| ext/stuck-integ-7fc43430 | LANDED-ELSEWHERE (92% of its lines on the base, 1214miss) |
| ext/stuck-integ-86b7d6eb | OWNED by an open integration READY: ext/stuck-integ-42241ff1@28a4b79ef:False |
| ext/stuck-integ-a6af81f7 | SUPERSEDED by a landed integration READY: ext/stuck-integ-fb4b4275@31bb1fccb:True |
| ext/stuck-integ-aeb8eb0f | STALE-SYSTEM (most added lines go to files main deleted: 1503gone vs 222miss) |
| ext/stuck-integ-b7a5717c | OWNED by an open integration READY: ext/vfx-telegraph-lead-rebased@f3f674581:False ext/vfx-telegraph-timing-rebased@7cbc2cae1:False |
| ext/stuck-integ-c2a69297 | NEEDS-PORT (1102miss lines missing, 86% landed; top: docs/heroes/dash_interactions.md:420 docs/heroes/bulwark.md:52) |
| ext/stuck-integ-d2f36c16 | NEEDS-PORT (2272miss lines missing, 67% landed; top: docs/heroes/dash_interactions.md:240 scripts/ui/prologue.gd:105) |
| ext/stuck-integ-d4379965 | SUPERSEDED by a landed integration READY: ext/vfx-telegraph-timing-rebased@7cbc2cae1:False ext/vex-dash-parity-rebased@ad34d150d:True ext/vfx-telegraph-timing-reb |
| ext/stuck-integ-e2561d23 | OWNED by an open integration READY: ext/meeko-rmb-verify-rebased@7c1762cf5:False |
| ext/stuck-integ-f60f9dd7 | NEEDS-PORT (539miss lines missing, 46% landed; top: tools/airdash_glide_check.gd:78 tools/aimkit_shots.gd:52) |
| ext/stuck-integ-f6bd2b7c | STALE-SYSTEM (most added lines go to files main deleted: 4185gone vs 2651miss) |
| ext/summon-clips-port | STALE-SYSTEM (most added lines go to files main deleted: 3780gone vs 3162miss) |
| ext/summon-kill-credit-port | STALE-SYSTEM (most added lines go to files main deleted: 5775gone vs 4154miss) |
| ext/summon-kill-credit-rebased | STALE-SYSTEM (most added lines go to files main deleted: 291gone vs 157miss) |
| ext/summon-pve-rules-rebased | NEEDS-PORT (172miss lines missing, 85% landed; top: tools/wisp_steal_check.gd:36 scripts/match/kin_summon.gd:28) |
| ext/supervive-impact | OWNED by an open integration READY: ext/feel-impact-tiers@371e736ab:False |
| ext/sv-private-1112 | NEEDS-PORT (297miss lines missing, 67% landed; top: docs/TTK.md:62 docs/heroes/dash_interactions.md:43) |
| ext/tarek-appeal | SUPERSEDED by a landed integration READY: ext/stuck-integ-f1f63a7a@42ff6e882:True |
| ext/telegraph-drawn-hit-port | STALE-SYSTEM (most added lines go to files main deleted: 6274gone vs 5118miss) |
| ext/tenzo-ridge-bursts | NEEDS-PORT (114miss lines missing, 18% landed; top: scripts/arch/rock_look.gd:37 tools/breah_combo_check.gd:30) |
| ext/training-merge-1111 | NEEDS-PORT (127miss lines missing, 11% landed; top: tools/arena_check.gd:33 scripts/match/arena.gd:23) |
| ext/training-time-trial | STALE-SYSTEM (most added lines go to files main deleted: 346gone vs 97miss) |
| ext/ttk-five-cast-share | NEEDS-PORT (93miss lines missing, 16% landed; top: docs/TTK.md:31 tools/ttk_check.gd:31) |
| ext/ttk-kael | NEEDS-PORT (33miss lines missing, 34% landed; top: docs/TTK.md:8 docs/heroes/juggernaut.md:8) |
| ext/tut-air-rings | SUPERSEDED by a landed integration READY: ext/sfx-air-rings@d1a96b8d4:True |
| ext/tut-beat-retry | NEEDS-PORT (79miss lines missing, 41% landed; top: tools/tutorial_retry_check.gd:38 scripts/match/tutorial.gd:26) |
| ext/tut-beat-retry-port | STALE-SYSTEM (most added lines go to files main deleted: 970gone vs 524miss) |
| ext/tut-belt-hint-rebased | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/tut-creator-first | OWNED by an open integration READY: ext/stuck-integ-5b12f708@f3fd0b4b8:False ext/stuck-integ-be6ffab8@d4ec3f8b9:False |
| ext/tut-dive-hint | STALE-SYSTEM (most added lines go to files main deleted: 47gone vs 6miss) |
| ext/tut-dodge-dummy-rebased | STALE-SYSTEM (most added lines go to files main deleted: 864gone vs 493miss) |
| ext/tut-drop-old-farm-steps | NEEDS-PORT (118miss lines missing, 30% landed; top: tools/farm_tutorial_check.gd:25 scripts/home/farm_tutorial.gd:20) |
| ext/tut-duel-hint-port | SUPERSEDED by a landed integration READY: ext/duel-ring-port@f3be24f70:True |
| ext/tut-duel-ring-rebased | OWNED by an open integration READY: ext/tut-duel-hint-port@10c4c1be5:False |
| ext/tut-event-hints-rebased | STALE-SYSTEM (most added lines go to files main deleted: 116gone vs 37miss) |
| ext/tut-farm-old-steps-cut | NEEDS-PORT (131miss lines missing, 16% landed; top: tools/farm_tutorial_check.gd:44 scripts/home/farm_tutorial.gd:30) |
| ext/tut-first-evolve | STALE-SYSTEM (most added lines go to files main deleted: 622gone vs 36miss) |
| ext/tut-first-fuse | STALE-SYSTEM (most added lines go to files main deleted: 1516gone vs 1080miss) |
| ext/tut-first-games | NEEDS-PORT (326miss lines missing, 19% landed; top: tools/tut_first_games_check.gd:102 scripts/home/first_round.gd:57) |
| ext/tut-first-games-port | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/tut-first-heartspark-rebased | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/tut-first-hour-order | STALE-SYSTEM (most added lines go to files main deleted: 451gone vs 179miss) |
| ext/tut-first-proc | STALE-SYSTEM (most added lines go to files main deleted: 1582gone vs 1028miss) |
| ext/tut-first-race-rebased | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/tut-first-recast | SUPERSEDED by a landed integration READY: ext/tut-recast-hint@ccbbf0935:True |
| ext/tut-first-shop | STALE-SYSTEM (most added lines go to files main deleted: 4906gone vs 3775miss) |
| ext/tut-first-utility | STALE-SYSTEM (most added lines go to files main deleted: 1556gone vs 224miss) |
| ext/tut-garden-first-day-rebased | LANDED-ELSEWHERE (90% of its lines on the base, 706miss) |
| ext/tut-garden-no-gather | NEEDS-PORT (142miss lines missing, 21% landed; top: tools/hob_check.gd:24 tools/farm_tutorial_check.gd:23) |
| ext/tut-hatch-beat | SUPERSEDED by a landed integration READY: ext/stuck-integ-f1f63a7a@ddae66af6:True |
| ext/tut-hazard-hint | LANDED-ELSEWHERE (95% of its lines on the base, 57miss) |
| ext/tut-hints-blight-camp-box | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/tut-hot-zone-line | NEEDS-PORT (49miss lines missing, 13% landed; top: tools/hot_zone_check.gd:18 scripts/match/hot_zone.gd:16) |
| ext/tut-hud-pointers | NEEDS-PORT (447miss lines missing, 8% landed; top: scripts/ui/hud_vitals.gd:130 scripts/ui/hud_style.gd:68) |
| ext/tut-keycap-audit | NEEDS-PORT (32miss lines missing, 80% landed; top: tools/key_text_check.gd:9 scripts/match/match.gd:5) |
| ext/tut-last-hit-xp | NEEDS-PORT (39miss lines missing, 70% landed; top: tools/xp_share_check.gd:28 scripts/match/kill_xp.gd:4) |
| ext/tut-lead-swap-hint | STALE-SYSTEM (most added lines go to files main deleted: 248gone vs 174miss) |
| ext/tut-no-ripe-timer-1111 | STALE-SYSTEM (most added lines go to files main deleted: 970gone vs 378miss) |
| ext/tut-retry-port | STALE-SYSTEM (most added lines go to files main deleted: 970gone vs 379miss) |
| ext/tut-revive-hint | STALE-SYSTEM (most added lines go to files main deleted: 67gone vs 12miss) |
| ext/tut-rocket-hint | NEEDS-PORT (144miss lines missing, 78% landed; top: scripts/match/match.gd:32 scripts/match/drop_squad.gd:27) |
| ext/tut-seat-grace-hint | STALE-SYSTEM (most added lines go to files main deleted: 201gone vs 118miss) |
| ext/tut-solo-words | NEEDS-PORT (504miss lines missing, 40% landed; top: scripts/match/match.gd:50 scripts/match/capture.gd:48) |
| ext/tut-start-here-rebased-rebased | NEEDS-PORT (61miss lines missing, 17% landed; top: tools/prematch_check.gd:37 content/rules/class_unlock.json:8) |
| ext/tut-station-goals-rebased | STALE-SYSTEM (most added lines go to files main deleted: 717gone vs 427miss) |
| ext/tut-stomp-hints | STALE-SYSTEM (most added lines go to files main deleted: 855gone vs 766miss) |
| ext/tut-summon-killed | NEEDS-PORT (172miss lines missing, 84% landed; top: tools/summon_death_check.gd:51 tools/wisp_steal_check.gd:20) |
| ext/tut-summon-pad | STALE-SYSTEM (most added lines go to files main deleted: 7244gone vs 5395miss) |
| ext/tut-summon-station | NEEDS-PORT (363miss lines missing, 58% landed; top: tools/arena_check.gd:144 tools/summon_station_check.gd:49) |
| ext/tut-wall-kick-hint | LANDED-ELSEWHERE (0% of its lines on the base, 3miss) |
| ext/tut-ways-out | OWNED by an open integration READY: ext/tut-seat-grace-hint@0d777a87b:False |
| ext/tut-wisp-beats | NEEDS-PORT (180miss lines missing, 87% landed; top: tools/summon_death_check.gd:51 tools/wisp_steal_check.gd:20) |
| ext/tut-xp-share | NEEDS-PORT (40miss lines missing, 87% landed; top: tools/xp_hint_check.gd:14 tools/xp_share_check.gd:13) |
| ext/tut-zoom-hint | OWNED by an open integration READY: ext/feel-ranges-on-screen@23eac5342:False |
| ext/tutorial-banner-1111 | STALE-SYSTEM (most added lines go to files main deleted: 970gone vs 522miss) |
| ext/tutorial-beats-5-6-rebased-rebased | NEEDS-PORT (188miss lines missing, 5% landed; top: tools/tutorial_hud_check.gd:49 scripts/match/tutorial.gd:24) |
| ext/ui-ability-text-one | STALE-SYSTEM (most added lines go to files main deleted: 231gone vs 133miss) |
| ext/ui-aspect-sweep | STALE-SYSTEM (most added lines go to files main deleted: 4470gone vs 3749miss) |
| ext/ui-audio-buses | OWNED by an open integration READY: ext/stuck-integ-be6ffab8@6db102ca6:False ext/stuck-integ-be6ffab8@d4ec3f8b9:False |
| ext/ui-boki-box-carry | OWNED by an open integration READY: ext/ui-aspect-sweep@3ec816ed4:False |
| ext/ui-boki-box-hazard | STALE-SYSTEM (most added lines go to files main deleted: 389gone vs 169miss) |
| ext/ui-bonus-column | NEEDS-PORT (462miss lines missing, 2% landed; top: scripts/ui/hud_vitals.gd:130 scripts/ui/hud_style.gd:68) |
| ext/ui-declutter-1111 | NEEDS-PORT (88miss lines missing, 9% landed; top: tools/recast_cue_check.gd:23 scripts/ui/recast_cue.gd:22) |
| ext/ui-expedition-first | STALE-SYSTEM (most added lines go to files main deleted: 41gone vs 39miss) |
| ext/ui-font-wght-tag | NEEDS-PORT (71miss lines missing, 84% landed; top: scripts/ui/squad_frames.gd:42 tools/uipolish_check.gd:14) |
| ext/ui-hud-reveal-1110 | NEEDS-PORT (123miss lines missing, 76% landed; top: scripts/ui/boki_hud.gd:29 scripts/match/kin_summon.gd:28) |
| ext/ui-hud-scale | SUPERSEDED by a landed integration READY: ext/ui-quest-tracker@89ef4c9a0:True |
| ext/ui-hudref-verify | STALE-SYSTEM (most added lines go to files main deleted: 468gone vs 427miss) |
| ext/ui-interact-port | STALE-SYSTEM (most added lines go to files main deleted: 5094gone vs 3890miss) |
| ext/ui-level-gap | NEEDS-PORT (587miss lines missing, 33% landed; top: scripts/match/drop_feel.gd:113 tools/camps_check.gd:111) |
| ext/ui-loading-bar-steady | STALE-SYSTEM (most added lines go to files main deleted: 6274gone vs 5024miss) |
| ext/ui-loot-compare | STALE-SYSTEM (most added lines go to files main deleted: 4470gone vs 3682miss) |
| ext/ui-mode-cards | STALE-SYSTEM (most added lines go to files main deleted: 267gone vs 113miss) |
| ext/ui-next-form-port | NEEDS-PORT (47miss lines missing, 75% landed; top: tools/evo_check.gd:44 scripts/home/home.gd:2) |
| ext/ui-overhead-ref | NEEDS-PORT (567miss lines missing, 4% landed; top: scripts/ui/hud_vitals.gd:130 scripts/ui/hud_plate.gd:97) |
| ext/ui-plate-status-row | STALE-SYSTEM (most added lines go to files main deleted: 299gone vs 149miss) |
| ext/ui-portal-boki-card | STALE-SYSTEM (most added lines go to files main deleted: 281gone vs 104miss) |
| ext/ui-pro-1111 | NEEDS-PORT (333miss lines missing, 3% landed; top: scripts/ui/full_map.gd:79 scripts/ui/ui_theme.gd:51) |
| ext/ui-ride-pick | STALE-SYSTEM (most added lines go to files main deleted: 227gone vs 103miss) |
| ext/ui-safe-area-one | NEEDS-PORT (57miss lines missing, 83% landed; top: scripts/ui/prematch_view.gd:17 tools/prematch_shots.gd:13) |
| ext/ui-settings-trim | NEEDS-PORT (136miss lines missing, 53% landed; top: scripts/ui/overlay.gd:55 scripts/ui/title.gd:19) |
| ext/ui-simplify-1111 | STALE-SYSTEM (most added lines go to files main deleted: 434gone vs 295miss) |
| ext/ui-solos-hud | NEEDS-PORT (1025miss lines missing, 40% landed; top: scripts/ui/full_map.gd:195 scripts/match/life.gd:161) |
| ext/ui-squad-killer | NEEDS-PORT (46miss lines missing, 89% landed; top: scripts/ui/squad_frames.gd:37 scripts/ui/downed_marks.gd:8) |
| ext/ui-stolen-wisps | NEEDS-PORT (163miss lines missing, 60% landed; top: scripts/ui/boki_hud.gd:49 tools/wisp_steal_check.gd:36) |
| ext/ui-stomp-picker | STALE-SYSTEM (most added lines go to files main deleted: 465gone vs 273miss) |
| ext/ui-stomp-ring | STALE-SYSTEM (most added lines go to files main deleted: 400gone vs 394miss) |
| ext/ui-stomp-state | STALE-SYSTEM (most added lines go to files main deleted: 413gone vs 243miss) |
| ext/ui-summon-card | NEEDS-PORT (189miss lines missing, 83% landed; top: tools/wisp_check.gd:43 tools/summon_death_check.gd:23) |
| ext/ui-text-chat-rebased | STALE-SYSTEM (most added lines go to files main deleted: 344gone vs 144miss) |
| ext/ui-tooltip-from-data | NEEDS-PORT (275miss lines missing, 0% landed; top: content/archetypes/rimewright.json:20 content/archetypes/tender.json:18) |
| ext/ui-trios-only-text | NEEDS-PORT (49miss lines missing, 27% landed; top: scripts/match/match.gd:25 tools/style_baseline.json:6) |
| ext/ui-void-masks-v3 | NEEDS-PORT (512miss lines missing, 9% landed; top: scripts/ui/ui_torn.gd:126 scripts/ui/kin_reveal.gd:104) |
| ext/ui-w0246-boki-reds | STALE-SYSTEM (most added lines go to files main deleted: 4472gone vs 3689miss) |
| ext/ui-w0246-layout-reds | STALE-SYSTEM (most added lines go to files main deleted: 4476gone vs 3688miss) |
| ext/ui-waystone-keys | MERGED here (hints in the card tooltip) |
| ext/ui-zone-next | STALE-SYSTEM (most added lines go to files main deleted: 221gone vs 180miss) |
| ext/ult-ranks-rebased-rebased | NEEDS-PORT (114miss lines missing, 5% landed; top: scripts/arch/hero_ult.gd:15 docs/decisions/0022-ult-ranks.md:13) |
| ext/utility-parity-0246 | STALE-SYSTEM (most added lines go to files main deleted: 9074gone vs 5610miss) |
| ext/verify-solos-pacing | STALE-SYSTEM (most added lines go to files main deleted: 2515gone vs 214miss) |
| ext/verify-stomp-break-sweep | STALE-SYSTEM (most added lines go to files main deleted: 496gone vs 286miss) |
| ext/verify-ttk-0246 | NEEDS-PORT (4549miss lines missing, 65% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:261) |
| ext/verify-tut-starters-0246 | STALE-SYSTEM (most added lines go to files main deleted: 1017gone vs 413miss) |
| ext/verify-w0246-audio | STALE-SYSTEM (most added lines go to files main deleted: 2714gone vs 1703miss) |
| ext/vex-body7-1111 | SUPERSEDED by a landed integration READY: ext/stuck-integ-f1f63a7a@42ff6e882:True |
| ext/vex-greenfire-1108 | OWNED by an open integration READY: ext/stuck-integ-b7a5717c@586fb5124:False ext/stuck-integ-f60f9dd7@b764e6e38:False |
| ext/vfx-air-rings-read | STALE-SYSTEM (most added lines go to files main deleted: 913gone vs 240miss) |
| ext/vfx-albert-ivory-arcs | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-archer-strips | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-carry-wisps | STALE-SYSTEM (most added lines go to files main deleted: 6817gone vs 5109miss) |
| ext/vfx-colour-audit | SUPERSEDED by a landed integration READY: ext/vfx-sparkle-ult-local@008b68098:True |
| ext/vfx-dash-no-rings | NEEDS-PORT (2582miss lines missing, 68% landed; top: docs/heroes/dash_interactions.md:305 docs/MOVEMENT_FEEL.md:237) |
| ext/vfx-dolm-shots | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-gil-colour | SUPERSEDED by a landed integration READY: ext/gil-train-1112@268cb4076:True |
| ext/vfx-grimble-data | OWNED by an open integration READY: ext/vfx-grimble-wedges@47c045645:False |
| ext/vfx-grimble-fist-port | STALE-SYSTEM (most added lines go to files main deleted: 2687gone vs 1882miss) |
| ext/vfx-kael-hold-arc | NEEDS-PORT (271miss lines missing, 29% landed; top: tools/dancer_jug_check.gd:60 tools/hero_vfx_reel.gd:42) |
| ext/vfx-last-hit-colour | OWNED by an open integration READY: ext/stuck-integ-be6ffab8@6db102ca6:False ext/stuck-integ-be6ffab8@d4ec3f8b9:False |
| ext/vfx-mage-strips | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-meeko-hit-hearth | NEEDS-PORT (518miss lines missing, 18% landed; top: scripts/arch/kits/mage_kit.gd:70 tools/hero_vfx_check.gd:67) |
| ext/vfx-meeko-kindle | NEEDS-PORT (58miss lines missing, 10% landed; top: tools/care_combo_check.gd:35 tools/vfx_reel/tender.gd:9) |
| ext/vfx-meeko-kindle-numbers | STALE-SYSTEM (most added lines go to files main deleted: 73gone vs 53miss) |
| ext/vfx-meeko-palette | NEEDS-PORT (452miss lines missing, 2% landed; top: scripts/arch/kits/mage_kit.gd:70 scripts/arch/kits/gunslinger_kit.gd:46) |
| ext/vfx-mob-telegraphs | STALE-SYSTEM (most added lines go to files main deleted: 404gone vs 49miss) |
| ext/vfx-motley-kit | SUPERSEDED by a landed integration READY: ext/vfx-motley-data@9bd1c33c9:True |
| ext/vfx-motley-port | STALE-SYSTEM (most added lines go to files main deleted: 5621gone vs 4241miss) |
| ext/vfx-neve-rimelock-area | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-pass | OWNED by an open integration READY: ext/vfx-origin-v2-rebased@82998a018:False ext/grimble-fist-vfx@48466a85f:False |
| ext/vfx-pass-triage | NEEDS-PORT (295miss lines missing, 20% landed; top: content/vfx/dolm.json:54 content/vfx/ostra.json:51) |
| ext/vfx-spitter-tell | STALE-SYSTEM (most added lines go to files main deleted: 426gone vs 49miss) |
| ext/vfx-stolen-wisps-rebased | STALE-SYSTEM (most added lines go to files main deleted: 335gone vs 213miss) |
| ext/vfx-stomp | OWNED by an open integration READY: ext/stuck-integ-38a28c4e@cbb26d25d:False |
| ext/vfx-strips-tender | SUPERSEDED by a landed integration READY: ext/stuck-integ-62ec7ba9@d05ab3bec:True |
| ext/vfx-summon-ring | STALE-SYSTEM (most added lines go to files main deleted: 1693gone vs 1035miss) |
| ext/vfx-telegraph-timing-rebased | STALE-SYSTEM (most added lines go to files main deleted: 4429gone vs 4198miss) |
| ext/vfx-tenzo-punch-hold | NEEDS-PORT (106miss lines missing, 3% landed; top: scripts/arch/kits/kit_looks.gd:45 tools/breah_combo_check.gd:40) |
| ext/vfx-utilities-2 | STALE-SYSTEM (most added lines go to files main deleted: 2387gone vs 200miss) |
| ext/vfx-utility-read | STALE-SYSTEM (most added lines go to files main deleted: 1999gone vs 356miss) |
| ext/vfx-vex-kit | SUPERSEDED by a landed integration READY: ext/vfx-vex-data@c2a99301c:True |
| ext/vfx-vex-tracer | NEEDS-PORT (98miss lines missing, 10% landed; top: tools/hero_vfx_check.gd:57 scripts/arch/kits/gunslinger_kit.gd:32) |
| ext/vfx-vex-tracer-0246 | STALE-SYSTEM (most added lines go to files main deleted: 2678gone vs 1842miss) |
| ext/vfx-vex-tracer-strips | NEEDS-PORT (98miss lines missing, 10% landed; top: tools/hero_vfx_check.gd:57 scripts/arch/kits/gunslinger_kit.gd:32) |
| ext/w0246-misc | STALE-SYSTEM (most added lines go to files main deleted: 6274gone vs 5028miss) |
| ext/wisp-gpu-ab-rebased | STALE-SYSTEM (most added lines go to files main deleted: 3142gone vs 1993miss) |
| ext/wisp-merge-from-wisp-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1412gone vs 1136miss) |
| ext/wisp-passive-stack-rebased | NEEDS-PORT (108miss lines missing, 88% landed; top: tools/wisp_steal_check.gd:20 scripts/match/kin_summon.gd:14) |
| ext/wisp-summon-key-c | NEEDS-PORT (132miss lines missing, 87% landed; top: tools/summon_death_check.gd:23 tools/wisp_steal_check.gd:20) |
| ext/wisp-summon-leash-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1522gone vs 1067miss) |
| ext/wisp-summon-net-rebased | STALE-SYSTEM (most added lines go to files main deleted: 1648gone vs 1089miss) |
