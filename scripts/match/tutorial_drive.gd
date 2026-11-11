class_name TutorialDrive
extends RefCounted
## Test driver: plays the tutorial course by itself so the whole flow can be checked headless
## (--tutorial --tut-test, and the teammate check).

static var last_step := -1
static var still_t := 0.0     # s the player has stood in one place while walking
static var last_pos := Vector3.INF

static func drive(m: Match) -> void:
	var tu: Tutorial = m.tut
	tu.ack()
	tu.pell.test_skip()
	if tu.step != last_step:
		var live := m.mobs.filter(func(x): return not x.dead).size()
		print("TUT step ", tu.step, " ", tu.id(), " t=", snapped(m.time, 0.1), " mobs=", live)
		last_step = tu.step
	var p := m.player
	for k in ["fire", "glide", "interact", "crouch", "sec", "sig", "jump", "dash", "throw"]:
		p.inp[k] = false
	p.inp["move"] = Vector2.ZERO
	still_t = still_t + Match.DT if p.pos.distance_to(last_pos) < 0.02 else 0.0
	last_pos = p.pos
	var goto := func(at: Vector3, r := 0.5):
		var d := Vector2(at.x - p.pos.x, at.z - p.pos.z)
		p.inp["move"] = d.normalized() if d.length() > r else Vector2.ZERO
	var sid := tu.id()
	var leg := tu.stop_id()          # the dash step's second half is the glide stop
	var dest := tu.stop(leg)
	var pad := tu.stop(leg, "pad")
	match sid:
		"move":
			if not p.dropping:      # (the drop lands you on the meadow by itself)
				goto.call(dest, 0.4)
		"dash":
			var to := Vector2(dest.x - p.pos.x, dest.z - p.pos.z)
			var pd := Vector2(pad.x - p.pos.x, pad.z - p.pos.z)
			var there: bool = m.world.island_of(p.pos.x, p.pos.z) == m.world.island_of(dest.x, dest.z)
			if p.grounded and there:
				goto.call(dest, 0.5)
			elif p.grounded:
				if pd.length() > 0.9:
					p.inp["move"] = pd.normalized()
				else:
					p.inp["move"] = to.normalized()
					if leg == "dash": p.inp["dash"] = true
					else: p.inp["jump"] = true
			else:
				p.inp["move"] = to.normalized()
				if leg == "glide": p.inp["glide"] = true
		"shoot", "sig", "throw", "fight":
			_fight(m, tu, goto)
		"rival":
			_rival(m, tu, goto)
		"grab":
			var at := tu.rival.boki_at()
			if at != Vector3.INF:
				goto.call(at, 0.3)
				p.inp["interact"] = true       # (held: the hold is what grabs)
		"chest":
			goto.call(tu.stop("chest"), 0.4)
			p.inp["interact"] = true
		"extract":
			_outpost(m, tu, goto)
	var go: Vector2 = p.inp["move"]
	if p.grounded and go != Vector2.ZERO:
		var ahead := p.pos + Vector3(go.x, 0.0, go.y).normalized() * 0.9
		if m.world.ground_at(ahead.x, ahead.z) > p.pos.y + 0.3 and not m.world.is_void(ahead.x, ahead.z):
			p.inp["jump"] = true       # a ledge in the way: jump it, as a player would
	if still_t > 1.5 and go != Vector2.ZERO:
		p.inp["jump"] = true       # (stuck against something: hop)

static func _fight(m: Match, tu: Tutorial, goto: Callable) -> void:
	var p := m.player
	var best: Ent = null
	var bd := 1e9
	for mb in m.mobs:
		if not mb.dead and p.flat_dist(mb) < bd:
			bd = p.flat_dist(mb)
			best = mb
	var sid := tu.id()
	if best == null:
		return
	p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
	if p.flat_dist(best) > 3.0: goto.call(best.pos)
	if sid in ["shoot", "fight"]: p.inp["fire"] = true
	if sid in ["sig", "fight"]: p.inp["sig"] = int(m.time * 2.0) % 2 == 0
	if sid == "throw" and fmod(m.time, 1.5) < Match.DT and p.kin:
		KinCommand.tap(p)       # a tap calls it back when it is out, a tap sends it when it is beside you
	elif sid == "fight" and p.kin and p.kin.state in ["shoulder", "active"]:
		p.kin.throw_to(best.pos)

## The rival Hunter: stand off a little and shoot it, with the E ability now and then.
static func _rival(m: Match, tu: Tutorial, goto: Callable) -> void:
	var h := tu.rival.h
	if h == null or h.downed:
		return
	var p := m.player
	p.inp["aim"] = h.pos + Vector3(0, 0.9, 0)
	if p.flat_dist(h) > 5.0:
		goto.call(h.pos)
	p.inp["fire"] = not h.dropping
	p.inp["sig"] = int(m.time * 2.0) % 2 == 0

## The lift: there the way a bot would go (over the bridge), then into the light.
static func _outpost(m: Match, tu: Tutorial, goto: Callable) -> void:
	var p := m.player
	var o := tu.outpost()
	if o.is_empty():
		return
	var c: Vector3 = o["pos"]
	if m.world.island_of(p.pos.x, p.pos.z) == m.world.island_of(c.x, c.z) and p.grounded:
		goto.call(c)      # on the outpost's island: into the light
		return
	# go there the way a bot would: over the bridges, or jump and glide across a gap
	var mv := m.bot_brain._path_dir(m, p, c)
	if p.ai.has("cross"):
		var L: Dictionary = p.ai["cross"]
		var land: Vector3 = L["land"]
		var tol := Vector2(land.x - p.pos.x, land.z - p.pos.z)
		if p.grounded and m.world.island_of(p.pos.x, p.pos.z) == int(L["to"]):
			p.ai.erase("cross")
		elif not p.grounded:
			mv = tol.normalized()
			p.inp["glide"] = tol.length() > 1.6 or m.world.is_void(p.pos.x, p.pos.z)
		elif p.flat_dist(L["take"]) < 1.3:
			mv = tol.normalized()
			p.inp["jump"] = true
	p.inp["move"] = mv
	p.inp["aim"] = p.pos + Vector3(mv.x, 0.9, mv.y) * 3.0
