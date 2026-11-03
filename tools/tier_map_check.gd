extends RefCounted
## --tier-map-check: the top tier's own map, the Riven Wilds (docs/decisions/0014-tier-map.md, built by
## tools/make_riven.py), checked on the real world:
##   1. the tier picks the map: the Meadow and the Dusk Isles stay on the Hollow Crown, the Hollow is
##      on the Riven Wilds, which is 2-3x the Hollow Crown's area
##   2. harder monsters there: the map's threat folds into the tier (strength, camp size, rarer monsters)
##   3. high ground is terrain you walk up: from the landings, on foot (stairs, bridges, a climb of up to
##      CLIMB terraces), no walkable surface is left higher than its surroundings; no jump pads or
##      updrafts lead anywhere you can't walk to
##   4. the camera at every high spot: standing on it your hunter stays in view, and round its foot only
##      a cliff you stand right against hides you
##   5. the sky train winds (not a ring), runs over open air except under bridges, and every stop's
##      pier walks to a landing and a way out
## --tier-map-perf: the Riven Wilds' load and frame cost against the Hollow Crown's (see _perf).
## The parts that read a map take --map=<id> (the Hollow Crown and Skyreach are reported, not judged).

const CLIMB := 2            # terraces a hunter gets up without stairs (a jump and a mantle: 1.6 m)
const HIGH := 4             # terraces: a "high spot" is ground this far up (3.2 m), where the camera is tested
const CLIFF_HUG := 2.0      # m: round a high spot, only a cliff this close to you may hide you from the camera
const STOP_WALK := 60       # tiles: from a train stop's pier, the walk to a landing and to a way out
const AREA_MIN := 2.0       # the Riven Wilds against the Hollow Crown: map area and walkable ground
const AREA_MAX := 3.0

var main: Node
var fails := 0
var n := 0

func ok(label: String, cond: bool, info := "") -> void:
	n += 1
	print("TIERMAP %-70s %s  %s" % [label, "PASS" if cond else "FAIL", info])
	if not cond: fails += 1

func run(main_node: Node, mode := "all") -> void:
	main = main_node
	Save.no_write = true
	if mode == "perf":
		await load("res://tools/tier_map_perf.gd").new().run(self)
	else:
		var id := _map_arg()
		if id == "":
			_tiers()
			await _threat()
			id = "riven"
		_map(id)
	print("TIERMAP DONE, %d checks, failures: %d" % [n, fails])
	main.get_tree().quit()

func _map_arg() -> String:
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--map="): return String(a).substr(6)
	return ""

## A world built from an authored map, as a match builds it (no meshes).
static func world_of(id: String, seed_i := 9) -> World:
	var w := World.new()
	w.generate_authored(World.load_layout(id), seed_i)
	return w

# ------------------------------------------------------------------ 1. tier -> map
func _tiers() -> void:
	var names: Array = []
	for t in Data.TIERS.size(): names.append(World.layout_for_tier(t))
	ok("tiers 0-1 keep the Hollow Crown, the Hollow gets the Riven Wilds",
		names == ["hollowcrown", "hollowcrown", "riven"], str(names))
	var hc := world_of("hollowcrown")
	var rv := world_of("riven")
	var area := float(rv.w * rv.h) / float(hc.w * hc.h)
	var ground := float(_ground(rv)) / float(_ground(hc))
	ok("the Riven Wilds is %.2fx the Hollow Crown's area, %.2fx its ground" % [area, ground],
		area >= AREA_MIN and area <= AREA_MAX and ground >= AREA_MIN and ground <= AREA_MAX)
	var counts := func(w: World) -> Array:
		var landmarks := w.labels.filter(func(l): return l["kind"] == "poi").size()
		return [w.chest_spots.size(), w.camp_spots.size(), w.spawns.size(), w.exit_defs.size(), w.lair_defs.size(),
			landmarks]
	var a: Array = counts.call(hc)
	var b: Array = counts.call(rv)
	var scaled := true
	for i in a.size():
		if float(b[i]) < float(a[i]) * 1.6: scaled = false
	ok("chests, camps, landings, exits, lairs and landmarks scale with it", scaled, "%s -> %s" % [str(a), str(b)])
	hc.free()
	rv.free()

func _ground(w: World) -> int:
	var c := 0
	for i in w.w * w.h:
		if w.kind[i] != World.T_VOID: c += 1
	return c

