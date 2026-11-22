extends RefCounted
## New checks for the "tutorial" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	# every first-time hint shows once per save: three matches with a save and load between
	"--hint-once-check": ["res://tools/hint_once_check.gd", "hint_once_check", null],
}
