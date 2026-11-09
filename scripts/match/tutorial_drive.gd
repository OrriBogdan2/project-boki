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
	var dest := tu.stop(sid)
	var pad := tu.stop(sid, "pad")
	match sid:
		"move": goto.call(dest, 0.4)
		"dash", "exdash", "glide":
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
					if sid == "dash": p.inp["dash"] = true
					else: p.inp["jump"] = true
			else:
				p.inp["move"] = to.normalized()
				if sid == "exdash" and p.vel.y < 0.5: p.inp["dash"] = true
				if sid == "glide": p.inp["glide"] = true
		"crouch":
			goto.call(dest, 0.4)
			p.inp["crouch"] = Vector2(dest.x - p.pos.x, dest.z - p.pos.z).length() < 1.2
		"pickup":
			var wp := tu.ground_item()
			if not wp.is_empty():
				goto.call(wp["pos"])
				p.inp["interact"] = int(m.time * 30.0) % 2 == 0     # (a tap per item: one press, one pickup)
		"shoot", "sig", "utility", "throw", "kin1", "fight":
			_fight(m, tu, goto)
		"gkey":
			if fmod(m.time, 1.5) < Match.DT and p.kin:
				KinCommand.tap(p)
		"rank":
			p.level_slot("kin")
		"key":
			for pk in m.pickups:
				if pk["kind"] == "ckey":
					goto.call(pk["pos"], 0.3)
		"orders":
			if fmod(m.time, 1.0) < Match.DT:
				KinCommand.order(p, "guard" if p.kin and p.kin.cmd != "guard" else "follow")
		"chest":
			goto.call(tu.stop("chest"), 0.4)
			p.inp["interact"] = true
		"goexit", "uplink", "defend", "extract":
			_outpost(m, tu, goto)
	var go: Vector2 = p.inp["move"]
	if p.grounded and go != Vector2.ZERO:
		var ahead := p.pos + Vector3(go.x, 0.0, go.y).normalized() * 0.9
		if m.world.ground_at(ahead.x, ahead.z) > p.pos.y + 0.3 and not m.world.is_void(ahead.x, ahead.z):
			p.inp["jump"] = true       # a ledge in the way: jump it, as a player would
	if still_t > 1.5 and go != Vector2.ZERO and sid != "crouch":
		p.inp["jump"] = true       # (stuck against something: hop, but never on the lookout: it is climbed plainly)

static func _fight(m: Match, tu: Tutorial, goto: Callable) -> void:
	var p := m.player
	var best: Ent = null
	var bd := 1e9
	for mb in m.mobs:
		if not mb.dead and p.flat_dist(mb) < bd:
			bd = p.flat_dist(mb)
			best = mb
	var sid := tu.id()
	if sid == "utility":
		_rmb(m, tu)
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

## Right click: taps, and a hold after them when the kit has a hold variant.
static func _rmb(m: Match, tu: Tutorial) -> void:
	var ph := fmod(tu.t, 2.0)
	m.player.inp["sec"] = ph < 0.1 or (ph > 0.6 and ph < (1.5 if tu.rmb_has_hold() else 0.7))
	m.player.inp["sec_hold"] = m.player.inp["sec"]

static func _outpost(m: Match, tu: Tutorial, goto: Callable) -> void:
	var p := m.player
	var o := tu.outpost()
	if o.is_empty():
		return
	var c: Vector3 = o["pos"]
	match tu.id():
		"goexit":
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
		"uplink":
			goto.call(c)
			p.inp["interact"] = p.flat_dist(c) < 1.4
		"defend":
			goto.call(c + Vector3(1.2, 0, 1.2))
			var best: Ent = null
			var bd := 1e9
			for mb in m.mobs:
				if not mb.dead and p.flat_dist(mb) < bd:
					bd = p.flat_dist(mb)
					best = mb
			if best and p.flat_dist(best) < 8.0:
				p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
				p.inp["fire"] = true
		"extract":
			goto.call(c)
