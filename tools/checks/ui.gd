extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--shops-check": ["res://tools/shops_check.gd", "shops_check", null],      # in-match shops, the map legend
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--hatch-flow-shots": ["res://tools/hatch_flow_shots.gd", "hatch_flow_shots", null],  # --hatch-flow-shots=<dir>
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
	"--ui-text-probe-check": ["res://tools/ui_text_probe.gd", "ui_text_probe", null],  # no text per-letter/off screen
}
