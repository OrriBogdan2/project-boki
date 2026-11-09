class_name TutorialDrive
extends RefCounted
## Test driver: plays the tutorial course by itself so the whole flow can be checked headless
## (--tutorial --tut-test, and the teammate check).

static var last_step := -1
static var still_t := 0.0     # s the player has stood in one place while walking
static var last_pos := Vector3.INF
static var recalled_once := false     # the summon beat: the first window is called back early, as a hasty player would

static func drive(m: Match) -> void:
	var tu: Tutorial = m.tut
	tu.ack()
	tu.pell.test_skip()
	if tu.step != last_step:
		var live := m.mobs.filter(func(x): return not x.dead).size()
		print("TUT step ", tu.step, " ", tu.id(), " t=", snapped(m.time, 0.1), " mobs=", live)
		last_step = tu.step
	var p := m.player
	for k in ["fire", "glide", "interact", "crouch", "sec", "sig", "jump", "dash"]:
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
		"shoot", "sig", "fight":
			_fight(m, tu, goto)
		"summon":
			_summon(m, tu)
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
	if sid == "fight" and p.kin and p.kin.summon and not p.kin.summon.out() and p.kin.summon.cd <= 0.0:
		KinSummon.press(p)      # (the ring is bright: summon again)
	if best == null:
		return
	p.inp["aim"] = best.pos + Vector3(0, 0.9, 0)
	if p.flat_dist(best) > 3.0: goto.call(best.pos)
	if sid in ["shoot", "fight"]: p.inp["fire"] = true
	if sid in ["sig", "fight"]: p.inp["sig"] = int(m.time * 2.0) % 2 == 0

## The Summon key: out of the wisp whenever it is ready (the first window, once, is called back early).
static func _summon(m: Match, tu: Tutorial) -> void:
	var s: KinSummon = m.player.kin.summon
	if s.left > 0.0 and not recalled_once and tu.sm.phase == TutorialSummon.OUT and s.left < s.dur - 1.0:
		recalled_once = true
		KinSummon.press(m.player)
	elif not s.out() and s.cd <= 0.0:
		KinSummon.press(m.player)

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
