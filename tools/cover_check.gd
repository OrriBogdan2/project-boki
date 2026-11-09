extends RefCounted
## --cover-check: the Hollow Crown's hiding cover (docs/decisions/0009-keys-and-cover.md; the map is
## built by tools/make_hollowcrown.py). For several match seeds it builds the real world and checks:
##   1. the share of walkable ground in tall grass, per biome, against content/rules/keys.json "cover",
##      and the order bloom > meadow > gloom > storm and ember > frost (the shares are printed)
##   2. cover comes as patches (no single tufts), never on stairs, bridges or their edges, landing drop
##      circles, or the foot of an exit
##   3. in the bush biomes every extraction point has a patch in sight, and chests and camps in bloom
##      and meadow have a patch beside them (ambush play)
##   4. cover never closes a path: from every landing a bush-free walk reaches each chest, camp and exit
##      on its island, and the tile A* still finds a way
##   5. Shrublings have somewhere to live: each bush biome has spots with 3+ patches in sprint range

var main: Node
var fails := 0
var n := 0
const BUSH_BIOMES := ["bloom", "meadow", "gloom", "storm"]
const ORDER := ["bloom", "meadow", "gloom", "storm", "ember", "frost"]

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("COVERCHECK %-62s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node) -> void:
	main = main_node
	Save.no_write = true
	var L := World.load_layout("hollowcrown")
	var T: Dictionary = KeyRun.rules()["cover"]["biome_targets"]
	for sd in [3, 5, 9, 12, 21]:
		var w := World.new()
		w.generate_authored(L, sd)
		_shares(w, sd, T)
		_placement(w, sd)
		_sight(w, sd)
		_ambush(w, sd)
		_paths(w, sd)
		_homes(w, sd)
		w.free()
	print("COVERCHECK DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

# ------------------------------------------------------------------ 1. shares
func _is_ground(w: World, i: int) -> bool:
	return w.kind[i] == World.T_GROUND and not w.bridge.has(i) and w.island[i] >= 0

func _shares(w: World, sd: int, T: Dictionary) -> void:
	var ground := {}
	var bush := {}
	for i in w.w * w.h:
		if not _is_ground(w, i): continue
		var b := String(w.islands[w.island[i]].get("biome", ""))
		ground[b] = int(ground.get(b, 0)) + 1
		if w.bush.has(i): bush[b] = int(bush.get(b, 0)) + 1
	var share := {}
	var line := "seed %d cover share:" % sd
	for b in ORDER:
		share[b] = float(bush.get(b, 0)) / maxf(1.0, float(ground.get(b, 1)))
		line += "  %s %.1f%%" % [b, share[b] * 100.0]
	print("COVERCHECK " + line)
	for b in ORDER:
		var lo: float = T[b][0]
		var hi: float = T[b][1]
		ok(
				"seed %d: %s cover %.1f%% is inside %.1f-%.1f%%" % [sd, b, share[b] * 100.0, lo * 100.0, hi * 100.0],
				share[b] >= lo and share[b] <= hi)
	ok("seed %d: order bloom > meadow > gloom > storm/ember > frost" % sd,
		share["bloom"] > share["meadow"] and share["meadow"] > share["gloom"] and share["gloom"] > share["storm"] \
		and share["gloom"] > share["ember"] and share["storm"] > share["frost"] and share["ember"] > share["frost"])
	var shard_bare := true
	for i in w.w * w.h:
		if w.bush.has(i) and String(w.islands[w.island[i]].get("id", "")) == "shard": shard_bare = false
	ok("seed %d: Shard Perch stays bare" % sd, shard_bare)

# ------------------------------------------------------------------ patches (8-way components)
func _components(w: World) -> Array:
	var out: Array = []
	var seen := {}
	for bi in w.bush:
		if seen.has(bi) or w.kind[bi] != World.T_GROUND: continue
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
					if not w.inb(nx, nz): continue
					var ni := w.idx(nx, nz)
					if w.bush.has(ni) and not seen.has(ni) and w.kind[ni] == World.T_GROUND:
						seen[ni] = true
						q.append(ni)
		out.append(tiles)
	return out

# ------------------------------------------------------------------ 2. placement
func _placement(w: World, sd: int) -> void:
	var comps := _components(w)
	var small := comps.filter(func(c): return (c as Array).size() < 4).size()
	ok(
			"seed %d: %d patches, none a single tuft" % [sd, comps.size()], small == 0 and comps.size() >= 30,
			"%d under 4 tiles" % small)
	var bad_stair := 0
	var bad_bridge := 0
	for bi in w.bush:
		var x: int = bi % w.w
		var z: int = bi / w.w
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if not w.inb(x + dx, z + dz): continue
				var j := w.idx(x + dx, z + dz)
				if w.stairs.has(j): bad_stair += 1
				if w.bridge.has(j): bad_bridge += 1
	ok(
			"seed %d: no cover on or beside stairs, ramps or bridges" % sd, bad_stair == 0 and bad_bridge == 0,
			"stairs %d bridges %d" % [bad_stair, bad_bridge])
	var bad_land := 0
	for bi in w.bush:
		var p := Vector2(bi % w.w + 0.5, bi / w.w + 0.5)
		for s in w.spawns:
			if p.distance_to(Vector2(s.x, s.z)) < 5.0: bad_land += 1
		for ed in w.exit_defs:
			var e: Vector3 = ed["pos"]
			if p.distance_to(Vector2(e.x, e.z)) < 3.0: bad_land += 1
	ok("seed %d: no cover in a landing's drop circle or at an exit" % sd, bad_land == 0, "%d tiles" % bad_land)
	var off := 0
	var where: Array = []
	for bi in w.bush:
		if w.kind[bi] != World.T_GROUND or w.island[bi] < 0:
			off += 1
			if where.size() < 4: where.append("(%d,%d) kind %d" % [bi % w.w, bi / w.w, w.kind[bi]])
	ok("seed %d: every cover tile is open ground" % sd, off == 0, "%d off: %s" % [off, ", ".join(where)])

# ------------------------------------------------------------------ 3. in sight of every way out
func _sight(w: World, sd: int) -> void:
	var comps := _components(w)
	var missing: Array = []
	var seen_n := 0
	for ed in w.exit_defs:
		var e: Vector3 = ed["pos"]
		var b := w.biome_at(e.x, e.z)
		if not BUSH_BIOMES.has(b): continue
		seen_n += 1
		var found := false
		for c in comps:
			for t in c:
				var p := Vector3(t.x + 0.5, w.ground_at(t.x + 0.5, t.y + 0.5), t.y + 0.5)
				if Vector2(p.x - e.x, p.z - e.z).length() <= 14.0 \
						and w.los(Vector3(e.x, e.y + 1.0, e.z), Vector3(p.x, e.y + 1.0, p.z), e.y + 1.0):
					found = true
					break
			if found: break
		if not found:
			var nd := 999.0
			var nlos := 0
			for c in comps:
				for t in c:
					var dd := Vector2(t.x + 0.5 - e.x, t.y + 0.5 - e.z).length()
					nd = minf(nd, dd)
					if dd <= 14.0 and w.los(Vector3(
							e.x, e.y + 1.0, e.z), Vector3(t.x + 0.5, e.y + 1.0, t.y + 0.5), e.y + 1.0): nlos += 1
			missing.append("%s at (%d,%d) %s nearest %.1f m, %d in sight" % [ed["kind"], e.x, e.z, b, nd, nlos])
	ok(
			"seed %d: a patch in sight of each of the %d exits in bush biomes" % [sd, seen_n],
			missing.is_empty() and seen_n >= 6, ", ".join(missing))

## Ambush play: in the bush biomes most chests and camps have a patch beside them (within 7 m).
func _ambush(w: World, sd: int) -> void:
	var spots: Array = []
	for c in w.chest_spots: spots.append(c["pos"])
	for c in w.camp_spots: spots.append(c["pos"])
	var tot := 0
	var near := 0
	for p in spots:
		if not ["bloom", "meadow"].has(w.biome_at(p.x, p.z)): continue
		tot += 1
		var hit := false
		for dz in range(-7, 8):
			for dx in range(-7, 8):
				if dx * dx + dz * dz > 49: continue
				var x := int(floor(p.x)) + dx
				var z := int(floor(p.z)) + dz
				if w.inb(x, z) and w.bush.has(w.idx(x, z)):
					hit = true
					break
			if hit: break
		if hit: near += 1
	ok(
			"seed %d: bloom/meadow chests and camps with cover beside them" % sd, tot > 0 and near * 4 >= tot * 3,
			"%d of %d" % [near, tot])

# ------------------------------------------------------------------ 4. paths stay open
func _paths(w: World, sd: int) -> void:
	var cut: Array = []
	var no_path := 0
	var lost: Array = []
	var pairs := 0
	for ii in w.islands.size():
		var goals: Array = []
		for c in w.chest_spots:
			if w.island_of(c["pos"].x, c["pos"].z) == ii:
				goals.append(c["pos"])
		for ed in w.exit_defs:
			if w.island_of(ed["pos"].x, ed["pos"].z) == ii:
				goals.append(ed["pos"])
		var starts: Array = w.spawns.filter(func(s): return w.island_of(s.x, s.z) == ii)
		for s in starts:
			for g in goals:
				pairs += 1
				if not _free_walk(w, s, g): cut.append("%s -> (%d,%d)" % [w.islands[ii].get("id", ii), g.x, g.z])
				# the A* is windowed and capped, so a climb up a plateau's stairs is out of its reach:
				# same-height pairs only
				if absf(s.y - g.y) < 0.5 and KinPath.find(w, s, g, 14).is_empty() \
						and Vector2(s.x - g.x, s.z - g.z).length() > 1.5:
					no_path += 1
					lost.append("(%d,%d)->(%d,%d)" % [s.x, s.z, g.x, g.z])
	ok("seed %d: bush never closes a path (%d landing walks)" % [sd, pairs], cut.is_empty(), ", ".join(cut.slice(0, 4)))
	ok(
			"seed %d: the tile A* still finds every same-height one of them" % sd, no_path == 0,
			"%d without a path %s" % [no_path, ", ".join(lost.slice(0, 4))])

## A walk from a to b on open ground that never steps into tall grass (stairs and plateaus included).
func _free_walk(w: World, a: Vector3, b: Vector3) -> bool:
	var s := Vector2i(int(a.x), int(a.z))
	var g := Vector2i(int(b.x), int(b.z))
	var seen := {s: true}
	var q: Array = [s]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		if absi(cur.x - g.x) <= 1 and absi(cur.y - g.y) <= 1: return true
		for dv in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nx: Vector2i = cur + dv
			if seen.has(nx) or not w.inb(nx.x, nx.y): continue
			var ni := w.idx(nx.x, nx.y)
			if w.kind[ni] != World.T_GROUND or w.bush.has(ni): continue
			if absi(int(w.level[ni]) - int(w.level[w.idx(cur.x, cur.y)])) > 2: continue
			seen[nx] = true
			q.append(nx)
	return false

# ------------------------------------------------------------------ 5. somewhere for a Shrubling to live
func _homes(w: World, sd: int) -> void:
	var comps := _components(w)
	var centres: Array = []
	for c in comps:
		var s := Vector2.ZERO
		for t in c: s += Vector2(t.x + 0.5, t.y + 0.5)
		centres.append(s / float((c as Array).size()))
	var sprint: float = KeyRun.rules()["shrubling"]["sprint_r"]
	var spots := {}
	for c in comps:
		for t in c:
			var p := Vector2(t.x + 0.5, t.y + 0.5)
			var near := 0
			for cc in centres:
				if p.distance_to(cc) <= sprint: near += 1
			if near >= 3:
				var b := w.biome_at(p.x, p.y)
				spots[b] = int(spots.get(b, 0)) + 1
	var line := ""
	for b in BUSH_BIOMES: line += " %s %d" % [b, int(spots.get(b, 0))]
	var every_bush_biome := ["bloom", "meadow", "gloom", "storm"].all(func(b): return int(spots.get(b, 0)) > 0)
	ok("seed %d: bush biomes have cover spots with 3+ patches in sprint range" % sd, every_bush_biome, line)
