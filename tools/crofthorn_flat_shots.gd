extends "res://tools/toon_lineup_farm_shots.gd"
## --crofthorn-flat-shots --shots-dir=<dir> [--cam=farm|combat] [--close] [--spots=x:z;x:z] [--species=a,b,c,d]
## [--fullres=WxH]: Crofthorn standing in a row with three other Boki on the real farm (third-person camera) or at
## the match camera. Per spot it writes the whole frame at native size (1920x1080 unless --fullres, no resize):
## <dir>/<cam>[_close]_s<i>_{after,before}.png, plus two close cameras on Crofthorn (3/4 front and 3/4 from behind, the
## spine) as <dir>/tele_{front,back}_s<i>_{after,before}.png, rendered by a real camera 1.1 m away, not a crop.
## "after" is the game's look; "before" (--before-atlas=<file>) draws the coat atlas the game had before, with no
## override. <dir>/coat_stats_<cam>.tsv: luminance std-dev, mean luminance and saturation of each model's own pixels
## (edge pixels left out). Needs a renderer (jobq submit --needs gpu).

const TELE_FOV := 30.0
const TELE_VIEWS := {"front": Vector3(0.55, 0.5, 1.0), "back": Vector3(-0.5, 0.95, -0.85)}
const CROFT := "heatherhorn"

var cam_mode := "farm"
var full := Vector2i(1920, 1080)
var species: Array = ["kilnbadger", "heatherhorn", "glaciyak", "nimbostrich"]
var close := false
var spots: Array = [Vector2(56.0, 29.0)]
var nodes: Array = []
var combat_owner = null
var tele_cam: Camera3D
var base_cam: Camera3D  # the scene's own camera, put back after a close camera
var rows: Array = []
var tele_only := false
# name, Crofthorn coat uniforms put over the game's ("_atlas": a coat atlas to draw)
var passes: Array = [["after", {}]]


func run(main_node: Node) -> void:
	main = main_node
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--cam="):
			cam_mode = arg.substr(6)
		if arg.begins_with("--species="):
			species = Array(arg.substr(10).split(","))
		if arg.begins_with("--fullres="):
			var p := arg.substr(10).split("x")
			full = Vector2i(int(p[0]), int(p[1]))
		if arg.begins_with("--spots="):
			spots = []
			for s in arg.substr(8).split(";"):
				var xz := s.split(":")
				spots.append(Vector2(float(xz[0]), float(xz[1])))
	close = "--close" in OS.get_cmdline_user_args()
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--variants="):  # name:albedo_flat:lod:contrast:desat:dark_lift:gain;...
			for v in String(a).substr(11).split(";"):
				var f := v.split(":")
				var look := {
					"albedo_flat": float(f[1]),
					"albedo_flat_lod": float(f[2]),
					"albedo_flat_contrast": float(f[3]),
					"desat": float(f[4]),
					"dark_lift": float(f[5]),
					"albedo_flat_gain": float(f[6]),
					"albedo_flat_key": Vector3(0.72, 0.165, 0.116),
					"albedo_flat_key_width": 0.1
				}
				passes.append([f[0], look])
		if String(a).begins_with("--before-atlas="):  # the coat atlas the game had before (a file under res://)
			passes.append(["before", {"_atlas": String(a).substr(15)}])
		if String(a) == "--tele-only":
			tele_only = true
	DirAccess.make_dir_recursive_absolute(dir)
	main.get_window().size = full
	main.get_viewport().size = full
	var base: Vector3 = await _stage_cam()
	var spacing := 1.0 if cam_mode == "farm" else 1.3
	var tag := cam_mode + ("_close" if close else "")
	for pass_i in passes:
		var state: String = pass_i[0]
		for si in spots.size():
			_clear_row()
			var spot := await _move_to(si, base)
			await _settle(0.8)
			_last_empty = main.get_viewport().get_texture().get_image()  # (the spot without the row)
			_spawn_row(spot, spacing)
			var croft: Node3D = nodes[species.find(CROFT)]
			var look: Dictionary = (pass_i[1] as Dictionary).duplicate()
			if look.has("_atlas"):
				_swap_atlas(croft, String(look["_atlas"]))
				look.erase("_atlas")
			if not look.is_empty():
				_apply_look(croft, look)
			await _settle(1.2)
			if not tele_only:
				_shoot(tag, state, si)
			if cam_mode == "farm" or si == 0:
				await _tele(state, si)
	var f := FileAccess.open(dir.path_join("coat_stats_%s.tsv" % tag), FileAccess.WRITE)
	f.store_line("cam\tstate\tspot\tspecies\tlum_std\tlum\tsat\tpixels")
	for r in rows:
		f.store_line(r)
	f.close()
	print("CROFTFLAT %s done in %s" % [tag, dir])
	main.get_tree().quit(0)


func _stage_cam() -> Vector3:
	if cam_mode == "farm":
		return await _stage()
	var inner = load("res://tools/toon_lineup_shots.gd").new()  # the match staging, which this tool cannot extend too
	inner.main = main
	var spot: Vector3 = await inner._stage()
	world = inner.world
	combat_owner = inner
	for layer in main.find_children("*", "CanvasLayer", true, false):  # (the drill card, hotbar and tips)
		(layer as CanvasLayer).visible = false
	return spot


## The camera on spots[si] (the farm: the third-person camera moves there; the match: one spot only).
func _move_to(si: int, base: Vector3) -> Vector3:
	var spot := base
	if cam_mode == "farm":
		spot = farm.world.free_spot_near(Vector3(spots[si].x, 0, spots[si].y), [], 0.8)
		farm.ppos = spot + Vector3(0, 0, 2.4)
		farm.player.position = farm.ppos
		farm.cam.snap(farm.ppos)
	return spot