# ------------------------------------------------------------------ 2. harder monsters
func _threat() -> void:
	var L := World.load_layout("riven")
	var th: Dictionary = L.get("threat", {})
	var t2 := MapThreat.apply(Data.TIERS[2], L)
	var want_mob := float(Data.TIERS[2]["mob"]) * float(th.get("mob", 0.0))
	ok("the Riven Wilds' threat multiplies the tier's monster strength",
		absf(float(t2["mob"]) - want_mob) < 0.001 and float(th.get("mob", 0.0)) > 1.0,
		"x%.2f -> %.2f" % [float(th.get("mob", 0.0)), float(t2["mob"])])
	ok("the Hollow Crown adds none", MapThreat.apply(Data.TIERS[1], World.load_layout("hollowcrown")) == Data.TIERS[1])
	var rare := {}
	var camp := {}
	for id in ["hollowcrown", "riven"]:
		var m := Match.new()
		main.add_child(m)
		m.start({"teams": 2, "squad": 1, "tier": 2, "seed": 77, "no_drop": true, "map": id})
		m.set_process(false)
		var sum := 0.0
		for mb in m.mobs: sum += float(mb.get_meta("rarity", 0))
		rare[id] = sum / maxf(1.0, m.mobs.size())
		var c0: Dictionary = m.world.camp_spots[0]
		var light: int = m.biomes.camp_comp({"pos": c0["pos"], "kind": "light"}).size()
		camp[id] = [light, m.biomes.camp_comp({"pos": c0["pos"], "kind": "heavy"}).size()]
		if id == "riven":
			ok("a Hollow match is on the Riven Wilds",
				m.world.layout_id == "riven" and absf(float(m.T["mob"]) - float(t2["mob"])) < 0.001)
		m.free()
	ok("camps are one monster bigger there (light, heavy)",
		camp["riven"][0] == camp["hollowcrown"][0] + 1 and camp["riven"][1] == camp["hollowcrown"][1] + 1,
		"%s vs %s" % [str(camp["riven"]), str(camp["hollowcrown"])])
	ok("and its monsters roll rarer", float(rare["riven"]) > float(rare["hollowcrown"]),
		"mean rarity %.2f vs %.2f" % [float(rare["riven"]), float(rare["hollowcrown"])])

# ------------------------------------------------------------------ 3-5. one map
func _map(id: String) -> void:
	var w := world_of(id)
	var judged := id == "riven"
	var from: Array = w.spawns
	var dist := walk(w, from)
	_high_ground(w, dist, judged)
	_air_links(w, dist, judged)
	_camera(w, judged)
	if not w.train_route.is_empty():
		_train(w, judged)
	elif judged:
		ok("the map has a sky train", false)
	w.free()

## Steps on foot from the nearest start to every tile (-1: not reached): 4-way, onto ground no more
## than CLIMB terraces up, any drop down.
static func walk(w: World, from: Array) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(w.w * w.h)
	dist.fill(-1)
	var queue := PackedInt32Array()
	for p: Vector3 in from:
		var i := w.idx(int(p.x), int(p.z))
		if w.inb(int(p.x), int(p.z)) and w.kind[i] == World.T_GROUND and dist[i] < 0:
			dist[i] = 0
			queue.append(i)
	var head := 0
	while head < queue.size():
		var i := queue[head]
		head += 1
		var x := i % w.w
		var z := i / w.w
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if not w.inb(x + d.x, z + d.y):
				continue
			var j := w.idx(x + d.x, z + d.y)
			if dist[j] >= 0 or w.kind[j] != World.T_GROUND or int(w.level[j]) - int(w.level[i]) > CLIMB:
				continue
			dist[j] = dist[i] + 1
			queue.append(j)
	return dist

func _report(label: String, cond: bool, judged: bool, info := "") -> void:
	if judged:
		ok(label, cond, info)
	else:
		print("TIERMAP %-70s %s  %s" % [label, "ok" if cond else "(not judged here)", info])

