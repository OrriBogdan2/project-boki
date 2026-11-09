extends RefCounted
## --current-check: every wind road and updraft in the map data has its visual (CurrentFx): one
## streak road (MultiMesh of cards from a to b, a ring at each end) or one column per entry of every
## authored map's "winds" / "updrafts" and of generated maps, placed where the data puts it; Low
## draws fewer streaks than High and never more than the cap; a road's index from World.wind_at is
## its node. With --shots-dir=<dir> (window): road_ground, road_glide, updraft_ground and
## updraft_ride in the Skyreach, as PNGs.

const MAPS := ["tutorial", "hollowcrown", "skyreach", "arena"]
const GEN_SEEDS := 12
const LOW_FX := 0.45     # the Low preset's fx (Settings.QUALITY)

var bad := 0
var n := 0
var main: Node

func ok(cond: bool, what: String) -> void:
	n += 1
	print("CURRENT %s %s" % ["ok  " if cond else "FAIL", what])
	if not cond: bad += 1

func run(m: Node) -> void:
	main = m
	Save.no_write = true
	var shots := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="): shots = a.substr(12)
	for id in MAPS:
		var L := World.load_layout(id)
		var w := World.new()
		await w.generate_authored(L, 3)
		_world(w, id, (L.get("winds", []) as Array).size(), (L.get("updrafts", []) as Array).size())
		w.free()
	for sd in range(1, GEN_SEEDS + 1):
		var w := World.new()
		w.generate(sd, 64, 7)
		_world(w, "generated %d" % sd, w.winds.size(), w.updrafts.size())
		w.free()
	if shots != "":
		await _shots(shots)
	print("CURRENT %d checks, %d failed" % [n, bad])
	print("CURRENT_DONE %s" % ("PASS" if bad == 0 else "FAIL"))
	m.get_tree().quit()

## One built world: a node per entry in the data (want_w / want_u are the data's own counts).
func _world(w: World, label: String, want_w: int, want_u: int) -> void:
	var counts := w.winds.size() == want_w and w.updrafts.size() == want_u
	ok(counts, "%s: the world places all %d wind roads and %d updrafts" % [label, want_w, want_u])
	var hi := CurrentFx.new()
	hi.build(w, 1.0)
	var lo := CurrentFx.new()
	lo.build(w, LOW_FX)
	var roads := hi.get_children().filter(func(c): return c.name.begins_with("Road"))
	var columns := hi.get_children().filter(func(c): return c.name.begins_with("Column"))
	var nodes := roads.size() == want_w and columns.size() == want_u
	ok(nodes, "%s: %d road and %d column nodes" % [label, roads.size(), columns.size()])
	var fewer := true
	var placed := true
	var capped := true
	var rings := true
	for i in w.winds.size():
		var road := hi.get_node("Road%d" % i) as Node3D
		var wd: Dictionary = w.winds[i]
		var span: float = (wd["b"] - wd["a"]).length()
		var far_end: Vector3 = road.transform * Vector3(span, 0, 0)
		placed = placed and road.position.is_equal_approx(wd["a"]) and far_end.is_equal_approx(wd["b"])
		var hi_n := _streaks(hi, i)
		var lo_n := _streaks(lo, i)
		var at_limit := hi_n == CurrentFx.MIN_STREAKS or hi_n == CurrentFx.MAX_STREAKS
		fewer = fewer and lo_n <= hi_n and (lo_n < hi_n or at_limit)
		capped = capped and hi_n >= CurrentFx.MIN_STREAKS and hi_n <= CurrentFx.MAX_STREAKS
		rings = rings and road.has_node("Ring0") and road.has_node("Ring1")
		var mid: Vector3 = (wd["a"] + wd["b"]) * 0.5
		var hit := w.wind_at(mid)
		rings = rings and not hit.is_empty() and w.winds[int(hit["i"])] == wd
	for i in w.updrafts.size():
		var c: Vector3 = w.updrafts[i]["pos"]
		var col := hi.get_node("Column%d" % i) as Node3D
		placed = placed and is_equal_approx(col.position.x, c.x) and is_equal_approx(col.position.z, c.z)
	ok(placed, "%s: every node sits where its road or updraft is (a to b, the column's foot)" % label)
	ok(capped and rings, "%s: each road has 6-48 streaks, a ring at both ends, and wind_at names it" % label)
	ok(fewer, "%s: Low draws fewer streaks than High" % label)
	hi.free()
	lo.free()

## How many streak cards road i has.
func _streaks(fx: CurrentFx, i: int) -> int:
	var streaks := fx.get_node("Road%d" % i).get_node("Streaks") as MultiMeshInstance3D
	return streaks.multimesh.instance_count

# ---------------------------------------------------------------- shots
func _shots(out: String) -> void:
	DirAccess.make_dir_recursive_absolute(out)
	var tree := main.get_tree()
	if main.get("fade") != null:
		await main.fade.reveal(0.01)
	var m := Match.new()
	main.add_child(m)
	await m.start({"teams": 1, "squad": 1, "tier": 0, "seed": 5, "no_drop": true, "god": true, "map": "skyreach",
			"length": 1e9})
	m.set_process(false)
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	var p := m.player
	var wd: Dictionary = m.world.winds[0]
	var a: Vector3 = wd["a"]
	var b: Vector3 = wd["b"]
	var fwd := (b - a).normalized()
	p.teleport(a - Vector3(0, 1.6, 0) - fwd * 4.0)
	await _frames(m, p, false, a + fwd * 8.0, 30)
	_save(main, out, "road_ground")
	var mid := a.lerp(b, 0.4)
	p.teleport(mid)
	p.vel = fwd * 14.0
	await _frames(m, p, true, mid + fwd * 2.0, 24)
	_save(main, out, "road_glide")
	var u: Dictionary = m.world.updrafts[0]
	var c: Vector3 = u["pos"]
	p.teleport(Vector3(c.x + 7.0, c.y + 1.0, c.z))
	await _frames(m, p, false, c + Vector3(0, 4, 0), 30)
	_save(main, out, "updraft_ground")
	p.teleport(Vector3(c.x, c.y + 3.0, c.z))
	await _frames(m, p, true, c + Vector3(0, 4, 0), 22)
	_save(main, out, "updraft_ride")
	ok(p.in_current, "the player rides the updraft in the shot")
	m.queue_free()

## Runs frames with the player gliding (or not) and the camera on a spot.
func _frames(m: Match, p: Hunter, glide: bool, look: Vector3, frames: int) -> void:
	for i in frames:
		p.inp["glide"] = glide
		if glide:
			p.gliding = true
			p.air_t = 1.0
		m.step(1.0 / 60.0)
		m.cam.snap(look)
		await main.get_tree().process_frame

func _save(node: Node, out: String, stem: String) -> void:
	node.get_viewport().get_texture().get_image().save_png(out.path_join(stem + ".png"))
