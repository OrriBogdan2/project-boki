extends "res://tools/vv_shots.gd"
## --hunter-grade-shots --shots-dir=<dir> [--arch=a,b] [--variants=name:key=val;key=val,name2:...]: the 13 Hunters one
## after another on the same spot, under the same light, at the match camera, in a real match (jobq submit --needs
## gpu). Per variant it writes <dir>/<variant>/<arch>.png and one row per Hunter in <dir>/grade_stats.tsv: the
## saturation, value and luminance of the model's own pixels, the luminance gap between its outline pixels and the
## ground just outside them (rim), and between its whole body and the ground; the empty ground's saturation too.
## A variant key "env.<prop>" sets that property on the match's Environment (env.adjustment_saturation=1.2); any
## other key sets that shader parameter on every hero material of the model (far_lift=0). "base" is the game as is.
## --terrain: a real match instead of the arena; per variant one frame over the first island of each biome, and one
## row "terrain <variant> <biome> sat val" of the median saturation and value of the screen's centre.

const DIFF_MIN := 0.12  # colour-balance shift from the empty spot that makes a pixel the model's
const RIM_PX := 2  # the outline band: model pixels this close to a non-model pixel
const GROUND_GAP_PX := 3  # the ground ring starts this far outside the model
const GROUND_PX := 5  # and is this wide

var crop_px := Vector2i(190, 190)
var rows: Array = []
var terrain := false


func run(main_node: Node) -> void:
	main = main_node
	var hunters: Array = Arch.ORDER.duplicate()
	var variants: Array = ["base"]
	for a in OS.get_cmdline_user_args():
		var arg := String(a)
		if arg.begins_with("--shots-dir="):
			dir = arg.substr(12)
		if arg.begins_with("--arch="):
			hunters = Array(arg.substr(7).split(","))
		if arg == "--terrain":
			terrain = true
			extra_opts = {"arena": false, "training": false, "seed": 777}
		if arg.begins_with("--variants="):
			variants = Array(arg.substr(11).split(","))
	DirAccess.make_dir_recursive_absolute(dir)
	await _setup()
	m.hud.visible = false
	P.teleport(home + Vector3(-30, 0, 30))  # the hero and the target out of every crop
	T.teleport(home + Vector3(-30, 0, 40))
	cam_at = home + Vector3(8, 0, 0)
	await _go(0.8)
	var env := m.env.environment
	var env_base := {}
	for v in variants:
		var parts := String(v).split(":")
		var settings := _parse(parts[1] if parts.size() > 1 else "")
		for key in settings:
			if key.begins_with("env."):
				var prop: String = key.substr(4)
				env_base[prop] = env.get(prop)
				env.set(prop, settings[key])
		if terrain:
			await _terrain(parts[0])
		else:
			await _variant(parts[0], settings, hunters)
		for prop in env_base:
			env.set(prop, env_base[prop])
	var f := FileAccess.open(dir.path_join("grade_stats.tsv"), FileAccess.WRITE)
	f.store_line("variant\tarch\tsat\tval\tlum\trim_gap\tbody_gap\tpx\tground_lum\tground_sat")
	for r in rows:
		f.store_line("\t".join(r))
	f.close()
	print("HUNTERGRADE %d rows in %s" % [rows.size(), dir])
	main.get_tree().quit(0)


func _parse(spec: String) -> Dictionary:
	var out := {}
	for kv in spec.split(";", false):
		var p := kv.split("=")
		out[p[0]] = float(p[1])
	return out


func _variant(vname: String, settings: Dictionary, hunters: Array) -> void:
	DirAccess.make_dir_recursive_absolute(dir.path_join(vname))
	await _go(0.3)
	var empty := main.get_viewport().get_texture().get_image()
	var at := cam_at + Vector3(0, 0.8, 0)
	var ground := _ground_sat(empty, at)
	empty.save_png(dir.path_join(vname).path_join("empty.png"))
	for arch in hunters:
		var node := Models.hunter(
			Arch.weight(arch), Data.TEAM_COLORS[0], Arch.signature(arch), "", PlayerLook.neutral(), arch
		)
		node.position = cam_at
		m.add_child(node)
		await _go(0.2)
		_set_params(node, settings)
		await _go(0.5)
		var img := main.get_viewport().get_texture().get_image()
		_crop(img, at, crop_px, 2.0).save_png(dir.path_join(vname).path_join("%s.png" % arch))
		rows.append([vname, arch] + _measure(img, empty, at) + [ground])
		node.queue_free()


