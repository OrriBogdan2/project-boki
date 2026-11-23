extends RefCounted
## New checks for the "combat" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--camps-check": ["res://tools/camps_check.gd", "camps_check", null],  # fixed camps and their XP
	"--mob-fsm-check": ["res://tools/mob_fsm_check.gd", "mob_fsm_check", null],  # monster + boss machines (M9)
}
