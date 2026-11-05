class_name DJDemo
extends RefCounted
## Animation strips of Sable (thief) and Juggernaut for the owner's review (used by ArenaDemo):
## --arena-demo=anim_<move> --arena-shot=<png>. Each is 6 frames: anticipation, release, follow-through,
## recovery. The move is triggered at 0.5s unless noted. --arena-demo=dj_<moment> is one frame at the
## moment itself (STILLS); add --demo-zoom=1.0 for the gameplay zoom.

const ANIM := {
	"thf_lmb": ["thief", "arc_bolts", [0.49, 0.51, 0.54, 0.62, 0.76, 0.95, 1.2]],
	"thf_lmb_held": ["thief", "arc_bolts", [0.5, 0.54, 0.62, 0.76, 0.95, 1.01]],
	"thf_lmb_run": ["thief", "arc_bolts", [0.5, 0.54, 0.62, 0.76, 0.95, 1.01]],
	"thf_primed": ["thief", "arc_bolts", [0.99, 1.02, 1.05, 1.11, 1.24, 1.38, 1.55]],
	"thf_vault": ["thief", "arc_bolts", [0.55, 0.62, 0.69, 0.86, 0.98]],
	"thf_exdash": ["thief", "arc_bolts", [0.55, 0.7, 0.95, 1.4, 1.7]],
	"thf_loop": ["thief", "arc_bolts", [0.53, 0.68, 0.86, 0.97, 1.03, 1.1, 1.22, 1.28, 1.36, 1.49, 1.65, 1.8]],
	"thf_chain": ["thief", "arc_bolts", [0.6, 0.68, 0.76, 1.26, 1.32, 1.44, 1.52, 2.1, 2.16, 2.3, 2.42, 2.9, 2.96]],
	"thf_dance": ["thief", "arc_bolts", [1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.8, 2.0, 2.2, 2.4]],
	"thf_dance_still": ["thief", "arc_bolts", [0.96, 1.0, 1.16, 1.2, 1.36, 1.56]],
	"thf_bola": ["thief", "arc_bolts", [0.5, 0.6, 0.7, 0.8, 0.92, 1.05]],
	"thf_bola_pair": ["thief", "arc_bolts", [0.5, 0.92, 1.0, 1.1, 1.3, 1.6]],
	"thf_knife": ["thief", "arc_bolts", [0.5, 0.54, 0.58, 0.62, 0.72, 0.92]],
	"thf_blink": ["thief", "arc_bolts", [0.99, 1.01, 1.04, 1.1, 1.25, 1.5]],
	"thf_encore": ["thief", "arc_bolts", [0.5, 0.58, 0.7, 0.8, 0.88, 0.97]],
	"thf_reset": ["thief", "arc_bolts", [0.5, 0.54, 0.58, 0.64, 0.74, 0.95]],
	"thf_flourish": ["thief", "arc_bolts", [0.5, 0.58, 0.68, 0.85, 1.0, 1.3]],
	"jug_slash": ["juggernaut", "greatsword", [0.5, 0.54, 0.58, 0.64, 0.74, 0.95]],
	"jug_wave": ["juggernaut", "greatsword", [0.5, 0.9, 1.4, 1.46, 1.55, 1.85]],
	"jug_slam": ["juggernaut", "greatsword", [0.6, 0.85, 1.08, 1.12, 1.25, 1.6]],
	"jug_riposte": ["juggernaut", "greatsword", [0.6, 1.0, 1.16, 1.22, 1.32, 1.55]],
	"jug_lunge": ["juggernaut", "greatsword", [0.65, 1.0, 1.31, 1.42, 1.5, 1.8]],
	"jug_meteor": ["juggernaut", "greatsword", [0.53, 0.62, 0.7, 0.82, 0.98, 1.3]],
	"jug_dash": ["juggernaut", "greatsword", [0.55, 0.64, 0.74, 0.9, 1.2]],
	"jug_exdash": ["juggernaut", "greatsword", [0.5, 0.54, 0.62, 0.72, 0.9]],
	"jug_pull": ["juggernaut", "greatsword", [0.82, 0.92, 1.0, 1.08, 1.16, 1.32]],
	"jug_chain": ["juggernaut", "greatsword", [0.52, 0.58, 0.66, 0.92, 0.98, 1.2]],
	"jug_chainlunge": ["juggernaut", "greatsword", [1.0, 1.4, 1.62, 1.68, 1.78, 2.1]],
	"jug_haul": ["juggernaut", "greatsword", [1.0, 1.24, 1.32, 1.42, 1.52, 1.9]],
	"jug_spin": ["juggernaut", "greatsword", [0.86, 0.9, 0.95, 1.0, 1.07, 1.2]],
	"jug_roar": ["juggernaut", "greatsword", [0.5, 0.56, 0.64, 0.8, 1.1, 1.5]],
	"jug_lunge_air": ["juggernaut", "greatsword", [0.55, 0.75, 0.95, 1.3, 1.42, 1.65]],
}

