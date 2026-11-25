extends RefCounted
## New checks for the "misc" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--stolen-extract-check": ["res://tools/stolen_extract_check.gd", "stolen_extract_check", null],  # extract, saves
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
	"--step-up-check": ["res://tools/step_up_check.gd", "step_up_check", null],  # lips walked over
}
