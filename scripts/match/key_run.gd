class_name KeyRun
extends RefCounted
## Keys for the match (docs/decisions/0009-keys-and-cover.md). Every chest needs one key. Keys come
## from monsters: in each region (an authored map's named region, else the island) the number of key
## carriers equals the number of chests there. Which monsters carry them is rolled per match on this
## class's own seeded stream, so it never shifts the match's other dice. A region with fewer monsters
## than chests (a quiet landing) first gets Shrublings (the bush mimic, always carriers); any
## shortfall left is carried by monsters in the nearest regions that have some to spare, so the world
## always holds as many keys as chests.

static var _rules: Dictionary = {}

static func rules() -> Dictionary:
	if _rules.is_empty():
		var d = JSON.parse_string(FileAccess.get_file_as_string("res://content/rules/keys.json"))
		_rules = d if d is Dictionary else {}
	return _rules

## A chest key picked up off the ground (a carrier's drop, or one lost from a deathbox).
static func on_pickup(m: Match, h: Hunter) -> void:
	KeyChest.give(h, 1)
	if h == m.player:
		m.hud.toast_small("Chest key found", KeyModels.BRASS)
		m.sfx("key_get", null, -4.0, 1.0)

var m: Match
var rng := RandomNumberGenerator.new()
var patches: Array = []        # tall-grass patches: {c: Vector2, tiles: Array[Vector2i], island: int}
# key -> {chests: int, centre: Vector2, mobs: Array, carriers: Array, shrubs: int, spilled_in: int}
var regions := {}
var shrublings: Array = []
var carriers: Array = []       # every Mob carrying a key at setup
var bonus_rng := RandomNumberGenerator.new()      # bonus keys (KeyBonus): a stream of their own
var bonus_given := 0

func _init(match_node: Match) -> void:
	m = match_node

## Region key of a point: the authored region, else the island ("" over the void).
func region_of(p: Vector3) -> String:
	var ii := m.world.island_of(p.x, p.z)
	if ii < 0 or ii >= m.world.islands.size():
		return ""
	var isl: Dictionary = m.world.islands[ii]
	return "r%d" % int(isl["region_fixed"]) if isl.has("region_fixed") else "i%d" % ii

func _reg(key: String) -> Dictionary:
	if not regions.has(key):
		regions[key] = {
				"chests": 0, "centre": Vector2.ZERO, "mobs": [], "carriers": [], "shrubs": 0, "spilled_in": 0,
				"spilled_out": 0}
	return regions[key]

## Host (or an offline game) only: spawns the Shrublings and rolls the carriers.
func setup() -> void:
	if m.net_on and not m.is_host:
		return
	rng.seed = int(m.seed_val) * int(rules()["keys"]["seed_mul"]) + int(rules()["keys"]["seed_add"])
	bonus_rng.seed = int(m.seed_val) * int(rules()["keys"]["seed_mul"]) + int(KeyBonus.rules()["seed_add"])
	build_patches()
	_count_chests()
	_count_mobs()
	spawn_shrublings()
	assign_carriers()

# ------------------------------------------------------------------ the map's cover
## Connected clumps of tall grass (8-way), at least 4 tiles each.
func build_patches() -> void:
	patches.clear()
	var w := m.world
	var seen := {}
	for bi in w.bush:
		if seen.has(bi) or w.kind[bi] != World.T_GROUND:
			continue
		var tiles: Array = []
		var q: Array = [bi]
		seen[bi] = true
		while not q.is_empty():
			var cur: int = q.pop_back()
			tiles.append(Vector2i(cur % w.w, cur / w.w))
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					var nx: int = cur % w.w + dx
					var nz: int = cur / w.w + dz
					if not w.inb(nx, nz):
						continue
					var ni := w.idx(nx, nz)
					if w.bush.has(ni) and not seen.has(ni) and w.kind[ni] == World.T_GROUND:
						seen[ni] = true
						q.append(ni)
		if tiles.size() < 4:
			continue
		var c := Vector2.ZERO
		for t in tiles: c += Vector2(t.x + 0.5, t.y + 0.5)
		c /= float(tiles.size())
		patches.append({
				"c": c, "tiles": tiles, "island": w.island[w.idx((tiles[0] as Vector2i).x, (tiles[0] as Vector2i).y)]})