## Walkable ground nobody can walk to, in pieces: a piece more than CLIMB terraces above the reached
## ground round it (or a floating piece of its own) is an isolated high surface.
func _high_ground(w: World, dist: PackedInt32Array, judged: bool) -> void:
	var seen := {}
	var bad: Array = []
	var pockets := 0
	for i in w.w * w.h:
		if w.kind[i] != World.T_GROUND or dist[i] >= 0 or seen.has(i):
			continue
		var piece := _piece(w, dist, i, seen)
		var top := 0
		for j: int in piece: top = maxi(top, int(w.level[j]))
		var below := _reached_below(w, dist, piece)
		if below < 0 or top - below > CLIMB:
			var where := w.island_id((piece[0] % w.w) + 0.5, (piece[0] / w.w) + 0.5)
			bad.append("%s %d tiles at %.1f m (round it %s)" % [where, piece.size(), top * World.LEVEL,
				"nothing" if below < 0 else "%.1f m" % (below * World.LEVEL)])
		else:
			pockets += 1
	_report("no isolated high ground: every height is walked up (%d low pockets)" % pockets, bad.is_empty(), judged,
		", ".join(bad.slice(0, 4)))

func _piece(w: World, dist: PackedInt32Array, start: int, seen: Dictionary) -> Array:
	var out: Array = [start]
	seen[start] = true
	var head := 0
	while head < out.size():
		var i: int = out[head]
		head += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var x := i % w.w + d.x
			var z := i / w.w + d.y
			if not w.inb(x, z):
				continue
			var j := w.idx(x, z)
			if not seen.has(j) and w.kind[j] == World.T_GROUND and dist[j] < 0:
				seen[j] = true
				out.append(j)
	return out

## The lowest reached ground within 3 tiles of a piece, or -1 when nothing reached is near it.
func _reached_below(w: World, dist: PackedInt32Array, piece: Array) -> int:
	var low := 99
	for i: int in piece:
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var x := i % w.w + dx
				var z := i / w.w + dz
				if w.inb(x, z) and dist[w.idx(x, z)] >= 0:
					low = mini(low, int(w.level[w.idx(x, z)]))
	return -1 if low == 99 else low

## Jump pads and updrafts: none on the Riven Wilds, and wherever a map has them, never the only way.
func _air_links(w: World, dist: PackedInt32Array, judged: bool) -> void:
	_report("no jump pads or updraft towers (%d pads, %d updrafts)" % [w.pads.size(), w.updrafts.size()],
		w.pads.is_empty() and w.updrafts.is_empty(), judged)
	var only: Array = []
	for pd in w.pads:
		var reached := false
		for c: Vector2i in w.islands[int(pd["to"])]["cells"]:
			if dist[w.idx(c.x, c.y)] >= 0: reached = true
		if not reached: only.append(String(w.islands[int(pd["to"])]["name"]))
	_report("no jump pad is the only way onto an island", only.is_empty(), judged, ", ".join(only))

## Where the match camera (CamRig's default style) sits for a hunter standing at a tile, and whether the
## line to their chest clears the terrain. Returns the horizontal distance (m) to what hides them, or -1.
static func hidden_by(w: World, x: int, z: int) -> float:
	var st: Dictionary = CamRig.STYLES["supervive"]
	var pitch := deg_to_rad(float(st["pitch"]))
	var feet := Vector3(x + 0.5, w.level[w.idx(x, z)] * World.LEVEL, z + 0.5)
	var aim := Vector3(feet.x, maxf(feet.y * 0.6, feet.y - 4.0) + float(st.get("rise", 0.0)), feet.z)
	var cam := aim + Vector3(0, sin(pitch), cos(pitch)) * float(st["dist"])
	var chest := feet + Vector3(0, 1.0, 0)
	var d := cam - chest
	var flat := Vector2(d.x, d.z).length()
	var t := 0.6 / flat
	while t < 1.0:
		var p := chest + d * t
		if p.y > 20 * World.LEVEL:
			break
		var tx := int(floor(p.x))
		var tz := int(floor(p.z))
		if w.inb(tx, tz) and w.kind[w.idx(tx, tz)] != World.T_VOID and w.level[w.idx(tx, tz)] * World.LEVEL > p.y:
			return flat * t
		t += 0.2 / flat
	return -1.0

