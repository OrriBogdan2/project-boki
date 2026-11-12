extends RefCounted
## Owner item 113, Kael's accuracy pass against the source: no accidental glider (2), the blade forward in the
## Lunge's hold (3), the Searing Wave a side swing (4), E free of RMB's direction (5), the Meteor Drop straight
## down (6), E > R > the pull through the ult (7), the short dash hit (8); the owner's 11-10 playtest: the air
## slam spikes and knocks down, and the combo E > air RMB > jump > RMB > E > Haul Slam chains with no dropped press.
## Runs inside --juggernaut-combo-check (tools/zedran_feel_check.gd). A is tools/archetype_check.gd.

const AKCheck := preload("res://tools/archetype_check.gd")
var A: AKCheck

func run(a) -> void:
	A = a
	await no_glide()
	poses()
	await e_free()
	await vertical_slam()
	await ult_pull()
	await short_dash()
	await slam_combo()
	await pull_waits()
	await rmb_steer()

func _rig() -> Dictionary:
	var r := A.setup("juggernaut", 6.0)
	var P: Hunter = r[1]
	P.lvl = maxi(P.lvl, 6)
	P.slot_lv["ult"] = 1
	return {"m": r[0], "P": P, "T": r[2], "home": r[4], "K": P.ak}

func _fresh(m: Match, P: Hunter, K: JuggernautKit, home: Vector3) -> void:
	A.step(m, 0.7)
	K.warchain.snap("")
	K.riposte.drop()
	P.inp["sec_hold"] = false
	A.step(m, 0.1)
	P.teleport(home)
	P.vel = Vector3.ZERO
	P.stun_t = 0.0
	P.gliding = false
	P.glide_cd = 0.0
	for s in ["e", "rmb", "x", "air"]:
		K.cd[s] = 0.0
	K.ch_rmb = float(K.rmb_charges())
	P.dashes = 3.0
	m.step(A.DT)

# ------------------------------------------------------------------ 2: no accidental glider
func no_glide() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	var held := func(): P.inp["sec_hold"] = true
	held.call()
	K.press_rmb()
	A.step(m, 0.4, held)
	P.do_jump()
	A.step(m, 0.2, held)
	var air := not P.grounded and K.rmb_down
	P.do_jump()
	A.step(m, 0.1, held)
	A.ok("jug 113.2: holding RMB, a jump then a second press never opens the glider", air and not P.gliding,
			"air %s gliding %s" % [air, P.gliding])
	var open_held := P.can_glide()
	P.inp["sec_hold"] = false
	A.step(m, 0.1)
	A.ok("jug 113.2: let go of RMB and the glider is back", not open_held and not K.no_glide())
	_fresh(m, P, K, home)
	K.cast_ult()
	P.teleport(home + Vector3(0, 6.0, 0))
	P.grounded = false
	var shut_guard := K.riposte.guarding() and not P.can_glide()
	A.step(m, float(K.x_def()["guard"]) + 0.03)
	var shut_cleave := String(K.riposte.st.get("phase", "")) == "strike" and not P.can_glide()
	A.ok("jug 113.2: the guard and the cleave keep the glider shut", shut_guard and shut_cleave,
			"%s %s" % [shut_guard, shut_cleave])
	_fresh(m, P, K, home)
	K.cast_ult()
	var t := 0.0
	while String(K.riposte.st.get("phase", "")) != "recover" and t < 2.0:
		m.step(A.DT)
		t += A.DT
	var in_recover := K.riposte.running()
	P.do_jump()
	A.step(m, 0.3)
	P.do_jump()
	A.ok("jug 113.2: in the ult's last beat a jump and a glide input end the rest of it in a glide",
			in_recover and P.gliding and not K.riposte.running(), "recover %s gliding %s ult %s" % [
			in_recover, P.gliding, K.riposte.running()])
	await A.done(m)