## The stills: hero, weapon, where the hunter starts from the dummy.
const STILLS := {
	"lmb": ["thief", Vector3(-11.0, 0, 0)], "fizzle": ["thief", Vector3(-6.0, 0, 0)],
	"primed": ["thief", Vector3(-6.0, 0, 0)], "bola_whirl": ["thief", Vector3(-4.5, 0, 0)],
	"bola": ["thief", Vector3(-3.4, 0, 0.2)], "knife": ["thief", Vector3(-6.0, 0, 0)],
	"blink": ["thief", Vector3(-6.0, 0, 0)], "knock": ["thief", Vector3(-3.0, 0, 0)],
	"exdash": ["thief", Vector3(-10.0, 0, 3.0)], "vault": ["thief", Vector3(-5.0, 0, 0)],
	"glint": ["thief", Vector3(-5.0, 0, 0)],
	"slash": ["juggernaut", Vector3(-2.6, 0, 0)], "wave": ["juggernaut", Vector3(-8.0, 0, 0)],
	"chain_fly": ["juggernaut", Vector3(-9.5, 0, 0)], "chain": ["juggernaut", Vector3(-7.0, 0, 0)],
	"rampage": ["juggernaut", Vector3(-6.5, 0, 0)], "enraged": ["juggernaut", Vector3(-3.0, 0, 1.5)],
	"sweet": ["juggernaut", Vector3(-3.3, 0, 0)], "lunge_air": ["juggernaut", Vector3(-7.5, 0, 0)],
	"exec": ["juggernaut", Vector3(-3.0, 0, 0)], "meteor_hit": ["juggernaut", Vector3(-4.0, 0, 0)],
	"pull_steer": ["juggernaut", Vector3(-10.0, 0, 0)],
}

const SLOW_STRIPS := ["thf_vault", "thf_exdash", "thf_loop", "thf_primed", "thf_chain", "thf_dance", "thf_dance_still"]
const STRIP_SLOW := 0.15     # Engine.time_scale while Kael's strips and Sable's dash strips play

static func at(t: float, dt: float, when: float) -> bool:
	return ArenaDemo._at(t, dt, when)

