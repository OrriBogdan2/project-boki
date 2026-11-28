class_name BaseRoutine
extends RefCounted
## What an untended Boki does with a free moment (briefs/design/GARDEN.md section 4): the last pick of
## BaseLife.choose, after eating, napping, toys and tag. One weighted pick of
## wander (a random walk), fave (its own favourite spot of the zone: one of the nap spots, by its uid), shade (a
## midday nap in the zone's shade), friend (walks over to a Boki it gets on with and plays tag), drink (the pond's
## edge) and sit (by you, once its trust is high). The picks only set goals and states the farm already walks
## (BaseLife's nap and tag, the garden nav through k["goal"]): no pathing of its own.
## Odds come from content/rules/base_life.json "routine": a weight per routine, scaled by the Boki's traits and needs.

const IDS := ["wander", "fave", "shade", "friend", "drink", "sit"]

var ran := {}  # routine id -> times started (--garden-day-check reads it)

var _life  # the BaseLife that owns this
var _h  # the home
var _r: Dictionary  # content/rules/base_life.json "routine"
var _water_tiles: Array = []  # [Vector3] centres of the pond's tiles
var _water_n := -1  # tiles the cache was made from (a pond you build or dig changes it)


func _init(life) -> void:
	_life = life
	_h = life.h
	_r = life.r_v["routine"]


## Starts one routine for the roaming Boki `k`; false when it is a plain wander (the caller sends it somewhere).
func pick(k: Dictionary) -> bool:
	var targets := {}
	var weights := {}
	var total := 0.0
	for id in IDS:
		targets[id] = _target(id, k)
		if targets[id] != null:
			weights[id] = float(_r["weights"][id]) * _factor(id, k["rec"])
			total += weights[id]
	var roll := randf() * total
	for id in weights:
		roll -= weights[id]
		if roll <= 0.0 and id != "wander":
			_start(id, k, targets[id])
			return true
		if roll <= 0.0:
			break
	return false


## What `id` would go to for `k` (a spot, a Boki, true), or null when it cannot run now.
func _target(id: String, k: Dictionary) -> Variant:
	match id:
		"fave":
			return _fave(k)
		"shade":
			return _shade(k)
		"friend":
			return _friend(k)
		"drink":
			return _drink(k)
		"sit":
			return _sit(k)
	return true


## 1 plus the traits and needs that lean `rec` to `id` (rules: traits, needs), kept within factor.
func _factor(id: String, rec: Dictionary) -> float:
	var scale := 1.0
	for key in _r["traits"].get(id, {}) as Dictionary:
		scale += float(_r["traits"][id][key]) * (float(rec.get("traits", {}).get(key, 0.5)) - 0.5) * 2.0
	for need in _r["needs"].get(id, {}) as Dictionary:
		scale += float(_r["needs"][id][need]) * (50.0 - Care.need(rec, need)) / 50.0
	if id == "sit":
		scale *= BaseAxes.mult(rec, "cling")
	return clampf(scale, float(_r["factor"][0]), float(_r["factor"][1]))


func _start(id: String, k: Dictionary, to: Variant) -> void:
	ran[id] = int(ran.get(id, 0)) + 1
	match id:
		"shade":
			_life._nap(k, "shade", String(_r["shade_kind"]))
		"friend":
			var o: Dictionary = to
			if BaseLife._dist(k, o) < float(_life.r_v["near"]):
				_life._tag(k, o)
			else:
				_walk(k, o["pos"], false)
		"drink":
			k["stare"] = to["water"]
			_walk(k, to["at"], true)
		_:
			_walk(k, to, true)


## Goal `to`, and the time to get there (and to stay, `linger`) before it thinks again.
func _walk(k: Dictionary, to: Vector3, linger: bool) -> void:
	k["goal"] = to
	var secs := Vector2(to.x - k["pos"].x, to.z - k["pos"].z).length() / float(_r["pace"])
	if linger:
		secs += randf_range(_r["linger"][0], _r["linger"][1])
	k["t"] = maxf(float(k["t"]), secs)


## The Boki's own favourite of the zone's nap spots, a place beside it, or null.
func _fave(k: Dictionary) -> Variant:
	var spots := BaseLife.nap_spots()
	if spots.is_empty():
		return null
	var spot: Array = spots[absi(String(k["rec"]["uid"]).hash()) % spots.size()]
	var at: Vector3 = _h._seat(k, Vector3(float(spot[1]) + 0.5, 0.0, float(spot[2]) + 0.5), 1.2)
	return at if _life._reach(k, at) else null


## Midday, and the zone has a shade spot.
func _shade(k: Dictionary) -> Variant:
	var span: Array = _r["midday"]
	if _life.night or _h.day_t < float(span[0]) or _h.day_t > float(span[1]) or not _life._awake(k):
		return null
	var kind := String(_r["shade_kind"])
	return true if BaseLife.nap_spots().any(func(s): return s[0] == kind) else null


## The free Boki on its island it likes most (bond over greet_at), or null.
func _friend(k: Dictionary) -> Variant:
	var best: Variant = null
	var top := float(_life.r_v["greet_at"])
	var here: int = _h.world.island_of(k["pos"].x, k["pos"].z)
	for o in _h.kins:
		var liking := BaseLife.bond(k["rec"], o["rec"])
		if o == k or liking <= top or not BaseLife.roams(o) or o.has("play") or BaseShy.shy(o["rec"]):
			continue
		if _h.world.island_of(o["pos"].x, o["pos"].z) == here:
			top = liking
			best = o
	return best


## {at, water}: dry ground by the nearest pond tile on its island, and that tile, or null.
func _drink(k: Dictionary) -> Variant:
	var water: Dictionary = _h.hb.L()["water"] if _h.hb != null else {}
	if water.size() != _water_n:
		_water_n = water.size()
		_water_tiles = water.keys().map(
			func(key: String) -> Vector3:
				var tile := HomeLayout.unkey(key)
				return Vector3(float(tile.x) + 0.5, 0.0, float(tile.y) + 0.5)
		)
	var here: int = _h.world.island_of(k["pos"].x, k["pos"].z)
	var best: Variant = null
	var top := INF
	for tile in _water_tiles:
		var d := Vector2(tile.x - k["pos"].x, tile.z - k["pos"].z).length()
		if d < top and _h.world.island_of(tile.x, tile.z) == here:
			top = d
			best = tile
	if best == null:
		return null
	var at: Vector3 = _h._seat(k, best, 1.6)
	if _h.water.depth(at.x, at.z) > 0:
		at = _h.world.free_spot_near(best, [], 1.0, 0.45, 3.0)
	return {"at": at, "water": best} if _h.water.depth(at.x, at.z) == 0 and _life._reach(k, at) else null


## Its trust in you is high and you are on its island: where to sit beside you, or null.
func _sit(k: Dictionary) -> Variant:
	if float(k["rec"].get("trust", 50.0)) < float(_r["trust_at"]):
		return null
	if _h.world.island_of(_h.ppos.x, _h.ppos.z) != _h.world.island_of(k["pos"].x, k["pos"].z):
		return null
	return _h._seat(k, _h.ppos, float(_r["sit_m"]))