# ------------------------------------------------------------------ 3, 4: the keyed poses
## The highest pitch of the blade over a move's keys, and how far its yaw travels between two keys.
func poses() -> void:
	var hold: Array = KMovesDJ.MOVES["jug_lunge_wind"]["keys"]
	var held: Vector3 = hold[-1][1]["blade"]
	A.ok("jug 113.3: the Lunge's held blade points forward (level, on the aim), not overhead",
			absf(held.x) < 0.2 and held.y < 0.5, str(held))
	var wave: Array = KMovesDJ.MOVES["jug_wave"]["keys"]
	var top := -9.0
	for key in wave:
		if (key[1] as Dictionary).has("blade"):
			top = maxf(top, ((key[1] as Dictionary)["blade"] as Vector3).y)
	var sweep: float = absf((wave[1][1]["blade"] as Vector3).x - (wave[0][1]["blade"] as Vector3).x)
	var wind: Vector3 = KMovesDJ.MOVES["jug_wave_wind"]["keys"][-1][1]["blade"]
	A.ok("jug 113.4: the Searing Wave is a side swing: a yaw sweep over 2.5 rad, the blade never above the waist",
			sweep > 2.5 and top < 0.5 and wind.y < 0.5, "sweep %.1f top %.2f" % [sweep, top])

# ------------------------------------------------------------------ 5: E free of RMB's direction
func _throw_after(m: Match, P: Hunter, K: JuggernautKit, home: Vector3, how: String) -> Dictionary:
	_fresh(m, P, K, home)
	var north := home + Vector3(0, 0, -6.0)
	var east := home + Vector3(8.0, 0, 0)
	A.aim_at(P, north)
	match how:
		"slam":
			A.tap(m, P)
			A.step(m, 0.1)
		"lunge":
			A.hold(m, P, 0.45)
			A.step(m, 0.05)
		"rampage":
			P.inp["move"] = Vector2(0, -1)
			P.do_dash()
			A.step(m, 0.08)
			P.inp["move"] = Vector2.ZERO
	A.aim_at(P, east)
	var shots0: int = m.shots.size()
	K.use_e()
	var shot: Dictionary = m.shots[-1] if m.shots.size() > shots0 else {}
	var vel: Vector2 = shot.get("vel", Vector2.ZERO)
	return {"state": K.warchain.state, "dir": vel.normalized()}

func e_free() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	for how in ["slam", "lunge", "rampage"]:
		var r := await _throw_after(m, P, K, home, how)
		A.ok("jug 113.5: RMB/dash north (%s) then E at once at the east: the hook flies at the cursor" % how,
				r["state"] == "throwing" and (r["dir"] as Vector2).dot(Vector2(1, 0)) > 0.97, str(r))
	# both work: the Slam started north still strikes north though the cursor has gone east with the throw
	var T: Hunter = g["T"]
	_fresh(m, P, K, home)
	T.teleport(home + Vector3(0, 0, -3.2))
	A.fresh(T)
	A.aim_at(P, T.pos)
	A.tap(m, P)
	A.step(m, 0.1)
	A.aim_at(P, home + Vector3(8.0, 0, 0))
	K.use_e()
	var thrown := K.warchain.state == "throwing"
	A.step(m, float(K.rmb_def()["windup"]))
	A.ok("jug 113.5: the Slam started north strikes north after E goes east (both work)",
			thrown and A.dmg(T) >= 20.0, "thrown %s, foe took %.0f" % [thrown, A.dmg(T)])
	await A.done(m)

# ------------------------------------------------------------------ 6: the Meteor Drop straight down
func vertical_slam() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	var D := K.meteor
	P.teleport(home + Vector3(0, 3.0, 0))
	P.grounded = false
	P.vel = Vector3.ZERO
	A.aim_at(P, home + Vector3(4.0, 0, 0))
	K.press_rmb()
	var t := 0.0
	var drift := 0.0
	var top := Vector3.ZERO
	while D.phase != "recover" and t < 2.0:
		m.step(A.DT)
		t += A.DT
		if D.phase == "dive":
			if top == Vector3.ZERO:
				top = P.pos
			drift = maxf(drift, Vector2(P.pos.x - D.land.x, P.pos.z - D.land.z).length())
	A.ok("jug 113.6: the slam comes straight down onto the spot (no sideways travel in the dive)",
			top != Vector3.ZERO and drift < 0.15 and D.drops == 1, "%.2f m off the spot in the dive" % drift)
	await A.done(m)

