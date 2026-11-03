class_name CheckRegistry
extends RefCounted
## The check registry (AGENTS.md section 2): flag -> the tool that runs it, so new checks never add
## inline hooks to main.gd. Each entry: [script path, meta name the check is kept under on Main
## (some checks read their own state back through it), optional argument passed to run()].
## Older checks still hooked inline in main.gd move here in the cleanup pass (docs/DEBT.md).

const CHECKS := {
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
	"--hunter-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],
	"--class-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],      # (the old name)
	"--shot-vertical-check": ["res://tools/shot_vertical_check.gd", "shot_vertical_check", null],
	"--kin-regen-check": ["res://tools/kin_regen_check.gd", "kin_regen_check", null],
	"--kin-loss-check": ["res://tools/kin_loss_check.gd", "kin_loss_check", null],
	"--kill-reset-check": ["res://tools/kill_reset_check.gd", "kill_reset_check", null],
	"--dash-dir-check": ["res://tools/dash_dir_check.gd", "dash_dir_check", null],
	"--dash-flow-check": ["res://tools/dash_flow_check.gd", "dash_flow_check", null],      # dash -> ability rows
	"--airdash-glide-check": ["res://tools/airdash_glide_check.gd", "airdash_glide_check", null],
	"--hero-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--hudref-check": ["res://tools/hudref_check.gd", "hudref_check", null],
	"--shake-check": ["res://tools/shake_check.gd", "shake_check", null],
	"--keys-check": ["res://tools/keys_check.gd", "keys_check", null],
	"--breakables-check": ["res://tools/breakables_check.gd", "breakables_check", null],
	"--cover-check": ["res://tools/cover_check.gd", "cover_check", null],
	"--aimkit-check": ["res://tools/aimkit_check.gd", "aimkit_check", null],
	"--pin-bjorn-shots": ["res://tools/pin_bjorn_shots.gd", "pin_bjorn_shots", null],
	"--dancer-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "thief"],
	"--juggernaut-combo-check": ["res://tools/dancer_jug_check.gd", "dancer_jug_check", "juggernaut"],
	"--vv-shots": ["res://tools/vv_shots.gd", "vv_shots", null],          # Vireo / Venator screenshots
	"--breah-shots": ["res://tools/breah_shots.gd", "breah_shots", null],          # Breah review screenshots
	"--title-check": ["res://tools/title_check.gd", "title_check", null],      # the title: menu, key art, frame budget
	"--hatch-check": ["res://tools/hatch_check.gd", "hatch_check", null],      # the hatch: a quiet, personal moment
	"--ultbond-check": ["res://tools/ultbond_check.gd", "ultbond_check", null],      # keys, bond hook, release
	"--wallmove-check": ["res://tools/wallmove_check.gd", "wallmove_check", null],
	"--uipolish-check": ["res://tools/uipolish_check.gd", "uipolish_check", null],     # settings, menu look
	"--perkorb-check": ["res://tools/perkorb_check.gd", "perkorb_check", null],      # perk orbs, the boss fan, the fixed weapon path
	"--wall-size-check": ["res://tools/wall_size_check.gd", "wall_size_check", null],  # no lone posts
	"--farmbuild": ["res://tools/farmbuild_check.gd", "farmbuild_check", null],      # also --farmbuild-shots=<dir>
	"--prologue-check": ["res://tools/prologue_check.gd", "prologue_check", null],      # also --shots-dir=<dir>
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
