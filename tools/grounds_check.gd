extends RefCounted
## --grounds-check: the Training Area (the --arena map). The floor is at least 3x the old Arena's, five sky
## perches are joined to it by pads and glides, every Hunter, Boki, glove / armor / boot and belt item has a
## pedestal that works, every Hunter can be spawned as a sparring bot, the duel ring is there, and a fall off the
## map brings you home. The Movement Fields south of it (dash lanes, tier steps, a cliff, a glide jump-off to
## Cloud Isle) are checked too. Prints GROUNDSCHECK PASS/FAIL.

const OLD_FLOOR_TILES := 616  # the old Arena's floor circle (r 14 tiles), the area to beat 3x over
const DT := 1.0 / 60.0

var main: Node
var fails := 0
var n := 0


func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("GROUNDSCHECK %-46s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond:
		fails += 1


func step(m: Match, secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT


func run(main_node: Node) -> void:
	main = main_node
	var m := Match.new()
	main.add_child(m)
	await m.start(Match.arena_opts("gunslinger"))
	m.set_process(false)
	var a: Arena = m.arena
	var p: Hunter = m.player
	var g: Grounds = a.grounds
	ok(
		"grounds built on the arena map",
		g != null and m.world.layout_id == "arena" and not g.stations.is_empty()
	)
	_map(m)
	_fields(m)
	_counts(g)
	_sites(m, g)
	step(m, 0.3)
	_hints(m, g)
	_use_all(m, g)
	_rides(m)
	_duel_and_fall(m, g)
	print("GROUNDSCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()
	if p == null:
		fails += 1


func _map(m: Match) -> void:
	var w: World = m.world
	var floor_tiles := 0
	var perches := 0
	for isl in w.islands:
		if String(isl.get("id", "")) == "floor":
			floor_tiles = (isl["cells"] as Array).size()
		if bool(isl.get("perch", false)):
			perches += 1
	var info := "%d tiles vs %d" % [floor_tiles, OLD_FLOOR_TILES]
	ok("floor is at least 3x the old arena", floor_tiles >= 3 * OLD_FLOOR_TILES, info)
	ok("six sky perches (five stations, Cloud Isle)", perches == 6, "%d" % perches)
	ok("training room walls kept (3 dummies)", m.arena.dummies.size() == 3)


## The Movement Fields: two long flat dash lanes, tier steps you walk up, a cliff of 2 to 5 terraces, and a stair up to
## the glide jump-off whose route lands on Cloud Isle.
func _fields(m: Match) -> void:
	var w: World = m.world
	var p_v: Hunter = m.player
	var lanes: Array = Grounds.data().get("lanes", [])
	var shortest := 1e9
	for lane in lanes:
		var a := Vector2(float(lane[0]), float(lane[1]))
		var b := Vector2(float(lane[2]), float(lane[3]))
		var flat := 0.0
		for d in int(a.distance_to(b)):
			var p := a.lerp(b, float(d) / a.distance_to(b))
			if w.is_void(p.x, p.y) or w.ground_at(p.x, p.y) > World.STEP:
				break
			flat += 1.0
		shortest = minf(shortest, flat)
	ok(
		"two dash lanes, each 90 m of flat ground",
		lanes.size() == 2 and shortest >= 90.0,
		"shortest %.0f m" % shortest
	)
	var tiles := 0
	for isl in w.islands:
		if String(isl.get("id", "")) in ["floor", "bench"]:
			tiles += (isl["cells"] as Array).size()
	ok(
		"open ground with the fields is at least 3x the old arena",
		tiles >= 3 * OLD_FLOOR_TILES,
		"%d tiles" % tiles
	)
	var faces: Array = []
	for z in [146.5, 150.5, 154.5, 158.5]:
		faces.append(roundi(w.ground_at(48.5, z) / World.LEVEL))
	ok("cliff faces of 2, 3, 4 and 5 terraces", faces == [2, 3, 4, 5], "%s" % [faces])
	p_v.teleport(Vector3(74.5, 0.0, 140.5))
	p_v.vel = Vector3.ZERO
	var top := _walk_up(m, p_v, Vector2(1, 0), 8.0)
	ok("tier steps: walking east climbs 6 terraces", top > 4.7, "top %.1f m" % top)
	var jump_off := false
	for l in w.links:
		if l.get("glide", false) and String(w.islands[l["to"]]["id"]) == "cloud":
			jump_off = l["take"].y > 10.0
	ok("a glide jump-off over 10 m up reaches Cloud Isle", jump_off)
	p_v.teleport(m.arena.home)
	p_v.vel = Vector3.ZERO
	p_v.inp["move"] = Vector2.ZERO


## Hold `move` until the player stands higher than the 6th terrace or `secs` pass; the highest ground reached.
func _walk_up(m: Match, p: Hunter, move: Vector2, secs: float) -> float:
	var top := 0.0
	var t := 0.0
	while t < secs and top < 6.0 * World.LEVEL:
		p.inp["move"] = move
		m.step(DT)
		t += DT
		top = maxf(top, p.pos.y)
	return top


## Ride every pad up and every glide route down: each must land you on its island.
func _rides(m: Match) -> void:
	var w: World = m.world
	var p: Hunter = m.player
	var bad: Array = []
	for pd in w.pads:
		p.teleport(pd["pos"])
		p.vel = Vector3.ZERO
		_settle(m, p, Vector2.ZERO, 4.0)
		if w.island_id(p.pos.x, p.pos.z) != String(w.islands[pd["to"]]["id"]):
			bad.append("pad to %s" % w.islands[pd["to"]]["id"])
	ok("every pad lands you on its perch", bad.is_empty() and w.pads.size() >= 5, " ".join(bad))
	bad.clear()
	var glides := 0
	for l in w.links:
		if not l.get("glide", false):
			continue
		glides += 1
		var take: Vector3 = l["take"]
		var land: Vector3 = l["land"]
		var dir := Vector2(land.x - take.x, land.z - take.z).normalized()
		p.teleport(take - Vector3(dir.x, 0, dir.y) * 1.5)
		p.vel = Vector3.ZERO
		_settle(m, p, dir, 20.0)
		var to := String(w.islands[l["to"]]["id"])
		if w.island_id(p.pos.x, p.pos.z) != to:
			bad.append(
				"%s>%s (ended %.0f,%.0f)" % [w.islands[l["from"]]["id"], to, p.pos.x, p.pos.z]
			)
	var info := "%d routes %s" % [glides, " ".join(bad)]
	ok("every glide route lands you on its island", bad.is_empty() and glides >= 5, info)
	p.teleport(m.arena.home)
	p.vel = Vector3.ZERO
	p.inp["move"] = Vector2.ZERO
	p.inp["glide"] = false


## Hold `move` (and the glider once airborne) until you are back on the ground, up to `secs`.
func _settle(m: Match, p: Hunter, move: Vector2, secs: float) -> void:
	var t := 0.0
	var flew := false
	while t < secs:
		p.inp["move"] = move
		p.inp["glide"] = not p.grounded
		m.step(DT)
		t += DT
		flew = flew or not p.grounded
		if flew and p.grounded and p.pad.is_empty() and t > 0.5:
			return


func _counts(g: Grounds) -> void:
	var by := {}
	for s in g.stations:
		by[s["kind"]] = int(by.get(s["kind"], 0)) + 1
	ok("a pedestal per Hunter", by.get("arch", 0) == Arch.ids().size(), "%d" % by.get("arch", 0))
	ok("a pedestal per Boki", by.get("kin", 0) == KinLib.kin_ids().size(), "%d" % by.get("kin", 0))
	ok("a pedestal per gear piece", by.get("gear", 0) == Gear.ALL.size(), "%d" % by.get("gear", 0))
	ok(
		"a pedestal per belt item",
		by.get("item", 0) == UtilityBelt.stock_ids().size(),
		"%d" % by.get("item", 0)
	)
	ok(
		"a bot spawner per Hunter (+ clear)",
		by.get("bot", 0) == Arch.ids().size() + 1,
		"%d" % by.get("bot", 0)
	)


## Every pedestal stands on a perch (not in the void), apart from its neighbours, its name hidden from afar.
func _sites(m: Match, g: Grounds) -> void:
	var off := 0
	var tight := 99.0
	var shown := 0
	for i in g.stations.size():
		var s: Dictionary = g.stations[i]
		var at: Vector3 = s["at"]
		if m.world.island_id(at.x, at.z) in ["", "floor"] or m.world.is_void(at.x, at.z):
			off += 1
		if (s["label"] as Label3D).visible:
			shown += 1
		for j in range(i + 1, g.stations.size()):
			tight = minf(tight, at.distance_to((g.stations[j] as Dictionary)["at"]))
	ok("every pedestal stands on a perch", off == 0, "%d off" % off)
	ok("pedestals are 1.5m+ apart", tight >= 1.5, "closest %.2f" % tight)
	ok("no name drawn from afar", shown == 0, "%d shown" % shown)


func _use_all(m: Match, g: Grounds) -> void:
	var p: Hunter = m.player
	var a: Arena = m.arena
	var bad: Array = []
	for i in g.stations.size():
		var s: Dictionary = g.stations[i]
		var id := String(s["id"])
		var good := true
		g.use(i)
		match String(s["kind"]):
			"arch":
				good = p.arch == id
			"kin":
				good = p.kin != null and (p.kin as Kin).species == id
			"gear":
				good = _worn(p, id)
			"item":
				good = UtilityBelt.count(p, id) > 0
			"bot":
				good = _bot_ok(a, id)
		if not good:
			bad.append("%s:%s" % [s["kind"], id])
	ok("every pedestal does its thing", bad.is_empty(), "bad: %s" % ", ".join(bad.slice(0, 6)))


func _bot_ok(a: Arena, id: String) -> bool:
	if id == "clear":
		return a.bot == null
	return a.bot != null and a.bot.arch == id and a.bot_mode != "off"


func _worn(p: Hunter, id: String) -> bool:
	for g in p.gear:
		if not (g as Dictionary).is_empty() and String(g["id"]) == id:
			return true
	return false


func _duel_and_fall(m: Match, g: Grounds) -> void:
	var p: Hunter = m.player
	ok(
		"duel pad on the floor",
		m.duel_pad != Vector3.INF and m.world.island_id(m.duel_pad.x, m.duel_pad.z) == "floor"
	)
	p.teleport(Vector3(60, -20, 25))  # off the map
	g.tick(DT)
	ok(
		"a faller is brought home",
		p.flat_dist(m.arena.home) < 1.0 and p.pos.y > -1.0,
		"at %s" % p.pos
	)


## First-time hints: each pedestal island and the dash lanes say one line (the live key caps, the Training Grounds'
## own words) the first time you come near, and never again: not on a second visit, not in a later match.
func _hints(m: Match, g: Grounds) -> void:
	var p: Hunter = m.player
	var tut: Dictionary = Save.d["tutorial"]
	var spots := {}
	for s in g.stations:
		if not spots.has(s["kind"]):
			spots[s["kind"]] = s["at"]
	var lane: Array = Grounds.data()["lanes"][0]
	spots[GroundsHints.LANE_ID] = Vector3(float(lane[0]), 0.0, float(lane[1]) + 2.0)
	for id in spots:
		tut.erase(GroundsHints.KEY_PREFIX + id)
	g.hints = GroundsHints.new(m)
	var lines := {}
	var bad: Array = []
	for id in spots:
		var want := GroundsHints.line(id)
		lines[want] = true
		var at: Vector3 = spots[id]
		at.y = m.world.ground_at(at.x, at.z)
		m.hud.msgs.clear()
		p.teleport(m.arena.home)
		step(m, 0.1)
		if m.hud.msgs.texts().has(want):
			bad.append(id + " far")
		p.teleport(at)
		step(m, 0.1)
		if m.hud.msgs.texts().count(want) != 1 or not tut.get(GroundsHints.KEY_PREFIX + id, false):
			bad.append(id + " first")
		m.hud.msgs.clear()
		step(m, 0.5)
		p.teleport(m.arena.home)
		step(m, 0.1)
		p.teleport(at)
		step(m, 0.1)
		if m.hud.msgs.texts().has(want):
			bad.append(id + " twice")
	ok("each station says its line once, near it", bad.is_empty(), " ".join(bad))
	var plain := lines.keys().all(
		func(t):
			return (
				t.contains(Settings.key_cap("interact"))
				and not t.contains("Arena")
				and not t.contains("Training Area")
			)
	)
	ok(
		"six distinct lines with the live keys, no old names",
		lines.size() == spots.size() and plain
	)
	g.hints = GroundsHints.new(m)
	m.hud.msgs.clear()
	p.teleport(spots["arch"])
	step(m, 0.1)
	ok("a later match (flags set) stays quiet", m.hud.msgs.count() == 0)
	p.teleport(m.arena.home)
