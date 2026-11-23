extends RefCounted
## New checks for the "combat" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--camps-check": ["res://tools/camps_check.gd", "camps_check", null],  # fixed camps and their XP
	"--fall-parity-check": ["res://tools/fall_parity_check.gd", "fall_parity_check", null],  # a fall stays a fall
	"--utility-parity-check": ["res://tools/utility_parity_check.gd", "utility_parity_check", null],  # belt vs source
	"--vex-cast-closeup": ["res://tools/vex_cast_closeup.gd", "vex_cast_closeup", null],  # Vex RMB / E close-up film
}
