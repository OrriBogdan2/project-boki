extends RefCounted
## New checks for the "combat" area (AGENTS.md section 2). Same entry format as tools/check_registry.gd:
## flag -> [script path, meta name the check is kept under on Main, optional argument passed to run()].
## One entry per line, and a flag may appear in only ONE file (CheckRegistry.all() fails loudly on a duplicate).
## Never add entries to tools/check_registry.gd: that legacy file only shrinks.

const CHECKS := {
	"--air-rmb-feel-check": ["res://tools/air_rmb_feel_check.gd", "air_rmb_feel_check", null],  # Kael jump -> RMB
	# the glider opens after any attack or ability, LMB or not (input buffer, every hunter)
	"--glide-after-attack-check": ["res://tools/glide_after_attack_check.gd", "glide_after_attack_check", null],
	# a blast: falloff curve by distance, no damage through rock, the armour ring pitched by the shell left
	"--blast-parity-check": ["res://tools/blast_parity_check.gd", "blast_parity_check", null],
	"--move-speed-check": ["res://tools/move_speed_check.gd", "move_speed_check", null],  # run, walk, crouch per Hunter
	"--kit-refund-check": ["res://tools/kit_refund_check.gd", "kit_refund_check", null],  # refund/reset loops (11-27)
	"--mob-fsm-check": ["res://tools/mob_fsm_check.gd", "mob_fsm_check", null],  # monster + boss machines (M9)
	"--utility-parity-check": ["res://tools/utility_parity_check.gd", "utility_parity_check", null],  # belt vs source
	"--vex-daze-check": ["res://tools/vex_daze_check.gd", "vex_daze_check", null],  # Daze team, coin wall stun
	# a Boki plate, glove wall or ice wall never hides the Hunter behind it; a rock does
	"--barrier-sight-check": ["res://tools/barrier_sight_check.gd", "barrier_sight_check", null],
	# Vex's Slipstep: one plain dash, no pips, no Second Wind
	"--vex-dash-check": ["res://tools/vex_dash_check.gd", "vex_dash_check", null],
	"--camps-check": ["res://tools/camps_check.gd", "camps_check", null],  # fixed camps and their XP
	# 0022 ult ranks
	"--ult-rank-check": ["res://tools/ult_rank_check.gd", "ult_rank_check", null],
	# the Arena, training's practice tools, the kit card
	"--arena-check": ["res://tools/arena_check.gd", "arena_check", null],
	# every archetype kit, controls, locks, infusion, feel
	"--archetype-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	"--kit-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],  # (same tool: the combo section)
	# Sparkle's cross-ability interactions
	"--mage-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	# Vex's cross-ability interactions
	"--gunslinger-combo-check": ["res://tools/archetype_check.gd", "archetype_check", null],
	# Meshy-native Hunters: visible body vs hit_h / hit ring
	"--native-hitbox-check": ["res://tools/native_hitbox_check.gd", "native_hitbox_check", null],
	"--native-hitbox-shots": ["res://tools/native_hitbox_shots.gd", "native_hitbox_shots", null],
	"--boss-check": ["res://tools/boss_check.gd", "boss_check", null],  # boss lairs: dial, wards, phases, the Rare Egg
	# Anti-Heal leaves 30% of a heal (content/rules/combat.json)
	"--anti-heal-check": ["res://tools/anti_heal_check.gd", "anti_heal_check", null],
	"--bot-spacing-shots": ["res://tools/bot_spacing_shots.gd", "bot_spacing_shots", null],  # --shots-dir=<dir>, GPU
	"--stolen-extract-check": ["res://tools/stolen_extract_check.gd", "stolen_extract_check", null],  # extract, saves
	"--tenzo-rmb-air-check": ["res://tools/tenzo_rmb_air_check.gd", "hero_pair_check", null],  # RMB from every footing
}
