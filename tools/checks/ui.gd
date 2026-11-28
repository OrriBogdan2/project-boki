extends RefCounted
## New checks for the "ui" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--keycap-rebind-check": ["res://tools/keycap_rebind_check.gd", "keycap_rebind_check", null],
	"--solo-hud-shots": ["res://tools/solo_hud_shots.gd", "solo_hud_shots", null],  # GPU, --shots-dir=
	"--title-shots": ["res://tools/title_shots.gd", "title_shots", null],  # GPU: title before/after
	"--passive-gauge-shots": ["res://tools/passive_gauge_shots.gd", "passive_gauge_shots", null],
	"--map-clarity-shots": ["res://tools/map_clarity_shots.gd", "map_clarity_shots", null],  # GPU, --shots-dir=<dir>
	"--test-zone-shots": ["res://tools/test_zone_shots.gd", "test_zone_shots", null],  # --shots-dir=<dir>, GPU
	"--shops-check": ["res://tools/shops_check.gd", "shops_check", null],  # in-match shops, the map legend
	"--reticle-hunters-shots": ["res://tools/reticle_shots.gd", "reticle_shots", "hunters"],
	"--combat-calm-check": ["res://tools/combat_calm_check.gd", "combat_calm_check", null],  # fight HUD
	"--combat-hud-shots": ["res://tools/combat_hud_shots.gd", "combat_hud_shots", null],  # GPU
	"--levelup-reel": ["res://tools/levelup_reel.gd", "levelup_reel", null],  # movie writer: a level-up mid-fight
	"--title-loading-shots": ["res://tools/title_loading_shots.gd", "title_loading_shots", null],  # GPU, --shots-dir=
	"--scoreboard-check": ["res://tools/scoreboard_check.gd", "scoreboard_check", null],  # the Tab squad board
	"--scoreboard-shots": ["res://tools/scoreboard_shots.gd", "scoreboard_shots", null],  # --shots-dir=<dir>
	"--rename-check": ["res://tools/rename_check.gd", "rename_check", null],  # rename a Boki from its card
	"--ghost-visible-check": ["res://tools/ghost_visible_check.gd", "ghost_visible_check", "check"],
	"--ghost-visible-shots": ["res://tools/ghost_visible_check.gd", "ghost_visible_check", "shots"],
	"--hatch-flow-shots": ["res://tools/hatch_flow_shots.gd", "hatch_flow_shots", null],  # --hatch-flow-shots=<dir>
	"--hazard-counter-shots": ["res://tools/hazard_counter_shots.gd", "hazard_counter_shots", null],  # GPU
	"--plate-status-check": ["res://tools/plate_status_check.gd", "plate_status_check", null],  # one status row
	"--stomp-prompt-shots": ["res://tools/stomp_prompt_shots.gd", "stomp_prompt_shots", null],  # --shots-dir=<dir>
	"--ui-text-probe-check": ["res://tools/ui_text_probe.gd", "ui_text_probe", null],  # no text per-letter/off screen
}
