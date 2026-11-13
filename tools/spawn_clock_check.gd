extends RefCounted
## --spawn-clock-check: the spawns docs/SPAWNS.md made fixed and telegraphed. The Glimmerkin and the
## Watcher (TimedSpawns) are called out at warn_s and 10 s before they appear, then appear at their
## fixed spot on time, and the Glimmerkin's spot is an outer-island wild spot that the match's dice
## don't move; an uplink's monster waves come only out of its fixed wave posts, which glow first; a
## lair's dial-miss guards climb out of the same posts every time. Never touches the save.

var bad := 0


func ok(cond: bool, what: String) -> void:
	print("SPAWNCLOCK %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(main: Node) -> void:
	var m := Match.new()
	main.add_child(m)
	m.start({"teams": 2, "squad": 1, "tier": 0, "seed": 77, "no_drop": true, "autoplay": true})
	m.set_process(false)
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
		h.max_hp = 5000.0
		h.hp = 5000.0
	m.step(Match.DT)
	_timed(m)
	_waves(m)
	_guards(m)
	m.over = true
	print("SPAWNCLOCK DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


func _timed(m: Match) -> void:
	ok(m.timed != null and m.timed.list.size() == 2, "the Glimmerkin and the Watcher are both on the clock")
	if m.timed == null:
		return
	var g: Vector3 = m.timed.glimmer_spot()
	m.rng.randf()
	ok(
		m.timed.glimmer_spot() == g and g in m.world.wild_spots and m.world.island_of(g.x, g.z) >= 1,
		"the Glimmerkin's spot is a fixed outer-island wild spot the match dice don't move"
	)
	var warn := float(Content.rules("timed_spawns")["glimmer"]["warn_s"])
	var by_time: Array = m.timed.list.duplicate()
	by_time.sort_custom(func(x, y): return float(x["at"]) < float(y["at"]))
	for e: Dictionary in by_time:
		var at := float(e["at"])
		var pos: Vector3 = e["pos"]
		var pinged := func(): return m.pings.filter(func(p): return (p["pos"] as Vector3).distance_to(pos) < 0.1).size()
		var steps := [[at - warn - 1.0, 0], [at - warn + 0.1, 1], [at - 9.9, 2]]
		var calls_ok := true
		for s in steps:
			m.time = s[0]
			m.timed.tick()
			calls_ok = calls_ok and pinged.call() == s[1]
		ok(calls_ok, "%s: no callout before %.0f s, one at %.0f s and one at 10 s" % [e["id"], warn, warn])
		m.time = at + 0.01
		m.timed.tick()
		var kind := "glimmer" if e["id"] == "glimmer" else "warden"
		var there := m.mobs.any(func(mb): return mb.mkind == kind and not mb.dead and mb.flat_dist(pos) < 2.0)
		ok(there, "%s: appears at its spot on time" % e["id"])


func _waves(m: Match) -> void:
	var outs: Array = m.exits.of_kind("outpost")
	ok(not outs.is_empty(), "the map has an uplink outpost")
	if outs.is_empty():
		return
	var up: Dictionary = outs[0]
	var posts: Array = m.exits.wave_posts(up)
	ok(posts.size() >= 3 and posts == m.exits.wave_posts(up), "the outpost has %d fixed wave posts" % posts.size())
	var hunter: Hunter = m.hunters[0]
	var yard: Vector3 = up["pos"]
	m.time = maxf(m.time, float(up.get("open_at", 0.0)) + 1.0)
	m.exits._start(up, hunter)
	var radial0: int = m.fx.radial
	var glowed := false
	for _i in int((Exits.WAVE_WARN + 0.5) / Match.DT):
		hunter.teleport(yard)
		m.step(Match.DT)
		glowed = glowed or (int(up["waves"]) == 0 and m.fx.radial >= radial0 + posts.size())
		if int(up["waves"]) > 0:
			break  # the first wave is out: check where it stood up before it moves
	ok(glowed, "the wave posts glow before the first wave")
	var wave := m.mobs.filter(func(mb): return int(mb.get_meta("exit", -1)) == int(up["i"]))
	var on_posts := wave.all(func(mb): return posts.any(func(p): return mb.flat_dist(p) < 0.5))
	ok(not wave.is_empty() and on_posts, "all %d wave monsters climbed out of the posts" % wave.size())


func _guards(m: Match) -> void:
	if m.lairs == null or m.lairs.list.is_empty():
		ok(false, "the map has a lair")
		return
	var lair: Dictionary = m.lairs.list[0]
	m.lairs.activate(lair)
	var call_guards := func() -> Array:
		var n0 := (lair["guards"] as Array).size()
		m.lairs._call_guards(lair, lair["dial"], 2)
		var made: Array = (lair["guards"] as Array).slice(n0)
		var at := made.map(func(g): return g.pos)
		for g in made:
			g.dead = true
			lair["guards"].erase(g)
		return at
	var a: Array = call_guards.call()
	var b: Array = call_guards.call()
	ok(a.size() == 2 and a == b, "dial-miss guards come out of the same posts every time")