## Every high spot (and the ground round its foot) with the camera's own sight line.
func _camera(w: World, judged: bool) -> void:
	var on_high := 0
	var on_hidden: Array = []
	var foot := 0
	var foot_far: Array = []
	var near_high := {}
	for z in w.h:
		for x in w.w:
			var i := w.idx(x, z)
			if w.kind[i] != World.T_GROUND or w.level[i] < HIGH:
				continue
			on_high += 1
			var hb := hidden_by(w, x, z)
			if hb >= 0.0: on_hidden.append(Vector2i(x, z))
			for dz in range(-5, 6):
				for dx in range(-5, 6):
					if not w.inb(x + dx, z + dz):
						continue
					var j := w.idx(x + dx, z + dz)
					if w.kind[j] == World.T_GROUND and w.level[j] <= w.level[i] - CLIMB:
						near_high[j] = true
	for j: int in near_high:
		foot += 1
		var hb := hidden_by(w, j % w.w, j / w.w)
		if hb > CLIFF_HUG: foot_far.append(Vector2i(j % w.w, j / w.w))
	_report("the camera sees you on every high spot (%d tiles)" % on_high, on_hidden.is_empty(), judged,
		str(on_hidden.slice(0, 4)))
	_report("and round their feet only a cliff you hug hides you (%d tiles)" % foot, foot_far.is_empty(), judged,
		str(foot_far.slice(0, 4)))

## The loop's shape, where it runs, and its stops.
func _train(w: World, judged: bool) -> void:
	var R: Dictionary = w.train_route
	var pts: PackedVector3Array = R["pts"]
	var mid := Vector2(w.w * 0.5, w.h * 0.5)
	var near := INF
	var far := 0.0
	for p in pts:
		var r := Vector2(p.x, p.z).distance_to(mid)
		near = minf(near, r)
		far = maxf(far, r)
	_report("the train winds: %.0f-%.0f m from the middle over a %.0f m loop" % [near, far, float(R["len"])],
		far - near >= 25.0, judged)
	var rims: Array = []
	var dives := 0
	var was_low := false
	for k in pts.size():
		var low := pts[k].y < -0.1
		if low and not was_low: dives += 1
		was_low = low
		if low or k % 4 != 0 or _at_stop(R, k * World.TRAIN_STEP):
			continue
		for dz in range(-3, 4):
			for dx in range(-3, 4):
				var q := Vector2i(int(pts[k].x) + dx, int(pts[k].z) + dz)
				if not w.inb(q.x, q.y) or w.kind[w.idx(q.x, q.y)] == World.T_VOID or w.depth[w.idx(q.x, q.y)] == -1.6:
					continue
				if Vector2(q.x + 0.5, q.y + 0.5).distance_to(Vector2(pts[k].x, pts[k].z)) < 2.9:
					rims.append(q)
	_report("it runs over open air, dipping under %d bridges, never through a rim" % dives, rims.is_empty(), judged,
		str(rims.slice(0, 4)))
	var exits: Array = []
	for e in w.exit_defs: exits.append(e["pos"])
	var names: Array = R["names"]
	for si in (R["stations"] as Array).size():
		var at: Vector3 = w.train_at(float(R["stations"][si]))
		var start := _pier_tile(w, Vector2(at.x, at.z))
		var dist := walk(w, [start]) if start != Vector3.INF else PackedInt32Array()
		var to_land := _steps_to(w, dist, w.spawns)
		var to_exit := _steps_to(w, dist, exits)
		var stop := String(names[si]) if si < names.size() else "stop"
		_report("%s: the pier walks to a landing (%d m) and a way out (%d m)" % [stop, to_land, to_exit],
			to_land >= 0 and to_land <= STOP_WALK and to_exit >= 0 and to_exit <= STOP_WALK, judged)

## Within 5 m of a stop the cars run level with the ground beside its pier (TrainRoute._deck_heights).
func _at_stop(R: Dictionary, s: float) -> bool:
	var loop := float(R["len"])
	for ss in R["stations"]:
		if absf(fposmod(s - float(ss) + loop * 0.5, loop) - loop * 0.5) < 5.0:
			return true
	return false

func _pier_tile(w: World, at: Vector2) -> Vector3:
	var best := Vector3.INF
	var best_d := 6.0
	for dz in range(-6, 7):
		for dx in range(-6, 7):
			var x := int(at.x) + dx
			var z := int(at.y) + dz
			var dd := Vector2(x + 0.5, z + 0.5).distance_to(at)
			if w.inb(x, z) and w.kind[w.idx(x, z)] == World.T_GROUND and dd < best_d:
				best_d = dd
				best = Vector3(x + 0.5, 0, z + 0.5)
	return best

func _steps_to(w: World, dist: PackedInt32Array, spots: Array) -> int:
	var best := -1
	for p: Vector3 in spots:
		if dist.is_empty() or not w.inb(int(p.x), int(p.z)):
			continue
		var dd := dist[w.idx(int(p.x), int(p.z))]
		if dd >= 0 and (best < 0 or dd < best): best = dd
	return best
