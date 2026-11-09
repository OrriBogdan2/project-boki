extends RefCounted
## --depth-shots --shots-dir=<dir> [--seed=N]: the same framing at three height situations, to judge how
## readable height and drops are (briefs/CAMERA_DEPTH.md). Live match, one hunter on the near ground
## and another across the drop:
##   depth_a_edge   standing a metre from a cliff edge over the abyss
##   depth_b_step   at the top of a terrace step, a hunter on the lower tier
##   depth_c_low    the same step from below, looking up at a hunter on the upper tier
## --edge-read adds (instead) five edges on the Hollow Crown, 3 abyss and 2 terrace lips, spread over the map and
## taken from the match camera with the hunter on the lip tile: edge_1..3_abyss, edge_4..5_terrace.

const DT := 1.0 / 60.0
const SETTLE := 0.5     # s of match time before each capture

var main: Node
var m: Match
var P: Hunter
var dir := ""
var seed_v := 77

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--seed="): seed_v = int(String(a).substr(7))
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var w := m.world
	if "--edge-read" in OS.get_cmdline_user_args():
		await _edge_read()
		print("DEPTHSHOTS in %s" % dir)
		main.get_tree().quit(0)
		return
	var edge := _find(func(x, z, d): return w.kind[w.idx(x + d.x, z + d.y)] == World.T_VOID)
	var step := _find(func(x, z, d): return _step_to(w, x, z, d) >= 2)
	await _shoot("depth_a_edge", edge[0], edge[1], edge[2])
	await _shoot("depth_b_step", step[0], step[1], step[2])
	var low: Vector2i = step[0] + step[1] * 2
	await _shoot("depth_c_low", low, -step[1], step[0] - step[1])
	print("DEPTHSHOTS in %s" % dir)
	main.get_tree().quit(0)

## How many terrace levels lower the ground one tile from (x, z) along d lies (0 when it is not ground).
func _step_to(w: World, x: int, z: int, d: Vector2i) -> int:
	if not w.inb(x + d.x, z + d.y) or w.kind[w.idx(x + d.x, z + d.y)] != World.T_GROUND: return 0
	return int(w.level[w.idx(x, z)]) - int(w.level[w.idx(x + d.x, z + d.y)])

## First roomy ground tile (scanning from the middle out) with a neighbour that passes `test`:
## [tile, direction to the neighbour, tile the other hunter stands on].
func _find(test: Callable) -> Array:
	var found := _find_spread(test, 1, 0)
	var w := m.world
	return found[0] if not found.is_empty() else [Vector2i(w.w / 2, w.h / 2), Vector2i(0, 1), Vector2i(w.w / 2, w.h / 2 - 3)]

## Up to `count` such tiles, each at least `apart` tiles from the ones before it.
func _find_spread(test: Callable, count: int, apart: int) -> Array:
	var w := m.world
	var out: Array = []
	for r in range(0, w.w / 2 - 3):
		for z in range(w.h / 2 - r, w.h / 2 + r + 1):
			for x in range(w.w / 2 - r, w.w / 2 + r + 1):
				if w.kind[w.idx(x, z)] != World.T_GROUND or not w.roomy(x, z): continue
				if out.any(func(o): return Vector2(o[0]).distance_to(Vector2(x, z)) < apart): continue
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if w.inb(x + d.x, z + d.y) and test.call(x, z, d):
						out.append([Vector2i(x, z), d, Vector2i(x, z) - d * 3])
						break
				if out.size() >= count: return out
	return out

func _edge_read() -> void:
	var w := m.world
	var abyss := _find_spread(func(x, z, d): return w.kind[w.idx(x + d.x, z + d.y)] == World.T_VOID, 3, 24)
	var lips := _find_spread(func(x, z, d): return _step_to(w, x, z, d) >= 1, 2, 24)
	for i in abyss.size():
		await _shoot("edge_%d_abyss" % (i + 1), abyss[i][0], abyss[i][1], abyss[i][2])
	for i in lips.size():
		await _shoot("edge_%d_terrace" % (i + 4), lips[i][0], lips[i][1], lips[i][2])

func _shoot(file: String, tile: Vector2i, d: Vector2i, foe_tile: Vector2i) -> void:
	var w := m.world
	P.teleport(Vector3(tile.x + 0.5, w.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5))
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var fy := w.ground_at(foe_tile.x + 0.5, foe_tile.y + 0.5)
	if fy > -1e8: foe.teleport(Vector3(foe_tile.x + 0.5, fy, foe_tile.y + 0.5))
	var t := 0.0
	while t < SETTLE:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(file + ".png"))

func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	await m.start({"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true})
	m.set_process(false)
	P = m.player
	for mb in m.mobs: mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null: await fade.reveal(0.01)
