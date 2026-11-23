extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--range-screen-check": ["res://tools/range_screen_check.gd", "range_screen_check", null],  # ability ends on screen
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
	"--plate-status-check": ["res://tools/plate_status_check.gd", "plate_status_check", null],  # one status row
}
