extends RefCounted
## New checks for the "sfx" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--hunter-foley-check": ["res://tools/hunter_foley_check.gd", "hunter_foley_check", null],  # gear sounds
	"--incoming-hit-check": ["res://tools/incoming_hit_check.gd", "incoming_hit_check", null],  # [--shots-dir=] AVI
	"--sfx-priority-check": ["res://tools/sfx_priority_check.gd", "sfx_priority_check", null],  # enemy wind-ups
}
