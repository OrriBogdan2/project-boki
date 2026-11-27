extends RefCounted
## New checks for the "boki" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--toon-lineup-farm-shots": ["res://tools/toon_lineup_farm_shots.gd", "toon_lineup_farm_shots", null],
	"--toon-lineup-shots": ["res://tools/toon_lineup_shots.gd", "toon_lineup_shots", null],  # lineup, match cam
	"--toon-consistency-check": ["res://tools/toon_consistency_check.gd", "toon_consistency_check", null],  # toon look
	"--boki-everywhere-check": ["res://tools/boki_everywhere_check.gd", "boki_everywhere_check", null],  # Boki in .pck
	"--wisp-proc-check": ["res://tools/wisp_proc_check.gd", "wisp_proc_check", null],  # carried passive chirp + tip
	"--bot-summon-check": ["res://tools/bot_summon_check.gd", "bot_summon_check", null],  # bots press Summon
	"--wisp-default-check": ["res://tools/wisp_default_check.gd", "wisp_default_check", null],  # wisps + C for all
	"--wisp-summon-shots": ["res://tools/wisp_summon_shots.gd", "wisp_summon_shots", null],  # --shots-dir=<dir>
	"--summon-end-sfx-check": ["res://tools/summon_end_sfx_check.gd", "summon_end_sfx_check", null],  # end warning
}