## The scripted input of one strip (called every step).
static func trigger(P: Hunter, D: Hunter, mv: String, t: float, dt: float) -> void:
	var K: ArchKit = P.ak
	if P.ammo < 3: P.ammo = int(P.wpn["mag"])
	if t < 0.05 and (mv.begins_with("jug_") or mv in SLOW_STRIPS):
		Engine.time_scale = STRIP_SLOW       # (a slow software render must not skip the frames a strip asks for)
	match mv:
		"thf_lmb":
			P.inp["fire"] = t > 0.49 and t < 0.52
		"thf_lmb_held":
			P.inp["fire"] = t > 0.49 and t < 1.0
		"thf_lmb_run":
			P.inp["move"] = Vector2(0, 1) if t > 0.15 else Vector2.ZERO
			P.inp["fire"] = t > 0.49 and t < 1.0
		"thf_primed":
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(0, 1)
				P.do_dash()
			P.inp["fire"] = t > 1.0 and t < 1.03          # once she is up from the cartwheel (0.98)
		"thf_vault":
			if at(t, dt, 0.5):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(0, 1)
				P.do_dash()
			if t > 0.5 and t < 0.8: P.inp["move"] = Vector2(0, 1)
		"thf_loop":
			loop(P, t, dt)
		"thf_chain":
			chain(P, t, dt)
		"thf_dance", "thf_dance_still":
			if at(t, dt, 0.5): cast_ult(P)
			if mv == "thf_dance" and t > 0.6: P.inp["move"] = Vector2(0, 1)
		"thf_exdash":
			# sideways, away from the dummy (toward it the hunter ends up inside its model, which filled
			# the old strips' last frames with a big pink blur)
			if at(t, dt, 0.38): P.do_jump()
			if at(t, dt, 0.5):
				P.ex_cd = 0.0
				P.inp["move"] = Vector2(0, -1)
				K.on_dash(true)
		"thf_bola", "thf_bola_pair":
			if mv == "thf_bola_pair" and t < 1.2:
				if t < 0.45: P.teleport(D.pos + Vector3(-3.0, 0, 0))
				var second: Hunter = P.m.arena.dummies[1]["h"]
				second.teleport(D.pos + Vector3(3.0, 0, 0))       # (it strafes: held in the lane)
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
		"thf_encore":
			if at(t, dt, 0.5): cast_ult(P)
			P.inp["fire"] = t > 0.9 and t < 1.0
		"thf_reset", "jug_roar":
			if at(t, dt, 0.5): K.play(mv)
		"thf_flourish":
			if at(t, dt, 0.5): (K as ThiefKit).on_knock(D, true)      # the payoff: the star, the pillar, the flourish
		"jug_lunge_air":
			lunge_air(P, K, t, dt, 0.5)
		"jug_slash":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 2.4, P.pos.y, D.pos.z))
			P.inp["fire"] = t > 0.49 and t < 0.51
		"jug_wave":
			P.inp["fire"] = t > 0.4 and t < 1.44
		"jug_riposte":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 2.4, P.pos.y, D.pos.z))
			if at(t, dt, 0.5): cast_ult(P)
		"jug_slam":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 3.2, P.pos.y, D.pos.z))
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				P.inp["sec_hold"] = false
				K.press_rmb()
		"jug_pull":
			pull_steer(P, K, D, t, dt)
		"jug_lunge":
			if t < 0.45: P.teleport(Vector3(D.pos.x - 6.5, P.pos.y, D.pos.z))
			if at(t, dt, 0.5):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.bot_hold["rmb"] = 0.9
				K.press_rmb()
		"jug_meteor":
			if at(t, dt, 0.4):
				P.teleport(Vector3(D.pos.x - 4.0, P.pos.y + 2.5, D.pos.z))
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
			if at(t, dt, 0.38): P.do_jump()
			if at(t, dt, 0.5):
				P.ex_cd = 0.0
				P.inp["move"] = Vector2(0, -1)
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

## Sable's reset loop (footage 0137-0143 and 0187-0194): a Vault at 0.5 (away from the dummy), the empowered bolt
## thrown once she is up (1.0), its hit gives the Vault back, then a Vault at 1.3 with the bolt thrown mid-flip.
static func loop(P: Hunter, t: float, dt: float) -> void:
	if (t > 0.45 and t < 0.9) or (t > 1.25 and t < 1.7):
		P.inp["move"] = Vector2(-1 if t < 1.0 else 1, 0)       # away from the dummy, then back: it stays in frame
	if at(t, dt, 0.5):
		P.dashes = P.max_dashes()
	if at(t, dt, 0.5) or at(t, dt, 1.3):
		P.do_dash()
	# the second click comes while the first bolt still cools: it is kept and goes mid-flip (ThiefKit.bolt_buf)
	P.inp["fire"] = (t > 1.0 and t < 1.03) or (t > 1.36 and t < 1.39)

