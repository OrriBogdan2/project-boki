extends RefCounted
## --camps-check: predictable monster camps and boss wake times (Camps, docs/CAMPS.md) on the Hollow Crown.
##   1. the data: every region names its camps (unique ids, tier 1-3, a respawn, a known reward, a real monster
##      set) and a region that leans one gear slot pays that slot; every lair has a wake time
##   2. two seeds of a real match fill every camp with exactly its set at its tier's rarity, in the same places
##   3. a cleared camp pays its reward, counts its own timer down and comes back with the same set; a peer
##      hearing the "camp" event counts the same timer
##   4. the player's squad scouts a camp by going near it, and the maps draw it
##   5. a live lair stays shut until its wake time, then its boss rises
## Never touches the save.

const MAP := "hollowcrown"
const SEEDS := [5201, 5202]

var bad := 0

func ok(cond: bool, what: String) -> void:
	print("CAMPS %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1

func run(main: Node) -> void:
	Save.no_write = true
	Save.d = Save.fresh()
	Econ.ensure()
	var L := World.load_layout(MAP)
	var defs := _data(L)
	var places: Array = []
	for sd in SEEDS:
		var m := Match.new()
		main.add_child(m)
		m.start({"teams": 2, "squad": 1, "tier": 0, "length": 1e9, "seed": sd, "no_drop": true, "map": MAP})
		m.set_process(false)         # the check drives the clock itself
		places.append(_filled(m, defs))
		if sd == SEEDS[0]:
			_wake(m, L)
			_clear_and_back(m)
			await _scout_and_draw(m, main)
		m.queue_free()
		await main.get_tree().process_frame
	ok(places[0] == places[1], "both seeds put every camp in the same place with the same set")
	print("camps-check: %d failures" % bad)
	main.get_tree().quit(0 if bad == 0 else 1)

## 1. The map's camp list. Returns id -> camp def.
func _data(L: Dictionary) -> Dictionary:
	var defs := {}
	for R in L["regions"]:
		var camps: Array = R.get("camps", [])
		ok(not camps.is_empty(), "%s names its camps (%d)" % [R["id"], camps.size()])
		var lean: Dictionary = R.get("loot", {}).get("slots", {})
		for cd in camps:
			var id := String(cd["id"])
			var kinds_ok: bool = (cd["set"] as Array).all(func(k): return Data.MOBS.has(k))
			var shape_ok: bool = not defs.has(id) and int(cd["tier"]) in [1, 2, 3] and float(cd["respawn"]) > 0.0
			var has_set: bool = kinds_ok and not (cd["set"] as Array).is_empty()
			var reward_ok: bool = Camps.REWARDS.has(String(cd["reward"])) and has_set
			ok(shape_ok and reward_ok, "%s: %s, tier %d, back in %d s, %s for %s" % [id, cd["name"], int(cd["tier"]),
				int(cd["respawn"]), cd["reward"], ", ".join(cd["set"])])
			if not lean.is_empty():
				var slot := String(Camps.REWARDS.get(String(cd["reward"]), {}).get("slot", ""))
				ok(lean.has(slot), "%s pays %s, the slot %s leans to" % [id, slot, R["id"]])
			defs[id] = cd
	for D in L["lairs"]:
		ok(float(D.get("wake", 0.0)) > 0.0, "lair %s wakes at %d s every match" % [D["id"], int(D.get("wake", 0.0))])
	return defs

## 2. Every named camp has exactly its set, at its tier's rarity. Returns [id, tile, kinds] per camp.
func _filled(m: Match, defs: Dictionary) -> Array:
	var C := m.camps
	var n := C.list.size() if C else 0
	ok(n == defs.size(), "seed %d: %d camps out of %d named" % [m.seed_val, n, defs.size()])
	var out: Array = []
	var wrong := 0
	for c in C.list:
		var cd: Dictionary = defs.get(c["id"], {})
		var kinds: Array = (c["mobs"] as Array).map(func(mb): return mb.mkind)
		var rarity: int = Camps.TIER_RARITY[int(c["tier"])]
		var rare_ok: bool = (c["mobs"] as Array).all(func(mb): return int(mb.get_meta("rarity", 0)) == rarity)
		if cd.is_empty() or kinds != Array(cd["set"]) or not rare_ok:
			wrong += 1
		out.append([c["id"], Vector2i(int(c["pos"].x), int(c["pos"].z)), kinds])
	ok(wrong == 0, "seed %d: every camp holds its own set at its tier's rarity (%d wrong)" % [m.seed_val, wrong])
	return out

## 3. Clear one camp: its reward drops, its own timer runs, it comes back the same. A peer counts the same.
func _clear_and_back(m: Match) -> void:
	var C := m.camps
	var c: Dictionary = C.list.filter(func(x): return x["reward"] in ["armor", "glove", "boots", "relic"])[0]
	var set0: Array = (c["mobs"] as Array).map(func(mb): return mb.mkind)
	var loot0 := m.wpicks.size()
	for mb in c["mobs"]:
		mb.hurt(1e9, m.player)
	C.tick(Camps.PASS_T)
	var timer_ok: bool = not c["up"] and is_equal_approx(C.left(c), float(c["respawn"]))
	ok(timer_ok, "%s cleared: back in %d s" % [c["name"], int(C.left(c))])
	ok(m.wpicks.size() > loot0, "%s drops its %s reward" % [c["name"], c["reward"]])
	var peer := {"up": true, "respawn": c["respawn"], "cleared_at": -1.0}
	C.list.append(peer)
	C.net_in(["camp", C.list.size() - 1, c["cleared_at"]])
	C.list.pop_back()
	ok(not peer["up"] and is_equal_approx(C.left(peer), C.left(c)), "a peer hearing the clear counts the same timer")
	m.time += float(c["respawn"]) - 1.0
	C.tick(Camps.PASS_T)
	ok(not c["up"], "not back a second early")
	m.time += 1.0
	C.tick(Camps.PASS_T)
	var set1: Array = (c["mobs"] as Array).map(func(mb): return mb.mkind)
	var alive: bool = (c["mobs"] as Array).all(func(mb): return not mb.dead)
	ok(c["up"] and alive and set1 == set0 and C.refills == 1, "%s back on time with the same set" % c["name"])

## 4. Unseen until the squad gets near; then the minimap and the full map draw it (and its countdown).
func _scout_and_draw(m: Match, main: Node) -> void:
	var C := m.camps
	var far: Dictionary = {}
	var best := 0.0
	for c in C.list:
		var d: float = m.player.flat_dist(c["pos"])
		if d > best:
			best = d
			far = c
	C.tick(Camps.PASS_T)
	ok(not far["seen"], "%s, %d m away, is not scouted yet" % [far["name"], int(best)])
	m.player.teleport(far["pos"] + Vector3(3.0, 0.0, 0.0))
	C.tick(Camps.PASS_T)
	ok(far["seen"], "walking up to %s scouts it" % far["name"])
	for mb in far["mobs"]:
		mb.hurt(1e9, m.player)
	C.tick(Camps.PASS_T)
	if m.hud:
		m.hud.open_map()
		for _f in 3:
			await main.get_tree().process_frame
		m.hud.close_map()
	ok(not far["up"], "a scouted, cleared camp shows its countdown (%s)" % Lairs.clock(C.left(far)))

## 5. A live lair is shut until its wake time; its boss rises then.
func _wake(m: Match, L: Dictionary) -> void:
	var lairs: Array = m.lairs.list.filter(func(x): return x["active"])
	ok(lairs.size() == (L["lairs"] as Array).size(), "every Hollow Crown lair is live (%d)" % lairs.size())
	m.time = 1.0
	var shut: bool = lairs.all(func(x): return x["boss_mob"] == null and m.lairs.wake_left(x) > 0.0)
	ok(shut, "at the start no boss is up and each lair counts down to its wake")
	var first: Dictionary = lairs[0]
	for x in lairs:
		if float(x["wake"]) < float(first["wake"]):
			first = x
	m.time = float(first["wake"]) + 0.1
	m.lairs.tick(0.1)
	var risen: Array = lairs.filter(func(x): return x["boss_mob"] != null)
	ok(risen == [first] and first["state"] == "sealed", "%s's boss rises at %s, the others still wait" % [first["name"],
		Lairs.clock(float(first["wake"]))])
