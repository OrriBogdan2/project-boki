extends RefCounted
## --revive-check: a bot squadmate goes and picks up a downed player first. A downed player with a
## rival standing at medium range: an ally bot ~12 m away has to reach them and finish the revive in
## time (open ground; a wall in the way; the player down by the island's edge; the player down on
## the far side of a terrace step). And with a rival behind a wall, the bot never fires without a
## clear shot. Prints PASS/FAIL.

var bad := 0
var m: Match
var main: Node

func ok(cond: bool, what: String) -> void:
	print("REVIVE %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func _fresh(seed := 77) -> void:
	if m: m.queue_free()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": seed, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		# no kin: a kin pulling its owner up would do the revive for the bot
		for kk in [h.kin, h.kin2]:
			if kk: m.kins.erase(kk); kk.queue_free()
		h.kin = null; h.kin2 = null

func _put(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO

## Open ground: no void or blocks within r of p, all at one height.
func _roomy(p: Vector3, r: int) -> bool:
	var w := m.world
	for dx in range(-r, r + 1):
		for dz in range(-r, r + 1):
			if w.is_void(p.x + dx, p.z + dz) or w.is_block(p.x + dx, p.z + dz) or absf(w.ground_at(p.x + dx, p.z + dz) - w.ground_at(p.x, p.z)) > 0.3:
				return false
	return true

## Runs a revive: the player is knocked at `at`, the bot starts at `from`, a rival stands at `foe_at`.
func _case(name: String, at: Vector3, from: Vector3, foe_at: Vector3, limit: float) -> void:
	var p: Hunter = m.player
	var mates: Array = m.hunters.filter(func(x): return x.team == p.team and x != p)
	var bot: Hunter = mates[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != p.team)
	var foe: Hunter = foes[0]
	# park the rest far off
	for i in mates.size():
		if i > 0: _put(mates[i], m.world.random_ground()); mates[i].ctrl = "idle"
	for i in foes.size():
		if i > 0:
			var far := m.world.random_ground()
			for k in 50:
				if far.distance_to(at) > 40.0: break
				far = m.world.random_ground()
			_put(foes[i], far)
	_put(p, at)
	_put(bot, from)
	_put(foe, foe_at)
	foe.max_hp = 1e6; foe.hp = 1e6      # it soaks the bot's shots, so the test isn't won by killing it
	foe.ctrl = "idle"
	if p.downed: m.revive_hunter(p, null)
	m.knock(p, foe, {})
	p.ctrl = "idle"
	p.down_hp = 1e6       # no bleeding out mid-test
	bot.ctrl = "bot"
	bot.ai = m.bot_brain.new_mind(m.rng, 0.6)
	bot.ai["think"] = 0.0
	var t := 0.0
	var hops := 0
	var was_air := false
	var reached := -1.0
	while t < limit and p.downed:
		m.step(Match.DT); t += Match.DT
		var jumped := bot.vel.y > Hunter.JUMP_V * 0.85 and bot.pad.is_empty() and not bot.mantling()      # pressing jump, not a ledge rise
		if jumped and not was_air: hops += 1
		was_air = jumped
		if reached < 0.0 and bot.flat_dist(p) < Life.R["revive_radius"]: reached = t
	ok(not p.downed, "%s: revived in %.1fs (reached at %.1fs, %d hops, start %.1fm, rival %.1fm)%s" % [name, t, reached, hops, Vector2(from.x - at.x, from.z - at.z).length(), Vector2(foe_at.x - at.x, foe_at.z - at.z).length(), "" if not p.downed else " bot at %s, player at %s" % [bot.pos.snapped(Vector3(0.1, 0.1, 0.1)), p.pos.snapped(Vector3(0.1, 0.1, 0.1))]])
	bot.ctrl = "idle"; bot.inp["move"] = Vector2.ZERO; bot.inp["fire"] = false

## The first time the local player is downed in a real match, one hint card (content/rules/tutorial.json
## "tips"), even with no Boki out; the same save is never told again; the tutorial never shows it.
func _first_downed_tip() -> void:
	var tip: String = Content.rules("tutorial")["tips"]["down"]
	Save.d["tutorial"].erase("down_wisp")
	for case_name in ["real match", "second time on the same save", "tutorial"]:
		if case_name == "tutorial":
			Save.d["tutorial"].erase("down_wisp")
		if m: m.queue_free()
		m = Match.new()
		main.add_child(m)
		var opts := {"teams": 2, "squad": 3, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true}
		opts["tutorial"] = case_name == "tutorial"
		m.start(opts)
		m.set_process(false)
		var p: Hunter = m.player
		if p.kin:
			m.kins.erase(p.kin)
			p.kin.queue_free()
			p.kin = null
		m._tip_t = 2.0
		m._tips()
		m.hud.msgs.clear()
		ok(not (m.hud.msgs.texts().has(tip)), "%s: nothing before the fall" % case_name)
		p.downed = true
		m._tips()
		var lane: MsgLane = m.hud.msgs
		var shown := lane.count() == 1 and lane.texts().has(tip)
		ok(shown == (case_name == "real match"), "%s: card %s" % [case_name, "shown" if shown else "not shown"])
		m.hud.msgs.clear()
		m._tips()
		ok(m.hud.msgs.count() == 0, "%s: no repeat while still down" % case_name)
	ok(not tip.contains("%") and tip.length() < 120, "the card is one short plain line")

func run(mn: Node) -> void:
	main = mn
	Save.no_write = true
	_fresh()
	var w := m.world
	# ---- 1. open ground
	var home := Vector3.INF
	for k in 3000:
		var g := w.random_ground()
		if _roomy(g, 6): home = g; break
	ok(home != Vector3.INF, "found open ground")
	if home != Vector3.INF:
		_case("open ground", home, home + Vector3(6, 0, 0), home + Vector3(-4, 0, 5), 16.0)
	# ---- 2. a wall between the bot and the player
	_fresh(); w = m.world
	var wall := Vector3.INF; var wdir := Vector3.ZERO
	for k in 6000:
		var g := w.random_ground(-1, false)
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			# player just this side of a block, the bot 7 m behind the block on open ground
			if w.is_block(g.x + d.x * 1.0, g.z + d.z * 1.0) and not w.is_block(g.x, g.z) and not w.is_void(g.x, g.z):
				for far in [7.0, 6.0, 5.0, 4.0, 3.0]:
					var b: Vector3 = g + d * far
					if not w.is_void(b.x, b.z) and not w.is_block(b.x, b.z) and absf(w.ground_at(b.x, b.z) - w.ground_at(g.x, g.z)) < 0.9 and w.island_of(b.x, b.z) == w.island_of(g.x, g.z):
						wall = g; wdir = d * far; break
				if wall != Vector3.INF: break
		if wall != Vector3.INF: break
	ok(wall != Vector3.INF, "found a wall")
	if wall != Vector3.INF:
		var wn := wdir.normalized()
		_case("wall in the way (%.0fm through it)" % wdir.length(), wall, wall + wdir, wall - wn * 6.0 + Vector3(wn.z, 0, wn.x) * 4.0, 22.0)
	# ---- 3. down by the island's edge
	_fresh(); w = m.world
	var edge := Vector3.INF; var edir := Vector3.ZERO
	for k in 6000:
		var g := w.random_ground()
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			if w.is_void(g.x + d.x * 0.9, g.z + d.z * 0.9) and not w.is_void(g.x, g.z) and not w.is_block(g.x, g.z):
				var b: Vector3 = g - d * 10.0
				if not w.is_void(b.x, b.z) and not w.is_block(b.x, b.z) and w.island_of(b.x, b.z) == w.island_of(g.x, g.z) and absf(w.ground_at(b.x, b.z) - w.ground_at(g.x, g.z)) < 1.0:
					edge = g; edir = d; break
		if edge != Vector3.INF: break
	ok(edge != Vector3.INF, "found an edge")
	if edge != Vector3.INF:
		_case("by the edge", edge, edge - edir * 10.0, edge - edir * 4.0 + Vector3(edir.z, 0, edir.x) * 7.0, 20.0)
	# ---- 4. up a terrace step (a ledge between them)
	_fresh(); w = m.world
	var step := Vector3.INF; var sdir := Vector3.ZERO
	for k in 8000:
		var g := w.random_ground()
		for d in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var b: Vector3 = g + d * 6.0
			if not w.is_void(b.x, b.z) and not w.is_block(b.x, b.z) and not w.is_block(g.x, g.z) and w.island_of(b.x, b.z) == w.island_of(g.x, g.z):
				var dh := w.ground_at(g.x, g.z) - w.ground_at(b.x, b.z)
				if dh > 0.7 and dh < 1.7:
					step = g; sdir = d; break
		if step != Vector3.INF: break
	ok(step != Vector3.INF, "found a terrace step")
	if step != Vector3.INF:
		_case("up a ledge", step, step + sdir * 6.0, step + sdir * 2.0 + Vector3(sdir.z, 0, sdir.x) * 8.0, 24.0)
	# ---- 5. a rival close by but out of sight (behind a rock; up a ledge): the bot works round to a
	# clear shot instead of hopping at the obstacle and firing into it
	for variant in ["rock", "ledge"]:
		var bw := Vector3.INF; var bd := Vector3.ZERO
		_fresh(); w = m.world
		if variant == "ledge":
			# the maps rarely stack two terraces right next to each other: raise a shelf two
			# terraces (1.6 m) high on open ground, a couple of metres from where the bot stands
			for k in 3000:
				var g := w.random_ground()
				if _roomy(g, 6):
					for x in range(int(g.x) + 2, int(g.x) + 6):
						for z in range(int(g.z) - 3, int(g.z) + 4):
							w.level[w.idx(x, z)] += 2
					bw = g; bd = Vector3(3, 0, 0)
					break
		for k in (0 if bw != Vector3.INF else 8000):

			var g := w.random_ground(-1, false)
			if w.is_block(g.x, g.z) or w.is_void(g.x, g.z): continue
			for dd in [Vector3(3, 0, 0), Vector3(-3, 0, 0), Vector3(0, 0, 3), Vector3(0, 0, -3), Vector3(2.2, 0, 0), Vector3(-2.2, 0, 0), Vector3(0, 0, 2.2), Vector3(0, 0, -2.2)]:
				var d: Vector3 = dd / dd.length()
				var b: Vector3 = g + dd
				if w.is_void(b.x, b.z) or w.is_block(b.x, b.z) or w.island_of(b.x, b.z) != w.island_of(g.x, g.z):
					continue
				var dh := w.ground_at(b.x, b.z) - w.ground_at(g.x, g.z)
				if variant == "rock" and dd.length() > 2.9 and w.is_block(g.x + d.x * 1.5, g.z + d.z * 1.5) and absf(dh) < 0.5:
					bw = g; bd = dd; break
				if variant == "ledge" and dh > 1.2 and dh < 2.6 and not w.is_block(g.x + d.x * 1.1, g.z + d.z * 1.1):
					bw = g; bd = dd; break
			if bw != Vector3.INF: break
		ok(bw != Vector3.INF, "found a rival spot out of sight (%s)" % variant)
		if bw == Vector3.INF: continue
		var p: Hunter = m.player
		var bot: Hunter = m.hunters.filter(func(x): return x.team == p.team and x != p)[0]
		var foe: Hunter = m.hunters.filter(func(x): return x.team != p.team)[0]
		for h in m.hunters:
			if h != bot and h != foe:
				var far := w.random_ground()
				for k in 50:
					if far.distance_to(bw) > 40.0: break
					far = w.random_ground()
				_put(h, far)
		_put(bot, bw); _put(foe, bw + bd)
		foe.max_hp = 1e6; foe.hp = 1e6
		bot.ctrl = "bot"
		bot.ai = m.bot_brain.new_mind(m.rng, 0.8)
		bot.ai["think"] = 0.0
		bot.last_hit_by = foe       # provoked: it wants this fight
		var blind := 0; var fired := 0; var frames := 0; var aimed := 0; var hops := 0; var was_air := false
		var t := 0.0
		while t < 8.0:
			# (where they both were when the bot decided: it thinks at the start of the step)
			var bp0 := bot.pos
			var fp0 := foe.pos
			m.step(Match.DT); t += Match.DT; frames += 1
			# a hop is the bot pressing jump (a jump starts at Hunter.JUMP_V); mantles (a ledge pull, on
			# a pad) and stepping up a terrace aren't hopping at anything
			var jumped := bot.vel.y > Hunter.JUMP_V * 0.85 and bot.pad.is_empty() and not bot.mantling()
			if jumped and not was_air: hops += 1
			was_air = jumped
			if bot.ai.get("tgt") == foe: aimed += 1
			if bot.inp.get("fire", false) and bot.ai.get("tgt") == foe:
				fired += 1
				# (judged on the map itself: a rock on the line, or ground above the shot, which runs
				# from the bot's eye to the rival's chest)
				var dl := Vector2(fp0.x - bp0.x, fp0.z - bp0.z)
				for k in 20:
					var f := (k + 0.5) / 20.0
					var q := Vector2(bp0.x, bp0.z) + dl * f
					if w.is_block(q.x, q.y) or w.ground_at(q.x, q.y) > lerpf(bp0.y + 0.95, fp0.y + 0.9, f):
						blind += 1
						if blind <= 3: print("REVIVE  blind shot: bot %s foe %s grounded %s" % [bp0.snapped(Vector3(0.01, 0.01, 0.01)), fp0.snapped(Vector3(0.01, 0.01, 0.01)), bot.grounded])
						break
		ok(aimed > 0 and blind == 0 and hops <= 3, "%s: no shots without a clear line, no hopping at it (after the rival %d of %d frames, %d firing, %d blind, %d hops)" % [variant, aimed, frames, fired, blind, hops])
	_first_downed_tip()
	print("REVIVE CHECK %s" % ("PASS" if bad == 0 else "FAIL (%d)" % bad))
	main.get_tree().quit()
