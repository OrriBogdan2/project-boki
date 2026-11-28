extends RefCounted
## Kael's RMB into Shift turn limit (the source's patch 05.02.25, docs/heroes/dash_interactions.md "RMB -> dash"):
## Shift in the Slam's wind-up (the Slam Drive) or late in a Lunge (the dash goes as it ends), with the move keys
## and then the cursor swung straight behind him, turns his yaw at most dash.lock_deg from where he faced at the press,
## through the whole dash; dash.lock_t after the Smash the dash turns freely again. Runs inside
## --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
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
	for variant in ["slam", "lunge"]:
		_fresh(m, P, T, home)
		var went := false
		if variant == "slam":
			A.tap(m, P)
			A.step(m, 0.15)
			went = not K.slam_w.is_empty()
		else:
			A.hold(m, P, 0.5)
			went = not K.lunge.is_empty()
			while not K.lunge.is_empty() and P.roll_t > 0.1:      # Shift in its last 0.1s (inside the press buffer)
				m.step(A.DT)
		var y := _dash_behind(m, P, K)
		A.ok("jug turn limit: RMB (%s) into Shift turns his yaw at most %.0f degrees through the dash" % [variant, lim],
				went and y[0] and y[1] <= lim + 1.0, "went %s, dashed %s, yaw %.1f degrees" % [went, y[0], y[1]])
	_fresh(m, P, T, home)
	A.tap(m, P)
	var t := 0.0
	while not K.slam_w.is_empty() and t < 1.5:
		m.step(A.DT)
		t += A.DT
	A.step(m, float(K.dash_def()["lock_t"]) + 0.05)
	var free := _dash_behind(m, P, K)
	A.ok("jug turn limit: %.1fs after the Slam the dash turns freely" % float(K.dash_def()["lock_t"]),
			free[0] and free[1] >= 150.0, "dashed %s, yaw %.1f degrees" % [free[0], free[1]])
	await A.done(m)


func _fresh(m: Match, P: Hunter, T: Hunter, home: Vector3) -> void:
	var K: JuggernautKit = P.ak
	P.inp["move"] = Vector2.ZERO
	P.inp["sec_hold"] = false
	A.step(m, 1.0)
	K.warchain.snap(true)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.dashes = 3.0
	A.fresh(T)
	T.teleport(home + Vector3(0, 0, 40.0))       # out of the lane: nothing stops the drive short
	for s in ["e", "rmb", "x", "air"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	A.aim_at(P, home + Vector3(9.0, 0, 0))
	A.step(m, 0.3)


## Shift with the move keys straight behind him, the cursor swung behind the step after; follows the Rampage to
## its end.
## [the Rampage went, the largest yaw (degrees) of his facing or the dash's way from where he faced at the press].
func _dash_behind(m: Match, P: Hunter, K: JuggernautKit) -> Array:
	var face0 := P.face
	var fwd := Vector2(-sin(face0), -cos(face0))
	P.inp["move"] = -fwd
	K.st["last_dash"] = ""
	P.dashes = 3.0
	P.do_dash()
	m.step(A.DT)
	A.aim_at(P, P.pos - Vector3(fwd.x, 0, fwd.y) * 9.0)     # (the Slam aims freely until Shift: swung after it)
	var worst := 0.0
	var t := 0.0
	var went := false
	while t < 1.5:
		var ram := String(K.st.get("last_dash", "")) == "rampage"
		if ram and (P.roll_t > 0.0 or K.rampage_wind > 0.0):
			went = true
			worst = maxf(worst, absf(rad_to_deg(angle_difference(face0, P.face))))
			if P.roll_dir.length() > 0.1:
				worst = maxf(worst, absf(rad_to_deg(fwd.angle_to(P.roll_dir))))
		elif went:
			break
		m.step(A.DT)
		t += A.DT
	P.inp["move"] = Vector2.ZERO
	return [went, worst]
