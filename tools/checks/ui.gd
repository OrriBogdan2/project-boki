extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--combat-calm-check": ["res://tools/combat_calm_check.gd", "combat_calm_check", null],  # fight HUD
	"--combat-hud-shots": ["res://tools/combat_hud_shots.gd", "combat_hud_shots", null],  # GPU
	"--range-screen-check": ["res://tools/range_screen_check.gd", "range_screen_check", null],  # ability ends on screen
	"--scoreboard-check": ["res://tools/scoreboard_check.gd", "scoreboard_check", null],  # the Tab squad board
	"--scoreboard-shots": ["res://tools/scoreboard_shots.gd", "scoreboard_shots", null],  # --shots-dir=<dir>
	"--title-loading-shots": ["res://tools/title_loading_shots.gd", "title_loading_shots", null],  # GPU, --shots-dir=
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
}
