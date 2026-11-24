extends RefCounted
## New checks for the "combat" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	# one walk speed, run/walk/crouch gaits per Hunter (3 shards keep each under the gate's 300 s cap)
	"--move-speed-1-check":
	["res://tools/move_speed_check.gd", "move_speed_check", "archer,ashwick,bulwark,dolm,dredge"],
	"--move-speed-2-check": ["res://tools/move_speed_check.gd", "move_speed_check", "gil,gunslinger,juggernaut,mage"],
	"--move-speed-3-check": ["res://tools/move_speed_check.gd", "move_speed_check", "ostra,rimewright,tender,thief"],
	"--mob-fsm-check": ["res://tools/mob_fsm_check.gd", "mob_fsm_check", null],  # monster + boss machines (M9)
	# Vex's Slipstep: one plain dash, no pips, no Second Wind
	"--vex-dash-check": ["res://tools/vex_dash_check.gd", "vex_dash_check", null],
	"--camps-check": ["res://tools/camps_check.gd", "camps_check", null],  # fixed camps and their XP
	# the Arena, training's practice tools, the kit card
	"--arena-check": ["res://tools/arena_check.gd", "arena_check", null],
	# every archetype kit, controls, locks, infusion, feel
	"--archetype-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	"--kit-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],  # (same tool: the combo section)
	# Sparkle's cross-ability interactions
	"--mage-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	# Vex's cross-ability interactions
	"--gunslinger-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	"--boss-check": ["res://tools/boss_check.gd", "boss_check", null],  # boss lairs: dial, wards, phases, the Rare Egg
}