## Three cycles of the reset chain (item 53): a Vault every 0.85s to one side and back (the routine's three flips),
## the empowered bolt thrown as she lands, its hit giving the next Vault.
static func chain(P: Hunter, t: float, dt: float) -> void:
	for i in 3:
		var t0 := 0.5 + 0.85 * float(i)
		if at(t, dt, t0):
			P.inp["move"] = Vector2(0, 1 if i % 2 == 0 else -1)
			if i == 0: P.dashes = P.max_dashes()
			P.do_dash()
	var after := fmod(t - 0.5, 0.85)
	P.inp["fire"] = t > 0.5 and after > 0.5 and after < 0.53

## The Warchain's pull with a steer: hooked from 10m, pulled in while holding a sideways key.
static func pull_steer(P: Hunter, K: ArchKit, D: Hunter, t: float, dt: float) -> void:
	if t < 0.4: P.teleport(Vector3(D.pos.x - 10.0, P.pos.y, D.pos.z))
	if at(t, dt, 0.45):
		K.cd["e"] = 0.0
		K.use_e()
	if at(t, dt, 0.85): K.use_e()
	if t > 0.85: P.inp["move"] = Vector2(0, 1)

## X with the ultimate open (level 6) and off cooldown.
static func cast_ult(P: Hunter) -> void:
	P.lvl = maxi(P.lvl, int(Hunter.ULT_AT[0]))
	P.ak.cd["x"] = 0.0
	HunterKeys.ult_pressed(P)

## The Lunge charged from a jump: jump, hold through the rise and fall with the lane up, let go.
static func lunge_air(P: Hunter, K: ArchKit, t: float, dt: float, go: float) -> void:
	if at(t, dt, go):
		K.ch_rmb = 1.0
		K.cd["rmb"] = 0.0
		K.bot_hold["rmb"] = 0.85
		K.press_rmb()
	if at(t, dt, go + 0.32): P.do_jump()

## One still of a moment (--arena-demo=dj_<what>): sets the hero up, plays it, returns when to shoot.
static func still(A: Arena, P: Hunter, D: Hunter, w: String, t: float, dt: float) -> float:
	var spec: Array = STILLS.get(w, ["thief", Vector3(-4.0, 0, 0)])
	var K: ArchKit = P.ak
	if t < 0.05:
		var hero := String(spec[0])
		if P.arch != hero: A.set_arch(hero, "arc_bolts" if hero == "thief" else "greatsword")
		A.set_kin("")
		P.teleport(D.pos + (spec[1] as Vector3))
		A.home = P.pos
		K = P.ak
	P.inp["aim"] = D.pos + Vector3(0, 0.9, 0)
	P.inp["aim_y"] = D.pos.y
	P.inp["move"] = Vector2.ZERO
	P.hp = P.max_hp * (0.55 if w == "knock" else 1.0)      # (knock: so the heal has room to show)
	if P.ammo < 3: P.ammo = int(P.wpn["mag"])
	if P.arch == "thief":
		return _still_dancer(A, P, D, K as ThiefKit, w, t, dt)
	return _still_zedran(A, P, D, K as JuggernautKit, w, t, dt)

