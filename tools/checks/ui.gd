extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--results-boki-line-check": ["res://tools/results_boki_line_check.gd", "results_boki_line_check", "check"],
	"--results-boki-line-shots": ["res://tools/results_boki_line_check.gd", "results_boki_line_check", "shots"],
	"--stomp-prompt-shots": ["res://tools/stomp_prompt_shots.gd", "stomp_prompt_shots", null],  # --shots-dir=<dir>
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
}
