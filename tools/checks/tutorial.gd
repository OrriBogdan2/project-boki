extends RefCounted
## New checks for the "tutorial" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--hint-once-check": ["res://tools/hint_once_check.gd", "hint_once_check", null],
	"--tutorial-frame-archer-check": ["res://tools/tutorial_frame_check.gd", "tutorial_frame_check", "archer"],
	"--tutorial-frame-juggernaut-check": ["res://tools/tutorial_frame_check.gd", "tutorial_frame_check", "juggernaut"],
	"--tutorial-frame-gunslinger-check": ["res://tools/tutorial_frame_check.gd", "tutorial_frame_check", "gunslinger"],
	"--tut-first-evolve-check": ["res://tools/tut_first_evolve_check.gd", "tut_first_evolve_check", null],
	"--goals-next-check": ["res://tools/goals_next_check.gd", "goals_next_check", null],
}
