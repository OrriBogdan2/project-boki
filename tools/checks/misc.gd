extends RefCounted
## New checks for the "misc" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--jump-apex-shots": ["res://tools/jump_apex_shots.gd", "jump_apex_shots", null],  # old vs new jump top, side-on
	"--clip-preflight-check": ["res://tools/clip_preflight_check.gd", "clip_preflight_check", null],  # film preflight
	"--registry-check": ["res://tools/registry_check.gd", "registry_check", null],  # the registry holds together
	"--intro-deck-check": ["res://tools/intro_deck_check.gd", "intro_deck_check", null],
	"--tester-feedback-check": ["res://tools/tester_feedback_check.gd", "tester_feedback_check", null],  # tester 11-19
	"--cliff-mantle-meadow-check": ["res://tools/cliff_mantle_check.gd", "cliff_mantle_check", 0],
	"--cliff-mantle-dusk-check": ["res://tools/cliff_mantle_check.gd", "cliff_mantle_check", 1],
	"--drop-merge-audit": ["res://tools/drop_merge_check.gd", "drop_merge_check", "audit"],  # ground audit, not gated
	"--fight-p99-check": ["res://tools/fight_p99_check.gd", "fight_p99_check", null],  # p99 vs tools/perf.tsv
	# parse every kin grammar file (=<root> for another folder)
	"--grammar-check": ["res://tools/grammar_check.gd", "grammar_check", null],
	"--hero-reel": ["res://tools/hero_reel.gd", "hero_reel", null],  # private pitch footage (GPU)
	"--loadin-fps-check": ["res://tools/loadin_fps_check.gd", "loadin_fps_check", "advisory"],
	"--step-up-check": ["res://tools/step_up_check.gd", "step_up_check", null],  # lips walked over
	"--fall-parity-check": ["res://tools/fall_parity_check.gd", "fall_parity_check", null],  # fall parity
}
