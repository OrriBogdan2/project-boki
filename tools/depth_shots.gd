extends RefCounted
## --depth-shots --shots-dir=<dir> [--seed=N]: the same framing at three height situations, to judge how
## readable height and drops are (briefs/CAMERA_DEPTH.md). Live match, one hunter on the near ground
## and another across the drop:
##   depth_a_edge   standing a metre from a cliff edge over the abyss
##   depth_b_step   at the top of a terrace step, a hunter on the lower tier
##   depth_c_low    the same step from below, looking up at a hunter on the upper tier
##   depth_d_shots  the top of the step again with shots flying along the ledge (their drop shadows)
## --air --arch=<id>: instead, the player (that Hunter) on flat ground, standing (air_a_stand) and a moment
## after a jump (air_b_jump), at 1920x1080, to look at the shadow disc and ring under a Hunter in the air.
## --compat runs the same shots in a child game on the Compatibility renderer (the web and mobile look).
## --cues=off draws them with the height cues off, for the before shots (names get a "before_" prefix).

const DT := 1.0 / 60.0
const SETTLE := 0.5  # s of match time before each capture
const SHOTS := 5  # shots in the string of the shots capture
const JUMP_WAIT := 0.3  # s after the jump press for the --air capture
const SHOT_SPEED := 2.0  # m/s of those shots (slow, so they are still in frame at the capture)

var main: Node
var m: Match
var P: Hunter
var dir := ""
var seed_v := 77
var prefix := ""
var arch := ""


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--shots-dir="):
			dir = String(a).substr(12)
		if String(a).begins_with("--seed="):
			seed_v = int(String(a).substr(7))
		if String(a).begins_with("--arch="):
			arch = String(a).substr(7)
		if String(a) == "--ring-shadow=off":
			prefix += "noringsh_"
		if String(a) == "--cues=off":
			Settings.set_v("depth_cues", false, false)
			prefix += "before_"
	DirAccess.make_dir_recursive_absolute(dir)
	if "--compat" in OS.get_cmdline_user_args() and Look.full_renderer():
		_run_compat_child()
		main.get_tree().quit(0)
		return
	await _setup()
	var w := m.world
	if "--census" in OS.get_cmdline_user_args():
		await _census()
		main.get_tree().quit(0)
		return
	if "--air" in OS.get_cmdline_user_args():
		await _air_shots()
		main.get_tree().quit(0)
		return
	var edge := _find(func(x, z, d): return w.kind[w.idx(x + d.x, z + d.y)] == World.T_VOID)
	var step := _find(func(x, z, d): return _step_to(w, x, z, d) >= 2)
	await _shoot("depth_a_edge", edge[0], edge[1], edge[2])
	await _shoot("depth_b_step", step[0], step[1], step[2])
	var low: Vector2i = step[0] + step[1] * 2
	await _shoot("depth_c_low", low, -step[1], step[0] - step[1])
	await _shoot("depth_d_shots", step[0], step[1], step[2], Vector2i(-step[1].y, step[1].x))
	print("DEPTHSHOTS in %s" % dir)
	main.get_tree().quit(0)


## How many terrace levels lower the ground one tile from (x, z) along d lies (0 when it is not ground).
func _step_to(w: World, x: int, z: int, d: Vector2i) -> int:
	if not w.inb(x + d.x, z + d.y) or w.kind[w.idx(x + d.x, z + d.y)] != World.T_GROUND:
		return 0
	return int(w.level[w.idx(x, z)]) - int(w.level[w.idx(x + d.x, z + d.y)])


## First roomy ground tile (scanning from the middle out) with a neighbour that passes `test`:
## [tile, direction to the neighbour, tile the other hunter stands on].
func _find(test: Callable) -> Array:
	var w := m.world
	for r in range(0, int(w.w / 2.0) - 3):
		for z in range(int(w.h / 2.0) - r, int(w.h / 2.0) + r + 1):
			for x in range(int(w.w / 2.0) - r, int(w.w / 2.0) + r + 1):
				if w.kind[w.idx(x, z)] != World.T_GROUND or not w.roomy(x, z):
					continue
				for d in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0)]:
					if w.inb(x + d.x, z + d.y) and test.call(x, z, d):
						return [Vector2i(x, z), d, Vector2i(x, z) - d * 3]
	return [Vector2i(int(w.w / 2.0), int(w.h / 2.0)), Vector2i(0, 1), Vector2i(int(w.w / 2.0), int(w.h / 2.0) - 3)]


func _shoot(file: String, tile: Vector2i, d: Vector2i, foe_tile: Vector2i, fire := Vector2i.ZERO) -> void:
	var w := m.world
	P.teleport(Vector3(tile.x + 0.5, w.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5))
	var foe: Hunter = m.hunters.filter(func(x): return x != P)[0]
	var fy := w.ground_at(foe_tile.x + 0.5, foe_tile.y + 0.5)
	if fy > -1e8:
		foe.teleport(Vector3(foe_tile.x + 0.5, fy, foe_tile.y + 0.5))
	if fire != Vector2i.ZERO:  # a string of shots leaving along `fire`
		for k in range(1, SHOTS + 1):
			var at := P.pos + Vector3(fire.x, 0.0, fire.y) * (1.0 + k * 1.1) + Vector3(0, 1.2, 0)
			m.spawn_shot(P, at, Vector2(fire) * SHOT_SPEED, 1.0, 5.0, 0.12, Color("ffd66b"))
	var t := 0.0
	while t < SETTLE:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(prefix + file + ".png"))


