# Integration f11b417c (2026-11-14): the conflict-skipped READY branches, once more

Job 20261114-201513-a3 (rpc6, feel; takes over 20261114-195510-a3, which left nothing). Base: origin/main 167391b3f9,
not the newest `ext/mc-20261114-1510` (built on main f1871f48, 7 NEW-RED of its own). Input: the 923 SKIPPED rows of
mc-20261114-1510's MERGE_REPORT (a superset of the task's list).

## Where they are
- 32 gone from origin; 9 already ancestors of main.
- 592 have no commit since the stuck-integ-b6204ee2 triage (11-13 16:55), which found each in conflict
  with main; cff77e31 re-checked them today. Archive them, or redo a wanted one as a fresh task.
- 24 are owned by the two live integs (`stuck-integ-c2a69297`: 19 + 6 it merged at an older tip,
  `stuck-integ-cff77e31`: 5);
  157 sit inside older integ/mc branches that never landed (only their 18 with newer commits were retried).
- Integ-type branches (stuck-integ-*, integ-1113-*, merge-batch-*, agent-briefs) are not merged into another integ.
- 105 had commits after the triage and were tried. Many stale tips also carry their old base's files (one 1-commit
  branch touched 115 files), so each branch's own commits (git cherry vs main) were cherry-picked and recorded as a
  merge of the tip: the tip becomes an ancestor and merge-candidate stops skipping it.

## Merged here (7)
- ext/vfx-neve-statue-break 6a98e4a0a7: its own commits only; Rimelock end rows join main's hero_vfx parts; main's
  _scarf(main) kept
- ext/sfx-quest-exits 58c1f6d7cf: its own commits only; quest cues are check part 6 after main's countdown part 5
- ext/tut-heart-raid-hints 44ad9394cc: its own commits only; hints are check part 7 (main's part 6 is the sounds)
- ext/combat-raid-balance fd5a8cc7cf: its own commits only; --sweep rides main's _sim_opts
- ext/sfx-silence-audit-coverage 730afd7ddc: its own commits only; clean
- ext/verify-kael-guard-ult 3a5b5dadd7: its own commits only; guard rows join main's recovery rows; doc rows use
  main's R key
- ext/farm-friend-chase 6ab7404f87: clean

## Already in main by patch (9, archive): `anim-race-beats` `combat-steal-window-tell` `combat-ttk-five`
  `sfx-boki-landings` `sfx-garden-items` `sfx-silence-audit` `sfx-ui-controls` `sfx-voice-priority` `wisp-look-1112`

## Left, with a reason
- `ui-mask-preview-warm`: adds a Mutex to scripts/core/mesh_cache.gd for a preview worker main does not run that way.
- `farm-toys-joy-tune`: joy_gain 3 / base_joy_decay 8 against main's sim-based balance pass (joy_gain 14,
  092e163c4b); a balance call for the owner. Its soak toy rows alone would merge.
