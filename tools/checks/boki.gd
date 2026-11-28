extends RefCounted
## New checks for the "boki" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--boki-keys-check": ["res://tools/boki_keys_check.gd", "boki_keys_check", null],  # quick Boki command keys
	"--boki-everywhere-check": ["res://tools/boki_everywhere_check.gd", "boki_everywhere_check", null],  # Boki in .pck
	# the evolve moment
	"--evolve-moment-check": ["res://tools/evolve_moment_check.gd", "evolve_moment_check", "check"],
	"--evolve-moment-shots": ["res://tools/evolve_moment_check.gd", "evolve_moment_check", "shots"],
	"--boki-size-shots": ["res://tools/boki_size_shots.gd", "boki_size_shots", null],  # Boki beside Vex, true size
	"--wisp-proc-check": ["res://tools/wisp_proc_check.gd", "wisp_proc_check", null],  # carried passive chirp + tip
	"--bot-summon-check": ["res://tools/bot_summon_check.gd", "bot_summon_check", null],  # bots press Summon
	"--wisp-default-check": ["res://tools/wisp_default_check.gd", "wisp_default_check", null],  # wisps + C for all
	"--wisp-summon-shots": ["res://tools/wisp_summon_shots.gd", "wisp_summon_shots", null],  # --shots-dir=<dir>
	"--summon-end-sfx-check": ["res://tools/summon_end_sfx_check.gd", "summon_end_sfx_check", null],  # end warning
}
