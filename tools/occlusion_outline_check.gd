extends RefCounted
## --occlusion-outline-check: your side (you, your teammate, your Boki) wears the cover outline and a rival
## never does; Low takes it off again. --occlusion-outline-shots --shots-dir=<dir> (needs a GPU renderer):
## on the Hollow Crown, you and a teammate stand behind a cliff and two trees with a rival
## beside you, once with the outline (<cover>_on.png) and once without it (<cover>_off.png), cropped round the pair.

const DT := 1.0 / 60.0
const SIDE := 0.9          # m: you and your teammate stand this far either side of the cover's line
const BEHIND := 1.6         # m: how far past a tree they stand (the camera looks steeply down)

var main: Node
var m: Match
var P: Hunter
var failed := 0

func run(main_node: Node, mode := "check") -> void:
	main = main_node
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": 77, "no_drop": true, "map": "hollowcrown"})
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	if main.get("fade") != null:
		await main.get("fade").reveal(0.01)
	if mode == "shots":
		await _shots()
	else:
		await _check()
	main.get_tree().quit(1 if failed > 0 else 0)

func _covered(e: Node3D) -> bool:
	for n in e.model.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).material_overlay != null:
			return true
	return false

func _expect(what: String, ok: bool) -> void:
	print("OCCLUSION %s %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		failed += 1

func _check() -> void:
	await _go(0.2)
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var rival: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	_expect("you wear the outline", _covered(P))
	_expect("your teammate wears it", _covered(mate))
	_expect("a rival does not", not _covered(rival))
	if P.kin != null:
		_expect("your Boki wears it", _covered(P.kin))
	Settings.v["quality"] = "low"
	await _go(0.1)
	_expect("Low takes it off", not _covered(P) and not _covered(mate))
	Settings.v["quality"] = "medium"
	await _go(0.1)
	_expect("medium puts it back", _covered(P) and _covered(mate))

func _shots() -> void:
	var dir := ""
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
	DirAccess.make_dir_recursive_absolute(dir)
	P.teleport(m.world.random_ground())
	m.cam.snap(P.pos)
	var off := m.cam.global_position - P.pos      # the camera's fixed offset from what it follows
	m.hud.visible = false
	var covers := {"cliff": _cliff_spot(off), "tree": _prop_spot(off, m.world.tree_spots)}
	covers["tree2"] = _prop_spot(off, m.world.tree_spots.slice(m.world.tree_spots.size() / 2))
	var mate: Hunter = m.hunters.filter(func(x): return x.team == P.team and x != P)[0]
	var rival: Hunter = m.hunters.filter(func(x): return x.team != P.team)[0]
	for cover in covers:
		var g: Vector3 = covers[cover]
		var side := Vector3(off.z, 0, -off.x).normalized() * SIDE
		P.teleport(g + side)
		mate.teleport(g - side)
		rival.teleport(g - side * 6.0)
		await _go(0.5)
		_take(dir, cover + "_on", g)
		_strip(P)
		_strip(mate)
		await main.get_tree().process_frame
		await main.get_tree().process_frame
		_take(dir, cover + "_off", g)
		P.set_meta("occ", 0)       # so the next cover's first shot gets the line back
		mate.set_meta("occ", 0)
	print("OCCLUSIONSHOTS %d in %s" % [covers.size() * 2, dir])

## A zoomed crop round the pair behind the cover, so the line reads.
func _take(dir: String, file: String, g: Vector3) -> void:
	var c := m.cam.unproject_position(g + Vector3(0, 1.0, 0))
	var r := Rect2i(Vector2i(c) - Vector2i(150, 110), Vector2i(300, 220))
	var img := main.get_viewport().get_texture().get_image()
	var crop := img.get_region(r.intersection(Rect2i(Vector2i.ZERO, img.get_size())))
	crop.resize(crop.get_width() * 3, crop.get_height() * 3, Image.INTERPOLATE_NEAREST)
	crop.save_png(dir.path_join(file + ".png"))

func _strip(h: Node3D) -> void:
	for n in h.model.find_children("*", "MeshInstance3D", true, false):
		(n as MeshInstance3D).material_overlay = null

## The ground tile a cliff covers best from the camera: the most terrain standing above the line of
## sight to a hunter's torso (0.3 m up), sampled along the camera's side of the tile.
func _cliff_spot(off: Vector3) -> Vector3:
	var w: World = m.world
	var best := -99.0
	var at := Vector3.ZERO
	for z in range(4, w.h - 4):
		for x in range(4, w.w - 4):
			if w.kind[w.idx(x, z)] != World.T_GROUND:
				continue
			var g := Vector3(x + 0.5, w.ground_at(x + 0.5, z + 0.5), z + 0.5)
			var over := -99.0
			for s in range(1, 25):
				var d := float(s) * 0.25
				var q := g + Vector3(0, 0.3, 0) + off * (d / Vector2(off.x, off.z).length())
				over = maxf(over, w.ground_at(q.x, q.z) - q.y)
			if over > best:
				best = over
				at = g
	print("OCCLUSION cliff: terrain %.1f m above the sight line at %s" % [best, at])
	return at

## Open ground BEHIND a prop, as the camera sees it.
func _prop_spot(off: Vector3, spots: Array) -> Vector3:
	var away := Vector3(-off.x, 0, -off.z).normalized() * BEHIND
	for s in spots:
		var g: Vector3 = m.world.free_spot_near((s as Vector3) + away, [], 1.0, 0.4, 1.5)
		if g.distance_to((s as Vector3) + away) < 0.5 and absf(g.y - (s as Vector3).y) < 0.3:
			return g
	return m.world.random_ground()

func _go(secs: float) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		OcclusionOutline.for_match(m)
		await main.get_tree().process_frame
