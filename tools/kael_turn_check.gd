extends RefCounted
## Kael's turn lock (docs/heroes/juggernaut.md, the source's patch 05.02.25): a dash taken out of each Smash variant
## (the Slam, the Lunge, the Meteor Drop's recovery, the Cinder Spin in the pull) turns at most dash.lock_deg from
## where he faces, and dash.lock_t after the move he turns freely again. Runs inside --juggernaut-combo-check
## (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
const BACK := Vector2(-1, 0)      # the move keys held straight back from the aim (+x)
var A: AKCheck

func run(a) -> void:
	A = a
	var r := A.setup("juggernaut", 6.0)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var lim := float(K.dash_def()["lock_deg"])
	for variant in ["slam", "lunge", "meteor", "spin"]:
		_reset(m, P, K, T, home)
		var went := _smash(m, P, K, variant)
		var turned := _dash_back(m, P)
		A.ok("jug turn lock: a dash out of the %s turns at most %.0f degrees from where he faces" % [variant, lim],
				went and turned <= lim + 1.0, "went %s, turned %.0f degrees" % [went, turned])
	_reset(m, P, K, T, home)
	_smash(m, P, K, "slam")
	A.step(m, float(K.dash_def()["lock_t"]) + 0.05)
	var unlocked := _dash_back(m, P)
	A.ok("jug turn lock: %.1fs after the Slam the dash turns freely" % float(K.dash_def()["lock_t"]),
			unlocked >= 170.0, "turned %.0f degrees" % unlocked)
	await A.done(m)

func _reset(m: Match, P: Hunter, K: JuggernautKit, T: Hunter, home: Vector3) -> void:
	A.step(m, 1.0)
	K.warchain.snap("")
	P.teleport(home)
	P.vel = Vector3.ZERO
	A.fresh(T)
	T.teleport(home + Vector3(6.0, 0, 0))
	A.aim_at(P, T.pos)
	K.ch_rmb = 1.0
	for k in ["rmb", "air", "e"]:
		K.cd[k] = 0.0
	A.step(m, 0.3)

## Runs one Smash variant aimed at +x up to the moment Shift is pressed out of it; false if it never went.
func _smash(m: Match, P: Hunter, K: JuggernautKit, variant: String) -> bool:
	var t := 0.0
	match variant:
		"slam":
			A.tap(m, P)
			var wound := not K.slam_w.is_empty()
			while not K.slam_w.is_empty() and t < 1.0:
				m.step(A.DT)
				t += A.DT
			return wound and K.slam_w.is_empty()
		"lunge":
			A.hold(m, P, 0.5)
			var lunged := not K.lunge.is_empty()
			while not K.lunge.is_empty() and t < 1.0:
				m.step(A.DT)
				t += A.DT
			return lunged and K.lunge.is_empty()
		"meteor":
			P.teleport(P.pos + Vector3(0, 1.8, 0))
			P.grounded = false
			K.press_rmb()
			while K.meteor.phase != "recover" and t < 1.5:
				m.step(A.DT)
				t += A.DT
			return K.meteor.phase == "recover"
	K.use_e()
	A.step(m, 0.3)
	K.use_e()
	A.step(m, 0.05)
	var spins := K.spins
	A.tap(m, P)
	return K.spins == spins + 1

## Shift with the move keys held straight back; how far (degrees) the dash turned from where he faced.
func _dash_back(m: Match, P: Hunter) -> float:
	var fwd := Vector2(-sin(P.face), -cos(P.face))
	P.dashes = 3.0
	P.inp["move"] = BACK
	P.do_dash()
	m.step(A.DT)
	P.inp["move"] = Vector2.ZERO
	return absf(rad_to_deg(fwd.angle_to(P.roll_dir)))
