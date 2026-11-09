class_name Legendary
extends RefCounted
## Legendary Boki: very rare, at most one per match. Once per match the map rolls its
## legendary_spawn_chance; on a hit one species is picked uniformly from the map's eligible list
## and stands at a remote Rare Boki point (SpawnPlan). Numbers live in content/rules/legendary.json.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/legendary.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## This map's {chance, eligible}: the layout's own values, else the rules' defaults.
static func config(layout: Dictionary) -> Dictionary:
	var r := rules()
	return {"chance": float(layout.get("legendary_spawn_chance", r["chance"])),
		"eligible": layout.get("legendaries", r["roster"])}

## The species this match gets ("" for none). Its own seeded stream, so no other roll shifts.
static func roll(seed_val: int, cfg: Dictionary) -> String:
	var eligible: Array = cfg["eligible"]
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_val, "legendary"])
	if eligible.is_empty() or r.randf() >= float(cfg["chance"]):
		return ""
	return String(eligible[r.randi_range(0, eligible.size() - 1)])

## Where it stands: a Rare Boki point not live this match and at least min_start_dist from every
## start position in `starts`; if every point is too close, the one farthest from them.
static func pick_spot(cands: Array, starts: Array, seed_val: int) -> Dictionary:
	var pool: Array = cands.filter(func(c): return not c["active"])
	if pool.is_empty():
		pool = cands
	if pool.is_empty():
		return {}
	var far := float(rules()["min_start_dist"])
	var remote: Array = pool.filter(func(c): return _start_dist(c["pos"], starts) >= far)
	if remote.is_empty():
		pool.sort_custom(func(a, b): return _start_dist(a["pos"], starts) > _start_dist(b["pos"], starts))
		return pool[0]
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_val, "legendary_spot"])
	return remote[r.randi_range(0, remote.size() - 1)]

static func _start_dist(p: Vector3, starts: Array) -> float:
	var best := INF
	for s in starts:
		best = minf(best, Vector2(p.x - s.x, p.z - s.z).length())
	return best

## Puts the legendary on the map (host only, like all wild Boki).
static func spawn(m: Match, species: String, at: Vector3) -> Kin:
	var r := RandomNumberGenerator.new()
	r.seed = hash([m.seed_val, "legendary_kin"])
	var rec := Save.new_kin(species, "", m.kin_seed("legendary"))
	rec["level"] = int((m.T.get("kin_lvl", [1, 3]) as Array)[1]) + int(rules()["level_bonus"])
	Evo.simulate(rec, r)
	var k := m.spawn_wild(rec, at)
	k.set_meta("legendary", true)
	return k