## How many patches have their middle within `r` metres of p.
func patches_near(p: Vector3, r: float) -> int:
	var n := 0
	for pt in patches:
		if (pt["c"] as Vector2).distance_to(Vector2(p.x, p.z)) <= r:
			n += 1
	return n

# ------------------------------------------------------------------ counting
func _count_chests() -> void:
	for c in m.chests:
		if bool(c.get("free", false)) or c["open"]:
			continue
		var rg := _reg(region_of(c["pos"]))
		rg["chests"] += 1
		rg["centre"] += Vector2(c["pos"].x, c["pos"].z)
	for k in regions:
		if int(regions[k]["chests"]) > 0:
			regions[k]["centre"] /= float(regions[k]["chests"])

func _eligible(mb: Mob) -> bool:
	return not mb.dead and not (mb is Blight) and not (mb is Boss) and not (mb is Shrubling) \
		and not (rules()["keys"]["no_carry"] as Array).has(mb.mkind) and not mb.md.get("flee", false)

func _count_mobs() -> void:
	for mb in m.mobs:
		if _eligible(mb):
			var k := region_of(mb.pos)
			if k != "":
				_reg(k)["mobs"].append(mb)
	for k in regions:
		var rg: Dictionary = regions[k]
		if int(rg["chests"]) == 0 and not (rg["mobs"] as Array).is_empty():
			for mb in rg["mobs"]: rg["centre"] += Vector2(mb.pos.x, mb.pos.z)
			rg["centre"] /= float((rg["mobs"] as Array).size())

# ------------------------------------------------------------------ the Shrublings
## 1-3 of them, in bloom, meadow, gloom or storm country with 3 or more grass patches in sprinting
## range, preferably in regions with fewer monsters than chests; never more in a region than it has chests.
func spawn_shrublings() -> void:
	var sr: Dictionary = rules()["shrubling"]
	var want := rng.randi_range(int(sr["count"][0]), int(sr["count"][1]))
	var spots := _shrub_spots()
	for _i in want:
		var pick := _pick_spot(spots)
		if pick.is_empty():
			break
		var at: Vector3 = pick["pos"]
		var s := Shrubling.new()
		s.init_shrub(m, m.next_id("m"), at, float(m.T.get("mob", 1.0)) if not m.T.is_empty() else 1.0)
		m.add_child(s)
		m.mobs.append(s)
		m.ents_by_id[s.nid] = s
		shrublings.append(s)
		_reg(String(pick["region"]))["shrubs"] += 1

## Candidate hiding tiles: inside a patch of a suitable biome with enough other patches near, away
## from landings and exits. {pos, region, patches}
func _shrub_spots() -> Array:
	var sr: Dictionary = rules()["shrubling"]
	var w := m.world
	var out: Array = []
	for pt in patches:
		var isl: Dictionary = w.islands[int(pt["island"])] if int(pt["island"]) >= 0 else {}
		if not (sr["biomes"] as Array).has(String(isl.get("biome", ""))):
			continue
		var tiles: Array = pt["tiles"]
		# an interior tile if there is one (all 8 neighbours grass), nearest the middle
		var best := Vector2i(-1, -1)
		var bd := 1e9
		for t in tiles:
			var inner := true
			for dz in [-1, 0, 1]:
				for dx in [-1, 0, 1]:
					if not w.bush.has(w.idx(t.x + dx, t.y + dz)): inner = false
			var d := Vector2(t.x + 0.5, t.y + 0.5).distance_to(pt["c"])
			if (inner or best.x < 0) and d < bd:
				bd = d
				best = t
		var p := Vector3(best.x + 0.5, w.level[w.idx(best.x, best.y)] * World.LEVEL, best.y + 0.5)
		if patches_near(p, float(sr["sprint_r"])) < int(sr["min_patches"]):
			continue
		if _near_any(p, w.spawns, float(sr["landing_clear"])) or _near_any(p, w.portal_spots, float(sr["exit_clear"])):
			continue
		var rk := region_of(p)
		if not regions.has(rk) or int(regions[rk]["chests"]) <= 0:
			continue
		out.append({"pos": p, "region": rk, "patches": patches_near(p, float(sr["sprint_r"]))})
	return out

