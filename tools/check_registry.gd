class_name CheckRegistry
extends RefCounted
## The check registry (AGENTS.md section 2): flag -> the tool that runs it, so new checks never add
## inline hooks to main.gd. Each entry: [script path, meta name the check is kept under on Main
## (some checks read their own state back through it), optional argument passed to run()].
## Older checks still hooked inline in main.gd move here in the cleanup pass (docs/DEBT.md).

const CHECKS := {
	"--kin-indoors-check": ["res://tools/kin_indoors_check.gd", "kin_indoors_check", null],
	"--base-life-check": ["res://tools/base_life_check.gd", "base_life_check", null],      # GARDEN.md 9.2
	"--raising-check": ["res://tools/raising_check.gd", "raising_check", null],      # the home raising loop
	"--base-demo-check": ["res://tools/base_demo_check.gd", "base_demo_check", null],      # GARDEN.md 9.8
	"--snack-patch-check": ["res://tools/snack_patch_check.gd", "snack_patch_check", null],      # garden snack patch
	"--lean-check": ["res://tools/lean_check.gd", "lean_check", null],      # food lean by type (base_mode)
	"--lean-shots": ["res://tools/lean_shots.gd", "lean_shots", null],      # --shots-dir=<dir>
	"--mentor-check": ["res://tools/mentor_check.gd", "mentor_check", null],      # GARDEN.md section 3
	"--trait-drift-check": ["res://tools/trait_drift_check.gd", "trait_drift_check", null],      # GARDEN.md 3, lever 3
	"--kael-sword-check": ["res://tools/kael_sword_shots.gd", "kael_sword_shots", "check"],      # item 131b
	"--kael-sword-shots": ["res://tools/kael_sword_shots.gd", "kael_sword_shots", "shots"],      # --shots-dir=<dir>
	"--glider-heat-check": ["res://tools/glider_heat_check.gd", "glider_heat_check", null],      # item 63
	"--equal-check": ["res://tools/equal_check.gd", "equal_check", "all"],
	"--equal-migrate-check": ["res://tools/equal_check.gd", "equal_check", "migrate"],
	"--backpack-check": ["res://tools/backpack_check.gd", "backpack_check", null],      # backpack tiers, at risk
	"--practice-hero-check": ["res://tools/practice_hero_check.gd", "practice_hero_check", null],
	"--support-check": ["res://tools/support_check.gd", "support_check", "all"],
	"--tender-combo-check": ["res://tools/support_check.gd", "support_check", "tender"],
	"--rimewright-combo-check": ["res://tools/support_check.gd", "support_check", "rimewright"],
	"--zone-check": ["res://tools/hero_pair_check.gd", "hero_pair_check", null],
	"--dolm-combo-check": ["res://tools/breah_combo_check.gd", "hero_pair_check", null],
	"--ostra-combo-check": ["res://tools/ostra_combo_check.gd", "hero_pair_check", null],
	"--dredge-combo-check": ["res://tools/dredge_combo_check.gd", "hero_check", null],
	"--ashwick-combo-check": ["res://tools/ashwick_combo_check.gd", "hero_check", null],
	"--archer-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--bulwark-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--music-leave-check": ["res://tools/music_leave_check.gd", "music_leave_check", null],
	"--perf-bench": ["res://tools/perf_bench.gd", "perf_bench", null],      # item 94
	"--perf-overlay-check": ["res://tools/perf_overlay_check.gd", "perf_overlay_check", null],
	"--perf-throttle-check": ["res://tools/perf_throttle_check.gd", "perf_throttle_check", null],
	"--match-audio-check": ["res://tools/match_audio_check.gd", "match_audio_check", null],      # item 103
	"--hunter-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],
	"--class-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],      # (the old name)
	"--shot-vertical-check": ["res://tools/shot_vertical_check.gd", "shot_vertical_check", null],
	"--kin-regen-check": ["res://tools/kin_regen_check.gd", "kin_regen_check", null],
	"--kin-loss-check": ["res://tools/kin_loss_check.gd", "kin_loss_check", null],
	"--kill-reset-check": ["res://tools/kill_reset_check.gd", "kill_reset_check", null],
	"--dash-dir-check": ["res://tools/dash_dir_check.gd", "dash_dir_check", null],
	"--dash-aim-check": ["res://tools/dash_aim_check.gd", "dash_aim_check", null],
	"--boki-moves-check": ["res://tools/boki_moves_check.gd", "boki_moves_check", null],      # move tiles
	"--boki-moves-shots": ["res://tools/boki_moves_shots.gd", "boki_moves_shots", null],      # --shots-dir=<dir>
	"--rank-ui-check": ["res://tools/rank_ui_check.gd", "rank_ui_check", null],      # choose what to rank: + and pips
	"--rank-ui-shots": ["res://tools/rank_ui_shots.gd", "rank_ui_shots", null],      # --shots-dir=<dir>
	"--sfx-set-check": ["res://tools/sfx_set_check.gd", "sfx_set_check", null],      # sound sets, loudness
	"--outpost-look-shots": ["res://tools/outpost_look_shots.gd", "outpost_look_shots", null],
	"--outpost-look-check": ["res://tools/outpost_look_check.gd", "outpost_look_check", null],
	"--dash-slot-check": ["res://tools/dash_slot_check.gd", "dash_slot_check", null],
	"--reticle-check": ["res://tools/reticle_check.gd", "reticle_check", null],
	"--ping-check": ["res://tools/ping_check.gd", "ping_check", null],
	"--dash-flow-check": ["res://tools/dash_flow_check.gd", "dash_flow_check", null],      # dash -> ability rows
	"--airdash-glide-check": ["res://tools/airdash_glide_check.gd", "airdash_glide_check", null],
	"--boki-dash-check": ["res://tools/boki_dash_check.gd", "boki_dash_check", null],      # item 185
	"--air-limits-check": ["res://tools/air_limits_check.gd", "air_limits_check", null],      # items 162, 162b
	"--layout-check": ["res://tools/layout_check.gd", "layout_check", null],      # item 151
	"--drop-launch-check": ["res://tools/drop_launch_check.gd", "drop_launch_check", null],      # item 163
	"--ride-shots": ["res://tools/ride_shots.gd", "ride_shots", null],      # item 163 camera (GPU)
	"--hero-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--hudref-check": ["res://tools/hudref_check.gd", "hudref_check", null],
	"--shake-check": ["res://tools/shake_check.gd", "shake_check", null],
	"--keys-check": ["res://tools/keys_check.gd", "keys_check", null],
	"--breakables-check": ["res://tools/breakables_check.gd", "breakables_check", null],
	"--cover-check": ["res://tools/cover_check.gd", "cover_check", null],
	"--aimkit-check": ["res://tools/aimkit_check.gd", "aimkit_check", null],
	"--pin-bjorn-shots": ["res://tools/pin_bjorn_shots.gd", "pin_bjorn_shots", null],
	"--warden-model-check": ["res://tools/warden_model_check.gd", "warden_model_check", null],      # the Warden models
	"--warden-rig-json": ["res://tools/warden_rig_json.gd", "warden_rig_json", null],      # rig for the Blender build
	"--warden-glb-check": ["res://tools/warden_glb_check.gd", "warden_glb_check", null],      # .glb loader
	"--warden-shots": ["res://tools/warden_shots.gd", "warden_shots", null],      # models beside sheets
	"--clip-check": ["res://tools/clip_check.gd", "clip_check", null],      # hand-keyed clips, weapon on the bone
	"--clip-live-check": ["res://tools/clip_live_check.gd", "clip_live_check", null],      # clips in a real match
	"--clip-live-sable-check": ["res://tools/clip_live_sable_check.gd", "clip_live_sable_check", null],
	"--pip-live-check": ["res://tools/pip_live_check.gd", "pip_live_check", null],      # Pip's clips in a real match
	"--vex-clip-live-check": ["res://tools/vex_clip_live_check.gd", "vex_clip_live_check", null],
	"--cinder-art-check": ["res://tools/cinder_art_check.gd", "cinder_art_check", null],
	"--ryzz-live-check": ["res://tools/ryzz_live_check.gd", "ryzz_live_check", null],
	"--clip-live-claire-check": ["res://tools/clip_live_claire_check.gd", "clip_live_claire_check", null],
	"--claire-skate-shots": ["res://tools/claire_skate_shots.gd", "claire_skate_shots", null],
	"--clip-live-grimble": ["res://tools/clip_live_grimble.gd", "clip_live_grimble", null],      # Grimble, the same
	"--motley-live-check": ["res://tools/motley_live_check.gd", "motley_live_check", null],      # the jack, live
	"--motley-card-shots": ["res://tools/motley_card_shots.gd", "motley_card_shots", null],      # the card vs him
	"--clip-shots": ["res://tools/clip_shots.gd", "clip_shots", null],      # a Hero's hand-keyed clips, frame by frame
	"--idle-shots": ["res://tools/idle_shots.gd", "idle_shots", null],      # every Hunter standing still (IDLE_AUDIT)
	"--lineup-shot": ["res://tools/lineup_shot.gd", "lineup_shot", null],      # all 12 Hunters in a row, true scale
	"--crouch-check": ["res://tools/crouch_check.gd", "crouch_check", null],
	"--crouch-shots": ["res://tools/crouch_shots.gd", "crouch_shots", null],
	"--boki-rig-shots": ["res://tools/boki_rig_shots.gd", "boki_rig_shots", null],      # rigged Boki review sheets
	"--boki-rig-check": ["res://tools/boki_rig_check.gd", "boki_rig_check", null],      # rigged Boki
	"--dancer-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "thief"],
	"--juggernaut-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "juggernaut"],
	"--vv-shots": ["res://tools/vv_shots.gd", "vv_shots", null],          # Sparkle / Vex screenshots
	"--breah-shots": ["res://tools/breah_shots.gd", "breah_shots", null],          # Tarek review screenshots
	"--loot-full-check": ["res://tools/loot_full_check.gd", "loot_full_check", null],      # full-inventory looting
	"--loot-full-shots": ["res://tools/loot_full_shots.gd", "loot_full_shots", null],      # --shots-dir=<dir>
	"--dash-slot-shots": ["res://tools/dash_slot_shots.gd", "dash_slot_shots", null],
	"--reticle-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "reticle"],
	"--ping-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "ping"],
	"--combo51-shots": ["res://tools/combo51_shots.gd", "combo51_shots", null],      # item 51 combo strips
	"--dash-frames-check": ["res://tools/dash_frames.gd", "dash_frames", null],      # item 181
	"--hero-vfx-check": ["res://tools/hero_vfx_check.gd", "hero_vfx_check", null],
	"--gameplay-media": ["res://tools/gameplay_media.gd", "gameplay_media", null],      # website clips and stills
	"--hero-vfx-reel": ["res://tools/hero_vfx_reel.gd", "hero_vfx_reel", null],
	"--hero-vfx-gallery": ["res://tools/hero_vfx_gallery.gd", "hero_vfx_gallery", null],      # every look, side by side
	"--ostra-orb-shots": ["res://tools/ostra_orb_shots.gd", "ostra_orb_shots", null],      # item 60 screenshots
	"--title-check": ["res://tools/title_check.gd", "title_check", null],      # the title: menu, key art, frame budget
	"--hatch-check": ["res://tools/hatch_check.gd", "hatch_check", null],      # the hatch: a quiet, personal moment
	"--ultbond-check": ["res://tools/ultbond_check.gd", "ultbond_check", null],      # keys, bond hook, release
	"--wallmove-check": ["res://tools/wallmove_check.gd", "wallmove_check", null],
	"--tutorial-hud-shots": ["res://tools/tutorial_hud_shots.gd", "tutorial_hud_shots", null],      # --shots-dir=<dir>
	"--tutorial-hud-check": ["res://tools/tutorial_hud_check.gd", "tutorial_hud_check", null],      # one voice
	"--arrival-check": ["res://tools/arrival_check.gd", "arrival_check", null],      # results, arrival modals, top bar, key row
	"--journal-check": ["res://tools/journal_check.gd", "journal_check", null],      # journal, away card
	"--arrival-shots": ["res://tools/arrival_shots.gd", "arrival_shots", null],      # --shots-dir=<dir>
	"--uipolish-check": ["res://tools/uipolish_check.gd", "uipolish_check", null],     # settings, menu look
	"--msg-queue-check": ["res://tools/msg_queue_check.gd", "msg_queue_check", null],     # one message lane
	"--unmasked-check": ["res://tools/unmasked_check.gd", "unmasked_check", null],      # the Unmasked
	"--empty-shots": ["res://tools/empty_shots.gd", "empty_shots", null],      # the Empty creator + Relic moment shots
	"--portrait-check": ["res://tools/portrait_check.gd", "portrait_check", null],     # the Wardens' painted faces
	"--perkorb-check": ["res://tools/perkorb_check.gd", "perkorb_check", null],      # perk orbs, boss fan, weapon path
	"--prematch-check": ["res://tools/prematch_check.gd", "prematch_check", null],      # the pre-match lobby
	"--hero-title-check": ["res://tools/hero_title_check.gd", "hero_title_check", null],
	"--mantle-clip": ["res://tools/mantle_clip.gd", "mantle_clip", null],
	"--cliff-mantle-check": ["res://tools/cliff_mantle_check.gd", "cliff_mantle_check", null],
	"--wall-size-check": ["res://tools/wall_size_check.gd", "wall_size_check", null],  # no lone posts
	"--hitbox-size-check": ["res://tools/hitbox_size_check.gd", "hitbox_size_check", null],
	"--hitbox-size-shots": ["res://tools/hitbox_size_shots.gd", "hitbox_size_shots", null],
	"--toy-check": ["res://tools/toy_check.gd", "toy_check", null],      # the base's ball, post and tub (GARDEN.md section 4)
	"--farmbuild": ["res://tools/farmbuild_check.gd", "farmbuild_check", null],      # also --farmbuild-shots=<dir>
	"--boki-lines-check": ["res://tools/boki_lines_check.gd", "boki_lines_check", null],      # Boki talk (item 105)
	"--boki-talk-shots": ["res://tools/boki_talk_shots.gd", "boki_talk_shots", null],      # --shots-dir=<dir>
	"--build-ui-check": ["res://tools/build_ui_check.gd", "build_ui_check", null],      # also --build-ui-shots=<dir>
	"--build-hold-shots": ["res://tools/build_hold_shots.gd", "build_hold_shots", null],
	"--build-hold-check": ["res://tools/build_hold_check.gd", "build_hold_check", null],
	"--farm-tutorial-check": ["res://tools/farm_tutorial_check.gd", "farm_tutorial_check", null],
	"--race-check": ["res://tools/race_check.gd", "race_check", null],      # the Dash, GARDEN.md 9.4
	"--shove-check": ["res://tools/shove_check.gd", "shove_check", null],      # the Stump Shove, GARDEN.md 5.2
	"--farm-hob-shots": ["res://tools/farm_tutorial_check.gd", "farm_tutorial_check", null],
	"--prologue-check": ["res://tools/prologue_check.gd", "prologue_check", null],      # also --shots-dir=<dir>
	"--economy-floor-check": ["res://tools/economy_floor_check.gd", "economy_floor_check", null],      # never stuck
	"--market-check": ["res://tools/market_check.gd", "market_check", null],      # docs/decisions/0013-market.md
	"--drop-feel-check": ["res://tools/drop_check.gd", "drop_feel_check", null],      # the opening drop
	"--market-shots": ["res://tools/market_shots.gd", "market_shots", null],      # --market-shots=<dir>
	"--displace-net-check": ["res://tools/displace_net_check.gd", "displace_net_check", null],     # 2 games, relay
	"--breaker-proof-shots": ["res://tools/breaker_proof_shots.gd", "breaker_proof_shots", null],
	"--warden-clips-check": ["res://tools/warden_clips_check.gd", "warden_clips_check", null],
	"--rig-standard-check": ["res://tools/rig_standard_check.gd", "rig_standard_check", null],
	"--rig-shots": ["res://tools/rig_shots.gd", "rig_shots", null],
	"--shroud-shots": ["res://tools/shroud_shots.gd", "shroud_shots", null],
	"--shroud-check": ["res://tools/shroud_check.gd", "shroud_check", null],
	"--weapon-audit": ["res://tools/weapon_audit.gd", "weapon_audit", null],
	"--warden-stance-check": ["res://tools/warden_stance_check.gd", "warden_stance_check", null],
	"--warden-stance-shots": ["res://tools/warden_stance_shots.gd", "warden_stance_shots", null],
	"--mantle-look-check": ["res://tools/mantle_look_check.gd", "mantle_look_check", null],      # Mantle look, creator
	"--wisp-check": ["res://tools/wisp_check.gd", "wisp_check", null],      # docs/decisions/0019
	"--wisp-shots": ["res://tools/wisp_shots.gd", "wisp_shots", null],      # --shots-dir=<dir>
	"--box-revive-check": ["res://tools/box_revive_check.gd", "box_revive_check", null],      # docs/decisions/0018
	"--depth-shots": ["res://tools/depth_shots.gd", "depth_shots", null],      # --shots-dir=<dir> [--seed=N]
	"--box-revive-shots": ["res://tools/box_revive_shots.gd", "box_revive_shots", null],      # --shots-dir=<dir>
	"--shield-check": ["res://tools/shield_check.gd", "shield_check", null],      # shields never hide a Hunter
	"--clarity-shots": ["res://tools/clarity_shots.gd", "clarity_shots", null],      # 2v2, one down, --shots-dir=
	"--rate-card-check": ["res://tools/rate_card_check.gd", "rate_card_check", null],      # item 189
	"--clarity-check": ["res://tools/clarity_check.gd", "clarity_check", null],      # colour rule, downed, Boki
	"--roster-check": ["res://tools/roster_check.gd", "roster_check", null],      # docs/boki/ROSTER_50.md stubs
	"--roster-shots": ["res://tools/roster_shots.gd", "roster_shots", null],      # the 50 lined up
	"--mask-moment-check": ["res://tools/mask_moment_check.gd", "mask_moment_check", null],      # also --shots-dir=
	"--hob-check": ["res://tools/hob_check.gd", "hob_check", null],      # Hob in person, the second Mask; --shots-dir=
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
