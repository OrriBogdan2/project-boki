extends RefCounted
## --train-check: the sky train. Standing on a moving car you walk, strafe and jump in the train's
## frame (it carries you, your own movement goes on top), the car's edge over the abyss holds you,
## and a jump lands you back on it. The engine's front takes a hunter straight out (no wisp, cause
## "train", the kill feed says so, a deathbox near where they were hit) with a warning first (in
## its path ~2s ahead), the cars' frames hit anyone below the deck, and a monster on the rails is
## run over too. Never touches the save.

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("TCHECK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _local(st: SkyTrain, k: int, p: Vector3) -> Vector3:
	return (st.cur[k] as Transform3D).affine_inverse() * p

## A moment a fraction `u` of the way through leg `i`, when the train is well under way.
func _leg_time(st: SkyTrain, i: int, u: float) -> float:
	var t := 0.0
	for j in i:
		t += st.dwell + float(st.legs[j]["t"])
	return t + st.dwell + float(st.legs[i]["t"]) * u

## Jumps the match clock (and so the train) to time t, with nobody aboard.
func _set_time(m: Match, t: float) -> void:
	m.time = t
	m.skytrain.tick(0.0)
	m.skytrain.old = m.skytrain.cur.duplicate()

func _fwd2(st: SkyTrain, k: int) -> Vector2:
	var f: Vector3 = -(st.cur[k] as Transform3D).basis.z
	return Vector2(f.x, f.z).normalized()

func _right2(st: SkyTrain, k: int) -> Vector2:
	var f: Vector3 = (st.cur[k] as Transform3D).basis.x
	return Vector2(f.x, f.z).normalized()

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 3, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "god": false})
	m.set_process(false)
	var st: SkyTrain = m.skytrain
	ok(st != null, "the map has a sky train")
	if st == null:
		print("TRAIN CHECK DONE, failures: ", bad); main.get_tree().quit(); return
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.lives = 1
		h.teleport(m.world.random_ground())
	var P: Hunter = m.player
	var Q: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	# ---- 1. riding: stand on a car of a moving train, out over the abyss (open air both sides for
	# the next stretch)
	var K := 2
	var found := false
	for li in st.legs.size():
		for u in [0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55]:
			_set_time(m, _leg_time(st, li, u))
			var s0: float = st.head_s - K * SkyTrain.CAR_GAP
			var clear := true
			for ds in range(0, 9):
				var a: Vector3 = m.world.train_at(s0 + ds)
				var f: Vector3 = m.world.train_at(s0 + ds + 0.5) - m.world.train_at(s0 + ds - 0.5)
				var sd := Vector3(-f.z, 0, f.x).normalized()
				for xx in [-(SkyTrain.HALF_W + 0.8), SkyTrain.HALF_W + 0.8]:
					var q: Vector3 = a + sd * xx
					if not m.world.is_void(q.x, q.z): clear = false
			if clear:
				found = true
				break
		if found: break
	ok(found, "found a stretch where the train runs over open air")
	P.teleport((st.cur[K] as Transform3D).origin + Vector3(0, 0.02, 0))
	P.vel = Vector3.ZERO; P.grounded = true
	var w0 := P.pos
	for i in 30: m.step(Match.DT)
	var l := _local(st, K, P.pos)
	ok(st.head_v > 3.0, "the train is moving (%.1f m/s)" % st.head_v)
	ok(P.grounded and absf(l.x) < 0.2 and absf(l.z) < 0.2 and absf(l.y) < 0.05, "standing still on a car you ride along with it (local %s, carried %.1fm)" % [str(l.snapped(Vector3.ONE * 0.01)), P.pos.distance_to(w0)])
	# walk forward along the car (in the train's frame)
	var l0 := _local(st, K, P.pos)
	for i in 24:
		P.inp["move"] = _fwd2(st, K)
		m.step(Match.DT)
	P.inp["move"] = Vector2.ZERO
	var l1 := _local(st, K, P.pos)
	ok(l0.z - l1.z > 1.2, "walking forward moves you along the car: %.2fm in the train's frame" % (l0.z - l1.z))
	# and back the other way
	for i in 30:
		P.inp["move"] = -_fwd2(st, K)
		m.step(Match.DT)
	P.inp["move"] = Vector2.ZERO
	var l2 := _local(st, K, P.pos)
	ok(l2.z - l1.z > 1.2 and P.grounded, "walking backward too: %.2fm" % (l2.z - l1.z))
	# strafe to the side: you move across the deck, and the edge over the abyss holds you
	for i in 12:
		P.inp["move"] = _right2(st, K)
		m.step(Match.DT)
	var l3 := _local(st, K, P.pos)
	ok(l3.x - l2.x > 0.4, "strafing moves you across the car: %.2fm" % (l3.x - l2.x))
	var side := (st.cur[K] as Transform3D) * Vector3(SkyTrain.HALF_W + 1.0, 0, 0)
	var over_void := m.world.is_void(side.x, side.z)
	for i in 60:
		P.inp["move"] = _right2(st, K)
		m.step(Match.DT)
	P.inp["move"] = Vector2.ZERO
	var kk: int = st._car_under(P.pos, st.cur, 0.3)
	var l4 := _local(st, maxi(kk, 1), P.pos)
	if over_void:
		ok(kk > 0 and P.grounded and absf(l4.x) <= SkyTrain.HALF_W and not P.out, "pushing against the side over the abyss: still on the car (local x %.2f)" % l4.x)
	else:
		print("TCHECK note: ground beside the car here, skipped the edge test")
	# walk back to the middle and jump: you go up and come down on the train
	for i in 40:
		var lc := _local(st, maxi(kk, 1), P.pos)
		P.inp["move"] = -_right2(st, K) * signf(lc.x) if absf(lc.x) > 0.15 else Vector2.ZERO
		m.step(Match.DT)
	P.inp["move"] = Vector2.ZERO
	var kj: int = st._car_under(P.pos, st.cur, 0.3)
	var deck0: float = st.deck_y(P.pos)
	P.inp["jump"] = true
	var peak := 0.0
	var left := false
	for i in 120:
		m.step(Match.DT)
		var dk: float = st.deck_y(P.pos, 4.0)
		if not P.grounded: left = true
		if dk > World.VOID + 1.0: peak = maxf(peak, P.pos.y - dk)
		if left and P.grounded: break
	var kl: int = st._car_under(P.pos, st.cur, 0.3)
	ok(left and peak > 0.6, "jumping on the car leaves the deck (peak %.2fm above it)" % peak)
	ok(P.grounded and kl > 0 and st.on_deck(P.pos), "and lands back on the moving train (car %d, from car %d)" % [kl, kj])
	ok(not P.out and not P.downed, "the rider is fine")
	# a dash forward along the train: you cross to the next car (the decks run over the couplings)
	var kd0: int = st._car_under(P.pos, st.cur, 0.3)
	P.inp["dash"] = true
	P.inp["move"] = _fwd2(st, kd0)
	for i in 30: m.step(Match.DT)
	P.inp["move"] = Vector2.ZERO
	for i in 10: m.step(Match.DT)
	ok(not P.out and (st._car_under(P.pos, st.cur, 0.3) > 0 or not P.grounded), "dashing along the train keeps you on it or in the air (car %d -> %d)" % [kd0, st._car_under(P.pos, st.cur, 0.3)])
	# ---- 1b. waiting at a stop: walk off the side of a car onto the pier
	var stop_t := _leg_time(st, 1, 0.0) - st.dwell + 0.5
	_set_time(m, stop_t)
	var mid: Vector3 = ((st.cur[1] as Transform3D).origin + (st.cur[2] as Transform3D).origin) * 0.5
	var stepped := false
	var side_s := 0.0
	for sgn in [-1.0, 1.0]:
		_set_time(m, stop_t)
		P.teleport(mid + Vector3(0, 0.02, 0)); P.vel = Vector3.ZERO; P.grounded = true; P.pad = {}
		for i in 40:
			P.inp["move"] = _right2(st, 1) * sgn
			m.step(Match.DT)
			# (stop on the pier: there's a launch pad further out on some of them)
			if P.grounded and not st.on_deck(P.pos) and not m.world.is_void(P.pos.x, P.pos.z) and _local(st, 1, P.pos).x * sgn > SkyTrain.HALF_W - 0.2:
				break
		P.inp["move"] = Vector2.ZERO
		P.vel = Vector3.ZERO
		if P.grounded and not st.on_deck(P.pos) and not m.world.is_void(P.pos.x, P.pos.z):
			stepped = true; side_s = sgn
			break
	ok(stepped and st.head_v < 0.3, "at a stop you walk off the car onto the pier (side %+.0f, at %s)" % [side_s, str(P.pos.snapped(Vector3.ONE * 0.1))])
	# and back on again
	P.pad = {}
	for i in 40:
		P.inp["move"] = -_right2(st, 1) * side_s
		m.step(Match.DT)
		if st.on_deck(P.pos): break
	P.inp["move"] = Vector2.ZERO
	ok(st.on_deck(P.pos) and P.grounded, "and from the pier back onto the car")
	P.teleport(m.world.random_ground()); P.vel = Vector3.ZERO; P.grounded = true
	# ---- 2. the engine's front: straight out, no wisp
	_set_time(m, _leg_time(st, 1, 0.25))
	var s_hit: float = st.head_s + SkyTrain.CAR_LEN * 0.5 + 24.0
	var pin: Vector3 = m.world.train_at(s_hit)
	Q.teleport(pin)
	var downs0 := Q.downs
	var warned_at := -1.0
	var hit_at := -1.0
	var hit_pos := Vector3.ZERO
	var t0 := m.time
	var was_down := false
	while not Q.out and m.time - t0 < 8.0:
		if not Q.out:
			Q.pos = pin; Q.vel = Vector3.ZERO; Q.grounded = true
		if warned_at < 0.0 and st.head_v > 0.3 and st.in_path(SkyTrain.HORN_LEAD) == Q:
			warned_at = m.time
		hit_pos = Q.pos
		m.step(Match.DT)
		if Q.downed: was_down = true
		if Q.out: hit_at = m.time
	ok(Q.out, "standing on the rails, the engine takes you out (%.1fs)" % (m.time - t0))
	ok(String(Q.get_meta("died_why", "")) == "train", "cause of death: '%s'" % String(Q.get_meta("died_why", "")))
	ok(not was_down and Q.downs == downs0, "no wisp, no down state: straight out")
	ok(warned_at >= 0.0 and hit_at - warned_at >= 1.5, "warned first: in the horn's path %.1fs before the hit" % (hit_at - warned_at))
	ok(m.feed_all.any(func(t): return String(t).contains("%s was hit by the Sky Train" % Q.pname)), "the kill feed says '%s was hit by the Sky Train'" % Q.pname)
	ok(Game._why("train") == "was hit by the Sky Train" and Match.out_text("X", "train") == "X was hit by the Sky Train", "the death recap names the train")
	ok(st.hits.any(func(x): return x["e"] == Q), "the train recorded the hit")
	var bx := Life.box_of(m, Q)
	ok(not bx.is_empty() and Vector2(bx["pos"].x - hit_pos.x, bx["pos"].z - hit_pos.z).length() < 16.0, "the deathbox drops by where they were hit (%.1fm away)" % (Vector2(bx["pos"].x - hit_pos.x, bx["pos"].z - hit_pos.z).length() if not bx.is_empty() else -1.0))
	ok(Q.has_meta("fling"), "the body is flung")
	# ---- 3. the cars' frames hit anything below the deck; nobody on top
	var t2: Transform3D = st.cur[2]
	ok(st.hit_by(t2 * Vector3(0, -1.0, 0)) == 2, "a body below car 2's deck is hit by it")
	ok(st.hit_by(t2 * Vector3(0, 0.0, 0)) == -1, "a body standing on car 2 isn't")
	ok(st.hit_by((st.cur[0] as Transform3D) * Vector3(0, 0.5, 0)) == 0, "a body inside the engine is hit by it")
	# ---- 4. a monster on the rails is run over
	_set_time(m, _leg_time(st, 2 % st.legs.size(), 0.25))
	var mpin: Vector3 = m.world.train_at(st.head_s + SkyTrain.CAR_LEN * 0.5 + 16.0)
	var mb: Mob = m.spawn_mob("brute", mpin)
	mb.teleport(mpin)
	t0 = m.time
	while not mb.dead and m.time - t0 < 6.0:
		mb.pos = mpin; mb.vel = Vector3.ZERO; mb.grounded = true
		m.step(Match.DT)
	ok(mb.dead and st.hits.any(func(x): return x["e"] == mb), "a brute on the rails is run over (%.1fs)" % (m.time - t0))
	print("TRAIN CHECK DONE, failures: ", bad)
	main.get_tree().quit()