func _near_any(p: Vector3, list: Array, r: float) -> bool:
	for q in list:
		if Vector2(p.x - q.x, p.z - q.z).length() < r:
			return true
	return false

## One spot: regions short of monsters first (weight 3), then regions with spare quota (1).
func _pick_spot(spots: Array) -> Dictionary:
	var gap := float(rules()["shrubling"]["min_gap"])
	var pool: Array = []
	var wts: Array = []
	for s in spots:
		var rg: Dictionary = regions[s["region"]]
		if int(rg["shrubs"]) >= int(rg["chests"]):
			continue
		var too_close := false
		for sh in shrublings:
			if Vector2(sh.pos.x - s["pos"].x, sh.pos.z - s["pos"].z).length() < gap: too_close = true
		if too_close:
			continue
		pool.append(s)
		wts.append(3.0 if (rg["mobs"] as Array).size() + int(rg["shrubs"]) < int(rg["chests"]) else 1.0)
	if pool.is_empty():
		return {}
	var tot := 0.0
	for x in wts: tot += float(x)
	var r := rng.randf() * tot
	for i in pool.size():
		r -= float(wts[i])
		if r <= 0.0: return pool[i]
	return pool[-1]

# ------------------------------------------------------------------ the carriers
func assign_carriers() -> void:
	carriers.clear()
	for s in shrublings:
		carriers.append(s)
	var deficits := {}
	for k in regions:
		var rg: Dictionary = regions[k]
		var need: int = int(rg["chests"]) - int(rg["shrubs"])
		var cand: Array = (rg["mobs"] as Array).duplicate()
		_shuffle(cand)
		var take := mini(maxi(need, 0), cand.size())
		for i in take:
			_carry(cand[i], rg, true)
		if need > take:
			deficits[k] = need - take
	# a region with fewer monsters than chests: the nearest regions with monsters to spare carry for it
	var keys: Array = deficits.keys()
	keys.sort()
	for k in keys:
		var from: Vector2 = regions[k]["centre"]
		var order: Array = regions.keys().filter(func(o): return o != k)
		order.sort_custom(func(a, b): return _centre_dist(a, from) < _centre_dist(b, from))
		for o in order:
			if int(deficits[k]) <= 0:
				break
			var spare: Array = (regions[o]["mobs"] as Array).filter(func(mb): return not KeyCarry.carries(mb))
			_shuffle(spare)
			for mb in spare:
				if int(deficits[k]) <= 0:
					break
				_carry(mb, regions[o], false)
				regions[o]["spilled_out"] += 1
				regions[k]["spilled_in"] += 1
				deficits[k] = int(deficits[k]) - 1

func _carry(mb: Mob, rg: Dictionary, own: bool) -> void:
	KeyCarry.mark(mb)
	if own:
		(rg["carriers"] as Array).append(mb)      # (carries for its own region's chests)
	carriers.append(mb)

func _shuffle(a: Array) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = a[i]
		a[i] = a[j]
		a[j] = t

## For checks and the full map: per region {chests, monsters, shrublings, carriers (for its own chests),
## spilled_in, spilled_out}.
func report() -> Dictionary:
	var out := {}
	for k in regions:
		var rg: Dictionary = regions[k]
		out[k] = {
			"chests": int(rg["chests"]),
			"monsters": (rg["mobs"] as Array).size(),
			"shrublings": int(rg["shrubs"]),
			"carriers": (rg["carriers"] as Array).size() + int(rg["shrubs"]),
			"spilled_in": int(rg["spilled_in"]),
			"spilled_out": int(rg["spilled_out"]),
		}
	return out

func _centre_dist(region_key, from: Vector2) -> float:
	return (regions[region_key]["centre"] as Vector2).distance_to(from)
