extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--combat-calm-check": ["res://tools/combat_calm_check.gd", "combat_calm_check", null],  # fight HUD queue
	"--passive-gauge-shots": ["res://tools/passive_gauge_shots.gd", "passive_gauge_shots", null],
	"--shops-check": ["res://tools/shops_check.gd", "shops_check", null],  # in-match shops, the map legend
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--ghost-visible-check": ["res://tools/ghost_visible_check.gd", "ghost_visible_check", "check"],
	"--ghost-visible-shots": ["res://tools/ghost_visible_check.gd", "ghost_visible_check", "shots"],
	"--hatch-flow-shots": ["res://tools/hatch_flow_shots.gd", "hatch_flow_shots", null],  # --hatch-flow-shots=<dir>
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
	"--plate-status-check": ["res://tools/plate_status_check.gd", "plate_status_check", null],  # one status row
	"--stomp-prompt-shots": ["res://tools/stomp_prompt_shots.gd", "stomp_prompt_shots", null],  # --shots-dir=<dir>
	"--ui-text-probe-check": ["res://tools/ui_text_probe.gd", "ui_text_probe", null],  # no text per-letter/off screen
}