func _run_compat_child() -> void:
	var args := ["--path", ProjectSettings.globalize_path("res://"), "--rendering-method", "gl_compatibility"]
	args.append_array(["--rendering-driver", "opengl3", "--audio-driver", "Dummy", "--"])
	args.append_array(OS.get_cmdline_user_args())
	OS.execute(OS.get_executable_path(), args, [], true)


## The player on the middle ground tile, standing and then JUMP_WAIT s into a jump, framed by the match camera.
func _air_shots() -> void:
	main.get_window().size = Vector2i(1920, 1080)
	var w := m.world
	var tile: Vector2i = _find(func(_x, _z, _d): return true)[0]
	P.teleport(Vector3(tile.x + 0.5, w.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5))
	await _settle()
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(prefix + "air_a_stand.png"))
	P.do_jump()
	await _settle(JUMP_WAIT)
	main.get_viewport().get_texture().get_image().save_png(dir.path_join(prefix + "air_b_jump.png"))
	var up := P.global_position.y - w.ground_at(P.pos.x, P.pos.z)
	print("AIRSHOTS %s grounded=%s height=%.2f" % [arch, P.grounded, up])


## --census: every drawn mesh low under each Hunter (standing, then mid-jump), to find what lies at the feet.
func _census() -> void:
	var w := m.world
	var tile: Vector2i = _find(func(_x, _z, _d): return true)[0]
	P.teleport(Vector3(tile.x + 0.5, w.ground_at(tile.x + 0.5, tile.y + 0.5), tile.y + 0.5))
	await _settle()
	_census_at("stand")
	P.do_jump()
	await _settle(JUMP_WAIT)
	_census_at("jump")


func _census_at(tag: String) -> void:
	for h: Hunter in m.hunters:
		var g := w_ground(h)
		for gi in main.find_children("*", "GeometryInstance3D", true, false):
			var n := gi as GeometryInstance3D
			if not n.is_visible_in_tree():
				continue
			var box := n.global_transform * n.get_aabb()
			var c := box.get_center()
			if Vector2(c.x - h.global_position.x, c.z - h.global_position.z).length() > 1.6:
				continue
			if box.position.y > h.global_position.y + 0.35 or box.end.y < g - 0.3:
				continue
			var mat: Variant = n.material_override
			var mi := n as MeshInstance3D
			if mat == null and mi and mi.mesh and mi.mesh.get_surface_count() > 0:
				mat = mi.get_active_material(0)
			var where: NodePath = h.get_path_to(n) if h.is_ancestor_of(n) else n.get_path()
			var mesh_cls: String = mi.mesh.get_class() if mi and mi.mesh else "-"
			var mdesc := "-"
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader:
				mdesc = (mat as ShaderMaterial).shader.resource_path
			elif mat is StandardMaterial3D:
				var sm := mat as StandardMaterial3D
				mdesc = "std alb=%s tex=%s tr=%d" % [sm.albedo_color, sm.albedo_texture != null, sm.transparency]
			elif mat != null:
				mdesc = mat.get_class()
			var fmt := "CENSUS %s %s %s %s mesh=%s size=%s y=%.2f..%.2f gnd=%.2f body=%.2f shadow=%d mat=%s"
			var who := h.arch + ":" + h.pname
			var box_y := [box.size, box.position.y, box.end.y, g, h.global_position.y]
			print(fmt % ([tag, who, n.get_class(), where, mesh_cls] + box_y + [n.cast_shadow, mdesc]))


func w_ground(h: Hunter) -> float:
	return m.world.ground_at(h.global_position.x, h.global_position.z)


func _settle(secs := SETTLE) -> void:
	var t := 0.0
	while t < secs:
		m.step(DT)
		t += DT
		m.cam.snap(P.pos)
		for h in m.hunters:
			h.render(DT, 1.0)
		await main.get_tree().process_frame


func _cls() -> String:
	return Arch.weight(arch) if arch != "" else Data.class_of_save()


func _setup() -> void:
	m = Match.new()
	main.add_child(m)
	var opts := {"teams": 2, "squad": 2, "tier": 0, "length": 1e9, "seed": seed_v, "no_drop": true}
	m.start(opts.merged({"arch": arch, "cls": _cls()}))
	m.set_process(false)
	P = m.player
	for mb in m.mobs:
		mb.queue_free()
	m.mobs.clear()
	for h in m.hunters:
		if "--ring-shadow=off" in OS.get_cmdline_user_args():
			var r := h.model.get_node_or_null("TeamRing") as GeometryInstance3D
			if r:
				r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		h.ctrl = "idle"
		h.inp["move"] = Vector2.ZERO
	var fade = main.get("fade")
	if fade != null:
		await fade.reveal(0.01)
