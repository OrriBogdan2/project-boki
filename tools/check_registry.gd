class_name CheckRegistry
extends RefCounted
## The check registry (AGENTS.md section 2): flag -> the tool that runs it, so new checks never add
## inline hooks to main.gd. Each entry: [script path, meta name the check is kept under on Main
## (some checks read their own state back through it), optional argument passed to run()].
## Older checks still hooked inline in main.gd move here in the cleanup pass (docs/DEBT.md).

const CHECKS := {
	"--practice-hero-check": ["res://tools/practice_hero_check.gd", "practice_hero_check", null],
	"--support-check": ["res://tools/support_check.gd", "support_check", "all"],
	"--tender-combo-check": ["res://tools/support_check.gd", "support_check", "tender"],
	"--rimewright-combo-check": ["res://tools/support_check.gd", "support_check", "rimewright"],
	"--zone-check": ["res://tools/hero_pair_check.gd", "hero_pair_check", null],
	"--dolm-combo-check": ["res://tools/hero_pair_check.gd", "hero_pair_check", null],
	"--ostra-combo-check": ["res://tools/hero_pair_check.gd", "hero_pair_check", null],
	"--dredge-combo-check": ["res://tools/dredge_combo_check.gd", "hero_check", null],
	"--ashwick-combo-check": ["res://tools/ashwick_combo_check.gd", "hero_check", null],
	"--archer-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--bulwark-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--music-leave-check": ["res://tools/music_leave_check.gd", "music_leave_check", null],
	"--hunter-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],
	"--class-unlock-check": ["res://tools/class_unlock_check.gd", "class_unlock_check", null],      # (the old name)
	"--shot-vertical-check": ["res://tools/shot_vertical_check.gd", "shot_vertical_check", null],
	"--kin-regen-check": ["res://tools/kin_regen_check.gd", "kin_regen_check", null],
	"--kill-reset-check": ["res://tools/kill_reset_check.gd", "kill_reset_check", null],
	"--hero-combo-check": ["res://tools/archer_bulwark_combo_check.gd", "hero_check", null],
	"--aimkit-check": ["res://tools/aimkit_check.gd", "aimkit_check", null],
	"--perkorb-check": ["res://tools/perkorb_check.gd", "perkorb_check", null],      # perk orbs, the boss fan, the fixed weapon path
}

## Runs the registered check named in args, if any. Returns true when one started (Main stops there).
static func run(main: Node, args: PackedStringArray) -> bool:
	for flag in CHECKS:
		if flag in args:
			var e: Array = CHECKS[flag]
			var c = load(String(e[0])).new()
			main.set_meta(String(e[1]), c)
			if e[2] == null:
				c.run(main)
			else:
				c.run(main, e[2])
			return true
	return false
