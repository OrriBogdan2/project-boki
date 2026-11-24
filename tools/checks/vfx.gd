extends RefCounted
## New checks for the "vfx" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--range-screen-check": ["res://tools/range_screen_check.gd", "range_screen_check", null],  # ability ends on screen
	"--muzzle-check": ["res://tools/muzzle_check.gd", "muzzle_check", null],  # shots leave the weapon or hand
	"--boki-type-hit-check": ["res://tools/boki_type_hit_check.gd", "boki_type_hit_check", "check"],  # Juice.flash_col
	"--boki-type-hit-shots": ["res://tools/boki_type_hit_check.gd", "boki_type_hit_check", "shots"],  # --shots-dir
	"--fog-ab-shots": ["res://tools/fog_ab_shots.gd", "fog_ab_shots", null],  # GPU: sight fog on/off, same frame
	"--fx-hunter-cap-check": ["res://tools/fx_hunter_cap_check.gd", "fx_hunter_cap_check", null],  # glow sphere cap
}
