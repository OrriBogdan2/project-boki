extends RefCounted
## New checks for the "vfx" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--utility-vfx-check": ["res://tools/utility_vfx_check.gd", "utility_vfx_check", null],  # belt looks
	"--utility-vfx-shots": ["res://tools/utility_vfx_shots.gd", "utility_vfx_shots", null],  # --shots-dir=<dir>
	"--range-screen-check": ["res://tools/range_screen_check.gd", "range_screen_check", null],  # ability ends on screen
	"--muzzle-check": ["res://tools/muzzle_check.gd", "muzzle_check", null],  # shots leave the weapon or hand
	"--fog-ab-shots": ["res://tools/fog_ab_shots.gd", "fog_ab_shots", null],  # GPU: sight fog on/off, same frame
	"--fx-hunter-cap-check": ["res://tools/fx_hunter_cap_check.gd", "fx_hunter_cap_check", null],  # glow sphere cap
	"--boki-type-colour-check": ["res://tools/boki_type_colour_check.gd", "boki_type_colour_check", null],
	"--boki-type-hit-check": ["res://tools/boki_type_hit_check.gd", "boki_type_hit_check", "check"],  # Juice.flash_col
	"--boki-type-hit-shots": ["res://tools/boki_type_hit_check.gd", "boki_type_hit_check", "shots"],  # --shots-dir
	"--summon-pop-shots": ["res://tools/summon_pop_shots.gd", "summon_pop_shots", null],  # --shots-dir=<dir>
	"--tenzo-stone-shots": ["res://tools/tenzo_stone_shots.gd", "tenzo_stone_shots", null],  # GPU: Tenzo stone stills
	"--wisp-glow-check": ["res://tools/wisp_glow_check.gd", "wisp_glow_check", null],  # GPU: both wisps glow
}
