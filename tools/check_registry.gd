class_name CheckRegistry
extends RefCounted
## The check registry (AGENTS.md section 2): flag -> the tool that runs it, so new checks never add
## inline hooks to main.gd. Each entry: [script path, meta name the check is kept under on Main
## (some checks read their own state back through it), optional argument passed to run()].
## Older checks still hooked inline in main.gd move here in the cleanup pass (docs/DEBT.md).

const CHECKS := {
	"--place-clearance-check": ["res://tools/place_clearance_check.gd", "place_clearance_check", null],      # clearance
	"--ways-out-map-check": ["res://tools/ways_out_map_check.gd", "ways_out_map_check", null],      # spec 8 sites
	"--kit-parity-check": ["res://tools/kit_parity_check.gd", "kit_parity_check", null],
	"--feed-check": ["res://tools/feed_check.gd", "feed_check", null],      # hungry -> kibble -> feed -> can go
	"--demo-check": ["res://tools/demo_check.gd", "demo_check", null],      # the recording presets
	# first: it wraps the other flags on the line (a second launch of a bench or check)
	"--warm-twice": ["res://tools/warm_twice.gd", "warm_twice", null],      # a second launch, for benches
	"--boki-keys-check": ["res://tools/boki_keys_check.gd", "boki_keys_check", null],      # quick Boki command keys
	"--heart-check": ["res://tools/heart_check.gd", "heart_check", null],      # the Heart early seat (0023, 0051)
	# the Ways Out strip and Gate prompt
	"--ways-out-hud-check": ["res://tools/ways_out_hud_check.gd", "ways_out_hud_check", null],
	"--ways-out-map-ui-check": ["res://tools/ways_out_map_ui_check.gd", "ways_out_map_ui_check", null],
	"--ways-out-map-ui-shots": ["res://tools/ways_out_map_ui_shots.gd", "ways_out_map_ui_shots", null],      # GPU
	"--ways-out-hud-shots": ["res://tools/ways_out_hud_shots.gd", "ways_out_hud_shots", null],      # GPU
	"--ways-out-vfx-check": ["res://tools/ways_out_vfx_check.gd", "ways_out_vfx_check", null],      # 0051 seat looks
	"--ways-out-vfx-shots": ["res://tools/ways_out_vfx_shots.gd", "ways_out_vfx_shots", null],      # GPU, --shots-dir=
	"--ways-out-sfx-check": ["res://tools/ways_out_sfx_check.gd", "ways_out_sfx_check", null],      # the Ways Out calls
	"--carry-boki-check": ["res://tools/carry_boki_check.gd", "carry_boki_check", null],      # lifting a Boki
	"--carry-pose-check": ["res://tools/carry_pose_check.gd", "carry_pose_check", null],      # Heartspark carry layer
	"--kin-indoors-check": ["res://tools/kin_indoors_check.gd", "kin_indoors_check", null],
	"--chore-check": ["res://tools/chore_check.gd", "chore_check", null],      # GARDEN.md section 4 Chore
	"--item-pages-check": ["res://tools/item_pages_check.gd", "item_pages_check", null],      # GARDEN_MODERN.md 5
	"--garden-items-check": ["res://tools/garden_items_check.gd", "garden_items_check", null],      # GARDEN_MODERN.md 1
	"--nest-items-check": ["res://tools/nest_items_check.gd", "nest_items_check", null],      # GARDEN_MODERN 1.2
	"--garden-prizes-check": ["res://tools/garden_prizes_check.gd", "garden_prizes_check", null],
	"--garden-recipes-check": ["res://tools/garden_recipes_check.gd", "garden_recipes_check", null],      # Mixing Bowl
	"--base-life-check": ["res://tools/base_life_check.gd", "base_life_check", null],      # GARDEN.md 9.2
	"--stat-budget-check": ["res://tools/stat_budget_check.gd", "stat_budget_check", null],      # decision 0022
	"--duo-check": ["res://tools/duo_check.gd", "duo_check", null],      # GARDEN_MODERN 5 rank 4 duo bonus
	"--raising-check": ["res://tools/raising_check.gd", "raising_check", null],      # the home raising loop
	"--garden-soak": ["res://tools/garden_soak.gd", "garden_soak", null],      # the garden pieces together, 30 days
	"--base-demo-check": ["res://tools/base_demo_check.gd", "base_demo_check", null],      # GARDEN.md 9.8
	"--garden-nav-check": ["res://tools/garden_nav_check.gd", "garden_nav_check", null],      # GARDEN nav sweep
	"--wade-check": ["res://tools/wade_check.gd", "wade_check", null],      # GARDEN.md 4 Boki wading
	"--garden-whistle-check": ["res://tools/garden_whistle_check.gd", "garden_whistle_check", null],
	"--garden-whistle-shots": ["res://tools/garden_whistle_shots.gd", "garden_whistle_shots", null],
	"--garden-daily-check": ["res://tools/garden_daily_check.gd", "garden_daily_check", null],      # wishes, away gifts
	"--snack-patch-check": ["res://tools/snack_patch_check.gd", "snack_patch_check", null],      # garden snack patch
	"--lean-check": ["res://tools/lean_check.gd", "lean_check", null],      # food lean by type (base_mode)
	"--lean-shots": ["res://tools/lean_shots.gd", "lean_shots", null],      # --shots-dir=<dir>
	"--sable-hair-shots": ["res://tools/sable_hair_shots.gd", "sable_hair_shots", null],      # --shots-dir=<dir>, GPU
	"--mentor-check": ["res://tools/mentor_check.gd", "mentor_check", null],      # GARDEN.md section 3
	"--trait-drift-check": ["res://tools/trait_drift_check.gd", "trait_drift_check", null],      # GARDEN.md 3, lever 3
	"--baby-parents-check": ["res://tools/baby_parents_check.gd", "baby_parents_check", null],      # GARDEN.md 6
	"--family-tree-check": ["res://tools/family_tree_check.gd", "family_tree_check", null],      # GARDEN_MODERN 5.8
	"--kael-sword-check": ["res://tools/kael_sword_shots.gd", "kael_sword_shots", "check"],      # item 131b
	"--kael-sword-shots": ["res://tools/kael_sword_shots.gd", "kael_sword_shots", "shots"],      # --shots-dir=<dir>
	"--glide-hold-check": ["res://tools/glide_hold_check.gd", "glide_hold_check", null],  # holding Space never glides
	# the glider banks into its turns, the dive pitches nose-down, a rider keeps its seat: on every Hunter's rig
	"--glide-bank-check": ["res://tools/glide_bank_check.gd", "glide_bank_check", null],
	"--air-control-check": ["res://tools/air_control_check.gd", "air_control_check", null],      # one movement model
	"--glider-heat-check": ["res://tools/glider_heat_check.gd", "glider_heat_check", null],      # item 63
	"--mesh-arrays-check": ["res://tools/mesh_arrays_check.gd", "mesh_arrays_check", null],      # item 33 (1108)
	# shot, knocked, stunned, reeled under the glider; knocked in the air (Lace, Kael, Vex, Albert)
	"--glide-hit-check": ["res://tools/glide_hit_check.gd", "glide_hit_check", null],
	"--equal-check": ["res://tools/equal_check.gd", "equal_check", "all"],
	"--equal-migrate-check": ["res://tools/equal_check.gd", "equal_check", "migrate"],
	"--backpack-check": ["res://tools/backpack_check.gd", "backpack_check", null],      # backpack tiers, at risk
	"--practice-hero-check": ["res://tools/practice_hero_check.gd", "practice_hero_check", null],
	"--parity-bench-check": ["res://tools/parity_bench_check.gd", "parity_bench_check", null],
	"--support-check": ["res://tools/support_check.gd", "support_check", "all"],
	"--tender-combo-check": ["res://tools/support_check.gd", "support_check", "tender"],
	"--rimewright-combo-check": ["res://tools/support_check.gd", "support_check", "rimewright"],
	"--zone-check": ["res://tools/hero_pair_check.gd", "hero_pair_check", null],
	"--dolm-combo-check": ["res://tools/breah_combo_check.gd", "hero_pair_check", null],
	"--tenzo-edge-check": ["res://tools/tenzo_edge_check.gd", "hero_pair_check", null],
	"--ostra-combo-check": ["res://tools/ostra_combo_check.gd", "hero_pair_check", null],
	"--gil-kit-check": ["res://tools/gil_kit_check.gd", "hero_pair_check", null],      # Gil, the Novice Mage
	"--dredge-combo-check": ["res://tools/dredge_combo_check.gd", "hero_check", null],
	"--ashwick-combo-check": ["res://tools/ashwick_combo_check.gd", "hero_check", null],
	"--archer-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--bulwark-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--sting-check": ["res://tools/sting_check.gd", "sting_check", null],      # run-end stingers
	"--music-leave-check": ["res://tools/music_leave_check.gd", "music_leave_check", null],
	"--hot-zone-check": ["res://tools/hot_zone_check.gd", "hot_zone_check", null],      # map regions, hot drop zone
	"--region-shots": ["res://tools/region_shots.gd", "region_shots", null],      # --shots-dir=<dir>, GPU
	"--perf-bench": ["res://tools/perf_bench.gd", "perf_bench", null],      # item 94
	# draw calls, tris, shadow lights, frame ms
	"--perf-budget-check": ["res://tools/perf_budget_check.gd", "perf_budget_check", null],
	"--perf-overlay-check": ["res://tools/perf_overlay_check.gd", "perf_overlay_check", null],
	"--perf-throttle-check": ["res://tools/perf_throttle_check.gd", "perf_throttle_check", null],
	"--quality-check": ["res://tools/quality_check.gd", "quality_check", null],      # graphics presets
	"--clutter-check": ["res://tools/clutter_check.gd", "clutter_check", null],
	"--match-audio-check": ["res://tools/match_audio_check.gd", "match_audio_check", null],      # item 103
	"--hunter-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],
	"--class-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],      # (the old name)
	"--shot-vertical-check": ["res://tools/shot_vertical_check.gd", "shot_vertical_check", null],
	"--minigame-hub-check": ["res://tools/minigame_hub_check.gd", "minigame_hub_check", null],  # title
	"--kin-regen-check": ["res://tools/kin_regen_check.gd", "kin_regen_check", null],
	# Bokidex quirks, sex ratios
	"--mode-boki-check": ["res://tools/mode_boki_check.gd", "mode_boki_check", null],      # MODE_BOKI.md
	"--boki-quirks-check": ["res://tools/boki_quirks_check.gd", "boki_quirks_check", null],
	"--boki-react-check": ["res://tools/boki_react_check.gd", "boki_react_check", null],      # a Boki flinches when hit
	"--hp-regen-check": ["res://tools/hp_regen_check.gd", "hp_regen_check", null],
	"--kin-loss-check": ["res://tools/kin_loss_check.gd", "kin_loss_check", null],
	# level-up / ready: one body glow, no ring
	"--level-vfx-check": ["res://tools/level_vfx_check.gd", "level_vfx_check", null],
	"--results-ways-check": ["res://tools/results_ways_check.gd", "results_ways_check", null],      # 0051 results
	"--kill-reset-check": ["res://tools/kill_reset_check.gd", "kill_reset_check", null],
	"--dash-dir-check": ["res://tools/dash_dir_check.gd", "dash_dir_check", null],
	# two-step abilities report their window
	"--recast-cue-check": ["res://tools/recast_cue_check.gd", "recast_cue_check", null],
	"--recast-cue-shots": ["res://tools/recast_cue_shots.gd", "recast_cue_shots", null],      # --shots-dir=<dir>
	"--dash-dir-shots": ["res://tools/dash_dir_shots.gd", "dash_dir_shots", null],  # each Hunter dashes four ways (GPU)
	"--dash-aim-check": ["res://tools/dash_aim_check.gd", "dash_aim_check", null],
	"--boki-moves-check": ["res://tools/boki_moves_check.gd", "boki_moves_check", null],      # move tiles
	"--boki-moves-shots": ["res://tools/boki_moves_shots.gd", "boki_moves_shots", null],      # --shots-dir=<dir>
	"--rank-ui-check": ["res://tools/rank_ui_check.gd", "rank_ui_check", null],      # choose what to rank: + and pips
	"--rank-ui-shots": ["res://tools/rank_ui_shots.gd", "rank_ui_shots", null],      # --shots-dir=<dir>
	"--sfx-set-check": ["res://tools/sfx_set_check.gd", "sfx_set_check", null],      # sound sets, loudness
	"--outpost-look-shots": ["res://tools/outpost_look_shots.gd", "outpost_look_shots", null],
	"--outpost-look-check": ["res://tools/outpost_look_check.gd", "outpost_look_check", null],
	"--exit-signal-check": ["res://tools/exit_signal_check.gd", "exit_signal_check", null],
	"--exit-signal-shots": ["res://tools/exit_signal_shots.gd", "exit_signal_shots", null],
	"--dash-slot-check": ["res://tools/dash_slot_check.gd", "dash_slot_check", null],
	"--reticle-check": ["res://tools/reticle_check.gd", "reticle_check", null],
	"--ping-check": ["res://tools/ping_check.gd", "ping_check", null],
	"--hold-pose-check": ["res://tools/hold_pose_check.gd", "hold_pose_check", null],      # hold poses need the key
	# bots use every kit slot (docs/BOT_KIT_USE.md)
	"--bot-kit-use": ["res://tools/bot_kit_use_check.gd", "bot_kit_use_check", null],
	"--dash-streak-check": ["res://tools/dash_streak_check.gd", "dash_streak_check", null],
	"--dash-streak-shots": ["res://tools/dash_streak_shots.gd", "dash_streak_shots", null],
	"--dash-flow-check": ["res://tools/dash_flow_check.gd", "dash_flow_check", null],      # dash -> ability rows
	# docs/decisions/0022
	"--cc-exit-buffer-check": ["res://tools/cc_exit_buffer_check.gd", "cc_exit_buffer_check", null],
	"--airdash-glide-check": ["res://tools/airdash_glide_check.gd", "airdash_glide_check", null],
	"--boki-dash-check": ["res://tools/boki_dash_check.gd", "boki_dash_check", null],      # item 185
	"--wirerun-dist-check": ["res://tools/wirerun_dist_check.gd", "wirerun_dist_check", null],      # Sparkle 11-10
	"--boki-agency-check": ["res://tools/boki_agency_check.gd", "boki_agency_check", null],      # item 184b
	# golden Hunter movement traces (--update)
	"--feel-golden-check": ["res://tools/feel_golden_check.gd", "feel_golden_check", null],
	"--air-limits-check": ["res://tools/air_limits_check.gd", "air_limits_check", null],      # items 162, 162b
	"--layout-check": ["res://tools/layout_check.gd", "layout_check", null],      # item 151
	"--drop-launch-check": ["res://tools/drop_launch_check.gd", "drop_launch_check", null],      # item 163
	"--ride-shots": ["res://tools/ride_shots.gd", "ride_shots", null],      # item 163 camera (GPU)
	"--ttk-check": ["res://tools/ttk_check.gd", "ttk_check", null],      # time to knock vs the source (docs/TTK.md)
	"--hero-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--hudref-check": ["res://tools/hudref_check.gd", "hudref_check", null],
	# --shots-dir=<dir> [--size=WxH] (GPU)
	"--team-boki-shots": ["res://tools/team_boki_shots.gd", "team_boki_shots", null],
	"--shake-check": ["res://tools/shake_check.gd", "shake_check", null],
	"--cam-framing-check": ["res://tools/cam_framing_check.gd", "cam_framing_check", "check"],
	# --shots-dir=<dir> (GPU)
	"--cam-framing-shots": ["res://tools/cam_framing_check.gd", "cam_framing_check", "shots"],
	"--keys-check": ["res://tools/keys_check.gd", "keys_check", null],
	"--breakables-check": ["res://tools/breakables_check.gd", "breakables_check", null],
	"--cover-check": ["res://tools/cover_check.gd", "cover_check", null],
	"--aimkit-check": ["res://tools/aimkit_check.gd", "aimkit_check", null],
	"--pin-bjorn-shots": ["res://tools/pin_bjorn_shots.gd", "pin_bjorn_shots", null],
	"--warden-model-check": ["res://tools/warden_model_check.gd", "warden_model_check", null],      # the Warden models
	"--warden-rig-json": ["res://tools/warden_rig_json.gd", "warden_rig_json", null],      # rig for the Blender build
	"--warden-glb-check": ["res://tools/warden_glb_check.gd", "warden_glb_check", null],      # .glb loader
	"--warden-rest-check": ["res://tools/warden_rest_check.gd", "warden_rest_check", "check"],      # baked rig rests
	"--warden-rest-bake": ["res://tools/warden_rest_check.gd", "warden_rest_check", "bake"],
	"--warm-stamp-check": ["res://tools/warm_stamp_check.gd", "warm_stamp_check", null],      # warm-up kept on disk
	"--load-trim-check": ["res://tools/load_trim_check.gd", "load_trim_check", null],      # build.hunters trims
	"--warden-shots": ["res://tools/warden_shots.gd", "warden_shots", null],      # models beside sheets
	# no clip stretches a skinned edge past 1.3x
	"--stretch-check": ["res://tools/stretch_check.gd", "stretch_check", null],
	"--clip-check": ["res://tools/clip_check.gd", "clip_check", null],      # hand-keyed clips, weapon on the bone
	"--home-gait-check": ["res://tools/home_gait_check.gd", "home_gait_check", null],      # the Empty's planted feet
	"--clip-live-check": ["res://tools/clip_live_check.gd", "clip_live_check", null],      # clips in a real match
	"--clip-live-sable-check": ["res://tools/clip_live_sable_check.gd", "clip_live_sable_check", null],
	"--pip-live-check": ["res://tools/pip_live_check.gd", "pip_live_check", null],      # Pip's clips in a real match
	"--vex-clip-live-check": ["res://tools/vex_clip_live_check.gd", "vex_clip_live_check", null],
	"--cinder-art-check": ["res://tools/cinder_art_check.gd", "cinder_art_check", null],
	"--ryzz-live-check": ["res://tools/ryzz_live_check.gd", "ryzz_live_check", null],
	"--clip-live-claire-check": ["res://tools/clip_live_claire_check.gd", "clip_live_claire_check", null],
	"--claire-skate-shots": ["res://tools/claire_skate_shots.gd", "claire_skate_shots", null],
	"--neve-shots": ["res://tools/neve_shots.gd", "neve_shots", null],      # --shots-dir=<dir>
	"--boki-guard-shots": ["res://tools/boki_guard_shots.gd", "boki_guard_shots", null],      # --shots-dir=<dir>
	"--clip-live-grimble": ["res://tools/clip_live_grimble.gd", "clip_live_grimble", null],      # Grimble, the same
	"--motley-live-check": ["res://tools/motley_live_check.gd", "motley_live_check", null],      # the jack, live
	"--motley-card-shots": ["res://tools/motley_card_shots.gd", "motley_card_shots", null],      # the card vs him
	"--parity-strip": ["res://tools/parity_strip.gd", "parity_strip", null],      # our move vs footage frames (GPU)
	"--clip-shots": ["res://tools/clip_shots.gd", "clip_shots", null],      # a Hero's hand-keyed clips, frame by frame
	"--glide-shots": ["res://tools/glide_shots.gd", "glide_shots", null],      # every Hunter gliding: turns, dive
	# Meeko's sun and cloud orbit her, bob, clear the wings
	"--meeko-orbit-check": ["res://tools/meeko_orbit_check.gd", "meeko_orbit_check", null],
	"--meeko-orbit-shots": ["res://tools/meeko_orbit_shots.gd", "meeko_orbit_shots", null],   # frames of that orbit
	"--idle-shots": ["res://tools/idle_shots.gd", "idle_shots", null],      # every Hunter standing still (IDLE_AUDIT)
	"--lineup-shot": ["res://tools/lineup_shot.gd", "lineup_shot", null],      # every Hunter in a row, true scale
	"--hunter-tint-shots": ["res://tools/hunter_tint_shots.gd", "hunter_tint_shots", null],      # colour vs .glb
	"--anim-audit": ["res://tools/anim_audit.gd", "anim_audit", null],      # gait gate
	"--anim-shots": ["res://tools/anim_shots.gd", "anim_shots", null],      # walk, run, idle, attacks
	"--crouch-check": ["res://tools/crouch_check.gd", "crouch_check", null],
	"--crouch-shots": ["res://tools/crouch_shots.gd", "crouch_shots", null],
	"--boki-rig-shots": ["res://tools/boki_rig_shots.gd", "boki_rig_shots", null],      # rigged Boki review sheets
	# a Boki taking a hit, strips
	"--boki-flinch-shots": ["res://tools/boki_flinch_shots.gd", "boki_flinch_shots", null],
	"--boki-home-shots": ["res://tools/boki_home_shots.gd", "boki_home_shots", null],      # a sheet per home state
	"--boki-rig-check": ["res://tools/boki_rig_check.gd", "boki_rig_check", null],      # rigged Boki
	"--boki-anim-audit": ["res://tools/boki_anim_audit.gd", "boki_anim_audit", null],      # rigged Boki gait gate
	"--boki-anim-shots": ["res://tools/boki_anim_shots.gd", "boki_anim_shots", null],      # rigged Boki gait strips
	"--dancer-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "thief"],
	"--juggernaut-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "juggernaut"],
	"--vv-shots": ["res://tools/vv_shots.gd", "vv_shots", null],          # Sparkle / Vex screenshots
	"--breah-shots": ["res://tools/breah_shots.gd", "breah_shots", null],          # Tarek review screenshots
	"--loot-full-check": ["res://tools/loot_full_check.gd", "loot_full_check", null],      # full-inventory looting
	"--inventory-check": ["res://tools/inventory_check.gd", "inventory_check", null],      # in-match inventory
	"--inv-shots": ["res://tools/inv_shots.gd", "inv_shots", null],      # --shots-dir=<dir>, --resolution
	"--loot-full-shots": ["res://tools/loot_full_shots.gd", "loot_full_shots", null],      # --shots-dir=<dir>
	"--dash-slot-shots": ["res://tools/dash_slot_shots.gd", "dash_slot_shots", null],
	"--reticle-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "reticle"],
	"--ping-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "ping"],
	"--combo-mark-shots": ["res://tools/combo_mark_shots.gd", "combo_mark_shots", null],  # overhead combo tag strips
	"--combo51-shots": ["res://tools/combo51_shots.gd", "combo51_shots", null],      # item 51 combo strips
	"--dash-frames-check": ["res://tools/dash_frames.gd", "dash_frames", null],      # item 181
	"--hero-vfx-check": ["res://tools/hero_vfx_check.gd", "hero_vfx_check", null],
	"--gameplay-media": ["res://tools/gameplay_media.gd", "gameplay_media", null],      # website clips and stills
	"--hero-vfx-reel": ["res://tools/hero_vfx_reel.gd", "hero_vfx_reel", null],
	# the per-Hunter parity reels (docs/parity_reel)
	"--parity-reel": ["res://tools/parity_reel.gd", "parity_reel", null],
	"--hero-vfx-gallery": ["res://tools/hero_vfx_gallery.gd", "hero_vfx_gallery", null],      # every look, side by side
	"--ostra-orb-shots": ["res://tools/ostra_orb_shots.gd", "ostra_orb_shots", null],      # item 60 screenshots
	"--ostra-globe-shots": ["res://tools/ostra_globe_shots.gd", "ostra_globe_shots", null],      # Brimseed growth
	"--title-check": ["res://tools/title_check.gd", "title_check", null],      # the title: menu, key art, frame budget
	"--hatch-check": ["res://tools/hatch_check.gd", "hatch_check", null],      # the hatch: a quiet, personal moment
	# the black egg: pool, mutations, hidden basket
	"--mystery-egg-check": ["res://tools/mystery_egg_check.gd", "mystery_egg_check", null],
	"--ultbond-check": ["res://tools/ultbond_check.gd", "ultbond_check", null],      # keys, bond hook, release
	"--far-props-check": ["res://tools/far_props_check.gd", "far_props_check", null],      # far rocks and trees batched
	"--wallmove-check": ["res://tools/wallmove_check.gd", "wallmove_check", null],
	"--first15-shots": ["res://tools/first15_shots.gd", "first15_shots", null],      # --shots-dir=<dir> --size=WxH
	"--tutorial-strip-shots": ["res://tools/tutorial_strip_shots.gd", "tutorial_strip_shots", null],
	# walking off a ledge is never gated
	"--ledge-walk-check": ["res://tools/ledge_walk_check.gd", "ledge_walk_check", null],
	"--tutorial-hud-shots": ["res://tools/tutorial_hud_shots.gd", "tutorial_hud_shots", null],      # --shots-dir=<dir>
	"--tutorial-clean-check": ["res://tools/tutorial_clean_check.gd", "tutorial_clean_check", null],  # nothing random
	# the first two Extractions' guide
	"--first-match-guide-check": ["res://tools/first_match_guide_check.gd", "first_match_guide_check", null],
	"--tutorial-hud-check": ["res://tools/tutorial_hud_check.gd", "tutorial_hud_check", null],      # one voice
	"--tutorial-idle-check": ["res://tools/tutorial_idle_check.gd", "tutorial_idle_check", null],      # no idle moment
	# fight beats per starter
	"--tutorial-fight-check": ["res://tools/tutorial_fight_check.gd", "tutorial_fight_check", null],
	"--arrival-check": ["res://tools/arrival_check.gd", "arrival_check", null],      # arrival modals, top bar
	"--journal-check": ["res://tools/journal_check.gd", "journal_check", null],      # journal, away card
	"--arrival-shots": ["res://tools/arrival_shots.gd", "arrival_shots", null],      # --shots-dir=<dir>
	"--uipolish-check": ["res://tools/uipolish_check.gd", "uipolish_check", null],     # settings, menu look
	"--msg-queue-check": ["res://tools/msg_queue_check.gd", "msg_queue_check", null],     # one message lane
	"--unmasked-check": ["res://tools/unmasked_check.gd", "unmasked_check", null],      # the Unmasked
	"--empty-shots": ["res://tools/empty_shots.gd", "empty_shots", null],      # the Empty creator + Relic moment shots
	"--portrait-check": ["res://tools/portrait_check.gd", "portrait_check", null],     # the Wardens' painted faces
	"--perkorb-check": ["res://tools/perkorb_check.gd", "perkorb_check", null],      # perk orbs, boss fan, weapon path
	"--prematch-check": ["res://tools/prematch_check.gd", "prematch_check", null],      # the pre-match lobby
	# lobby screenshots + safe-area scan at the window size
	"--prematch-shots": ["res://tools/prematch_shots.gd", "prematch_shots", null],
	"--hero-title-check": ["res://tools/hero_title_check.gd", "hero_title_check", null],
	"--bot-names-check": ["res://tools/bot_names_check.gd", "bot_names_check", null],      # bots wear gamer tags
	"--bot-names-shots": ["res://tools/bot_names_shots.gd", "bot_names_shots", null],
	"--mantle-clip": ["res://tools/mantle_clip.gd", "mantle_clip", null],
	"--cliff-mantle-check": ["res://tools/cliff_mantle_check.gd", "cliff_mantle_check", null],
	"--wall-size-check": ["res://tools/wall_size_check.gd", "wall_size_check", null],  # no lone posts
	"--crowd-check": ["res://tools/crowd_check.gd", "crowd_check", null],  # 40 hunters: colours, naps, models once
	"--hitbox-size-check": ["res://tools/hitbox_size_check.gd", "hitbox_size_check", null],
	# measured reach, width and arc of every input
	"--hit-shape-check": ["res://tools/hit_shape_check.gd", "hit_shape_check", null],
	# kit hits on Boki (BokiHit)
	"--boki-hit-table-check": ["res://tools/boki_hit_table_check.gd", "boki_hit_table_check", null],
	"--hitbox-size-shots": ["res://tools/hitbox_size_shots.gd", "hitbox_size_shots", null],
	"--toy-check": ["res://tools/toy_check.gd", "toy_check", null],      # base toys (GARDEN.md 4)
	"--stat-up-vfx-check": ["res://tools/stat_up_vfx_check.gd", "stat_up_vfx_check", "check"],      # StatGlint
	"--stat-up-vfx-shots": ["res://tools/stat_up_vfx_check.gd", "stat_up_vfx_check", "shots"],      # --shots-dir=<dir>
	"--garden-first-day-check": ["res://tools/garden_first_day_check.gd", "garden_first_day_check", null],
	"--garden-trust-check": ["res://tools/garden_trust_check.gd", "garden_trust_check", null],      # trust from care
	"--lean-snacks-check": ["res://tools/lean_snacks_check.gd", "lean_snacks_check", null],
	"--garden-hud-groups": ["res://tools/garden_hud_groups.gd", "garden_hud_groups", null],      # day 1, 5
	"--garden-zone-shots": ["res://tools/garden_zone_shots.gd", "garden_zone_shots", null],      # --zone= --shots-dir=
	"--garden-unlock-pace-check": ["res://tools/garden_unlock_pace_check.gd", "garden_unlock_pace_check", null],
	"--garden-zones-check": ["res://tools/garden_zones_check.gd", "garden_zones_check", null],      # GARDEN.md 10 zones
	"--zone-affinity-check": ["res://tools/zone_affinity_check.gd", "zone_affinity_check", null],  # zone loves
	"--hub-hints-check": ["res://tools/hub_hints_check.gd", "hub_hints_check", null],      # GARDEN.md 10 hub hints
	"--garden-audio-check": ["res://tools/garden_audio_check.gd", "garden_audio_check", null],  # GARDEN.md 10.2 sound
	# --home-verbs-check also takes --home-verbs-shots=<dir>
	"--home-verbs-check": ["res://tools/home_verbs_check.gd", "home_verbs_check", null],
	"--farmbuild": ["res://tools/farmbuild_check.gd", "farmbuild_check", null],      # also --farmbuild-shots=<dir>
	"--come-look-check": ["res://tools/come_look_check.gd", "come_look_check", null],  # news at home
	"--boki-lines-check": ["res://tools/boki_lines_check.gd", "boki_lines_check", null],      # Boki talk (item 105)
	"--boki-talk-shots": ["res://tools/boki_talk_shots.gd", "boki_talk_shots", null],      # --shots-dir=<dir>
	"--build-ui-check": ["res://tools/build_ui_check.gd", "build_ui_check", null],      # also --build-ui-shots=<dir>
	"--build-hold-shots": ["res://tools/build_hold_shots.gd", "build_hold_shots", null],
	"--build-hold-check": ["res://tools/build_hold_check.gd", "build_hold_check", null],
	"--farm-tutorial-check": ["res://tools/farm_tutorial_check.gd", "farm_tutorial_check", null],
	"--farm-spot-shots": ["res://tools/farm_tutorial_check.gd", "farm_tutorial_check", null],
	"--race-check": ["res://tools/race_check.gd", "race_check", null],      # the Dash, GARDEN.md 9.4
	"--relay-cup-check": ["res://tools/relay_cup_check.gd", "relay_cup_check", null],      # GARDEN_MODERN 4.2
	"--shove-check": ["res://tools/shove_check.gd", "shove_check", null],      # the Stump Shove, GARDEN.md 5.2
	"--tumble-check": ["res://tools/tumble_check.gd", "tumble_check", null],      # Tumble, GARDEN_MODERN.md 4.2
	"--seek-check": ["res://tools/seek_check.gd", "seek_check", null],      # Seek, GARDEN.md 5.3
	"--garden-visitor-check": ["res://tools/garden_visitor_check.gd", "garden_visitor_check", null],
	"--volley-check": ["res://tools/volley_check.gd", "volley_check", null],      # Spark Volley, GARDEN.md 5.4
	"--showcase-check": ["res://tools/showcase_check.gd", "showcase_check", null],      # the Dash's showcase wall
	# --glint-fishing-check also takes --glint-fishing-shots=<dir>
	"--glint-fishing-check": ["res://tools/glint_fishing_check.gd", "glint_fishing_check", null],      # 4.2 game 4
	"--garden-sfx-check": ["res://tools/garden_sfx_check.gd", "garden_sfx_check", null],      # garden minigame sounds
	"--echo-steps-check": ["res://tools/echo_steps_check.gd", "echo_steps_check", null],  # GARDEN_MODERN 4.2
	"--echo-steps-clip": ["res://tools/echo_steps_clip.gd", "echo_steps_clip", null],  # --shots-dir=<dir>
	"--show-ring-check": ["res://tools/show_ring_check.gd", "show_ring_check", null],      # GARDEN_MODERN 4.2 game 3
	"--show-ring-shots": ["res://tools/show_ring_shots.gd", "show_ring_shots", null],      # --shots-dir= (GPU)
	"--farm-hob-shots": ["res://tools/farm_tutorial_check.gd", "farm_tutorial_check", null],
	# fresh save to first run
	"--new-player-flow-check": ["res://tools/new_player_flow_check.gd", "new_player_flow_check", null],
	"--prologue-check": ["res://tools/prologue_check.gd", "prologue_check", null],      # also --shots-dir=<dir>
	"--economy-floor-check": ["res://tools/economy_floor_check.gd", "economy_floor_check", null],      # never stuck
	"--market-check": ["res://tools/market_check.gd", "market_check", null],      # docs/decisions/0013-market.md
	"--drop-feel-check": ["res://tools/drop_check.gd", "drop_feel_check", null],      # the opening drop
	"--expedition-shots": ["res://tools/expedition_shots.gd", "expedition_shots", null],      # --expedition-shots=<dir>
	"--void-ui-shots": ["res://tools/void_ui_shots.gd", "void_ui_shots", null],      # --void-ui-shots=<dir>
	"--market-shots": ["res://tools/market_shots.gd", "market_shots", null],      # --market-shots=<dir>
	"--displace-net-check": ["res://tools/displace_net_check.gd", "displace_net_check", null],     # 2 games, relay
	# 2 games, relay, docs/decisions/0018
	"--revive-net-check": ["res://tools/revive_net_check.gd", "revive_net_check", null],
	"--remote-anim-check": ["res://tools/remote_anim_check.gd", "remote_anim_check", null],     # 2 games, relay
	# + a server, delay
	"--online-displace-check": ["res://tools/online_displace_check.gd", "online_displace_check", null],
	# 2 games, laggy relay
	"--remote-smooth-check": ["res://tools/remote_smooth_check.gd", "remote_smooth_check", null],
	"--breaker-proof-shots": ["res://tools/breaker_proof_shots.gd", "breaker_proof_shots", null],
	"--warden-clips-check": ["res://tools/warden_clips_check.gd", "warden_clips_check", null],
	"--dead-kmoves-check": ["res://tools/dead_kmoves_check.gd", "dead_kmoves_check", null],
	"--rig-standard-check": ["res://tools/rig_standard_check.gd", "rig_standard_check", null],
	"--rig-shots": ["res://tools/rig_shots.gd", "rig_shots", null],
	"--shroud-shots": ["res://tools/shroud_shots.gd", "shroud_shots", null],
	"--glider-skin-shots": ["res://tools/glider_skin_shots.gd", "glider_skin_shots", null],
	"--shroud-check": ["res://tools/shroud_check.gd", "shroud_check", null],
	"--weapon-audit": ["res://tools/weapon_audit.gd", "weapon_audit", null],
	"--warden-stance-check": ["res://tools/warden_stance_check.gd", "warden_stance_check", null],
	"--warden-stance-shots": ["res://tools/warden_stance_shots.gd", "warden_stance_shots", null],
	"--mantle-look-check": ["res://tools/mantle_look_check.gd", "mantle_look_check", null],      # Mantle look, creator
	"--wisp-check": ["res://tools/wisp_check.gd", "wisp_check", null],      # docs/decisions/0019
	"--wisp-shots": ["res://tools/wisp_shots.gd", "wisp_shots", null],      # --shots-dir=<dir>
	"--wisp-clarity-shots": ["res://tools/wisp_clarity_shots.gd", "wisp_clarity_shots", null],      # --shots-dir=<dir>
	"--kin-wisp-form-check": ["res://tools/kin_wisp_form_check.gd", "kin_wisp_form_check", null],  # downed: Boki wisps
	"--boki-wisp-check": ["res://tools/boki_wisp_check.gd", "boki_wisp_check", null],      # every species' Boki wisp
	"--kin-gallery": ["res://tests/kin_gallery.gd", "kin_gallery", null],      # the Model Room; --kin-wisps etc.
	"--garden-pace-check": ["res://tools/garden_pace_check.gd", "garden_pace_check", null],  # GARDEN.md Pace
	"--box-revive-check": ["res://tools/box_revive_check.gd", "box_revive_check", null],      # docs/decisions/0018
	"--depth-cue-check": ["res://tools/depth_cue_check.gd", "depth_cue_check", null],
	"--depth-shots": ["res://tools/depth_shots.gd", "depth_shots", null],      # --shots-dir=<dir> [--seed=N]
	"--minimap-check": ["res://tools/minimap_check.gd", "minimap_check", null],      # MapDetail: default vs hold
	"--train-map-check": ["res://tools/train_map_check.gd", "train_map_check", null],      # TrainMap
	"--train-map-shots": ["res://tools/train_map_shots.gd", "train_map_shots", null],      # --shots-dir=<dir>
	"--minimap-shots": ["res://tools/minimap_shots.gd", "minimap_shots", null],      # --shots-dir=<dir>
	"--blight-edge-shots": ["res://tools/blight_edge_shots.gd", "blight_edge_shots", null],      # --shots-dir=
	"--box-revive-shots": ["res://tools/box_revive_shots.gd", "box_revive_shots", null],      # --shots-dir=<dir>
	"--train-halts-shots": ["res://tools/train_halts_shots.gd", "train_halts_shots", null],      # --shots-dir=<dir>
	"--shield-check": ["res://tools/shield_check.gd", "shield_check", null],      # shields never hide a Hunter
	"--clarity-shots": ["res://tools/clarity_shots.gd", "clarity_shots", null],      # 2v2, one down, --shots-dir=
	"--rate-card-check": ["res://tools/rate_card_check.gd", "rate_card_check", null],      # item 189
	"--clarity-check": ["res://tools/clarity_check.gd", "clarity_check", null],      # colour rule, downed, Boki
	"--roster-check": ["res://tools/roster_check.gd", "roster_check", null],      # docs/boki/ROSTER_50.md stubs
	"--evo-check": ["res://tools/evo_check.gd", "evo_check", null],      # evolution rules, Inks, bred sex
	"--roster-shots": ["res://tools/roster_shots.gd", "roster_shots", null],      # the 50 lined up
	"--mask-moment-check": ["res://tools/mask_moment_check.gd", "mask_moment_check", null],      # also --shots-dir=
	"--hob-check": ["res://tools/hob_check.gd", "hob_check", null],      # Hob in person, the second Mask; --shots-dir=
	"--kit-drill-check": ["res://tools/kit_drill_check.gd", "kit_drill_check", null],      # the first-time kit drill
	"--mask-lag-check": ["res://tools/mask_lag_check.gd", "mask_lag_check", null],      # frame times, Mask screens
}

## Runs the registered check named in args, if any (a flag also matches --flag=value).
## Returns true when one started (Main stops there).
static func run(main: Node, args: PackedStringArray) -> bool:
	for flag in CHECKS:
		if Array(args).any(func(a): return String(a).begins_with(flag)):
			var e: Array = CHECKS[flag]
			var c = load(String(e[0])).new()
			main.set_meta(String(e[1]), c)
			if e[2] == null:
				c.run(main)
			else:
				c.run(main, e[2])
			return true
	return false