static func _still_dancer(A: Arena, P: Hunter, D: Hunter, K: ThiefKit, w: String, t: float, dt: float) -> float:
	match w:
		"lmb", "fizzle":
			if w == "fizzle": P.inp["aim"] = P.pos + Vector3(3.5, 0.9, -1.5)
			P.inp["fire"] = t > 0.3 and K.bolts == 0
			if K.bolts > 0 and not A.has_meta("b_at"): A.set_meta("b_at", t)
			if w == "fizzle":
				if K.fizzles > 0 and not A.has_meta("fz_at"): A.set_meta("fz_at", t)
				return float(A.get_meta("fz_at", 9.0)) + 0.05
			return float(A.get_meta("b_at", 9.0)) + 0.02
		"primed", "vault", "glint":
			if at(t, dt, 0.4):
				P.dashes = P.max_dashes()
				P.inp["move"] = Vector2(0, 1)
				P.do_dash()
			return {"vault": 0.62, "glint": 0.84}.get(w, 1.05)       # glint: the flare as she lands
		"bola_whirl", "bola":
			if w == "bola" and t < 0.6:
				var H: Hunter = A.dummies[2]["h"]
				H.teleport(D.pos + (D.pos - P.pos).normalized() * 2.6)
				H.vel = Vector3.ZERO
			if at(t, dt, 0.4):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				K.press_rmb()
			if K.bola_pairs > 0 and not A.has_meta("bp_at"): A.set_meta("bp_at", t)
			return 0.68 if w == "bola_whirl" else float(A.get_meta("bp_at", 9.0)) + 0.1
		"knife", "blink":
			if at(t, dt, 0.4):
				K.cd["e"] = 0.0
				K.use_e()
			if w == "blink" and at(t, dt, 1.0): K.use_e()
			return 0.95 if w == "knife" else 1.0 + 0.16
		"knock":
			if at(t, dt, 0.4): K.on_knock(D, true)
			return 0.52
		"exdash":
			if at(t, dt, 0.35): P.do_jump()
			if at(t, dt, 0.45):
				P.ex_cd = 0.0
				P.roll_dir = Vector2(1, 0)
				K.on_dash(true)
			return 0.85
	return 1.0

static func _still_zedran(A: Arena, P: Hunter, D: Hunter, K: JuggernautKit, w: String, t: float, dt: float) -> float:
	if t < 0.05 and w in ["meteor_hit", "pull_steer"]:
		Engine.time_scale = STRIP_SLOW
	match w:
		"slash":
			P.inp["fire"] = t > 0.4 and t < 0.42
			return 0.5
		"wave":
			P.inp["fire"] = t > 0.3 and t < 1.35
			if (P.ak as JuggernautKit).waves > 0 and not A.has_meta("wv_at"): A.set_meta("wv_at", t)
			return float(A.get_meta("wv_at", 9.0)) + 0.02
		"chain_fly", "chain":
			if at(t, dt, 0.4):
				K.cd["e"] = 0.0
				K.use_e()
			return 0.5 if w == "chain_fly" else 1.1
		"rampage":
			if at(t, dt, 0.4):
				P.dashes = P.max_dashes()
				P.do_dash()
			return 0.4 + 0.15 + 0.2
		"enraged":
			if at(t, dt, 0.3): K.gain_rage(200.0)
			return 1.4
		"sweet":
			if at(t, dt, 0.3):
				K.ch_rmb = 1.0
				K.cd["rmb"] = 0.0
				P.inp["sec_hold"] = false
				K.press_rmb()
			if K.sweet_spots > 0 and not A.has_meta("ss_at"): A.set_meta("ss_at", t)
			return float(A.get_meta("ss_at", 9.0)) + 0.12
		"lunge_air":
			lunge_air(P, K, t, dt, 0.3)
			return 0.3 + 0.32 + 0.22
		"meteor_hit":
			if at(t, dt, 0.3):
				P.teleport(P.pos + Vector3(0, 2.5, 0))
				P.grounded = false
				P.vel = Vector3.ZERO
			if at(t, dt, 0.4): K.press_rmb()
			if K.meteor.drops > 0 and not A.has_meta("mh_at"): A.set_meta("mh_at", t)
			return float(A.get_meta("mh_at", 9.0)) + 0.06
		"pull_steer":
			pull_steer(P, K, D, t, dt)
			return 1.1
		"exec":
			D.hp = D.max_hp * 0.25
			K.ch_rmb = 1.0
			K.cd["rmb"] = 0.0
			return 0.8
	return 1.0
