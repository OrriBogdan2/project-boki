extends RefCounted
## --camps-check: the fixed camps (Camps, docs/CAMPS.md). Every camp spot is up with its monsters, the
## monsters come from the spot alone (not Match.rng), a camp's XP is what its monsters pay and the
## last hit's squad gets it, a cleared camp comes back on its clock with nobody near, and a bot goes
## to the nearest standing camp it is strong enough for. Never touches the save.

var bad := 0
var m: Match


func ok(cond: bool, what: String) -> void:
	print("CAMPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func _spot(h: Hunter, at: Vector3) -> void:
	h.teleport(Vector3(at.x, m.world.ground_at(at.x, at.z), at.z))
	h.vel = Vector3.ZERO


func _kill_all(cp: Dictionary, by: Hunter) -> void:
	for mb in cp["mobs"]:
		mb.hurt(mb.max_hp * 2.0, by, {})


func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	m = Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 21, "no_drop": true})
	m.set_process(false)
	var me: Hunter = m.player
	me.set_arch("")
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var cps: Array = m.camps.list
	# ---- 1. every camp spot is up
	ok(not cps.is_empty() and cps.size() == m.world.camp_spots.size(), "one camp per camp spot (%d)" % cps.size())
	var all_up := true
	for cp in cps:
		all_up = all_up and cp["mobs"].size() == cp["comp"].size() and cp["xp"] > 0.0
	ok(all_up, "each camp stands with its monsters and pays XP")
	# ---- 2. the monsters come from the spot alone
	for k in 40:
		m.rng.randf()
	if m.biomes:
		for k in 40:
			m.biomes.rng.randf()
	var fresh := Camps.new(m)
	var same := true
	for cp in cps:
		var spot := {"pos": cp["pos"], "kind": cp["size"]}
		same = same and fresh._comp(spot, Camps.dice_at(cp["pos"])) == cp["comp"]
	ok(same, "a camp's monsters are the same whatever Match.rng has rolled")
	# ---- 3. a clear pays the camp's XP to the last hit's squad
	var cp: Dictionary = cps[0]
	var foes: Array = m.hunters.filter(func(x): return x.team != me.team)
	for h in foes:
		_spot(h, m.world.spawns[-1])
	_spot(me, cp["pos"])
	me.xp = 0.0
	_kill_all(cp, me)
	ok(is_equal_approx(me.xp, cp["xp"]), "the camp's XP is paid on its kills (%.1f of %.1f)" % [me.xp, cp["xp"]])
	# ---- 4. it comes back once, on its clock, with nobody near
	ok(m.camps.comeback() == 0 and float(cp["cleared_at"]) > -1e8, "the clear is noted")
	m.time += float(m.camps.cfg["back_s"]) + 1.0
	ok(m.camps.comeback() == 0, "nobody near: it waits while a Hunter stands in it")
	_spot(me, m.world.spawns[-1])
	ok(m.camps.comeback() == 1 and not m.camps._all_dead(cp), "it returns after back_s with nobody near")
	ok(m.camps.comeback() == 0, "and only once")
	# ---- 5. bots farm what they can beat
	var by_size := {"light": [], "normal": [], "heavy": []}
	for c in cps:
		by_size[c["size"]].append(c)
	for c in cps:
		if c["size"] != "heavy":
			c["cleared_at"] = 0.0
	if not by_size["heavy"].is_empty():
		me.lvl = 1
		ok(BotCamps.goal(m, me) == Vector3.INF, "a level 1 bot passes a Great Camp")
		me.lvl = 4
		ok(by_size["heavy"].any(func(c): return c["pos"] == BotCamps.goal(m, me)), "a level 4 bot goes to it")
	for c in by_size["light"]:
		c["cleared_at"] = -1e9
	if not by_size["light"].is_empty():
		me.lvl = 1
		var g := BotCamps.goal(m, me)
		ok(by_size["light"].any(func(c): return c["pos"] == g), "a level 1 bot goes to a Small Camp")
	print("CAMPS done, %d fail" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)