func _terrain(vname: String) -> void:
	var seen := {}
	for isl in m.world.islands:
		var biome := String(isl.get("biome", ""))
		if biome == "" or seen.has(biome):
			continue
		seen[biome] = true
		var c: Vector2 = isl["c"]
		var lv: int = int(m.world.level[m.world.idx(int(c.x), int(c.y))])
		cam_at = Vector3(c.x + 0.5, lv * World.LEVEL, c.y + 0.5)
		await _go(0.4)
		var img := main.get_viewport().get_texture().get_image()
		var sats: Array = []
		var vals: Array = []
		for y in range(img.get_height() / 4, img.get_height() * 3 / 4, 4):
			for x in range(img.get_width() / 4, img.get_width() * 3 / 4, 4):
				sats.append(img.get_pixel(x, y).s)
				vals.append(img.get_pixel(x, y).v)
		sats.sort()
		vals.sort()
		rows.append(["terrain", vname, biome, "%.3f" % sats[sats.size() / 2], "%.3f" % vals[vals.size() / 2]])
		img.save_png(dir.path_join("terrain_%s_%s.png" % [vname, biome]))


func _set_params(node: Node, settings: Dictionary) -> void:
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var mats: Array = [(mi as MeshInstance3D).material_override]
		for s in (mi as MeshInstance3D).get_surface_override_material_count():
			mats.append((mi as MeshInstance3D).get_surface_override_material(s))
		for mat in mats:
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader == Models.HERO:
				for key in settings:
					if not key.begins_with("env."):
						(mat as ShaderMaterial).set_shader_parameter(key, settings[key])


## The mean saturation of the empty ground in the crop round `at`.
func _ground_sat(empty: Image, at: Vector3) -> String:
	var c := main.get_viewport().get_camera_3d().unproject_position(at)
	var sum := 0.0
	var n := 0
	for y in range(int(c.y) - 60, int(c.y) + 60, 2):
		for x in range(int(c.x) - 60, int(c.x) + 60, 2):
			sum += empty.get_pixel(x, y).s
			n += 1
	return "%.3f" % (sum / n)


## [sat, val, lum, rim_gap, body_gap, pixels, ground lum] of the model's own pixels (not the empty spot, and not
## the ground its shadow darkens: a shadow keeps the ground's colour balance, a model does not).
func _measure(img: Image, empty: Image, at: Vector3) -> Array:
	var c := main.get_viewport().get_camera_3d().unproject_position(at)
	var x0 := int(c.x) - crop_px.x / 2
	var y0 := int(c.y) - crop_px.y / 2
	var mask := PackedByteArray()
	mask.resize(crop_px.x * crop_px.y)
	for y in crop_px.y:
		for x in crop_px.x:
			var a := img.get_pixel(x0 + x, y0 + y)
			var b := empty.get_pixel(x0 + x, y0 + y)
			var la := maxf(a.get_luminance(), 0.001)
			var lb := maxf(b.get_luminance(), 0.001)
			var shift := Vector3(a.r / la - b.r / lb, a.g / la - b.g / lb, a.b / la - b.b / lb).length()
			mask[y * crop_px.x + x] = 1 if shift > DIFF_MIN else 0
	# the discs round the model's edge pixels: the outline band (inside) and the ground ring (outside)
	var near_rim := PackedByteArray()
	var near_far := PackedByteArray()
	var near_gap := PackedByteArray()
	near_rim.resize(mask.size())
	near_far.resize(mask.size())
	near_gap.resize(mask.size())
	var reach := GROUND_GAP_PX + GROUND_PX
	for y in range(reach, crop_px.y - reach):
		for x in range(reach, crop_px.x - reach):
			var i := y * crop_px.x + x
			if (
				mask[i] == 1
				and (mask[i - 1] == 0 or mask[i + 1] == 0 or mask[i - crop_px.x] == 0 or mask[i + crop_px.x] == 0)
			):
				_stamp(near_rim, x, y, RIM_PX)
				_stamp(near_gap, x, y, GROUND_GAP_PX)
				_stamp(near_far, x, y, reach)
	var sums := [0.0, 0.0, 0.0, 0.0, 0.0]  # sat, val, lum, rim lum, ground lum
	var counts := [0, 0, 0]  # model, rim, ground
	for y in range(reach, crop_px.y - reach):
		for x in range(reach, crop_px.x - reach):
			var i := y * crop_px.x + x
			var px := img.get_pixel(x0 + x, y0 + y)
			if mask[i] == 1:
				sums[0] += px.s
				sums[1] += px.v
				sums[2] += px.get_luminance()
				counts[0] += 1
				if near_rim[i] == 1:
					sums[3] += px.get_luminance()
					counts[1] += 1
			elif near_far[i] == 1 and near_gap[i] == 0:
				sums[4] += px.get_luminance()
				counts[2] += 1
	var n := maxi(counts[0], 1)
	var g: float = sums[4] / maxi(counts[2], 1)
	return [
		"%.3f" % (sums[0] / n),
		"%.3f" % (sums[1] / n),
		"%.3f" % (sums[2] / n),
		"%.3f" % (sums[3] / maxi(counts[1], 1) - g),
		"%.3f" % (sums[2] / n - g),
		str(counts[0]),
		"%.3f" % g
	]


## Marks the disc of radius r round (x, y).
func _stamp(into: PackedByteArray, x: int, y: int, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				into[(y + dy) * crop_px.x + x + dx] = 1
