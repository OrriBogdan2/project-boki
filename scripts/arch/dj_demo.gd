class_name DJDemo
extends RefCounted
## Animation strips of Dancer (thief) and Juggernaut for the owner's review (used by ArenaDemo):
## --arena-demo=anim_<move> --arena-shot=<png>. Each is 6 frames: anticipation, release, follow-through,
## recovery. The move is triggered at 0.5s unless noted.

const ANIM := {
	"thf_lmb": ["thief", "arc_bolts", [0.5, 0.53, 0.58, 0.64, 0.74, 0.95]],
	"thf_primed": ["thief", "arc_bolts", [0.86, 0.89, 0.93, 1.0, 1.12, 1.35]],
	"thf_vault": ["thief", "arc_bolts", [0.5, 0.55, 0.6, 0.66, 0.76, 1.0]],
	"thf_exdash": ["thief", "arc_bolts", [0.5, 0.54, 0.6, 0.68, 0.78, 0.95]],
	"thf_bola": ["thief", "arc_bolts", [0.5, 0.6, 0.76, 0.92, 0.98, 1.2]],
	"thf_knife": ["thief", "arc_bolts", [0.5, 0.56, 0.62, 0.7, 0.85, 1.0]],
	"thf_blink": ["thief", "arc_bolts", [0.99, 1.01, 1.04, 1.1, 1.25, 1.5]],
	"thf_volley": ["thief", "arc_bolts", [0.55, 0.75, 0.95, 1.15, 1.35, 1.7]],
	"thf_reset": ["thief", "arc_bolts", [0.5, 0.54, 0.58, 0.64, 0.74, 0.95]],
	"thf_flourish": ["thief", "arc_bolts", [0.5, 0.58, 0.68, 0.85, 1.0, 1.3]],
	"jug_slash": ["juggernaut", "greatsword", [0.5, 0.54, 0.58, 0.64, 0.74, 0.95]],
	"jug_wave": ["juggernaut", "greatsword", [0.5, 0.9, 1.4, 1.46, 1.55, 1.85]],
	"jug_slam": ["juggernaut", "greatsword", [0.6, 0.85, 1.08, 1.12, 1.25, 1.6]],
	"jug_crash": ["juggernaut", "greatsword", [1.12, 1.18, 1.22, 1.3, 1.45, 1.8]],
	"jug_lunge": ["juggernaut", "greatsword", [0.6, 0.95, 1.3, 1.43, 1.5, 1.8]],
	"jug_meteor": ["juggernaut", "greatsword", [0.5, 0.55, 0.62, 0.7, 0.85, 1.1]],
	"jug_dash": ["juggernaut", "greatsword", [0.5, 0.56, 0.62, 0.7, 0.8, 1.0]],
	"jug_exdash": ["juggernaut", "greatsword", [0.5, 0.56, 0.62, 0.7, 0.8, 1.0]],
	"jug_chain": ["juggernaut", "greatsword", [0.52, 0.58, 0.66, 0.92, 0.98, 1.2]],
	"jug_chainlunge": ["juggernaut", "greatsword", [1.0, 1.4, 1.62, 1.68, 1.78, 2.1]],
	"jug_haul": ["juggernaut", "greatsword", [1.0, 1.24, 1.32, 1.42, 1.52, 1.9]],
	"jug_spin": ["juggernaut", "greatsword", [0.88, 0.92, 0.98, 1.04, 1.12, 1.35]],
	"jug_roar": ["juggernaut", "greatsword", [0.5, 0.56, 0.64, 0.8, 1.1, 1.5]],
}

static func at(t: float, dt: float, when: float) -> bool:
	return ArenaDemo._at(t, dt, when)

## The scripted input of one strip (called every step).
static func trigger(P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	if P.ammo < 3: P.ammo = int(P.wpn["mag"])
	match mv:
		"thf_lmb":
			P.inp["fire"] = t > 0.49 and t < 0.52
		"thf_primed":
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(0, 1)
				P.do_dash()
			P.inp["fire"] = t > 0.85 and t < 0.88
		"thf_vault":
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(0, 1)
				P.do_dash()
			if t > 0.5 and t < 0.8: P.inp["move"] = Vector2(0, 1)
		"thf_exdash":
			if at(t, dt, 0.5):
				P.ex_cd = 0.0
				P.roll_dir = Vector2(0, 1)
				K.on_dash(true)
		"thf_bola":
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				P.inp["sec_hold"] = false
				K.press_rmb()
		"thf_knife":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
		"thf_blink":
			if at(t, dt, 0.4):
				K.cd["e"] = 0.0
				P.inp["aim"] = P.pos + Vector3(0, 0.9, 5.0)
				K.use_e()
			if at(t, dt, 1.0): K.use_e()
		"thf_volley":
			if at(t, dt, 0.5):
				(K as ThiefKit).jp_cd = 0.0
				(K as ThiefKit).add_mark(D, 5, true)
			P.inp["fire"] = t > 0.9 and t < 1.0
		"thf_reset", "thf_flourish", "jug_roar":
			if at(t, dt, 0.5): K.play(mv)
		"jug_slash":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 2.4, P.pos.y, D.pos.z))
			P.inp["fire"] = t > 0.49 and t < 0.51
		"jug_wave":
			P.inp["fire"] = t > 0.4 and t < 1.44
		"jug_slam", "jug_crash":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 3.2, P.pos.y, D.pos.z))
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				P.inp["sec_hold"] = false
				K.press_rmb()
		"jug_lunge":
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 0.9
				K.press_rmb()
		"jug_meteor":
			if at(t, dt, 0.4):
				P.teleport(Vector3(D.pos.x - 4.0, P.pos.y + 3.0, D.pos.z))
				P.grounded = false
				P.vel = Vector3.ZERO
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.press_rmb()
		"jug_dash":
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.do_dash()
		"jug_exdash":
			if at(t, dt, 0.5):
				P.ex_cd = 0.0
				P.grounded = false
				K.on_dash(true)
		"jug_chain":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 0.9): K.use_e()
		"jug_chainlunge":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 0.8):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 0.85
				K.press_rmb()
		"jug_haul":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 0.8):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 1.5
				K.press_rmb()
			if at(t, dt, 1.2): K.use_e()
		"jug_spin":
			if at(t, dt, 0.5):
				K.cd["e"] = 0.0
				K.use_e()
			if at(t, dt, 0.84): K.use_e()
			if at(t, dt, 0.88):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				P.inp["sec_hold"] = false
				K.press_rmb()
