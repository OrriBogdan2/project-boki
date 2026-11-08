extends RefCounted
## --grounds-check: the Training Grounds (the --arena map). The floor is at least 3x the old Arena's, five sky
## perches are joined to it by pads and glides, every Hunter, Boki, glove / armor / boot and belt item has a
## pedestal that works, every Hunter can be spawned as a sparring bot, the duel ring is there, and a fall off the
## map brings you home. Prints GROUNDSCHECK PASS/FAIL.

const OLD_FLOOR_TILES := 616          # the old Arena's floor circle (r 14 tiles), the area to beat 3x over
const DT := 1.0 / 60.0

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	printerr("GROUNDSCHECK %-46s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

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
	var A: Arena = m.arena
	var P: Hunter = m.player
	var G: Grounds = A.grounds
	ok("grounds built on the arena map", G != null and m.world.layout_id == "arena" and not G.stations.is_empty())
	_map(m)
	_counts(G)
	_sites(m, G)
	step(m, 0.3)
	_use_all(m, G)
	_rides(m)
	_duel_and_fall(m, G)
	print("GROUNDSCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()
	if P == null: fails += 1

func _map(m: Match) -> void:
	var W: World = m.world
	var floor_tiles := 0
	var perches := 0
	for isl in W.islands:
		if String(isl.get("id", "")) == "floor":
			floor_tiles = (isl["cells"] as Array).size()
		if bool(isl.get("perch", false)):
			perches += 1
	var info := "%d tiles vs %d" % [floor_tiles, OLD_FLOOR_TILES]
	ok("floor is at least 3x the old arena", floor_tiles >= 3 * OLD_FLOOR_TILES, info)
	ok("five sky perches", perches == 5, "%d" % perches)
	ok("training room walls kept (3 dummies)", m.arena.dummies.size() == 3)

## Ride every pad up and every glide route down: each must land you on its island.
func _rides(m: Match) -> void:
	var W: World = m.world
	var P: Hunter = m.player
	var bad: Array = []
	for pd in W.pads:
		P.teleport(pd["pos"])
		P.vel = Vector3.ZERO
		_settle(m, P, Vector2.ZERO, 4.0)
		if W.island_id(P.pos.x, P.pos.z) != String(W.islands[pd["to"]]["id"]):
			bad.append("pad to %s" % W.islands[pd["to"]]["id"])
	ok("every pad lands you on its perch", bad.is_empty() and W.pads.size() >= 5, " ".join(bad))
	bad.clear()
	var glides := 0
	for L in W.links:
		if not L.get("glide", false):
			continue
		glides += 1
		var take: Vector3 = L["take"]
		var land: Vector3 = L["land"]
		var dir := Vector2(land.x - take.x, land.z - take.z).normalized()
		P.teleport(take - Vector3(dir.x, 0, dir.y) * 1.5)
		P.vel = Vector3.ZERO
		_settle(m, P, dir, 20.0)
		var to := String(W.islands[L["to"]]["id"])
		if W.island_id(P.pos.x, P.pos.z) != to:
			bad.append("%s>%s" % [W.islands[L["from"]]["id"], to])
	var info := "%d routes %s" % [glides, " ".join(bad)]
	ok("every glide route lands you on its island", bad.is_empty() and glides >= 5, info)
	P.teleport(m.arena.home)
	P.vel = Vector3.ZERO
	P.inp["move"] = Vector2.ZERO
	P.inp["glide"] = false

## Hold `move` (and the glider once airborne) until you are back on the ground, up to `secs`.
func _settle(m: Match, P: Hunter, move: Vector2, secs: float) -> void:
	var t := 0.0
	var flew := false
	while t < secs:
		P.inp["move"] = move
		P.inp["glide"] = not P.grounded
		m.step(DT)
		t += DT
		flew = flew or not P.grounded
		if flew and P.grounded and P.pad.is_empty() and t > 0.5:
			return

func _counts(G: Grounds) -> void:
	var by := {}
	for s in G.stations:
		by[s["kind"]] = int(by.get(s["kind"], 0)) + 1
	ok("a pedestal per Hunter", by.get("arch", 0) == Arch.ids().size(), "%d" % by.get("arch", 0))
	ok("a pedestal per Boki", by.get("kin", 0) == KinLib.kin_ids().size(), "%d" % by.get("kin", 0))
	ok("a pedestal per gear piece", by.get("gear", 0) == Gear.ALL.size(), "%d" % by.get("gear", 0))
	ok("a pedestal per belt item", by.get("item", 0) == UtilityBelt.stock_ids().size(), "%d" % by.get("item", 0))
	ok("a bot spawner per Hunter (+ clear)", by.get("bot", 0) == Arch.ids().size() + 1, "%d" % by.get("bot", 0))

## Every pedestal stands on a perch (not in the void), apart from its neighbours, its name hidden from afar.
func _sites(m: Match, G: Grounds) -> void:
	var off := 0
	var tight := 99.0
	var shown := 0
	for i in G.stations.size():
		var s: Dictionary = G.stations[i]
		var at: Vector3 = s["at"]
		if m.world.island_id(at.x, at.z) in ["", "floor"] or m.world.is_void(at.x, at.z):
			off += 1
		if (s["label"] as Label3D).visible:
			shown += 1
		for j in range(i + 1, G.stations.size()):
			tight = minf(tight, at.distance_to((G.stations[j] as Dictionary)["at"]))
	ok("every pedestal stands on a perch", off == 0, "%d off" % off)
	ok("pedestals are 1.5m+ apart", tight >= 1.5, "closest %.2f" % tight)
	ok("no name drawn from afar", shown == 0, "%d shown" % shown)

func _use_all(m: Match, G: Grounds) -> void:
	var P: Hunter = m.player
	var A: Arena = m.arena
	var bad: Array = []
	for i in G.stations.size():
		var s: Dictionary = G.stations[i]
		var id := String(s["id"])
		var good := true
		G.use(i)
		match String(s["kind"]):
			"arch": good = P.arch == id
			"kin": good = P.kin != null and (P.kin as Kin).species == id
			"gear": good = _worn(P, id)
			"item": good = UtilityBelt.count(P, id) > 0
			"bot": good = _bot_ok(A, id)
		if not good:
			bad.append("%s:%s" % [s["kind"], id])
	ok("every pedestal does its thing", bad.is_empty(), "bad: %s" % ", ".join(bad.slice(0, 6)))

func _bot_ok(A: Arena, id: String) -> bool:
	if id == "clear":
		return A.bot == null
	return A.bot != null and A.bot.arch == id and A.bot_mode != "off"

func _worn(P: Hunter, id: String) -> bool:
	for g in P.gear:
		if not (g as Dictionary).is_empty() and String(g["id"]) == id:
			return true
	return false

func _duel_and_fall(m: Match, G: Grounds) -> void:
	var P: Hunter = m.player
	ok("duel pad on the floor", m.duel_pad != Vector3.INF and m.world.island_id(m.duel_pad.x, m.duel_pad.z) == "floor")
	P.teleport(Vector3(60, -20, 25))      # off the map
	G.tick()
	ok("a faller is brought home", P.flat_dist(m.arena.home) < 1.0 and P.pos.y > -1.0, "at %s" % P.pos)
