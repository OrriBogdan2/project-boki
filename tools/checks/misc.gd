extends RefCounted
## New checks for the "misc" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--registry-check": ["res://tools/registry_check.gd", "registry_check", null],  # the registry holds together
	"--fight-p99-check": ["res://tools/fight_p99_check.gd", "fight_p99_check", null],  # p99 vs tools/perf.tsv
	"--warm-twice": ["res://tools/warm_twice.gd", "warm_twice", null],  # a second launch, for benches
}
