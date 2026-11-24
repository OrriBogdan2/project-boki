extends RefCounted
## New checks for the "vfx" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--utility-vfx-check": ["res://tools/utility_vfx_check.gd", "utility_vfx_check", null],  # belt looks
	"--utility-vfx-shots": ["res://tools/utility_vfx_shots.gd", "utility_vfx_shots", null],      # --shots-dir=<dir>
	"--muzzle-check": ["res://tools/muzzle_check.gd", "muzzle_check", null],  # shots leave the weapon or hand
	"--fog-ab-shots": ["res://tools/fog_ab_shots.gd", "fog_ab_shots", null],  # GPU: sight fog on/off, same frame
	"--fx-hunter-cap-check": ["res://tools/fx_hunter_cap_check.gd", "fx_hunter_cap_check", null],  # glow sphere cap
}
