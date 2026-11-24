extends RefCounted
## New checks for the "boki" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--boki-everywhere-check": ["res://tools/boki_everywhere_check.gd", "boki_everywhere_check", null],  # Boki in .pck
	"--stolen-extract-check": ["res://tools/stolen_extract_check.gd", "stolen_extract_check", null],  # extract, saves
}
