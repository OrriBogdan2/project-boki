extends RefCounted
## --hob-spot-check: Hob's fixed home spot and its clear ring (HobSpot, FarmHob, HomeBuild.cell_reason).
##   1. a new farm: his spot is saved, every tile and place you interact with stays outside the ring, and it is
##      the same spot after the layout syncs again
##   2. build mode: the market stall moved anywhere into his ring is refused, red, mostly with "Too close to Hob"
##   3. a save with the stall inside his ring: on load he moves to the nearest free tile (once) and walks there
##   4. interact: by Hob the prompt is Hob, by the stall it is the stall, and their talk rings never overlap
## Screenshots: --hob-spot-shots=<dir> (tools/hob_spot_shots.gd).

const STALL_REACH := 1.9     # m: the market stall's interact reach in Home._find_interact

var main: Node
var bad := 0
var home = null


func ok(cond: bool, what: String) -> void:
	print("HOBSPOT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond:
		bad += 1


func run(m: Node) -> void:
	main = m
	Save.no_write = true
	await _new_farm()
	_spot_is_clear()
	_placement()
	_interact()
	await _relocate()
	print("HOBSPOT DONE, failures: %d" % bad)
	main.get_tree().quit(1 if bad > 0 else 0)


## A farm-start island past the farm tutorial with the market stall set down (HomeStall), loaded from Save.d.
func _new_farm() -> void:
	var d := Save.fresh()
	var k := Save.new_kin("zapple", "Pip")
	k["starter"] = true
	d["roster"].append(k)
	d["active"] = k["uid"]
	d["tutorial"] = {"hatched": true, "intro": true, "day1_done": true}
	Save.d = d
	HomeLayout.ensure(Save.d)      # (a farm-start island)
	d["tutorial"]["home"] = true     # (the welcome is behind us)
	ClassUnlock.choose_starters(["gunslinger"])
	Game.apply_result({"arch": "gunslinger", "extracted": true, "why": "extracted", "knocks": 0, "kills": 0,
			"gems": 0, "seeds": {}, "stats": {}, "lvl": 1, "caught": [], "kin_runs": [], "tonics": 0, "tutorial": true})
	await _load()


func _load() -> void:
	if home:
		home.queue_free()
		await main.get_tree().process_frame
	home = await main._hb_home()
	var t0 := Time.get_ticks_msec()
	while not (home.hob != null and is_instance_valid(home.hob.node)) and Time.get_ticks_msec() - t0 < 20000:
		await main.get_tree().process_frame
	home._close_panel()


func _spot_is_clear() -> void:
	var hob: FarmHob = home.hob
	var spot := hob.spot
	ok(spot != Vector3.INF and FarmBuilder.state().get("spot") == [spot.x, spot.z], "Hob has a saved spot %s" % spot)
	ok(hob.pos == spot, "and that is where he stands")
	ok(_crowding(spot) == "", "nothing placed and no place you interact with inside %.1f m (%s)"
			% [HobSpot.clear_m(), _crowding(spot)])
	home._sync_fixtures()
	ok(hob.spot == spot, "the same spot after the layout syncs again")


## The first placed tile or interact place inside the ring round `spot`, or "".
func _crowding(spot: Vector3) -> String:
	var hb: HomeBuild = home.hb
	var w: World = home.world
	for i in hb.occ:
		if HobSpot.near_tile(spot, Vector2i(i % w.w, i / w.w)):
			return "tile %s (%s)" % [Vector2i(i % w.w, i / w.w), hb.occ[i]]
	for p in hb._targets():
		if Vector2(p.x - spot.x, p.z - spot.z).length() < HobSpot.clear_m():
			return "place %s" % p
	return ""


func _placement() -> void:
	var hb: HomeBuild = home.hb
	var e: Dictionary = HomeLayout.fixtures(Save.d, "stall")[0]
	var s := Vector2i(int(floor(home.hob.spot.x)), int(floor(home.hob.spot.z)))
	var item := {"kind": "deco", "id": "market_stall", "r": 0, "from": int(e["u"])}
	var sz := HomeLayout.size_of("market_stall", 0)
	hb.held = item
	var tried := 0
	var fits_inside := []
	var why_hob := 0
	for z in range(s.y - 5 - sz.y, s.y + 6):
		for x in range(s.x - 5 - sz.x, s.x + 6):
			var cells := HomeLayout.cells_of([x, z, x + sz.x - 1, z + sz.y - 1])
			if not cells.any(func(c): return home.hob.crowds(c)):
				continue
			tried += 1
			hb.cells = cells
			hb._check_cells()
			if hb.ghost_ok:
				fits_inside.append(Vector2i(x, z))
			elif hb.why == HobSpot.REASON:
				why_hob += 1
	ok(tried > 0 and fits_inside.is_empty() and why_hob > 0,
			"the stall moved into his ring: all %d spots refused, %d of them red with '%s' %s"
			% [tried, why_hob, HobSpot.REASON, fits_inside])
	hb.cells = HomeLayout.deco_cells(e)
	hb._check_cells()
	ok(hb.ghost_ok, "where it stands it still fits (%s)" % hb.why)
	hb.held = {}
	hb.cells = []


func _interact() -> void:
	var hob: FarmHob = home.hob
	var stall: Vector3 = home.spots["stall"]
	var apart := Vector2(stall.x - hob.spot.x, stall.z - hob.spot.z).length()
	ok(apart >= float(hob.rules()["talk_reach"]) + STALL_REACH,
			"his talk ring and the stall's never overlap (%.1f m apart)" % apart)
	for k in home.kins:
		k["pos"] = Vector3(-500, 0, -500)      # (no Boki wandering into the prompt)
	var to_stall := (stall - hob.spot).normalized()
	var picks: Array = []
	for step in [0.6, 1.0, 1.4, 1.8]:
		picks.append(_pick(hob.spot + to_stall * step))
	ok(picks.all(func(kind): return kind == "hob"), "from Hob toward the stall the prompt stays Hob %s" % [picks])
	picks.clear()
	for step in [0.4, 0.8, 1.2]:
		picks.append(_pick(stall - to_stall * step))
	ok(picks.all(func(kind): return kind == "stall"), "by the stall the prompt is the stall %s" % [picks])
	var mid := (stall + hob.spot) * 0.5
	var mid_kind := _pick(mid)
	ok(range(10).all(func(i): return _pick(mid + Vector3(0.01 * i, 0, 0)) == mid_kind),
			"halfway between them it does not flicker ('%s')" % mid_kind)


func _pick(at: Vector3) -> String:
	home.ppos = at
	home._find_interact()
	return String(home.interact.get("kind", ""))


func _relocate() -> void:
	var old: Vector3 = home.hob.spot
	var e: Dictionary = HomeLayout.fixtures(Save.d, "stall")[0]
	e["x"] = int(floor(old.x)) - 1      # (an older layout: the stall right where he stands)
	e["z"] = int(floor(old.z))
	e["r"] = 0
	await _load()
	var hob: FarmHob = home.hob
	ok(hob.spot != old and _crowding(hob.spot) == "", "a save with the stall on his spot: he moves to %s (%s)"
			% [hob.spot, _crowding(hob.spot)])
	ok(FarmBuilder.state().get("spot") == [hob.spot.x, hob.spot.z], "and that becomes his saved spot")
	var w: World = home.world
	ok(w.kind[w.idx(int(floor(hob.spot.x)), int(floor(hob.spot.z)))] == World.T_GROUND, "on open ground")
	var dist := Vector2(hob.spot.x - old.x, hob.spot.z - old.z).length()
	ok(dist < HobSpot.clear_m() + 6.0, "nearby (%.1f m from the old spot)" % dist)
	var t0 := Time.get_ticks_msec()
	while hob.node.position.distance_to(hob.spot) > 0.1 and Time.get_ticks_msec() - t0 < 15000:
		await main.get_tree().process_frame
	ok(hob.node.position.distance_to(hob.spot) <= 0.1, "he walks there")
	var moved := hob.spot
	home._sync_fixtures()
	ok(hob.spot == moved, "and stays (moved once)")