# ------------------------------------------------------------------ 7: E > R > the pull through the ult
func ult_pull() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var T: Hunter = g["T"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	var W := K.warchain
	var U := K.riposte
	T.teleport(home + Vector3(10.0, 0, 0))
	A.fresh(T)
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.45)
	var hooked := W.hooked() and W.target == T
	K.cast_ult()
	A.step(m, 0.1)
	var held := W.hooked() and U.guarding()
	var hp0 := T.hp
	K.use_e()
	var pulled := W.pulling()
	var bitten := 0.0
	var at_hit := 99.0
	var t := 0.0
	var dealt0 := U.strikes
	while (W.state == "pulling" or U.running()) and t < 2.0:
		m.step(A.DT)
		t += A.DT
		if U.strikes > dealt0 and bitten == 0.0:
			bitten = t
			at_hit = P.flat_dist(T)
	A.ok("jug 113.7: E on a foe, then R: the tether holds into the ult", hooked and held, "%s %s" % [hooked, held])
	A.ok("jug 113.7: E in the guard hauls him along the chain", pulled and W.exits == "arrived", "pulled %s exit %s" % [
			pulled, W.exits])
	A.ok("jug 113.7: the ult's cleave hits the hooked foe as he reaches them, once", U.strikes == dealt0 + 1
			and T.hp < hp0 - 20.0, "hit %.2fs in, %.1f m off, foe %.0f > %.0f" % [bitten, at_hit, hp0, T.hp])
	A.ok("jug 113.7: he is near the foe when it lands, the chain ended", P.flat_dist(T) < 3.0 and W.state != "hooked",
			"%.1f m" % P.flat_dist(T))
	# pressed in the cleave's own moment: the pull goes as it lands
	_fresh(m, P, K, home)
	A.fresh(T)
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.45)
	K.cast_ult()
	var st := 0.0
	while not (U.running() and String(U.st.get("phase", "")) == "strike") and st < 1.2:
		m.step(A.DT)
		st += A.DT
	K.use_e()
	A.step(m, 0.15)
	A.ok("jug 113.7: E in the cleave's strike pulls as it lands", W.pulling() or W.state == "arriving", W.state)
	await A.done(m)

# ------------------------------------------------------------------ 8: the short dash hit
func short_dash() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var T: Hunter = g["T"]
	var K: JuggernautKit = g["K"]
	var dd := K.dash_def()
	var home: Vector3 = g["home"]
	T.teleport(home + Vector3(2.5, 0, 0))
	A.fresh(T)
	A.aim_at(P, T.pos)
	P.inp["move"] = Vector2(1, 0)
	var hp0 := T.hp
	var t0: float = m.time
	P.do_dash()
	var t := 0.0
	while (P.roll_t > 0.0 or K.rampage_wind > 0.0 or t < A.DT * 2.0) and t < 1.0:
		m.step(A.DT)
		t += A.DT
	var commit: float = m.time - t0
	P.inp["move"] = Vector2.ZERO
	A.step(m, 0.1)
	A.ok("jug 113.8: press to the end of the drive is 0.3s or less", commit <= 0.3, "%.2fs" % commit)
	A.ok("jug 113.8: it still hits and knocks", T.hp < hp0 - float(dd["hit_dmg"]) * 0.5 and T.flat_dist(P) > 0.8,
			"foe %.0f > %.0f" % [hp0, T.hp])
	var last: float = KMovesDJ.MOVES["jug_dash"]["keys"][-1][0]
	A.ok("jug 113.8: its whole animation is under 0.5s", last < 0.5, "%.2fs" % last)
	await A.done(m)