func _spawn_row(spot: Vector3, spacing: float) -> void:
	for i in species.size():
		var at := spot + Vector3((i - (species.size() - 1) * 0.5) * spacing, 0, 0)
		var node: Node3D = _spawn(["boki", species[i]], at)
		node.rotation.y = PI + (0.0 if i % 2 == 0 else 0.35)  # (the export faces -Z: PI turns it to the camera)
		nodes.append(node)


func _clear_row() -> void:
	for n in nodes:
		(n as Node3D).queue_free()
	nodes.clear()


func _shoot(tag: String, state: String, si: int) -> void:
	var img := main.get_viewport().get_texture().get_image()
	img.save_png(dir.path_join("%s_s%d_%s.png" % [tag, si, state]))
	_measure(tag, state, si, img)


func _tele(state: String, si: int) -> void:
	var croft: Node3D = nodes[species.find(CROFT)]
	if tele_cam == null:
		base_cam = main.get_viewport().get_camera_3d()
		tele_cam = Camera3D.new()
		tele_cam.fov = TELE_FOV
		tele_cam.near = 0.05
		(world if world != null else main).add_child(tele_cam)
	for view in TELE_VIEWS:
		var g := croft.global_position + Vector3(0, 0.3, 0)
		tele_cam.global_position = g + (TELE_VIEWS[view] as Vector3) * 1.1
		tele_cam.look_at(g, Vector3.UP)
		tele_cam.current = true
		await _settle(0.3)
		main.get_viewport().get_texture().get_image().save_png(
			dir.path_join("tele_%s_s%d_%s.png" % [view, si, state])
		)
	base_cam.current = true
	await _settle(0.1)


func _settle(secs: float) -> void:
	if combat_owner != null:
		await combat_owner._settle(secs)
	else:
		await super._settle(secs)


func _spawn(row: Array, at: Vector3) -> Node3D:
	if combat_owner != null:
		return combat_owner._spawn(row, at)
	return super._spawn(row, at)


## A Boki's painted-coat materials (the atlas) with these shader uniforms put over the game's; albedo_flat* only on
## the atlas, so the face and eyes keep their texture.
func _apply_look(node: Node, look: Dictionary) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			var mat := (mi as MeshInstance3D).get_active_material(s)
			if (
				mat is ShaderMaterial
				and (mat as ShaderMaterial).get_shader_parameter("use_tex") == true
			):
				var tex: Texture2D = (mat as ShaderMaterial).get_shader_parameter("albedo_tex")
				var coat := tex.resource_path.contains("atlas")
				for k in look:
					if coat or not String(k).begins_with("albedo_flat"):
						(mat as ShaderMaterial).set_shader_parameter(k, look[k])


## Each model's own pixels, found against the frame with the models hidden (self.empty), a pixel belonging to the
## nearest model; a pixel with a background pixel two steps away is an edge or an ink line and is left out.
func _measure(tag: String, state: String, si: int, img: Image) -> void:
	var cam := main.get_viewport().get_camera_3d()
	var centres: Array = []
	for n in nodes:
		centres.append(cam.unproject_position((n as Node3D).global_position + Vector3(0, 0.3, 0)))
	var empty: Image = _last_empty
	var w := img.get_width()
	var h := img.get_height()
	var mask := PackedByteArray()
	mask.resize(w * h)
	var y0 := maxi(int((centres.map(func(c): return c.y).min()) - 200.0), 0)
	var y1 := mini(int((centres.map(func(c): return c.y).max()) + 200.0), h)
	for y in range(y0, y1):
		for x in w:
			var a := img.get_pixel(x, y)
			var b := empty.get_pixel(x, y)
			var la := maxf(a.get_luminance(), 0.001)
			var lb := maxf(b.get_luminance(), 0.001)
			var d := Vector3(a.r / la - b.r / lb, a.g / la - b.g / lb, a.b / la - b.b / lb).length()
			mask[y * w + x] = 1 if d > DIFF_MIN else 0
	for i in nodes.size():
		var c: Vector2 = centres[i]
		var lums: Array = []
		var sat := 0.0
		for y in range(maxi(int(c.y) - 160, 2), mini(int(c.y) + 160, h - 2)):
			for x in range(maxi(int(c.x) - 160, 2), mini(int(c.x) + 160, w - 2)):
				var p := Vector2(x, y)
				var nearest := 0
				for j in centres.size():
					if p.distance_to(centres[j]) < p.distance_to(centres[nearest]):
						nearest = j
				if nearest != i or mask[y * w + x] == 0:
					continue
				var at := y * w + x
				if (
					mask[at - 2] == 0
					or mask[at + 2] == 0
					or mask[at - 2 * w] == 0
					or mask[at + 2 * w] == 0
				):
					continue
				var col := img.get_pixel(x, y)
				lums.append(col.get_luminance())
				sat += col.s
		var n := maxi(lums.size(), 1)
		var mean := 0.0
		for l in lums:
			mean += float(l)
		mean /= n
		var var_sum := 0.0
		for l in lums:
			var_sum += (float(l) - mean) * (float(l) - mean)
		var std := sqrt(var_sum / n)
		var row := [tag, state, si, species[i], std, mean, sat / n, lums.size()]
		rows.append("%s\t%s\t%d\t%s\t%.3f\t%.3f\t%.3f\t%d" % row)


var _last_empty: Image
