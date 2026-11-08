extends RefCounted
## --depth-shots --shots-dir=<dir> [--seed=N]: the same framing at three height situations, to judge how
## readable height and drops are (briefs/CAMERA_DEPTH.md). Live match, one hunter on the near ground
## and another across the drop:
##   depth_a_edge   standing a metre from a cliff edge over the abyss
##   depth_b_step   at the top of a terrace step, a hunter on the lower tier
##   depth_c_low    the same step from below, looking up at a hunter on the upper tier
##   depth_d_shots  the top of the step again with shots flying out over the lower tier (their drop shadows)
## --cues=off draws them with the height cues off, for the before shots (names get a "before_" prefix).

const DT := 1.0 / 60.0
const SETTLE := 0.5     # s of match time before each capture
const SHOTS := 4        # shots in the string of the shots capture
const SHOT_SPEED := 2.0 # m/s of those shots (slow, so they are still over the lower tier at the capture)

var main: Node
var m: Match
var P: Hunter
var dir := ""
var seed_v := 77
var prefix := ""

func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="): dir = String(a).substr(12)
		if String(a).begins_with("--seed="): seed_v = int(String(a).substr(7))
		if String(a) == "--cues=off":
			Settings.set_v("depth_cues", false, false)
			prefix = "before_"
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	var w := m.world
	var edge := _find(func(x, z, d): return w.kind[w.idx(x + d.x, z + d.y)] == World.T_VOID)
	var step := _find(func(x, z, d): return _step_to(w, x, z, d) >= 2)
	await _shoot("depth_a_edge", edge[0], edge[1], edge[2])
	await _shoot("depth_b_step", step[0], step[1], step[2])
	var low: Vector2i = step[0] + step[1] * 2
	await _shoot("depth_c_low", low, -step[1], step[0] - step[1])
	await _shoot("depth_d_shots", step[0], step[1], step[2], step[1])
	print("DEPTHSHOTS in %s" % dir)
	main.get_tree().quit(0)

## How many terrace levels lower the ground one tile from (x, z) along d lies (0 when it is not ground).
func _step_to(w: World, x: int, z: int, d: Vector2i) -> int:
	if not w.inb(x + d.x, z + d.y) or w.kind[w.idx(x + d.x, z + d.y)] != World.T_GROUND: return 0
	return int(w.level[w.idx(x, z)]) - int(w.level[w.idx(x + d.x, z + d.y)])

## First roomy ground tile (scanning from the middle out) with a neighbour that passes `test`:
## [tile, direction to the neighbour, tile the other hunter stands on].
func _find(test: Callable) -> Array:
	var w := m.world
	for r in range(0, w.w / 2 - 3):
		for z in range(w.h / 2 - r, w.h / 2 + r + 1):
			for x in range(w.w / 2 - r, w.w / 2 + r + 1):
				if w.kind[w.idx(x, z)] != World.T_GROUND or not w.roomy(x, z): continue
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if w.inb(x + d.x, z + d.y) and test.call(x, z, d):
						return [Vector2i(x, z), d, Vector2i(x, z) - d * 3]
	return [Vector2i(w.w / 2, w.h / 2), Vector2i(0, 1), Vector2i(w.w / 2, w.h / 2 - 3)]

func _shoot(file: String, tile: Vector2i, d: Vector2i, foe_tile: Vector2i, fire := Vector2i.ZERO) -> void:
	var w := m.world
	P.teleport(Vector3(tile.x + 0.5, w.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5))
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var fy := w.ground_at(foe_tile.x + 0.5, foe_tile.y + 0.5)
	if fy > -1e8: foe.teleport(Vector3(foe_tile.x + 0.5, fy, foe_tile.y + 0.5))
	if fire != Vector2i.ZERO:      # a string of shots leaving along `fire`, out over the lower tier
		for k in range(1, SHOTS + 1):
			var at := P.pos + Vector3(fire.x, 0.0, fire.y) * (0.5 + k * 0.9) + Vector3(0, 1.2, 0)
			m.spawn_shot(P, at, Vector2(fire) * SHOT_SPEED, 1.0, 5.0, 0.12, Color("ffd66b"))
	var t := 0.0
	while t < SETTLE:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters: h.render(DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(prefix + file + ".png"))

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
