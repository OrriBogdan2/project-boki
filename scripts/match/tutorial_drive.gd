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
	if tu.step != last_step:
		var live := m.mobs.filter(func(x): return not x.dead).size()
		print("TUT step ", tu.step, " ", tu.id(), " t=", snapped(m.time, 0.1), " mobs=", live, " lv=", m.player.lvl,
			" pts=", m.player.skill_pts, " kin=", m.player.kin != null, " seen=", tu.seen.keys())
		last_step = tu.step
	var p := m.player
	for k in ["fire", "glide", "interact", "crouch", "sec", "sig", "jump", "dash", "throw", "gear1", "ult"]:
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
		"pick_sec", "pick_dash", "pick_kin", "pick_ult":
			var slot := TutorialCamps.pick_slot(sid)
			if tu.t > 1.0:
				p.level_slot(slot)       # (the key press did not take: as a click on the gold +)
			elif tu.t > 0.4:
				p.inp[{"sec": "sec", "dash": "dash", "kin": "sig", "ult": "ult"}[slot]] = int(m.time * 10.0) % 2 == 0
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
		"wallkick":
			goto.call(tu.stop("crouch"), 0.4)
			if not p.grounded and p.vel.y < 1.0 and p.pos.y < tu.stop("crouch").y - 0.2:
				p.inp["jump"] = int(m.time * 10.0) % 2 == 0      # (again, against the cliff: the kick)
		"crouch":
			goto.call(dest, 0.4)
			p.inp["crouch"] = Vector2(dest.x - p.pos.x, dest.z - p.pos.z).length() < 1.2
		"glove":
			var wp := tu.ground_item()
			if not wp.is_empty():
				goto.call(wp["pos"])
				p.inp["interact"] = int(m.time * 30.0) % 2 == 0     # (a tap per item: one press, one pickup)
		"sec", "shoot", "gkey", "summon", "kin", "hook", "ult":
			_fight(m, tu, goto)
		"steal":
			var at := tu.goal("steal")
			if at != Vector3.INF:
				goto.call(at, 1.0)
				p.inp["interact"] = Vector2(at.x - p.pos.x, at.z - p.pos.z).length() < 1.6
		"ranks":
			for slot in ["sec", "dash", "kin"]:
				p.level_slot(slot)
		"wayout", "uplink", "defend", "extract":
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
	var sid := tu.id()
	var best: Mob = tu.camps.nearest("sentinel" if sid == "hook" else "")
	if best == null:
		best = tu.camps.nearest()
	if sid == "sec":
		_rmb(m, tu)
	if best == null:
		return
	p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
	var melee: bool = p.wpn.get("melee", false)
	var reach := 1.6 if melee else 3.0
	if sid == "hook" and not tu.flag:
		reach = 9.0
	if p.flat_dist(best) > reach: goto.call(best.pos)
	match sid:
		"shoot": p.inp["fire"] = _fire_key(m)
		"gkey":
			if fmod(m.time, 1.5) < Match.DT and p.kin:
				KinCommand.tap(p)       # a tap sends it when it is beside you, a tap calls it back when it is out
			p.inp["fire"] = tu.flag and _fire_key(m)
		"summon":
			var s: KinSummon = p.kin.summon if p.kin else null
			if s and not s.out() and s.cd <= 0.0 and tu.t > 1.0:
				KinSummon.press(p)       # (as the Summon key does; again each time its ring fills)
			p.inp["fire"] = tu.wb.seen_out and _fire_key(m)
		"kin":
			p.inp["sig"] = int(m.time * 2.0) % 2 == 0
			p.inp["fire"] = tu.flag and _fire_key(m)
		"hook":
			p.inp["gear1"] = not tu.flag and p.flat_dist(best) < 9.5 and int(m.time * 10.0) % 2 == 0
			p.inp["fire"] = tu.flag and _fire_key(m)
		"ult":
			p.inp["ult"] = not tu.flag and int(m.time * 10.0) % 2 == 0
			p.inp["fire"] = tu.flag and _fire_key(m)
			p.inp["sig"] = tu.flag and int(m.time * 2.0) % 2 == 0

## The attack key as a player works each weapon: a bow is drawn to its first stage then let go, a blade is
## tapped (a hold would charge it), a gun is held.
static func _fire_key(m: Match) -> bool:
	var p := m.player
	var st: Array = p.wpn.get("draw", [])
	if not st.is_empty():
		return p.draw_t < float((st[0] as Array)[0]) + 0.05
	if p.wpn.has("charge_time"):
		return fmod(m.time, 0.6) < 0.1      # a charged blade acts on release: tap it
	if p.wpn.get("melee", false):
		return fmod(m.time, 0.5) < 0.1
	return true

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
		"wayout":
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