# ------------------------------------------------------------------ 11-10: the slam combo
func _air(m: Match, P: Hunter, secs: float) -> void:
	P.do_jump()
	A.step(m, secs)

func _until(m: Match, cond: Callable, most: float) -> void:
	var t := 0.0
	while not cond.call() and t < most:
		m.step(A.DT)
		t += A.DT

## E onto a foe, jump and slam down (spiking an airborne foe beside him), jump out of the recovery, hold RMB (the
## Meteor Drop resting: the ground Smash), E pulls him in and the Haul Slam lands on arrival.
func slam_combo() -> void:
	var r := A.setup("juggernaut", 7.0, "", true)
	var m: Match = r[0]
	var P: Hunter = r[1]
	var T: Hunter = r[2]
	var T2: Hunter = r[3]
	var home: Vector3 = r[4]
	var K: JuggernautKit = P.ak
	var W := K.warchain
	var D := K.meteor
	A.fresh(T)
	A.fresh(T2)
	T.teleport(home + Vector3(7.0, 0, 0))
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.45)
	A.ok("jug combo: E hooks the foe", W.hooked() and W.target == T, W.state)
	_air(m, P, 0.25)
	var press_at := P.pos
	T2.teleport(home + Vector3(0.9, 1.2, 0))
	T2.grounded = false
	K.press_rmb()
	A.ok("jug combo: air RMB starts the slam", D.phase == "hang" and W.hooked(), D.phase)
	var drift := 0.0
	while D.phase != "recover" and D.phase != "":
		m.step(A.DT)
		drift = maxf(drift, Vector2(P.pos.x - press_at.x, P.pos.z - press_at.z).length())
		if D.airborne(): T2.pos.y = maxf(T2.pos.y, home.y + 1.2)      # (held up beside him: a foe in the air)
	A.ok("jug combo: the air slam drives straight down (no forward travel) and lands",
			D.drops == 1 and D.phase == "recover" and drift < 0.15, "drops %d drift %.2f" % [D.drops, drift])
	var fall := T2.vel.y
	A.step(m, 0.1)
	var t2_up := T2.pos.y - P.pos.y
	A.ok("jug combo: the landing knocks down and spikes the airborne foe beside him to the ground",
			D.spiked == 1 and fall <= -10.0 and T2.stun_t > 0.0 and t2_up < 0.3 and A.dmg(T2) >= 14.0,
			"spiked %d vy %.1f stun %.2f %.2f m up took %.0f" % [D.spiked, fall, T2.stun_t, t2_up, A.dmg(T2)])
	A.ok("jug combo: the chain still holds the foe after the slam", W.hooked() and W.target == T, W.state)
	_air(m, P, 0.12)
	A.ok("jug combo: a jump goes from the slam's recovery and ends it", not P.grounded and D.phase == "",
			"grounded %s phase %s" % [P.grounded, D.phase])
	var held := func(): P.inp["sec_hold"] = true
	held.call()
	K.press_rmb()
	A.ok("jug combo: RMB in the air with the slam resting is the Smash charge, not a dead press",
			K.rmb_down and not K.rmb_ctx.get("air", true) and D.drops == 1, "down %s ctx %s" % [K.rmb_down, K.rmb_ctx])
	A.step(m, 0.15, held)
	K.use_e()
	A.ok("jug combo: E pulls him in with the Haul Slam armed", W.pulling() and not K.haul.is_empty(),
			"%s haul %s" % [W.state, K.haul])
	var hp0 := T.hp
	_until(m, func(): return W.state != "pulling", 1.5)
	P.inp["sec_hold"] = false
	A.ok("jug combo: the pull reaches the foe (no jump-out from the earlier jump) and the Haul Slam lands",
			W.exits == "arrived" and K.haul_slams == 1 and T.hp < hp0 and T.stun_t > 0.0 and P.flat_dist(T) < 2.5,
			"exit %s hauls %d foe %.0f > %.0f at %.1f m" % [W.exits, K.haul_slams, hp0, T.hp, P.flat_dist(T)])
	await A.done(m)

