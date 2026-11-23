extends RefCounted
## New checks for the "farm" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--care-prompt-check": ["res://tools/care_prompt_check.gd", "care_prompt_check", null],  # the care line over a Boki
	"--bond-pace-check": ["res://tools/bond_pace_check.gd", "bond_pace_check", null],
	"--farm-place-check": ["res://tools/farm_place_check.gd", "farm_place_check", null],  # placing spotlight, hunger panel
}