- `perf-heart-final`: main's perf_bench gained trios and pose sampling; the heart_final part needs a port.
- Not attempted (real conflicts with main at the first own commit; files in brackets):
  `blight-nests` [scripts/match/blight.gd scripts/match/blight_nests.gd.uid, +2 more]
  `combat-daze-status` [docs/DEBT.md scripts/arch/kit_status.gd scripts/arch/kits/gunslinger_kit.gd]
  `farm-pet-personality` [docs/wiki/Rules.md scripts/home/home.gd scripts/home/interior.gd tools/check_registry.gd]
  `farm-site-paused` [docs/DEBT.md scripts/home/farm_hob.gd tools/farmbuild_check.gd]
  `feel-hit-marker` [docs/HUD.md scripts/match/match.gd scripts/ui/hud.gd tools/check_registry.gd]
  `garden-race-ghost` [docs/GARDEN.md scripts/home/base_race.gd scripts/home/home.gd tools/race_check.gd]
  `map-clear-1111` [scripts/ui/full_map.gd scripts/ui/hud.gd scripts/ui/map_key.gd tools/check_registry.gd]
  `sfx-hit-tick-family` [content/weapons/flamethrower.json content/weapons/rubble_fists.json, +5 more]
  `sfx-meeko-channel-loop` [scripts/arch/kits/tender_kit.gd tools/sfx_set_check.gd]
  `sfx-sable-ring-loop` [docs/heroes/thief.md scripts/arch/kits/thief_ult.gd tools/sfx_set_check.gd]
  `split-hunter` [docs/heroes/archer.md docs/heroes/ashwick.md, +8 more]
  `tut-hud-term-hints` [scripts/match/kin_follow.gd scripts/ui/hud_vitals.gd tools/msg_queue_check.gd]
  `ui-loot-feed` [docs/HUD.md scripts/match/match.gd scripts/match/pack.gd scripts/ui/hud.gd]
  `ui-meeko-channel-ally` [docs/HUD.md scripts/core/net.gd tools/displace_net_check.gd tools/hudref_check.gd]
  `anim-boki-slide-batch2` [art/kin/lodestick/lodestick.glb art/kin/mossgrade/mossgrade.glb, +7 more]
  `anim-meeko-tiptoe` [art/wardens/pip/IMPORT.md art/wardens/pip/pip.glb, +4 more]
  `cinder-flue-clips` [shaders/hero_vfx.gdshader tools/ashwick_combo_check.gd tools/ashwick_ult_check.gd]
  `creator-preview` [scripts/ui/hatch.gd tools/check_registry.gd]
  `farm-unmasked-feet` [content/rules/warden_stance.json docs/DEBT.md, +4 more]
  `feel-neve-statue-time` [content/archetypes/rimewright.json docs/heroes/rimewright.md, +2 more]
  `hud-g-armor-1111` [scripts/ui/hud.gd scripts/ui/hud_vitals.gd tools/check_registry.gd tools/hudref_check.gd]
  `parity-vex-coin-stick` [docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd]
  `prematch-safe-720` [docs/DEBT.md scripts/ui/prematch_view.gd tools/prematch_check.gd tools/prematch_shots.gd]
  `remote-smooth-reds` [docs/decisions/0039-remote-smooth.md scripts/match/net_smooth.gd tools/remote_smooth_check.gd]
  `sfx-interrupt-cut` [content/sfx/ui.json docs/AUDIO.md, +8 more]
  `sfx-voice-cap` [docs/AUDIO.md docs/wiki/Rules.md, +5 more]
  `tut-air-rings` [docs/AIR_RINGS.md scripts/match/air_rings.gd tools/air_rings_check.gd]
  `ui-card-numbers` [content/archetypes/mage.json content/archetypes/rimewright.json, +3 more]
  `ui-expedition-first` [scripts/home/home.gd scripts/home/hunter_pick_row.gd]
  `vex-greenfire-1108` [content/archetypes/gunslinger.json docs/heroes/gunslinger.md, +3 more]
  `vfx-breakables` [docs/HERO_VFX.md scripts/match/hero_vfx.gd shaders/hero_vfx_mote.gdshader tools/hero_vfx_check.gd]
  `vfx-number-sources` [scripts/match/ent.gd scripts/match/fx.gd scripts/match/match.gd tools/check_registry.gd]
  `airdash-anims-1108` [content/rules/warden_anim/cinder.json content/rules/warden_anim/hem.json, +5 more]
  `physics-unify-1111` [tools/check_registry.gd]
  `sfx-closing-zone` [scripts/match/shrink_zone.gd tools/shrink_zone_check.gd]
  `sfx-loudness-0245` [docs/AUDIO.md scripts/core/sfx.gd]
  `status-net-per-caster` [docs/DEBT.md scripts/arch/kit_status.gd scripts/core/net.gd tools/check_registry.gd]
  `tut-live-keys` [content/archetypes/juggernaut.json content/archetypes/rimewright.json, +13 more]
  `ui-prematch-margin` [docs/DEBT.md docs/GATE_TRIAGE_0244.md scripts/ui/prematch_view.gd tools/prematch_check.gd]
  `ui-raid-boss-bar-online` [scripts/match/boss.gd scripts/match/heart_raid.gd, +2 more]
  `ui-start-here-port` [content/rules/class_unlock.json docs/decisions/0019-prematch-lobby.md docs/wiki/Rules.md]
  `ui-waystone-keys` [content/rules/garden_zones.json scripts/ui/zone_cards.gd tools/garden_zones_check.gd]
  `vfx-vex-precast-slab` [docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_ult.gd]
  `anim-loot-open` [docs/art/wardens/CLIPS.md scripts/heroes/warden_glb.gd scripts/match/hunter.gd]
  `combat-mob-boss-fsm` [scripts/match/blight.gd scripts/match/boss.gd, +4 more]
  `combat-vex-cone-net` [docs/heroes/gunslinger.md scripts/arch/kits/gunslinger_kit.gd, +2 more]
  `farm-transfer-transport` [docs/DEBT.md]
  `levelup-clear-1111` [docs/HUD.md scripts/ui/hud.gd, +4 more]
  `select-loading-1111` [docs/decisions/0019-prematch-lobby.md scripts/ui/prematch_view.gd tools/prematch_check.gd]
  `sfx-enemy-tells` [scripts/arch/arch_kit.gd scripts/core/sfx.gd scripts/match/aim/aim_draw.gd]
  `anim-elim-beat-wisp` [tools/wisp_shots.gd]
  `anim-gil-clips` [art/wardens/gil/gil.glb docs/DEBT.md tools/clip_check.gd tools/warden_model_check.gd]
  `grimble-barge-chain` [content/archetypes/dredge.json]
  `sable-vault-exit` [scripts/arch/kits/thief_kit.gd]
  `ui-inventory-pass` [scripts/ui/hud.gd scripts/ui/loadout_panel.gd tools/inv_shots.gd tools/inventory_check.gd]
  `boss-bot-focus-1111` [scripts/combat/kin_tactics.gd scripts/match/bot.gd, +2 more]
  `combat-blight-endgame` [scripts/match/blight_dir.gd scripts/match/heart.gd, +3 more]
  `feel-dash-jump-keep` [content/rules/feel_golden.json content/rules/hunter_move.json, +8 more]
  `momentum-1111` [content/rules/hunter_move.json docs/MOVEMENT_FEEL.md, +3 more]
  `ui-hud-scale` [scripts/ui/hud.gd scripts/ui/hud_panels.gd tools/check_registry.gd tools/style_baseline.json]
  `ui-safe-area-one` [scripts/ui/hud.gd scripts/ui/prematch_view.gd scripts/ui/ui.gd scripts/ui/ways_out_hud.gd]
  `feel-home-fixed-step` [content/rules/feel_golden.json content/rules/hunter_move.json, +8 more]
  `feel-scout-cam` [content/rules/camera.json scripts/match/cam.gd]
  `sfx-incoming-hit-dir` [docs/AUDIO.md docs/wiki/Rules.md, +3 more]
  `sv-names-1113` [content/archetypes/gil.json docs/wiki/Class-Novice-Mage.md scripts/arch/kits/gil_kit.gd]
  `ui-glossary-pass` [scripts/home/home_classes.gd scripts/ui/full_map.gd]
  `vfx-albert-slab` [content/rules/kit_parity.json content/vfx/bulwark.json, +4 more]
  `vfx-meeko-hit-hearth` [content/archetypes/gunslinger.json content/archetypes/mage.json, +17 more]
  `carry-two-1111` [scripts/core/game.gd scripts/core/key_migrate.gd, +4 more]
  `feel-glide-sink-heat` [content/rules/feel_golden.json content/rules/hunter_move.json, +8 more]
  `anim-gil-grabbag` [art/wardens/gil/gil.glb docs/DEBT.md tools/clip_check.gd tools/warden_model_check.gd]
  `feel-gil-sweeps` [content/rules/tuning.json docs/HUD.md, +4 more]
  `teach-hold` [docs/HUD.md scripts/core/settings.gd]
  `ui-boki-box-hazard` [content/maps/hollowcrown.json scripts/match/bot.gd, +2 more]
  `ui-hazard-map` [content/maps/hollowcrown.json scripts/match/bot.gd scripts/match/match.gd tools/make_hollowcrown.py]
  `ui-quest-tracker` [scripts/ui/hud.gd scripts/ui/hud_panels.gd tools/check_registry.gd tools/style_baseline.json]
  `verify-camera-ab` [content/rules/camera.json tools/cam_framing_check.gd tools/gameplay_media.gd]
  `tut-lead-swap-hint` [scripts/core/game.gd scripts/core/key_migrate.gd, +4 more]