## E's pull on a hooked chain pressed while a Smash runs (the air slam's hang, the Finishing Slam's wind-up) is
## kept and goes the moment it lands, never lost and never fighting the slam's own movement.
func pull_waits() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var T: Hunter = g["T"]
	var K: JuggernautKit = g["K"]
	var home: Vector3 = g["home"]
	var W := K.warchain
	var D := K.meteor
	T.teleport(home + Vector3(7.0, 0, 0))
	A.fresh(T)
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.45)
	_air(m, P, 0.25)
	var press_at := P.pos
	K.press_rmb()
	m.step(A.DT)
	K.use_e()
	var waited := W.hooked() and D.phase == "hang"
	_until(m, func(): return D.phase != "hang" and D.phase != "dive", 1.0)
	var under := Vector2(D.last_drop.x - press_at.x, D.last_drop.z - press_at.z).length()
	m.step(A.DT)
	A.ok("jug E in the air slam: the pull waits for the landing, then goes at once",
			waited and D.drops == 1 and under < 0.15 and W.pulling(),
			"waited %s %.2f m off, %s" % [waited, under, W.state])
	_until(m, func(): return W.state != "pulling", 1.5)
	A.ok("jug E in the air slam: the pull then arrives", W.exits == "arrived", W.exits)
	_fresh(m, P, K, home)
	A.fresh(T)
	A.aim_at(P, T.pos)
	K.use_e()
	A.step(m, 0.45)
	A.tap(m, P)
	K.use_e()
	var kept := W.hooked() and not K.slam_w.is_empty()
	_until(m, func(): return K.slam_w.is_empty(), 1.0)
	m.step(A.DT)
	A.ok("jug E in the Slam's wind-up: the Slam lands where it was, then the pull goes", kept and W.pulling(),
			"kept %s %s" % [kept, W.state])
	await A.done(m)

# ------------------------------------------------------------------ RMB held: the aim stays his
## Holds RMB aimed north, turns the cursor east mid-hold and lets go: he faces east and the Lunge goes east,
## free and with the Warchain hooked to a foe in the north (only a hold aimed down the chain is a Chain Lunge).
func rmb_steer() -> void:
	var g := _rig()
	var m: Match = g["m"]
	var P: Hunter = g["P"]
	var K: JuggernautKit = g["K"]
	var T: Hunter = g["T"]
	var home: Vector3 = g["home"]
	var held := func(): P.inp["sec_hold"] = true
	for hooked in [false, true]:
		_fresh(m, P, K, home)
		T.teleport(home + Vector3(0, 0, -6.0))
		A.fresh(T)
		A.aim_at(P, T.pos)
		if hooked:
			K.use_e()
			A.step(m, 0.3)
		var on_chain := K.warchain.hooked()
		var lunges := K.chain_lunges
		held.call()
		K.press_rmb()
		A.step(m, 0.4, held)
		A.aim_at(P, home + Vector3(8.0, 0, 0))
		A.step(m, 0.55, held)
		var facing := Vector2(-sin(P.face), -cos(P.face))
		P.inp["sec_hold"] = false
		m.step(A.DT)
		var dir: Vector2 = K.lunge.get("dir", Vector2.ZERO)
		A.ok("jug rmb steer (%s): re-aimed east mid-hold, he faces east and the Lunge goes east" % (
				"chain hooked north" if hooked else "free"),
				on_chain == hooked and facing.dot(Vector2(1, 0)) > 0.97 and dir.dot(Vector2(1, 0)) > 0.97
				and K.chain_lunges == lunges,
				"hooked %s facing %s lunge %s chain lunges %d" % [on_chain, facing, dir, K.chain_lunges - lunges])
	await A.done(m)
