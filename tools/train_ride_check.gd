extends RefCounted
## --train-ride-check: the sky train's cars as moving platforms, as in the source. From a car at full
## speed you jump straight up, dash off the back, walk off the side falling and walk off the side with
## the glider open, and each logs a second of world velocity ("TRIDE <case> t v along"): you set off
## at the deck's speed (no jolt), the air never stops you dead and never slingshots you past the
## train, and the air steering and drag take it from there. A glide that lands on a moving car has no
## jolt either and moves with the deck within 0.1 s. Headless, scripted match time; never touches the save.

const DT := Match.DT
const LOG_EVERY := 6           # steps between log lines (0.1 s)
const JOLT := 0.5              # m/s: the most the world speed may change the step you leave or touch a car
const MATCH_T := 0.1           # s: a landing moves with the deck within this
const RISE_MAX := 0.5          # m the track may climb or drop where a case needs it level

var bad := 0
var m: Match
var st: SkyTrain
var P: Hunter

func ok(cond: bool, what: String) -> void:
	print("TRIDE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

## A moment a fraction `u` of the way through leg `i`.
func _leg_time(i: int, u: float) -> float:
	var t := 0.0
	for j in i:
		t += st.dwell + float(st.legs[j]["t"])
	return t + st.dwell + float(st.legs[i]["t"]) * u

## Jumps the match clock (and so the train) to time t, with nobody aboard.
func _set_time(t: float) -> void:
	m.time = t
	st.tick(0.0)
	st.old = st.cur.duplicate()
	st.carried = {}

func _fwd2(k: int) -> Vector2:
	var f: Vector3 = -(st.cur[k] as Transform3D).basis.z
	return Vector2(f.x, f.z).normalized()

func _right2(k: int) -> Vector2:
	var f: Vector3 = (st.cur[k] as Transform3D).basis.x
	return Vector2(f.x, f.z).normalized()

## How fast car k moved this step (m/s, world).
func _deck_v(k: int) -> Vector2:
	var d: Vector3 = (st.cur[k] as Transform3D).origin - (st.old[k] as Transform3D).origin
	return Vector2(d.x, d.z) / DT

## P's world velocity this step: on a car (or dashing on past its end) the train moved them on top
## of their own motion.
func _world_hv() -> Vector2:
	var hv := Vector2(P.vel.x, P.vel.z)
	if st.dash_off.has(P):
		return hv + (st.dash_off[P] as Vector2)
	if not st.carried.has(P):
		return hv
	var dp: Vector3 = st.carried[P]
	return hv + Vector2(dp.x, dp.z) / DT

## What else has hold of P (anything here means the moment isn't a clean ride).
func _tags() -> String:
	var t := ""
	if P.out: t += " out"
	if P.stun_t > 0.0: t += " stun"
	if not P.lfloat.is_empty(): t += " ledge"
	if P.wall_hit_v != Vector2.ZERO: t += " wall"
	if P.knock_t > 0.0 or P.fly_t > 0.0: t += " knock"
	return t

func _clear() -> void:
	for key in ["jump", "dash", "glide", "glide_btn", "crouch", "fire"]:
		P.inp[key] = false
	P.inp["move"] = Vector2.ZERO

## Stand on car k, lz metres back from its middle, settled into its motion at time t.
func _board(t: float, k: int, lz: float) -> void:
	_set_time(t)
	P.out = false
	P.gone = false
	P.downed = false
	_clear()
	P.teleport((st.cur[k] as Transform3D) * Vector3(0, 0.02, lz))
	var fwd := _fwd2(k)
	P.vel = Vector3(fwd.x, 0.0, fwd.y) * st.head_v     # already moving with it, like a rider since the stop
	P.grounded = true
	P.gliding = false
	# nothing left over from the last case
	P.pad = {}
	P._handoff = {}
	P.glide_lift.swoop = 0.0
	P.glide_lift.hang_t = 0.0
	for i in 6: m.step(DT)

## The fastest moment with open air beside the track from lo to hi metres of car 2's position (a
## bridge over the track is a wall to anyone in the air under it) and, when `flat`, level track there
## (the track dives under the bridges, and a car dropping or climbing under a jump changes it), so
## the case runs in clear air; `side` metres out to the right too, for someone falling off that
## side. The clearest such moment when none is wholly clear.
func _find_ride(lo: int, hi: int, flat: bool, side := 0.0) -> float:
	var K := 2
	var best_t := -1.0
	var best_n := -1
	var best_v := 0.0
	var lat: Array = [-(SkyTrain.HALF_W + 0.8), -0.8, 0.0, 0.8, SkyTrain.HALF_W + 0.8]
	for x in range(3, int(side) + 1):
		lat.append(float(x))     # (walking off to the right, you fall on out that way)
	var all := (hi - lo) * lat.size()
	for li in st.legs.size():
		for ui in range(20, 81):
			var t := _leg_time(li, ui * 0.01)
			var v: float = st._schedule(t).y
			if v < st.speed * 0.5 or st._schedule(t + 1.0).y < v * 0.7:
				continue
			_set_time(t)
			var s0: float = st.head_s - K * SkyTrain.CAR_GAP
			var n := 0
			var rise := 0.0
			for ds in range(lo, hi):
				var a: Vector3 = m.world.train_at(s0 + ds)
				rise = maxf(rise, absf(a.y - m.world.train_at(s0).y))
				var f: Vector3 = m.world.train_at(s0 + ds + 0.5) - m.world.train_at(s0 + ds - 0.5)
				var sd := Vector3(-f.z, 0, f.x).normalized()
				if sd.dot((st.cur[K] as Transform3D).basis.x) < 0.0:
					sd = -sd     # (positive is the cars' right)
				for xx in lat:
					var q: Vector3 = a + sd * float(xx)
					if m.world.ground_at(q.x, q.z) <= World.VOID + 1.0: n += 1
			if flat and rise > RISE_MAX:
				continue
			if n > best_n or (n == best_n and v > best_v):
				best_n = n
				best_t = t
				best_v = v
	if best_n < all:
		print("TRIDE note: no stretch %d..%d m is wholly over open air; using the clearest (%d of %d points)"
			% [lo, hi, best_n, all])
	return best_t

## Drives P with `drive` (called with the step index and whether they have left the deck) until they
## leave car k, then logs a second of world velocity. Returns what the second showed.
func _leave(label: String, k: int, drive: Callable) -> Dictionary:
	var fwd := _fwd2(k)
	var r := {"left": false, "jolt": INF, "min_v": INF, "max_along": -INF, "max_step": 0.0,
		"landed": -1.0, "landed_on_deck": false, "glide_at": -1.0}
	var prev := _world_hv()
	var left_i := -1
	for i in 240:
		drive.call(i, left_i >= 0)
		var dashing := P.roll_t > 0.0
		m.step(DT)
		var hv := _world_hv()
		if left_i < 0:
			var dk: float = st.deck_y(P.pos, 4.0)
			if not P.grounded and (dk <= World.VOID + 1.0 or P.pos.y - dk > 0.1):     # (not a step down a pitched deck)
				left_i = i
				r["left"] = true
				r["jolt"] = (hv - prev).length()
				print("TRIDE %s leaves the deck at %.1f m/s world (deck %.1f), first air step %.1f m/s"
					% [label, prev.length(), _deck_v(k).length(), hv.length()])
			prev = hv
			continue
		var tt := (i - left_i) * DT
		if tt > 1.0 + DT * 0.5:
			# (the second is logged; a jump off a climbing car hangs a little longer: wait for it to land)
			if P.grounded and r["landed"] < 0.0:
				r["landed"] = tt
				r["landed_on_deck"] = st.on_deck(P.pos)
			if r["landed"] >= 0.0 or tt > 2.0:
				break
			prev = hv
			continue
		if r["glide_at"] < 0.0 and P.gliding:
			r["glide_at"] = tt
		var dash_end := dashing and P.roll_t <= 0.0     # the dash's own hand-over to run speed, not the train's doing
		if r["landed"] < 0.0:
			r["min_v"] = minf(r["min_v"], hv.length())
			r["max_along"] = maxf(r["max_along"], hv.dot(fwd))
			if not dash_end:
				r["max_step"] = maxf(r["max_step"], (hv - prev).length())
			if P.grounded:
				r["landed"] = tt
				r["landed_on_deck"] = st.on_deck(P.pos)
		if (i - left_i) % LOG_EVERY == 0 or P.grounded and r["landed"] == tt:
			var state := (" gliding" if P.gliding else "") + _tags()
			if P.grounded:
				state += " landed"
			print("TRIDE %s t=%.2f v=(%.2f, %.2f) %.2f m/s along %.2f%s"
				% [label, tt, hv.x, hv.y, hv.length(), hv.dot(fwd), state])
		prev = hv
	return r

func _case_jump(t: float) -> void:
	_board(t, 2, 0.0)
	var deck := _deck_v(2).length()
	var r := _leave("jump", 2, func(i: int, _left: bool) -> void: P.inp["jump"] = i == 0)
	ok(r["left"] and r["jolt"] <= JOLT,
		"jump: the step you leave the deck keeps your world speed (change %.2f m/s)" % r["jolt"])
	ok(r["min_v"] >= deck * 0.6,
		"jump: no dead stop in the air (slowest %.1f of the deck's %.1f m/s)" % [r["min_v"], deck])
	ok(r["max_along"] <= deck + 0.3,
		"jump: no slingshot past the train (fastest along the track %.1f m/s)" % r["max_along"])
	ok(r["max_step"] <= JOLT,
		"jump: the air steering and drag ease it off, no step over %.2f m/s (largest %.2f)" % [JOLT, r["max_step"]])
	ok(r["landed"] > 0.0 and r["landed_on_deck"],
		"jump: comes down on the train (%.2f s, drifted back by the air drag)" % r["landed"])

func _case_dash_back(t: float) -> void:
	var k := st.cars_n - 1
	_board(t, k, 0.0)
	var deck := _deck_v(k).length()
	var back := -_fwd2(k)
	var r := _leave("dash_back", k, func(i: int, _left: bool) -> void:
		if i == 0:     # the base dash itself (a hero's kit may shape its own)
			P.dash_with({"type": "dash", "speed": Hunter.DASH_SPEED, "time": Hunter.DASH_TIME, "dir": back}))
	ok(r["left"] and r["jolt"] <= JOLT,
		"dash back: off the back of the train your world speed carries over (change %.2f m/s)" % r["jolt"])
	ok(r["max_along"] <= deck + 0.3, "dash back: no slingshot (fastest along the track %.1f m/s)" % r["max_along"])
	ok(r["min_v"] >= 2.0 and r["max_step"] <= JOLT,
		"dash back: no dead stop (slowest %.1f m/s), no step over %.2f m/s but the dash's own end (largest %.2f)"
			% [r["min_v"], JOLT, r["max_step"]])

func _case_walk_off(t: float, glide: bool) -> void:
	var label := "glide_off" if glide else "walk_off"
	_board(t, 2, 0.0)
	var deck := _deck_v(2).length()
	var right := _right2(2)
	var r := _leave(label, 2, func(_i: int, left: bool) -> void:
		P.inp["move"] = Vector2.ZERO if left else right
		P.inp["glide"] = glide and left
		P.inp["glide_btn"] = glide and left)
	ok(r["left"], "%s: walking off the side is never blocked" % label)
	ok(r["jolt"] <= JOLT, "%s: the step you walk off keeps your world speed (change %.2f m/s)" % [label, r["jolt"]])
	ok(r["min_v"] >= deck * 0.6,
		"%s: no dead stop in the air (slowest %.1f of the deck's %.1f m/s)" % [label, r["min_v"], deck])
	ok(r["max_along"] <= deck + 0.3 and r["max_step"] <= JOLT,
		"%s: no slingshot (fastest along %.1f m/s, largest step %.2f)" % [label, r["max_along"], r["max_step"]])
	if glide:
		ok(r["glide_at"] >= 0.0 and r["glide_at"] <= 0.1,
			"glide_off: the glider opens (%.2f s after stepping off)" % r["glide_at"])

## Gliding along the track at glide speed just above the front of car 2, holding forward (the car
## outruns a glider, so it's a short glide) and letting go on touching down: the landing keeps your
## world speed that step, then the ground brake has you moving with the deck within MATCH_T.
func _case_glide_land(t: float) -> void:
	_board(t, 2, 0.0)
	var k := 2
	var fwd := _fwd2(k)
	P.teleport((st.cur[k] as Transform3D) * Vector3(0, 0.5, -1.0))
	P.grounded = false
	st.carried.erase(P)     # (set down in the air, not stepped off the deck)
	P.gliding = true     # (open already and sinking: a glider opened right over the deck kicks up first)
	P.vel = Vector3(fwd.x * Hunter.GLIDE_SPEED, -1.4, fwd.y * Hunter.GLIDE_SPEED)
	P.inp["move"] = fwd
	P.inp["glide"] = true
	P.inp["glide_btn"] = true
	var prev := _world_hv()
	var landed := -1.0
	var jolt := 0.0
	var opened := false
	var trace: Array = []       # speed over the deck each step after touching down
	for i in 240:
		m.step(DT)
		opened = opened or P.gliding
		var hv := _world_hv()
		if landed < 0.0 and P.grounded:
			landed = i * DT
			jolt = (hv - prev).length()
			P.inp["move"] = Vector2.ZERO     # let go on touching down: the ground brake takes you to the deck's speed
			print("TRIDE glide_land touches down at %.1f m/s world, deck %.1f m/s, first step on it %.1f m/s"
				% [prev.length(), _deck_v(k).length(), hv.length()])
		if landed >= 0.0:
			trace.append(Vector2(P.vel.x, P.vel.z))
			if trace.size() % LOG_EVERY == 1:
				print("TRIDE glide_land t=%.2f v=(%.2f, %.2f) %.2f m/s over the deck %.2f%s"
					% [(trace.size() - 1) * DT, hv.x, hv.y, hv.length(), Vector2(P.vel.x, P.vel.z).length(), _tags()])
			if trace.size() > 36:
				break
		prev = hv
	ok(opened and landed > 0.0 and st.on_deck(P.pos),
		"glide_land: a glide along the train lands on a car (%.2f s%s)" % [landed, _tags()])
	ok(jolt <= JOLT + Hunter.GROUND_ACCEL * DT,
		"glide_land: no jolt touching down (world speed changed %.2f m/s that step)" % jolt)
	if trace.size() > 12:
		var settled: Vector2 = trace[trace.size() - 1]
		var when := -1.0
		for i in trace.size():
			if (trace[i] as Vector2).distance_to(settled) < 0.3:
				when = i * DT
				break
		ok(when >= 0.0 and when <= MATCH_T and settled.length() < 0.3,
			"glide_land: moving with the deck (%.1f m/s over it) %.2f s after touching down" % [settled.length(), when])

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false,
		"map": "skyreach"})
	m.set_process(false)
	st = m.skytrain
	ok(st != null, "the map has a sky train")
	if st == null:
		print("TRAIN RIDE CHECK DONE, failures: ", bad)
		main.get_tree().quit()
		return
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
		h.teleport(m.world.random_ground())
	P = m.player
	# each case settles a few steps on the car (1 m), then rides on for about a second (10 m)
	var t_jump := _find_ride(0, 9, true)       # a jump: level track under the whole hang
	var t_side := _find_ride(0, 15, false, 6.0)    # a walk off the side, falling or gliding out to the right
	var t_land := _find_ride(0, 10, true)      # a glide landing on level deck
	var t_back := _find_ride(-12, 3, false)    # a dash off the back
	ok(t_jump > 0.0 and t_side > 0.0 and t_land > 0.0 and t_back > 0.0,
		"found the fastest clear stretches (match time %.1f, %.1f, %.1f and %.1f s)" % [t_jump, t_side, t_land, t_back])
	var t_ahead := t_side
	_board(t_ahead, 2, 0.0)
	var dv := _deck_v(2)
	ok(st.head_v >= st.speed and (_world_hv() - dv).length() < 0.1,
		"riding at full speed: world speed is the deck's (%.1f m/s)" % dv.length())
	_case_jump(t_jump)
	_case_walk_off(t_side, false)
	_case_walk_off(t_side, true)
	_case_glide_land(t_land)
	_case_dash_back(t_back)
	print("TRAIN RIDE CHECK DONE, failures: ", bad)
	main.get_tree().quit()
